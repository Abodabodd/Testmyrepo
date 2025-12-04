import requests
import json
import re
import time
import sys # سنستخدمها لتحديث السطر

url = "https://www.YouTube.com/@MrBeast/videos"
# ملاحظة: قد تحتاج إلى تحديث هذا الكوكي "VISITOR_INFO1_LIVE" يدوياً من خلال فحص طلبات الشبكة في المتصفح إذا توقف السكريبت عن العمل.
# وهو ضروري أحياناً للحصول على بيانات "visitorData" الصحيحة.
cookies = {"VISITOR_INFO1_LIVE": "fzYjM8PCwjw"} 
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}
SLEEP_BETWEEN = 0.5
PAGES_TO_FETCH = 6 # الحد الأقصى للصفحات المطلوب جلبها

session = requests.Session()
session.headers.update(HEADERS)

print("جاري طلب الصفحة الرئيسية...")

try:
    response = session.get(url, cookies=cookies, timeout=25)
    response.raise_for_status()
except requests.exceptions.RequestException as e:
    print(f"حدث خطأ أثناء الاتصال بالشبكة: {e}")
    exit()

sys.stdout.write("تم الاتصال بنجاح. جاري تحليل المحتوى...\n")
sys.stdout.flush()

match = re.search(r'var ytInitialData = ({.*?});', response.text)
if not match:
    sys.stdout.write("لم يتم العثور على بيانات (ytInitialData).\n")
    sys.stdout.flush()
    exit()

try:
    json_data = json.loads(match.group(1))
except Exception as e:
    sys.stdout.write(f"فشل تحويل ytInitialData إلى JSON: {e}\n")
    sys.stdout.flush()
    exit()

videos_list = []

def process_video_item(item):
    video_renderer = item.get('videoRenderer')
    if not video_renderer: return False

    video_id = video_renderer.get('videoId')
    title = video_renderer.get('title', {}).get('runs', [{}])[0].get('text')
    view_count = video_renderer.get('viewCountText', {}).get('simpleText', 'N/A')

    thumbnail_url = None
    if 'thumbnail' in video_renderer and 'thumbnails' in video_renderer['thumbnail']:
        thumbnails = video_renderer['thumbnail']['thumbnails']
        if thumbnails:
            thumbnail_url = thumbnails[-1].get('url')

    if video_id and title:
        link = f"https://www.YouTube.com/watch?v={video_id}"
        videos_list.append({
            'title': title, 
            'link': link, 
            'views': view_count, 
            'thumbnail': thumbnail_url
        })
        return True
    return False

# --- البحث عن تبويب الفيديوهات بشكل أكثر موثوقية ---
def find_videos_tab_content(data_obj):
    try:
        tabs = data_obj['contents']['twoColumnBrowseResultsRenderer']['tabs']
        for tab in tabs:
            # قد تحتاج لتعديل 'Videos' أو 'الفيديوهات' حسب لغة الواجهة التي يحصل عليها الكوكي
            if 'tabRenderer' in tab and tab['tabRenderer'].get('title') in ['Videos', 'الفيديوهات']: 
                return tab['tabRenderer']['content']
        # إذا لم يتم العثور بالاسم، جرب الفهرس الثاني كافتراضي (كما كان في الكود الأصلي)
        if len(tabs) > 1 and 'tabRenderer' in tabs[1]:
             print("تحذير: لم يتم العثور على تبويب 'الفيديوهات' بالاسم، تم استخدام التبويب الثاني افتراضياً.")
             return tabs[1]['tabRenderer']['content']
    except (KeyError, IndexError):
        pass
    return None

try:
    video_tab_content = find_videos_tab_content(json_data)
    if not video_tab_content:
        raise Exception("لم يتم العثور على محتوى تبويب الفيديوهات في ytInitialData.")
        
    video_items_container = video_tab_content['richGridRenderer']['contents']

except Exception as e: # Catch the custom exception or general parse errors
    sys.stdout.write(f"بنية ytInitialData غير متوقعة أو مختلفة أو لم يتم العثور على تبويب الفيديوهات: {e}\n")
    sys.stdout.flush()
    video_items_container = []

for item in video_items_container:
    if 'richItemRenderer' in item:
        process_video_item(item['richItemRenderer']['content'])

sys.stdout.write(f"تم جلب {len(videos_list)} فيديو من الصفحة الأولى.\n")
sys.stdout.flush()

def extract_continuation_from_initial(data):
    try:
        video_tab_content = find_videos_tab_content(data)
        if video_tab_content:
            contents = video_tab_content['richGridRenderer']['contents']
            last_item = contents[-1]
            if 'continuationItemRenderer' in last_item:
                return last_item['continuationItemRenderer']['continuationEndpoint']['continuationCommand']['token']
    except (KeyError, IndexError):
        pass
    return None

def find_innertube_key(html_text, key):
    m = re.search(rf'"{re.escape(key)}"\s*:\s*"([^"]+)"', html_text)
    if m: return m.group(1)
    return None

INNERTUBE_API_KEY = find_innertube_key(response.text, "INNERTUBE_API_KEY")
INNERTUBE_CLIENT_VERSION = find_innertube_key(response.text, "INNERTUBE_CLIENT_VERSION")
VISITOR_DATA = cookies.get("VISITOR_INFO1_LIVE")

if not INNERTUBE_API_KEY:
    sys.stdout.write("تحذير: لم أجد INNERTUBE_API_KEY. قد لا تعمل طلبات الاستمرار.\n")
    sys.stdout.flush()
if not INNERTUBE_CLIENT_VERSION:
    sys.stdout.write("تحذير: لم أجد INNERTUBE_CLIENT_VERSION. قد لا تعمل طلبات الاستمرار.\n")
    sys.stdout.flush()
if not VISITOR_DATA:
    sys.stdout.write("تحذير: لم أجد VISITOR_DATA من الكوكيز. قد لا تعمل طلبات الاستمرار.\n")
    sys.stdout.flush()


def fetch_continuation_page(token):
    api_url = f"https://www.YouTube.com/youtubei/v1/browse?key={INNERTUBE_API_KEY}"
    payload = {
        "context": { 
            "client": { 
                "hl": "ar", 
                "gl": "SA", 
                "clientName": "WEB", 
                "clientVersion": INNERTUBE_CLIENT_VERSION, 
                "visitorData": VISITOR_DATA 
            } 
        },
        "continuation": token
    }
    r = session.post(api_url, json=payload, timeout=25)
    r.raise_for_status()
    return r.json()

def extract_items_and_token_from_continuation(data):
    try:
        items = data['onResponseReceivedActions'][0]['appendContinuationItemsAction']['continuationItems']
        next_token = None
        for item in items:
            if 'continuationItemRenderer' in item:
                next_token = item['continuationItemRenderer']['continuationEndpoint']['continuationCommand']['token']
                break 
        return items, next_token
    except (KeyError, IndexError):
        return [], None

current_token = extract_continuation_from_initial(json_data)
if not current_token:
    sys.stdout.write("\nلم أجد رمز استمرار (continuation) بعد الصفحة الأولى. لن يتم جلب صفحات إضافية.\n")
    sys.stdout.flush()
else:
    sys.stdout.write(f"\nبدء جلب {PAGES_TO_FETCH - 1} صفحات إضافية...\n") 
    sys.stdout.flush()
    page_count = 1 # الصفحة الأولى تم جلبها بالفعل
    start_time = time.time()

    # --- بداية التعديل: جلب 6 صفحات ---
    while current_token and page_count < PAGES_TO_FETCH: 
        try:
            page_count += 1 # نزيد عداد الصفحات للإشارة إلى الصفحة التي نقوم بمعالجتها حالياً

            continuation_json = fetch_continuation_page(current_token)
            
            items, next_token = extract_items_and_token_from_continuation(continuation_json)
            
            new_videos_count = 0
            for item in items:
                if 'richItemRenderer' in item:
                    if process_video_item(item['richItemRenderer']['content']):
                        new_videos_count += 1
            
            elapsed_time = time.time() - start_time
            sys.stdout.write(f"  > الوقت المنقضي: {elapsed_time:.1f} ثانية | الصفحات المكتملة: {page_count} من {PAGES_TO_FETCH} | إجمالي الفيديوهات: {len(videos_list)}\r")
            sys.stdout.flush()
            
            current_token = next_token
            
            if not current_token:
                sys.stdout.write("\n\nاكتمل التحميل. تم الوصول إلى آخر صفحة متاحة.\n")
                sys.stdout.flush()
                break # لا توجد صفحات إضافية
            
            time.sleep(SLEEP_BETWEEN)

        except Exception as e:
            sys.stdout.write(f"\nحدث خطأ أثناء جلب الصفحة الإضافية رقم {page_count}: {e}\n")
            sys.stdout.flush()
            break
    
    sys.stdout.write("\n") # سطر جديد بعد تحديث التقدم النهائي
    sys.stdout.flush()
    if page_count >= PAGES_TO_FETCH and current_token: 
        sys.stdout.write(f"تم جلب {PAGES_TO_FETCH} صفحات كما هو مطلوب. لم يتم جلب المزيد من الصفحات.\n")
        sys.stdout.flush()
    # --- نهاية التعديل ---

def save_to_file(data, filename="mrbeast_videos.json"):
    try:
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
        sys.stdout.write(f"\nتم حفظ جميع البيانات بنجاح في ملف: {filename}\n")
        sys.stdout.flush()
    except Exception as e:
        sys.stdout.write(f"\nحدث خطأ أثناء حفظ الملف: {e}\n")
        sys.stdout.flush()

save_to_file(videos_list)

sys.stdout.write(f"\nالعدد الإجمالي للفيديوهات التي تم جلبها: {len(videos_list)}\n")
sys.stdout.flush()

# --- إضافة: طباعة مشاهدات الفيديو لكل فيديو ---
print("\n--- مشاهدات الفيديو ---")
if videos_list:
    for i, video in enumerate(videos_list):
        print(f"{i+1}. العنوان: {video['title']}")
        print(f"   المشاهدات: {video['views']}")
        # print(f"   الرابط: {video['link']}") # اختياري: إذا أردت طباعة الروابط أيضاً
        print("-" * 30)
else:
    print("لم يتم العثور على أي فيديوهات لطباعة مشاهداتها.")
# --- نهاية الإضافة ---

sys.stdout.write("انتهى البرنامج.\n")
sys.stdout.flush()
