import cloudscraper
from bs4 import BeautifulSoup
import re
import warnings

# تجاهل التحذيرات غير الضرورية
warnings.filterwarnings("ignore", category=FutureWarning, module='soupsieve')

BASE_URL = "https://got.animerco.org"

def get_anime_structure(anime_url):
    """
    يجلب قائمة المواسم والحلقات الخاصة بأنمي معين من موقع Animerco.
    """
    scraper = cloudscraper.create_scraper()
    
    try:
        print(f"\n[*] جارِ جلب بيانات الأنمي من: {anime_url}")
        response = scraper.get(anime_url)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        anime_title = soup.select_one("div.media-title h1").text.strip()
        print(f"[*] اسم الأنمي: {anime_title}")

        # --- البحث عن المواسم ---
        season_links = soup.select("div.media-seasons ul.episodes-lists li a.title")
        
        # إذا لم نجد مواسم منفصلة، نعتبر الصفحة الحالية هي الموسم الوحيد
        if not season_links:
            print("\n===============================")
            print(f"      {anime_title} (موسم واحد)")
            print("===============================")
            episodes = fetch_episodes_from_page(soup)
            if not episodes:
                print("لم يتم العثور على حلقات.")
            else:
                for ep_title, ep_url in episodes:
                    print(f"- {ep_title}: {ep_url}")
            return

        # إذا وجدنا مواسم متعددة
        print(f"\n[*] تم العثور على {len(season_links)} مواسم. جارِ جلب الحلقات...")
        for season_link in season_links:
            season_url = season_link.get('href')
            season_name = season_link.select_one("h3").text.strip()
            
            print("\n===============================")
            print(f"      {season_name}")
            print("===============================")
            
            # جلب محتوى صفحة الموسم
            season_response = scraper.get(season_url)
            season_soup = BeautifulSoup(season_response.text, 'html.parser')
            
            episodes = fetch_episodes_from_page(season_soup)
            
            if not episodes:
                print("لم يتم العثور على حلقات لهذا الموسم.")
            else:
                for ep_title, ep_url in episodes:
                    print(f"- {ep_title}: {ep_url}")

    except Exception as e:
        print(f"\n[!] حدث خطأ غير متوقع: {e}")

def fetch_episodes_from_page(soup):
    """
    دالة فرعية تستخرج قائمة الحلقات من كود HTML معين.
    """
    episodes = []
    # الـ Selector الصحيح لقائمة الحلقات
    episode_elements = soup.select("ul.episodes-lists#filter li")
    
    for ep_element in episode_elements:
        link_tag = ep_element.select_one("a.title")
        if link_tag:
            ep_url = link_tag.get('href')
            ep_title = link_tag.select_one("h3").text.strip()
            episodes.append((ep_title, ep_url))
            
    # فرز الحلقات تصاعديًا بناءً على الرقم في العنوان
    episodes.sort(key=lambda x: int(re.search(r'(\d+)', x[0]).group(1) or 0))
    return episodes

# --- بداية تشغيل البرنامج ---
if __name__ == "__main__":
    # يمكنك تغيير الرابط هنا لاختبار أي أنمي
    anime_url = "https://got.animerco.org/animes/one-punch-man/"
    get_anime_structure(anime_url)