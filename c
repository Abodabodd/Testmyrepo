import requests
import json
import urllib.parse
import hashlib
import base64
import time
from collections import OrderedDict
import html
import re
from urllib.parse import urljoin
import sys

# Optional import for better HTML parsing; fallback to regex if not available
try:
    from bs4 import BeautifulSoup  # type: ignore
    HAVE_BS4 = True
except Exception:
    HAVE_BS4 = False

# --- Configuration ---
FIREBASE_PROJECT_ID = "animewitcher-1c66d"
ALGOLIA_APP_ID = "V67NZNF3RR"
ALGOLIA_API_KEY = "2a0e44dbb2b46865f88fd584d154d0bd"
ALGOLIA_INDEX_NAME = "series"
BU_AUTH_KEY = None  # ضع مفتاح BunnyCDN هنا إن وجد

# --- Utility functions ---
def remove_till_word(input_str, word):
    idx = input_str.find(word)
    if idx != -1:
        return input_str[idx:]
    return input_str

def remove_after_word(input_str, word):
    idx = input_str.find(word)
    if idx != -1:
        return input_str[:idx]
    return input_str

def get_final_url_python(initial_url, session=None):
    try:
        sess = session or requests
        response = sess.get(initial_url, allow_redirects=True, timeout=12)
        response.raise_for_status()
        return response.url
    except requests.exceptions.RequestException as e:
        print(f"  [ERROR] Network error resolving URL {initial_url}: {e}", file=sys.stderr)
        return None

def get_final_download_url_python(initial_url, session=None):
    try:
        sess = session or requests
        response = sess.get(initial_url, allow_redirects=False, timeout=12)
        response.raise_for_status()
        if response.status_code in [301, 302, 303]:
            redirected_url = response.headers.get("Location")
            if redirected_url:
                return requests.compat.urljoin(initial_url, redirected_url)
            else:
                return initial_url
        else:
            return initial_url
    except requests.exceptions.RequestException as e:
        print(f"  [ERROR] Network error resolving redirect for {initial_url}: {e}", file=sys.stderr)
        return None

def encode_value_python(value):
    return urllib.parse.quote(value, safe='')

def add_countries_python(url, countries_allowed, countries_blocked):
    temp_url = url
    if len(countries_allowed) > 0:
        temp_url += ("?" if "?" not in temp_url else "&") + "token_countries=" + countries_allowed
    if len(countries_blocked) > 0:
        temp_url += ("?" if "?" not in temp_url else "&") + "token_countries_blocked=" + countries_blocked
    return temp_url

def sign_url_python(
    url_in, security_key_in, expiration_time_in="28800", user_ip_in="",
    is_directory_in=False, path_allowed_in=None, countries_allowed_in=None, countries_blocked_in=None
):
    if not security_key_in:
        # Caller should provide key
        return None

    countries_allowed = countries_allowed_in if countries_allowed_in is not None else ""
    countries_blocked = countries_blocked_in if countries_blocked_in is not None else ""
    is_directory = is_directory_in

    url = add_countries_python(url_in, countries_allowed, countries_blocked)
    parsed_url = urllib.parse.urlparse(url)
    
    expires = int(time.time()) + int(expiration_time_in)

    query_params = urllib.parse.parse_qs(parsed_url.query, keep_blank_values=True)
    params_for_sorting = {}
    for k, v_list in query_params.items():
        if v_list:
            params_for_sorting[k] = v_list[0]
        else:
            params_for_sorting[k] = ""

    parameters_map = OrderedDict(sorted(params_for_sorting.items()))

    parameter_data_url = ""
    hashable_base_params = ""
    
    for key, value in parameters_map.items():
        if hashable_base_params:
            hashable_base_params += "&"
        hashable_base_params += f"{key}={value}"
        
        parameter_data_url += "&" + key + "=" + encode_value_python(value)

    signature_path = path_allowed_in if path_allowed_in is not None else parsed_url.path

    hashable_string_parts = [
        security_key_in,
        signature_path,
        str(expires),
        hashable_base_params,
        user_ip_in if user_ip_in else ""
    ]
    hashable_base_final = "".join(hashable_string_parts)
    
    sha256_hash = hashlib.sha256(hashable_base_final.encode('utf-8')).digest()
    
    token = base64.b64encode(sha256_hash).decode('utf-8')
    token = token.replace("\n", "").replace("+", "-").replace("/", "_").replace("=", "")
    
    if not is_directory:
        final_url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}?token={token}{parameter_data_url}&expires={expires}"
    else:
        final_url = f"{parsed_url.scheme}://{parsed_url.netloc}/bcdn_token={token}{parameter_data_url}&expires={expires}{parsed_url.path}"

    return final_url


# --- Provider class (improved) ---
class AnimeWitcherCloudstreamProvider:
    def __init__(self, firebase_project_id, algolia_app_id, algolia_api_key, algolia_index_name, bu_auth_key=None):
        self.firebase_project_id = firebase_project_id
        self.algolia_app_id = algolia_app_id
        self.algolia_api_key = algolia_api_key
        self.algolia_index_name = algolia_index_name
        self.algolia_search_url = f"https://{algolia_app_id}-dsn.algolia.net/1/indexes/{algolia_index_name}/query"
        self.bu_auth_key = bu_auth_key

        # Cache to avoid repeated Firestore calls
        self.cache_episodes = {}   # anime_id -> episodes list
        self.cache_servers = {}    # (anime_id, episode_id) -> servers list
        self.server_words_cache = {}

        # pre-fill known server words (safe defaults)
        self.server_words_cache["MF"] = {
            "name": "MF",
            "word1": "<div class=\"download-buttons\">",
            "word2": "</div>",
            "word3": "src=\"",
            "word4": "\""
        }
        # PD words often: <video src="..."> or <source src="...">
        self.server_words_cache["PD"] = {
            "name": "PD",
            "word1": "<video src=\"",
            "word2": "\"",
            "word3": None,
            "word4": None
        }

        # Session reuse for speed and reliability
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (compatible; AnimeWitcherBot/1.0)"
        })

    # Firestore REST fetch helper
    def _fetch_from_firestore_rest(self, doc_path):
        url = f"https://firestore.googleapis.com/v1/projects/{self.firebase_project_id}/databases/(default)/documents/{doc_path}"
        try:
            r = self.session.get(url, timeout=12)
            r.raise_for_status()
            return r.json()
        except (requests.exceptions.RequestException, json.JSONDecodeError, KeyError) as e:
            print(f"  [ERROR] Firestore fetch error for {doc_path}: {e}", file=sys.stderr)
            return None

    # Get server words (with caching)
    def _get_server_words(self, server_name):
        if server_name in self.server_words_cache:
            return self.server_words_cache[server_name]
        
        data = self._fetch_from_firestore_rest(f"Settings/servers/servers/{server_name}")
        if data and "fields" in data:
            f = data["fields"]
            words = {
                "name": server_name,
                "word1": f.get("word1", {}).get("stringValue"),
                "word2": f.get("word2", {}).get("stringValue"),
                "word3": f.get("word3", {}).get("stringValue"),
                "word4": f.get("word4", {}).get("stringValue")
            }
            self.server_words_cache[server_name] = words
            return words
        return None

    # Algolia search (build safe params string)
    def search_anime(self, query=""):
        headers = {
            "X-Algolia-Application-Id": self.algolia_app_id,
            "X-Algolia-API-Key": self.algolia_api_key,
            "Content-type": "application/json; charset=UTF-8",
            "User-Agent": "Algolia for Android (3.27.0); Android (13)"
        }

        # attributes list as JSON string, then URL-encode it
        attributes = json.dumps(["name", "poster_uri", "objectID", "details", "tags", "story", "english_title"])
        encoded_attributes = urllib.parse.quote(attributes, safe='')

        params = f"attributesToRetrieve={encoded_attributes}&hitsPerPage=200&page=0&query={urllib.parse.quote(query)}"
        payload = {"params": params}

        try:
            r = self.session.post(self.algolia_search_url, headers=headers, json=payload, timeout=15)
            r.raise_for_status()
            data = r.json()
            hits = data.get("hits", [])
            anime_list = []
            for hit in hits:
                anime_list.append({
                    "id": hit.get("objectID"),
                    "name": hit.get("name"),
                    "details": hit.get("details", {}),
                    "poster_uri": hit.get("poster_uri"),
                    "tags": hit.get("tags", []),
                    "story": hit.get("story") or hit.get("_highlightResult", {}).get("story", {}).get("value"),
                })
            return anime_list
        except requests.exceptions.RequestException as e:
            print(f"  [ERROR] Algolia search failed: {e}", file=sys.stderr)
            return []

    # Fetch episodes (cached)
    def fetch_episodes(self, anime_id):
        if anime_id in self.cache_episodes:
            return self.cache_episodes[anime_id]

        collection_path = f"anime_list/{anime_id}/episodes"
        # REST list documents endpoint
        url = f"https://firestore.googleapis.com/v1/projects/{self.firebase_project_id}/databases/(default)/documents/{collection_path}"
        try:
            r = self.session.get(url, timeout=15)
            r.raise_for_status()
            data = r.json()
            episodes = []
            for doc in data.get("documents", []):
                doc_id = doc["name"].split("/")[-1]
                fields = doc.get("fields", {})
                num = 0
                if "number" in fields and "integerValue" in fields["number"]:
                    try:
                        num = int(fields["number"]["integerValue"])
                    except Exception:
                        num = 0
                episodes.append({
                    "id": doc_id,
                    "name": fields.get("name", {}).get("stringValue"),
                    "number": num,
                    "release_date": fields.get("release_date", {}).get("stringValue") if "release_date" in fields else None
                })
            episodes.sort(key=lambda x: x.get("number", 0))
            self.cache_episodes[anime_id] = episodes
            return episodes
        except (requests.exceptions.RequestException, ValueError) as e:
            print(f"  [ERROR] Fetch episodes failed for {anime_id}: {e}", file=sys.stderr)
            return []

    # Fetch servers for a given episode (cached)
    def _fetch_servers_for_episode(self, anime_id, episode_id):
        key = (anime_id, episode_id)
        if key in self.cache_servers:
            return self.cache_servers[key]

        # Try servers2/all_servers
        doc_path = f"anime_list/{anime_id}/episodes/{episode_id}/servers2/all_servers"
        data = self._fetch_from_firestore_rest(doc_path)
        servers = []
        if data and "fields" in data and "servers" in data["fields"]:
            raw = data["fields"]["servers"]["arrayValue"].get("values", [])
            for item in raw:
                f = item["mapValue"]["fields"]
                s = {
                    "name": f.get("name", {}).get("stringValue"),
                    "quality": f.get("quality", {}).get("stringValue"),
                    "link": f.get("link", {}).get("stringValue"),
                    "open_browser": f.get("open_browser", {}).get("booleanValue", False),
                    "original_link": f.get("original_link", {}).get("stringValue")
                }
                if s["name"] and s["link"]:
                    servers.append(s)
            self.cache_servers[key] = servers
            return servers

        # Fallback to collection servers
        coll_path = f"anime_list/{anime_id}/episodes/{episode_id}/servers"
        url = f"https://firestore.googleapis.com/v1/projects/{self.firebase_project_id}/databases/(default)/documents/{coll_path}"
        try:
            r = self.session.get(url, timeout=12)
            r.raise_for_status()
            data = r.json()
            for doc in data.get("documents", []):
                f = doc.get("fields", {})
                s = {
                    "name": f.get("name", {}).get("stringValue"),
                    "quality": f.get("quality", {}).get("stringValue"),
                    "link": f.get("link", {}).get("stringValue"),
                    "open_browser": f.get("open_browser", {}).get("booleanValue", False),
                    "original_link": f.get("original_link", {}).get("stringValue")
                }
                # only visible servers
                if s["name"] and s["link"] and f.get("visible", {}).get("booleanValue", True):
                    servers.append(s)
            self.cache_servers[key] = servers
            return servers
        except Exception as e:
            print(f"  [ERROR] Fetch servers collection failed: {e}", file=sys.stderr)
            return []

    # Resolve links (improved PD handling)
    def _resolve_server_link(self, server_model, server_words):
        server_name = server_model.get("name")
        initial_link = server_model.get("link")
        final_uri = None

        try:
            # Use session
            resp = self.session.get(initial_link, timeout=15)
            resp.raise_for_status()
            text = resp.text

            if server_name == "MF":
                # existing MF logic (kept as-is but using session)
                s = remove_till_word(text, server_words["word1"])
                s2 = remove_after_word(s, server_words["word2"])
                extracted_part1 = s2.replace(server_words["word1"], "").replace(server_words["word2"], "").strip()
                if extracted_part1.endswith('>'):
                    extracted_part1 = extracted_part1[:-1]
                new_link = f"https://{extracted_part1}"
                r2 = self.session.get(new_link, timeout=15)
                r2.raise_for_status()
                s = remove_till_word(r2.text, server_words["word3"])
                s2 = remove_after_word(s, server_words["word4"])
                final_uri = s2.replace(server_words["word3"], "").replace(server_words["word4"], "")

            elif server_name == "PD":  # Pixeldrain - improved extractor
                try:
                    getter = getattr(self, "session", requests)
                    resp = getter.get(initial_link, timeout=15)
                    resp.raise_for_status()
                    html_text = resp.text

                    import re, html
                    from urllib.parse import urljoin

                    final_uri = None

                    # ✅ 1. حاول استخراج من og:video (أبسط وأسرع)
                    m = re.search(r'<meta property="og:video" content="([^"]+)"', html_text)
                    if m:
                        final_uri = html.unescape(m.group(1))

                    # ✅ 2. أو من زر التحميل الرئيسي (رابط /u/xxxxx)
                    if not final_uri:
                        m = re.search(r'href="(/u/[A-Za-z0-9_-]+)"[^>]*>\s*(Download|تحميل|download)', html_text, re.I)
                        if m:
                            final_uri = urljoin(initial_link, m.group(1))

                    # ✅ 3. أو من سكربت JSON يحتوي file id
                    if not final_uri:
                        m = re.search(r'"(/u/[A-Za-z0-9_-]+)"', html_text)
                        if m:
                            final_uri = urljoin(initial_link, m.group(1))

                    # ✅ 4. fallback: أي رابط /u/xxxx موجود
                    if not final_uri:
                        m = re.search(r'https?://pixeldrain\.com/u/[A-Za-z0-9_-]+', html_text)
                        if m:
                            final_uri = m.group(0)

                    # ✅ إذا ما وجدنا شيء
                    if not final_uri:
                        print(f"  [WARN] لم يتم العثور على رابط الفيديو في صفحة Pixeldrain ({initial_link})")
                        final_uri = initial_link  # fallback

                    final_uri = html.unescape(final_uri).replace("&amp;", "&")
                    return final_uri

                except Exception as e:
                    print(f"  [ERROR] مشكلة في استخراج رابط PD: {e}")
                    return initial_link
            elif server_name == "ST":
                if '=' in initial_link:
                    streamtape_id = initial_link[initial_link.index('=') + 1:].strip()
                else:
                    streamtape_id = initial_link.strip()
                if "+" in streamtape_id:
                    print("  [WARNING] Streamtape ID contains '+', cannot resolve.", file=sys.stderr)
                    return None
                final_uri = f"https://streamtape.com/get_video?id={streamtape_id}&dl=1"

            elif server_name == "AR":
                final_uri = get_final_url_python(initial_link, session=self.session)

            elif server_name == "WC":
                final_uri = get_final_download_url_python(initial_link, session=self.session)

            elif server_name == "BU":
                if self.bu_auth_key:
                    final_uri = sign_url_python(initial_link, self.bu_auth_key)
                else:
                    print("  [WARNING] BunnyCDN key not provided; skipping BU.", file=sys.stderr)
                    return None

            elif server_name == "QI":
                final_uri = server_model.get("original_link", initial_link)

            else:
                # Generic: try using server_words if available, else attempt to find <video|source|href>
                if server_words and server_words.get("word1"):
                    s = remove_till_word(text, server_words["word1"])
                    s2 = remove_after_word(s, server_words["word2"] if server_words.get("word2") else "")
                    final_uri = s2.replace(server_words.get("word1",""), "").replace(server_words.get("word2",""), "").replace("amp;", "")
                else:
                    # generic regex fallback
                    m = re.search(r'(https?://[^\s"\'<>]+(?:mp4|m3u8|mkv|mpd|m4s))', text)
                    if m:
                        final_uri = m.group(1)

        except requests.exceptions.RequestException as e:
            print(f"  [ERROR] Network error resolving link for {server_name} ({initial_link}): {e}", file=sys.stderr)
            return None
        except Exception as e:
            print(f"  [ERROR] General error resolving link for {server_name} ({initial_link}): {e}", file=sys.stderr)
            return None

        return final_uri

    # Public: fetch episode stream links
    def fetch_episode_stream_links(self, anime_id, episode_id):
        servers = self._fetch_servers_for_episode(anime_id, episode_id)
        results = []
        for s in servers:
            name = s.get("name")
            words = self._get_server_words(name) or {}
            final = self._resolve_server_link(s, words)
            if final:
                results.append({
                    "name": name,
                    "quality": s.get("quality"),
                    "url": final
                })
        return results


# --- Interactive CLI (simple) ---
def run_interactive_session():
    provider = AnimeWitcherCloudstreamProvider(
        firebase_project_id=FIREBASE_PROJECT_ID,
        algolia_app_id=ALGOLIA_APP_ID,
        algolia_api_key=ALGOLIA_API_KEY,
        algolia_index_name=ALGOLIA_INDEX_NAME,
        bu_auth_key=BU_AUTH_KEY
    )

    selected_anime = None
    selected_episode = None

    while True:
        print("\n--- قائمة الخيارات ---")
        print("1. البحث عن أنمي")
        if selected_anime:
            print(f"2. عرض حلقات الأنمي: {selected_anime['name']} (ID: {selected_anime['id']})")
        if selected_episode:
            print(f"3. جلب روابط بث الحلقة: {selected_episode['name']} (ID: {selected_episode['id']})")
        print("4. الخروج")

        choice = input("اختر رقم الخيار: ").strip()

        if choice == '1':
            q = input("أدخل اسم الأنمي: ").strip()
            results = provider.search_anime(q)
            if not results:
                print("لم يتم العثور على نتائج.")
                selected_anime = None
                continue
            for i, a in enumerate(results, 1):
                print(f"{i}. {a['name']}  [ID: {a['id']}]")
            try:
                idx = int(input(f"اختر رقم الأنمي (1-{len(results)}): ")) - 1
                if 0 <= idx < len(results):
                    selected_anime = results[idx]
                    selected_episode = None
                    print(f"تم اختيار: {selected_anime['name']}")
                else:
                    print("اختيار غير صالح.")
            except Exception:
                print("إدخال غير صحيح.")

        elif choice == '2':
            if not selected_anime:
                print("اختر أنمي أولًا (الخيار 1).")
                continue
            eps = provider.fetch_episodes(selected_anime['id'])
            if not eps:
                print("لم يتم العثور على حلقات.")
                continue
            for i, e in enumerate(eps, 1):
                print(f"{i}. الحلقة {e.get('number')} - {e.get('name')}  [ID: {e.get('id')}]")
            try:
                idx = int(input(f"اختر رقم الحلقة (1-{len(eps)}): ")) - 1
                if 0 <= idx < len(eps):
                    selected_episode = eps[idx]
                    print(f"تم اختيار الحلقة: {selected_episode['name']}")
                else:
                    print("اختيار غير صالح.")
            except Exception:
                print("إدخال غير صحيح.")

        elif choice == '3':
            if not selected_episode or not selected_anime:
                print("يجب اختيار حلقة أولًا (الخيار 2).")
                continue
            print("جلب الروابط... (قد يستغرق بعض الثواني)")
            links = provider.fetch_episode_stream_links(selected_anime['id'], selected_episode['id'])
            if links:
                for l in links:
                    print(f"- السيرفر: {l['name']}, الجودة: {l['quality']}, الرابط: {l['url']}")
            else:
                print("لا توجد روابط متاحة أو فشل في الحل.")
        elif choice == '4':
            print("تم إغلاق البرنامج. شكرًا.")
            break
        else:
            print("اختيار غير صالح. حاول مجددًا.")


if __name__ == "__main__":
    run_interactive_session()
