import requests
from bs4 import BeautifulSoup
import re
import urllib.parse

# رابط الحلقة الواحدة (نقطة البداية)
START_URL = "https://mycima.page/%d9%85%d8%b3%d9%84%d8%b3%d9%84-game-of-thrones-%d8%a7%d9%84%d9%85%d9%88%d8%b3%d9%85-%d8%a7%d9%84%d8%ae%d8%a7%d9%85%d8%b3-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-1-%d8%a7%d9%84%d8%a7%d9%88%d9%84%d9%8a/"
BASE_URL = "https://mycima.page"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Referer": START_URL
}

POST_ID = '1187246'
AJAX_EPISODES_URL = "https://mycima.page/wp-content/themes/mycima/Ajaxt/Single/Episodes.php"


def extract_episode_number(episode_title_text):
    """يستخلص رقم الحلقة من النص (مثال: 'الحلقة 10 والاخيرة' -> '10')"""
    # البحث عن كلمة "الحلقة" متبوعة بأرقام
    match = re.search(r'الحلقة\s*(\d+)', episode_title_text)
    if match:
        return match.group(1).strip()
    
    # إذا لم ينجح الاستخلاص، نرجع النص الأصلي أو جزء منه
    return episode_title_text.replace("الحلقة", "").strip()

# تم تبسيط هذه الدالة لحذف التتبع العميق الغير مطلوب هنا
def scrape_series_pages(start_url):
    """تستخرج جميع المواسم والحلقات وروابط صفحاتها بالاسم الجديد."""
    print(f"جاري جلب بيانات المسلسل من: {start_url}")
    
    try:
        response = requests.get(start_url, headers=HEADERS)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        series_title_tag = soup.select_one('div.Title--Content--Single-begin h1')
        series_title = series_title_tag.contents[0].strip() if series_title_tag else "مسلسل غير معروف"

        print("-" * 70)
        print(f"اسم المسلسل: {series_title}")
        print("-" * 70)

        seasons_tags = soup.select('div.SeasonsList ul li a.no-ajax')
        
        if not seasons_tags:
            print("لم يتم العثور على قائمة المواسم.")
            return

        seasons_data = []
        
        # 1. تكرار لجلب الحلقات لكل موسم
        for season_tag in seasons_tags:
            season_full_name = season_tag.text.strip() # مثال: الموسم الاول مترجم
            season_id = season_tag.get('data-season')
            
            # استخلاص اسم الموسم النظيف (للتنسيق)
            season_name_parts = season_full_name.split(' ')
            if 'الموسم' in season_name_parts:
                try:
                    # محاولة استخلاص "الموسم X" فقط
                    season_index = season_name_parts.index('الموسم')
                    season_number = season_name_parts[season_index + 1]
                    clean_season_name = f"الموسم {season_number}"
                except IndexError:
                    clean_season_name = season_full_name
            else:
                 clean_season_name = season_full_name


            if not season_id: continue

            print(f"\nجاري جلب حلقات {season_full_name} (ID: {season_id})")
            
            ajax_data = {
                'season': season_id,
                'post_id': POST_ID
            }
            
            episodes_response = requests.post(AJAX_EPISODES_URL, data=ajax_data, headers=HEADERS)
            
            episode_links = []
            if episodes_response.status_code == 200:
                episodes_html = episodes_response.text
                episodes_soup = BeautifulSoup(episodes_html, 'html.parser')
                
                for a_tag in episodes_soup.select('a[href]'):
                    episode_title_tag = a_tag.find('episodetitle')
                    episode_title_raw = episode_title_tag.text.strip() if episode_title_tag else ""
                    episode_url = a_tag['href']
                    
                    # استخلاص رقم الحلقة فقط
                    ep_number = extract_episode_number(episode_title_raw)
                    
                    # إنشاء الاسم الجديد المطلوب: "الموسم X الحلقة Y"
                    new_episode_title = f"{clean_season_name} الحلقة {ep_number}"
                    
                    episode_links.append({
                        'title': new_episode_title,
                        'url': urllib.parse.urljoin(BASE_URL, episode_url), 
                    })
            
                if episode_links:
                    seasons_data.append({
                        'season_name': season_full_name, # احتفاظ بالاسم الكامل للعرض في العنوان
                        'episodes': episode_links
                    })

        # 2. طباعة النتائج النهائية
        
        print("\n" + "#"*70)
        print(">> مواسم المسلسل وروابط صفحات الحلقات (بالتنسيق الجديد) <<")
        print("#"*70)

        for season in seasons_data:
            print(f"\n*** {season['season_name']} ({len(season['episodes'])} حلقة) ***")
            for episode in season['episodes']:
                print(f"  > {episode['title']}: {episode['url']}")
        
        print("\n" + "#"*70)


    except requests.exceptions.RequestException as e:
        print(f"حدث خطأ أثناء جلب الصفحة الرئيسية: {e}")

# تشغيل الدالة
scrape_series_pages(START_URL)