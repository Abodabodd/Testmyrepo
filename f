#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
اجلب روابط المشاهدة أولًا ثم روابط التحميل (WitAnime episode).
- يقرأ صفحة الحلقة
- يفك موارد المشاهدة عبر _zG/_zH (x18c.js logic)
- يفك روابط التحميل عبر _m.r / _p* (px9 logic)
- يطبع "Watch links" ثم "Download links" بترتيب الصفحة
"""
import re, requests, base64, json
from urllib.parse import urljoin

URL = "https://witanime.red/episode/akujiki-reijou-to-kyouketsu-koushaku-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-1/"

session = requests.Session()
session.headers.update({"User-Agent": "Mozilla/5.0 (compatible; script/1.0)"})

# FRAMEWORK_HASH values from x18c.js (تعديل يدوي إذا تغيّرت لاحقًا)
_M1 = "1c0f"
_M2 = "3441-e3c2-"
_M3 = "4023-9e8b-"
_M4 = "bee77ff59adf"
FRAMEWORK_HASH = _M1 + _M2 + _M3 + _M4

# ---------- helper HTTP ----------
def fetch(url):
    r = session.get(url, timeout=20)
    r.raise_for_status()
    return r.text

# ---------- helpers for x18c (watch links) ----------
def extract_base64_var(name, text):
    m = re.search(r'var\s+' + re.escape(name) + r'\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else None

def clean_base64_chars(s):
    return re.sub(r'[^A-Za-z0-9+/=]', '', s)

def decode_resource_data_x18c(resource_data_raw, param_offset):
    if not isinstance(resource_data_raw, str):
        # if object, try known keys
        if isinstance(resource_data_raw, dict):
            for k in ("r","resource","data"):
                if k in resource_data_raw and isinstance(resource_data_raw[k], str):
                    resource_data_raw = resource_data_raw[k]
                    break
            else:
                return ""
        else:
            return ""
    rev = resource_data_raw[::-1]
    rev = clean_base64_chars(rev)
    try:
        decoded = base64.b64decode(rev)
    except Exception:
        return ""
    if param_offset and param_offset > 0:
        if param_offset <= len(decoded):
            decoded = decoded[:-param_offset]
        else:
            decoded = b''
    try:
        return decoded.decode('utf-8', errors='replace')
    except:
        return decoded.decode('latin-1', errors='replace')

def get_param_offset(config_settings):
    if not config_settings:
        return 0
    if isinstance(config_settings, list):
        if len(config_settings) > 0 and isinstance(config_settings[0], dict):
            config_settings = config_settings[0]
        else:
            return 0
    k = config_settings.get('k') if isinstance(config_settings, dict) else None
    d = config_settings.get('d') if isinstance(config_settings, dict) else None
    if not k or not d:
        return 0
    try:
        index_key = base64.b64decode(k).decode()
        idx = int(index_key, 10)
        return int(d[idx])
    except Exception:
        return 0

def find_server_elements(html):
    """Return list of tuples (server_id, server_label) in page order."""
    items = []
    # find each <a ... class="server-link"...> ... <span class="ser">LABEL</span>
    for m in re.finditer(r'(<a[^>]+class=["\'][^"\']*server-link[^"\']*["\'][^>]*>.*?</a>)', html, re.DOTALL | re.IGNORECASE):
        tag_html = m.group(1)
        mm = re.search(r'data-server-id\s*=\s*["\']([^"\']+)["\']', tag_html)
        label = None
        ms = re.search(r'<span[^>]+class=["\'][^"\']*ser[^"\']*["\'][^>]*>(.*?)</span>', tag_html, re.DOTALL | re.IGNORECASE)
        if ms:
            label = re.sub(r'\s+', ' ', ms.group(1)).strip()
        if mm:
            items.append((mm.group(1), label or "server-"+mm.group(1)))
    return items

# ---------- helpers for px9 (download links) ----------
def parse_px9_vars(js_text):
    # extract _m.r
    m_r = re.search(r'var\s+_m\s*=\s*\{\s*"r"\s*:\s*"([^"]+)"\s*\}', js_text)
    t_l = re.search(r'var\s+_t\s*=\s*\{\s*"l"\s*:\s*"([^"]+)"\s*\}', js_text)
    s_arr_match = re.search(r'var\s+_s\s*=\s*\[(.*?)\]\s*;', js_text, re.DOTALL)
    s_list = []
    if s_arr_match:
        s_list = re.findall(r'"([^"]*)"', s_arr_match.group(1))
    p_matches = re.findall(r'var\s+(_p\d+)\s*=\s*\[\s*(.*?)\s*\]\s*;', js_text, re.DOTALL)
    p_dict = {}
    for name, body in p_matches:
        items = re.findall(r'"([^"]*)"', body)
        p_dict[name] = items
    return (m_r.group(1) if m_r else None,
            t_l.group(1) if t_l else None,
            s_list, p_dict)

def hex_to_bytes(hexstr):
    if not hexstr:
        return b''
    hexstr = re.sub(r'[^0-9a-fA-F]', '', hexstr)
    return bytes.fromhex(hexstr)

def process_chunk_px9(hexstr, secret_bytes):
    data = hex_to_bytes(hexstr)
    if not data:
        return ""
    keylen = len(secret_bytes)
    out_bytes = bytes((b ^ secret_bytes[i % keylen]) for i, b in enumerate(data))
    try:
        return out_bytes.decode('utf-8')
    except:
        return out_bytes.decode('latin-1', errors='replace')

def decrypt_px9_all(m_r_b64, s_list, p_dict):
    if not m_r_b64:
        return []
    secret_bytes = base64.b64decode(m_r_b64)
    results = []
    count = max(len(s_list), len(p_dict))
    for i in range(count):
        key_p = f"_p{i}"
        if key_p not in p_dict:
            continue
        chunks = p_dict[key_p]
        seq_raw = s_list[i] if i < len(s_list) else None
        if seq_raw:
            seq_json_str = process_chunk_px9(seq_raw, secret_bytes)
            try:
                seq = json.loads(seq_json_str)
            except:
                try:
                    seq = json.loads(json.loads(json.dumps(seq_json_str)))  # weird fallback
                except:
                    seq = None
        else:
            seq = None
        decrypted = [process_chunk_px9(chunk, secret_bytes) for chunk in chunks]
        if seq and len(seq) == len(decrypted):
            arranged = [None] * len(seq)
            for j, pos in enumerate(seq):
                if 0 <= pos < len(decrypted):
                    arranged[pos] = decrypted[j]
                else:
                    arranged.append(decrypted[j])
            final = "".join(part if part is not None else "" for part in arranged)
        else:
            final = "".join(decrypted)
        results.append(final)
    return results

# ---------- main ----------
def main(url):
    print("Fetching page:", url)
    html = fetch(url)

    # --- Watch links (x18c) ---
    zG = extract_base64_var('_zG', html) or extract_base64_var('_zg', html)
    zH = extract_base64_var('_zH', html) or extract_base64_var('_zh', html)
    if not (zG and zH):
        # search inline scripts and external scripts
        script_blocks = re.findall(r'<script[^>]*>(.*?)</script>', html, re.DOTALL|re.IGNORECASE)
        for s in script_blocks:
            if not zG:
                zG = extract_base64_var('_zG', s) or extract_base64_var('_zg', s)
            if not zH:
                zH = extract_base64_var('_zH', s) or extract_base64_var('_zh', s)
            if zG and zH:
                break
        if not (zG and zH):
            srcs = re.findall(r'<script[^>]+src=["\']([^"\']+)["\'][^>]*>', html, re.IGNORECASE)
            for src in srcs:
                src_url = src if src.startswith('http') else urljoin(url, src)
                try:
                    js = fetch(src_url)
                    if not zG:
                        zG = extract_base64_var('_zG', js) or extract_base64_var('_zg', js)
                    if not zH:
                        zH = extract_base64_var('_zH', js) or extract_base64_var('_zh', js)
                    if zG and zH:
                        break
                except Exception:
                    pass

    watch_links = {}
    if zG and zH:
        try:
            resourceRegistry = json.loads(base64.b64decode(zG).decode())
        except Exception as e:
            print("Error parsing resourceRegistry:", e)
            resourceRegistry = None
        try:
            configRegistry = json.loads(base64.b64decode(zH).decode())
        except Exception as e:
            print("Error parsing configRegistry:", e)
            configRegistry = None

        server_elems = find_server_elements(html)
        # iterate in page order
        for sid, label in server_elems:
            # obtain resource_raw safely for dict or list
            resource_raw = None
            config_settings = None
            if isinstance(resourceRegistry, dict):
                resource_raw = resourceRegistry.get(sid)
                if resource_raw is None:
                    try:
                        resource_raw = resourceRegistry.get(int(sid))
                    except Exception:
                        pass
            elif isinstance(resourceRegistry, list):
                try:
                    idx = int(sid)
                    if 0 <= idx < len(resourceRegistry):
                        resource_raw = resourceRegistry[idx]
                except Exception:
                    pass
            # config
            if isinstance(configRegistry, dict):
                config_settings = configRegistry.get(sid)
                if config_settings is None:
                    try:
                        config_settings = configRegistry.get(int(sid))
                    except Exception:
                        pass
            elif isinstance(configRegistry, list):
                try:
                    idx = int(sid)
                    if 0 <= idx < len(configRegistry):
                        config_settings = configRegistry[idx]
                except Exception:
                    pass

            if resource_raw is None:
                watch_links[sid] = None
            else:
                param_offset = get_param_offset(config_settings)
                resolved = decode_resource_data_x18c(resource_raw, param_offset)
                # attach FRAMEWORK_HASH if yonaplay
                if re.match(r'^https:\/\/yonaplay\.net\/embed\.php\?id=\d+$', resolved):
                    resolved = resolved + "&apiKey=" + FRAMEWORK_HASH
                watch_links[sid] = {"label": label, "link": resolved}

    # --- Download links (px9) ---
    # find px9 related vars inline or in external script
    scripts_inline = re.findall(r'<script[^>]*>(.*?)</script>', html, re.DOTALL|re.IGNORECASE)
    px_mr = None; px_s = []; px_p = {}
    for s in scripts_inline:
        if "_m" in s and "_p0" in s:
            px_mr, _, px_s, px_p = parse_px9_vars(s)
            break
    if not px_p:
        # try to fetch px9.js
        srcs = re.findall(r'<script[^>]+src=["\']([^"\']+)["\'][^>]*>', html, re.IGNORECASE)
        for src in srcs:
            if 'px9' in src or 'px' in src:
                src_url = src if src.startswith('http') else urljoin(url, src)
                try:
                    js = fetch(src_url)
                    px_mr2, _, px_s2, px_p2 = parse_px9_vars(js)
                    if px_mr2 and not px_mr:
                        px_mr = px_mr2
                    if px_p2:
                        px_p.update(px_p2)
                    if px_s2 and not px_s:
                        px_s = px_s2
                except Exception:
                    pass
    # fallback: parse entire html for px9 vars
    if not px_p:
        px_mr, _, px_s, px_p = parse_px9_vars(html)

    download_links = []
    if px_mr and px_p:
        download_links = decrypt_px9_all(px_mr, px_s, px_p)

    # ---------- Print results: watch links first, then downloads ----------
    print("\n\n===== Watch (iframe) links =====")
    if not watch_links:
        print("No watch links found.")
    else:
        for sid, info in watch_links.items():
            lbl = info["label"] if info else f"server-{sid}"
            link = info["link"] if info else None
            print(f"[{sid}] {lbl}  ->  {link}")

    print("\n\n===== Download links (order p0..pN) =====")
    if not download_links:
        print("No download links found.")
    else:
        for idx, dl in enumerate(download_links):
            if dl and dl.strip():
                print(f"[p{idx}] {dl.strip()}")

if __name__ == "__main__":
    main(URL)
