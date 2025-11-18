import requests
import json
import re
import time

# ======= إعدادات =======
url = "https://www.youtube.com/"
cookies = {"VISITOR_INFO1_LIVE": "fzYjM8PCwjw"}
HEADERS = { }
MAX_PAGES = 5      # عدد صفحات continuation المراد جلبها (يمكن تغييره)
SLEEP_BETWEEN = 0.8  # ثانية بين كل طلب وآخر

session = requests.Session()
session.headers.update(HEADERS)

print("جاري طلب الصفحة الرئيسية...")
try:
    response = session.get(url, cookies=cookies, timeout=25)
    response.raise_for_status()
except requests.exceptions.RequestException as e:
    print(f"حدث خطأ أثناء الاتصال بالشبكة: {e}")
    exit()

print(f"تم الاتصال بنجاح. جاري تحليل المحتوى...")

# === استخراج ytInitialData ===
match = re.search(r'var ytInitialData = (\{.*?\});', response.text, flags=re.DOTALL)
if not match:
    print("لم يتم العثور على بيانات (ytInitialData).")
    exit()

try:
    json_data = json.loads(match.group(1))
except Exception as e:
    print("فشل تحويل ytInitialData إلى JSON:", e)
    exit()

# ===== مكان تخزين الفيديوهات =====
videos_list = []

# =========================================================================
# === تعديل جذري: دالة المعالجة الآن تبني رابط الصورة مباشرة من videoId ===
# =========================================================================
def process_content(content_item):
    if not isinstance(content_item, dict):
        return

    lockup_renderer = content_item.get('lockupViewModel')
    video_renderer = content_item.get('videoRenderer')
    shorts_lockup_renderer = content_item.get('shortsLockupViewModel') or content_item.get('shortsLockupRenderer') or content_item.get('reelItemPreviewRenderer')

    if lockup_renderer:
        video_id = lockup_renderer.get('contentId')
        title = lockup_renderer.get('metadata', {}).get('lockupMetadataViewModel', {}).get('title', {}).get('content')
        
        # --- الحل الجديد والموثوق: بناء رابط الصورة مباشرة ---
        thumbnail_url = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg" if video_id else None
        
        if video_id and title:
            videos_list.append({'title': title, 'link': f"https://www.youtube.com/watch?v={video_id}", 'thumbnail': thumbnail_url})
        return

    if video_renderer:
        video_id = video_renderer.get('videoId')
        title = None
        t = video_renderer.get('title', {})
        if isinstance(t.get('runs'), list) and t['runs']:
            title = "".join([r.get('text', '') for r in t['runs']])
        else:
            title = t.get('simpleText') or t.get('text')
            
        # --- الحل الجديد والموثوق: بناء رابط الصورة مباشرة ---
        thumbnail_url = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg" if video_id else None

        if video_id and title:
            videos_list.append({'title': title, 'link': f"https://www.youtube.com/watch?v={video_id}", 'thumbnail': thumbnail_url})
        return

    if shorts_lockup_renderer:
        video_id = None
        on_tap = shorts_lockup_renderer.get('onTap') or {}
        video_id = (on_tap.get('innertubeCommand') or {}).get('reelWatchEndpoint', {}).get('videoId') \
                   or (on_tap.get('watchEndpoint') or {}).get('videoId') \
                   or shorts_lockup_renderer.get('videoId')
        title = (shorts_lockup_renderer.get('overlayMetadata') or {}).get('primaryText', {}).get('content') \
                or (shorts_lockup_renderer.get('overlayMetadata') or {}).get('primaryText', {}).get('simpleText')

        # --- الحل الجديد والموثوق: بناء رابط الصورة مباشرة ---
        # بالنسبة للشورتز، الصورة تكون i.ytimg.com/vi/... وليس i.ytimg.com/shorts/...
        thumbnail_url = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg" if video_id else None

        if video_id and title:
            videos_list.append({'title': f"[Shorts] {title}", 'link': f"https://www.youtube.com/shorts/{video_id}", 'thumbnail': thumbnail_url})
        return

# === استخراج عناصر الصفحة الأولى (بدون تغيير) ===
try:
    video_items_container = json_data['contents']['twoColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']['content']['richGridRenderer']['contents']
except Exception as e:
    print("بنية ytInitialData غير متوقعة أو مختلفة:", e)
    video_items_container = []

for item in video_items_container:
    if 'richItemRenderer' in item:
        process_content(item['richItemRenderer'].get('content', {}))
    elif 'richSectionRenderer' in item:
        for content in item.get('richSectionRenderer', {}).get('content', {}).get('richShelfRenderer', {}).get('contents', []):
            if 'richItemRenderer' in content:
                process_content(content['richItemRenderer'].get('content', {}))

# === الطباعة الأولية (بدون تغيير) ===
if videos_list:
    print(f"\n--- نجح التحليل! تم العثور على {len(videos_list)} مقطع (فيديوهات و Shorts) ---\n")
    for i, video in enumerate(videos_list, 1):
        print(f"{i}. العنوان: {video['title']}")
        print(f"   الرابط: {video['link']}")
        print(f"   الصورة: {video.get('thumbnail', 'غير متوفرة')}")
        print("-" * 40)
else:
    print("\nفشل التحليل. لم يتم العثور على أي فيديوهات مطابقة.")

# =========================
# بقية الكود لجلب صفحات Continuation يبقى كما هو بدون تغيير
# =========================

def extract_continuation_from_initial(data):
    try:
        contents = data['contents']['twoColumnBrowseResultsRenderer']['tabs'][0]['tabRenderer']['content']['richGridRenderer']['contents']
        for it in contents:
            if isinstance(it, dict) and 'continuationItemRenderer' in it:
                return it['continuationItemRenderer']['continuationEndpoint']['continuationCommand']['token']
    except Exception:
        pass
    return None

def find_innertube_key(html_text, key):
    m = re.search(rf'"{re.escape(key)}"\s*:\s*"([^"]+)"', html_text)
    if m:
        return m.group(1)
    m2 = re.search(rf"{re.escape(key)}\s*:\s*'([^']+)'", html_text)
    if m2:
        return m2.group(1)
    return None

INNERTUBE_API_KEY = find_innertube_key(response.text, "INNERTUBE_API_KEY")
INNERTUBE_CLIENT_VERSION = find_innertube_key(response.text, "INNERTUBE_CLIENT_VERSION")
VISITOR_DATA = find_innertube_key(response.text, "VISITOR_DATA")

if not INNERTUBE_API_KEY:
    print("تحذير: لم أجد INNERTUBE_API_KEY في الصفحة — قد تفشل طلبات youtubei بدون المفتاح.")
else:
    print("تم العثور على INNERTUBE_API_KEY.")

def fetch_continuation_page(api_key, client_version, visitor_data, token, session_obj, cookies_obj):
    url = f"https://www.youtube.com/youtubei/v1/browse?key={api_key}"
    payload = {
        "context": {
            "client": {
                "visitorData": visitor_data or "",
                "clientName": "WEB",
                "clientVersion": client_version or "2.20251114.01.00",
                "platform": "DESKTOP"
            }
        },
        "continuation": token
    }
    headers = {
        "Content-Type": "application/json",
        "User-Agent": session_obj.headers.get("User-Agent", ""),
        "X-Youtube-Client-Name": "WEB",
        "X-Youtube-Client-Version": client_version or "2.20251114.01.00"
    }
    if visitor_data:
        headers["X-Goog-Visitor-Id"] = visitor_data

    r = session_obj.post(url,  json=payload, cookies=cookies_obj, timeout=25)
    r.raise_for_status()
    return r.json()

def extract_items_from_continuation_json(j):
    items = []
    try:
        items = j["continuationContents"]["richGridContinuation"]["items"]
        return items
    except Exception:
        pass
    try:
        for a in j.get("onResponseReceivedActions", []) + j.get("onResponseReceivedEndpoints", []):
            if isinstance(a, dict) and "appendContinuationItemsAction" in a:
                return a["appendContinuationItemsAction"].get("continuationItems", [])
    except Exception:
        pass
    return items

continuation_token = extract_continuation_from_initial(json_data)
if not continuation_token:
    print("\nلم أجد رمز استمرار (continuation) في الدفعة الأولى. لا توجد صفحات إضافية.")
else:
    print("\nبدأت جلب الصفحات الإضافية (continuation)...")
    page = 0
    while continuation_token and page < MAX_PAGES:
        page += 1
        print(f"\nجلب صفحة continuation رقم {page} ...")
        try:
            j = fetch_continuation_page(INNERTUBE_API_KEY, INNERTUBE_CLIENT_VERSION, VISITOR_DATA, continuation_token, session, cookies)
        except Exception as e:
            print("فشل طلب continuation:", e)
            break

        items = extract_items_from_continuation_json(j)
        if not items:
            print("لم أجد عناصر في صفحة continuation هذه. انتهى.")
            break
            
        new_found = 0
        for it in items:
            if 'richItemRenderer' in it:
                process_content(it['richItemRenderer'].get('content', {}))
                new_found += 1
            elif 'richSectionRenderer' in it:
                shelf_contents = it['richSectionRenderer'].get('content', {}).get('richShelfRenderer', {}).get('contents', [])
                for c in shelf_contents:
                    if 'richItemRenderer' in c:
                        process_content(c['richItemRenderer'].get('content', {}))
                        new_found += 1
            elif 'continuationItemRenderer' in it:
                pass
            else:
                process_content(it)
                new_found += 1

        new_token = None
        for it in items:
            if isinstance(it, dict) and 'continuationItemRenderer' in it:
                new_token = it['continuationItemRenderer']['continuationEndpoint']['continuationCommand']['token']
                break
        if not new_token:
            for a in j.get("onResponseReceivedActions", []):
                if isinstance(a, dict) and "appendContinuationItemsAction" in a:
                    arr = a["appendContinuationItemsAction"].get("continuationItems", [])
                    for it in arr:
                        if 'continuationItemRenderer' in it:
                            new_token = it['continuationItemRenderer']['continuationEndpoint']['continuationCommand']['token']
                            break
                    if new_token:
                        break

        continuation_token = new_token
        print(f"الصفحة {page}: جُمعت تقريباً {new_found} عناصر جديدة. المجموع الآن: {len(videos_list)}")
        time.sleep(SLEEP_BETWEEN)

# === الطباعة النهائية (بدون تغيير) ===
print("\n---- النتائج النهائية (مجمعة) ----")
for i, video in enumerate(videos_list, 1):
    print(f"{i}. العنوان: {video['title']}")
    print(f"   الرابط: {video['link']}")
    print(f"   الصورة: {video.get('thumbnail', 'غير متوفرة')}")
    print("-" * 40)

print("انتهى.")
