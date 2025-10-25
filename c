import requests
from bs4 import BeautifulSoup
import re
from concurrent.futures import ThreadPoolExecutor, as_completed

def fetch_season_episodes(session, season_info, headers):
    """
    دالة مخصصة لجلب حلقات موسم واحد. سيتم استدعاؤها بشكل متزامن.
    """
    season_name = season_info['name']
    season_url = season_info['url']
    season_poster = season_info['poster_url']
    
    print(f"--- [Thread] جاري جلب حلقات '{season_name}'...")
    
    try:
        response_season = session.get(season_url, headers=headers, timeout=15)
        response_season.raise_for_status()
        
        soup_season = BeautifulSoup(response_season.content, 'html.parser')
        
        episodes_container = soup_season.find('div', id='epAll')
        if not episodes_container:
            return season_name, None # إرجاع None في حالة الفشل

        episode_tags = episodes_container.find_all('a')
        if not episode_tags:
            return season_name, None

        episodes_list = []
        for tag in episode_tags:
            episode_title = tag.text.strip()
            episode_url = tag.get('href')
            if "باقي الحلقات" in episode_title:
                continue
            episodes_list.append({
                "title": episode_title,
                "url": episode_url
            })
        
        if episodes_list:
            print(f"  [+] [Thread] تم العثور على {len(episodes_list)} حلقة للموسم '{season_name}'.")
            return season_name, {
                "poster": season_poster,
                "episodes": episodes_list
            }
            
    except requests.exceptions.RequestException as e:
        print(f"  [!] [Thread] حدث خطأ أثناء جلب الموسم '{season_name}': {e}")
    
    return season_name, None # إرجاع None في حالة حدوث أي خطأ


def scrape_faselhd_fast(main_series_url):
    """
    يجلب جميع المواسم والحلقات بشكل متزامن لزيادة السرعة.
    """
    BASE_URL = "https://www.faselhds.net"
    HEADERS = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    }
    
    session = requests.Session()
    all_series_data = {}

    # --- الخطوة 1: جلب الصفحة الرئيسية للمواسم (تبقى تسلسلية) ---
    print(f"[*] الخطوة 1: جلب بيانات المواسم من الصفحة الرئيسية: {main_series_url}")
    try:
        response_main = session.get(main_series_url, headers=HEADERS, timeout=15)
        response_main.raise_for_status()
        
        soup_main = BeautifulSoup(response_main.content, 'html.parser')

        series_title_tag = soup_main.find('div', class_='h1-single-title')
        series_title = series_title_tag.text.strip() if series_title_tag else "عنوان غير معروف"
        print(f"[*] اسم المسلسل: {series_title}")

        season_containers = soup_main.find_all('div', class_='seasonDiv')
        if not season_containers:
            print("[!] لم يتم العثور على أي حاويات مواسم (div.seasonDiv).")
            return {}

        season_tasks = []
        for container in season_containers:
            onclick_attr = container.get('onclick')
            if not onclick_attr: continue
            
            match = re.search(r"'\s*(/\?p=\d+)\s*'", onclick_attr)
            if match:
                relative_url = match.group(1)
                full_url = BASE_URL + relative_url
                season_name_tag = container.find('div', class_='season-title')
                season_name = season_name_tag.text.strip() if season_name_tag else f"الموسم {len(season_tasks) + 1}"
                image_tag = container.find('img')
                image_url = image_tag.get('data-src', image_tag.get('src')) if image_tag else "صورة غير متاحة"
                
                season_tasks.append({
                    "name": season_name,
                    "url": full_url,
                    "poster_url": image_url
                })
        
        if not season_tasks:
            print("[!] لم يتم استخلاص أي روابط للمواسم.")
            return {}
            
        print(f"[+] تم العثور على {len(season_tasks)} مواسم. جاري جلب الحلقات بشكل متزامن...")
        # لا نعكس الترتيب هنا، سنقوم بالفرز لاحقًا إذا أردنا
        
    except requests.exceptions.RequestException as e:
        print(f"[!] حدث خطأ أثناء الاتصال بالصفحة الرئيسية: {e}")
        return {}

    # --- الخطوة 2: تنفيذ جلب الحلقات على التوازي ---
    print("\n[*] الخطوة 2: بدء جلب الحلقات من كل صفحة موسم على التوازي...")
    # استخدم max_workers لتحديد عدد المهام المتزامنة، 10 هو عدد جيد
    with ThreadPoolExecutor(max_workers=10) as executor:
        # إنشاء قائمة بالمهام المستقبلية
        future_to_season = {executor.submit(fetch_season_episodes, session, task, HEADERS): task for task in season_tasks}
        
        for future in as_completed(future_to_season):
            season_name, season_data = future.result()
            if season_data:
                all_series_data[season_name] = season_data
            
    return {"series_title": series_title, "seasons": all_series_data}


# ======================= التنفيذ =======================

SERIES_URL = "https://www.faselhds.net/seasons/series-game-thrones"

final_data = scrape_faselhd_fast(SERIES_URL)

# طباعة النتائج بشكل منظم
if final_data and final_data.get("seasons"):
    print("\n" + "="*60)
    print(f"          نتائج مسلسل: {final_data['series_title']}")
    print("="*60)
    
    # فرز المواسم قبل الطباعة لضمان الترتيب الصحيح (من الموسم 1 إلى الأخير)
    sorted_seasons = sorted(final_data["seasons"].items(), key=lambda item: int(re.search(r'\d+', item[0]).group()) if re.search(r'\d+', item[0]) else 99)
    
    for season_name, season_info in sorted_seasons:
        episodes = season_info['episodes']
        poster = season_info['poster']
        
        print(f"\n✅ {season_name}  ({len(episodes)} حلقة):")
        print(f"   رابط البوستر: {poster}")
        for episode in episodes:
            print(f"  - {episode['title']}: {episode['url']}")
            
    print("\n" + "="*60)
    print("[*] انتهت العملية بنجاح.")
else:
    print("\n[!] لم يتم استخراج أي بيانات.")
