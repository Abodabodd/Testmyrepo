import requests
from bs4 import BeautifulSoup
import re

def absolutize(base_url, href):
    if not href: return None
    if href.startswith("http"):
        return href
    return base_url.strip('/') + '/' + href.strip('/')

def get_page_soup(url, base_url):
    print(f"\n[*] يتم الآن طلب الرابط: {url}")
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.0 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'ar-EG,ar;q=0.9,en-US;q=0.8,en;q=0.7',
            'Referer': base_url
        }
        response = requests.get(url, headers=headers)
        response.encoding = 'utf-8'
        response.raise_for_status()
        return BeautifulSoup(response.content, 'html.parser')
    except requests.exceptions.RequestException as e:
        print(f"[x] فشل في جلب الصفحة: {e}")
        return None

def extract_episodes_from_season(soup, season_name):
    if not soup: return
    print(f"\n{'='*15} حلقات: {season_name} {'='*15}")
    episode_elements = soup.select("div#series-episodes .row > div[class*='col-lg-4']")
    
    if episode_elements:
        for episode_container in episode_elements:
            link = episode_container.select_one("a[href*='/episode/'] h2")
            if link:
                ep_name = link.text.strip()
                ep_url = absolutize("https://ak.sv", link.parent.get('href'))
                ep_poster = episode_container.select_one('img')
                
                print(f"  - اسم الحلقة: {ep_name}")
                print(f"    رابط الحلقة: {ep_url}")
                print(f"    صورة الحلقة: {ep_poster.get('data-src') if ep_poster else 'لا يوجد'}\n")
    else:
        print("[-] لم يتم العثور على حلقات في هذه الصفحة.")

def get_season_number(season_name):
    """
    *** الإصلاح: تم توسيع القاموس ليشمل حتى الموسم الثلاثين ***
    """
    ARABIC_TO_INT = {
        "الاول": 1, "الأول": 1, "الثاني": 2, "الثالث": 3, "الرابع": 4, "الخامس": 5,
        "السادس": 6, "السابع": 7, "الثامن": 8, "التاسع": 9, "العاشر": 10,
        "الحادي عشر": 11, "الثاني عشر": 12, "الثالث عشر": 13, "الرابع عشر": 14,
        "الخامس عشر": 15, "السادس عشر": 16, "السابع عشر": 17, "الثامن عشر": 18,
        "التاسع عشر": 19, "العشرون": 20, "الحادي والعشرون": 21, "الثاني والعشرون": 22,
        "الثالث والعشرون": 23, "الرابع والعشرون": 24, "الخامس والعشرون": 25,
        "السادس والعشرون": 26, "السابع والعشرون": 27, "الثامن والعشرون": 28,
        "التاسع والعشرون": 29, "الثلاثون": 30
    }
    for word, number in ARABIC_TO_INT.items():
        if word in season_name:
            return number
            
    numbers = re.findall(r'\d+', season_name)
    if numbers:
        return int(numbers[-1])
        
    return 999

# --- نقطة بداية تشغيل الكود ---
if __name__ == "__main__":
    base_url = "https://ak.sv"
    start_url = f"{base_url}/series/154/the-walking-dead-%D8%A7%D9%84%D9%85%D9%88%D8%B3%D9%85-%D8%A7%D9%84%D8%AB%D8%A7%D9%85%D9%86-3"

    print("===== المرحلة الأولى: تجميع كل المواسم من الصفحة الأولية =====")
    
    main_soup = get_page_soup(start_url, base_url)
    
    if main_soup:
        all_seasons_map = {}

        current_title = main_soup.select_one("h1.entry-title")
        if current_title:
            all_seasons_map[start_url] = {'name': current_title.text.strip(), 'url': start_url}

        other_seasons_elements = main_soup.select("div.widget-body > a.btn[href*='/series/']")
        for link in other_seasons_elements:
            url = absolutize(base_url, link.get('href'))
            if url and url not in all_seasons_map:
                all_seasons_map[url] = {'name': link.text.strip(), 'url': url}
        
        final_ordered_seasons = sorted(list(all_seasons_map.values()), key=lambda s: get_season_number(s['name']))

        print("\n[نجاح!] تم بناء قائمة المواسم الكاملة وفرزها بنجاح:")
        for i, season in enumerate(final_ordered_seasons):
            print(f"  {i+1}. {season['name']}")

        print(f"\n\n{'*'*40}")
        print("الآن سيتم استخراج حلقات كل موسم بالترتيب الصحيح...")
        print(f"{'*'*40}")
        
        soups_cache = {start_url: main_soup}
        
        for season in final_ordered_seasons:
            season_name = season['name']
            season_url = season['url']
            
            soup_to_use = soups_cache.get(season_url) or get_page_soup(season_url, base_url)
            
            extract_episodes_from_season(soup_to_use, season_name)

    print("\n[Program finished]")