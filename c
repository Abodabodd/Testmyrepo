import requests
from bs4 import BeautifulSoup
import json
import re
from collections import defaultdict

# الرؤوس الأساسية لمحاكاة المتصفح
BASE_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'X-Requested-With': 'XMLHttpRequest',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
}

def get_series_data(series_main_url):
    """
    يقوم بجلب وتحليل بيانات مواسم وحلقات مسلسل معين.
    """
    
    BASE_DOMAIN = series_main_url.split('/')[2]
    API_URL = f"https://{BASE_DOMAIN}/season__episodes/"
    
    session = requests.Session()
    all_series_data = {}
    
    # ------------------ الخطوة 1: جلب التوكن ومعرفات المواسم ------------------
    
    print(f"الخطوة 1: جلب الكوكيز والتوكن ومعرفات المواسم من: {series_main_url}")
    try:
        response_initial = session.get(series_main_url, timeout=15)
        response_initial.encoding = 'utf-8'
        
        if response_initial.status_code != 200:
            print(f"(!) فشل جلب الصفحة الأساسية. رمز الحالة: {response_initial.status_code}")
            return {}

        soup = BeautifulSoup(response_initial.text, 'html.parser')

        # استخلاص التوكن (CSRF Token)
        csrf_token_match = re.search(r"'csrf__token':\s+\"([a-f0-9]+)\"", response_initial.text)
        csrf_token = csrf_token_match.group(1) if csrf_token_match else None
        
        if not csrf_token:
            print("(!) فشل في استخلاص توكن الأمان (CSRF Token).")
            return {}

        print("تم الحصول على التوكن بنجاح.")

        # استخلاص Term IDs للمواسم
        seasons_list_div = soup.find('div', id='seasons__list')
        if not seasons_list_div:
            print("(!) لم يتم العثور على قائمة المواسم (#seasons__list).")
            return {}
            
        seasons_to_fetch = {}
        for li in seasons_list_div.find('ul').find_all('li'):
            season_name_tag = li.find('span')
            term_id = li.get('data-term')
            if season_name_tag and term_id:
                seasons_to_fetch[season_name_tag.text.strip()] = term_id
        
        if not seasons_to_fetch:
            print("(!) لم يتم العثور على Term IDs للمواسم.")
            return {}
            
        print(f"تم العثور على {len(seasons_to_fetch)} مواسم متاحة.")

    except requests.exceptions.RequestException as e:
        print(f"حدث خطأ أثناء الاتصال بالصفحة الأساسية: {e}")
        return {}

    # ------------------ الخطوة 2: جلب الحلقات لكل موسم عبر AJAX ------------------
    
    print("\nالخطوة 2: بدء جلب حلقات المسلسل لكل موسم عبر AJAX...")

    # تحديث الرؤوس بإضافة Referer و Origin بناءً على URL الحالي
    current_headers = BASE_HEADERS.copy()
    current_headers['Referer'] = series_main_url
    current_headers['Origin'] = f"https://{BASE_DOMAIN}"

    for season_name, term_id in seasons_to_fetch.items():
        print(f"--- جاري جلب {season_name} (ID: {term_id}) ---")
        
        payload = {
            'season_id': term_id,
            'csrf_token': csrf_token,
        }
        
        try:
            response = session.post(API_URL, data=payload, headers=current_headers, timeout=10)
            response.encoding = 'utf-8'
            
            if response.status_code == 200:
                try:
                    data = response.json()
                except json.JSONDecodeError:
                    # قد تكون المشكلة في أن الخادم يرد بـ 200 لكن يرسل HTML خطأ
                    print(f"(!) فشل تحليل استجابة الموسم {season_name} كـ JSON. (الرد ربما يكون صفحة حماية)")
                    continue
                
                if 'html' in data:
                    episodes = parse_episodes_html(data['html'])
                    if episodes:
                        all_series_data[season_name] = episodes
                        print(f"  > تم جلب {len(episodes)} حلقة بنجاح.")
                    else:
                         print(f"  > تم جلب محتوى HTML لكن لم يتم العثور على أي روابط حلقات.")
                
            else:
                print(f"(!) فشل جلب الموسم {season_name}. رمز الحالة: {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"حدث خطأ أثناء الاتصال بجلب الموسم {season_name}: {e}")

    return all_series_data

def parse_episodes_html(html_content):
    """يحلل HTML المستلم لاستخراج أرقام الحلقات وروابطها."""
    soup = BeautifulSoup(html_content, 'html.parser')
    episodes_details = []
    
    # البحث عن كل عنصر حلقة (يجب أن تكون علامات <a> داخل li)
    for li in soup.find_all('li'):
        episode_link = li.find('a')
        if episode_link:
            url = episode_link.get('href')
            episode_number_tag = li.find('b')
            
            if url and episode_number_tag:
                episode_num = episode_number_tag.text.strip()
                
                episodes_details.append({
                    "name": f"الحلقة {episode_num}",
                    "url": url
                })
                
    # فرز الحلقات تصاعدياً
    if episodes_details:
        try:
            episodes_details.sort(key=lambda x: int(x['name'].split()[-1]), reverse=False)
        except ValueError:
            pass # ترك الترتيب الافتراضي في حالة وجود أسماء غير رقمية
            
    return episodes_details

# ------------------ التنفيذ (لاستخدامها في مسلسلات أخرى) ------------------

# استخدم رابط أي حلقة من المسلسل، وسيقوم الكود باستخلاص Term IDs و التوكن تلقائياً.
SERIES_URL = "https://a.asd.homes/%d9%85%d8%b3%d9%84%d8%b3%d9%84-game-of-thrones-%d8%a7%d9%84%d9%85%d9%88%d8%b3%d9%85-%d8%a7%d9%84%d8%b3%d8%a7%d8%a8%d8%b9-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-5-%d8%a7%d9%84%d8%ae%d8%a7%d9%85%d8%b3/"

final_series_data = get_series_data(SERIES_URL)

print("\n" + "=" * 80)
print("النتائج النهائية (الاسم والرابط لكل حلقة):")
print("=" * 80)

if final_series_data:
    # ترتيب المواسم للطباعة بترتيب منطقي
    season_order = {"الموسم الاول": 1, "الموسم الثاني": 2, "الموسم الثالث": 3, 
                    "الموسم الرابع": 4, "الموسم الخامس": 5}
    
    sorted_season_names = sorted(final_series_data.keys(), 
                                 key=lambda s: season_order.get(s, 99))

    for season_name in sorted_season_names:
        episodes = final_series_data[season_name]
        print(f"\n[{season_name}] ({len(episodes)} حلقة):")
        for episode in episodes:
            print(f"  - {episode['name']}: {episode['url']}")

else:
    print("فشل في جلب البيانات. الرجاء التأكد من صلاحية الرابط وعدم وجود حظر.")

print("=" * 80)
