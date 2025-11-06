import requests
from bs4 import BeautifulSoup

url = "https://amd.brstej.com/watch.php?vid=4a729bc9d"

try:
    # محاولة جلب محتوى الرابط
    response = requests.get(url, timeout=10) # تعيين مهلة 10 ثوانٍ
    response.raise_for_status() # يثير استثناء لأكواد حالة HTTP الخاطئة (4xx أو 5xx)
    html_content = response.text

    soup = BeautifulSoup(html_content, 'html.parser')

    seasons_data = {}

    # البحث عن جميع عناصر المواسم
    season_list_items = soup.select('.SeasonsBoxUL ul li')

    for season_li in season_list_items:
        season_name = season_li.text.strip()
        season_id = season_li.get('data-serie')
        if season_id:
            seasons_data[season_name] = []

            # البحث عن الحلقات الخاصة بهذا الموسم
            # لاحظ أن الروابط في HTML تبدأ بـ "./" مما يتطلب بناء الرابط الكامل
            base_url_for_episodes = "https://amd.brstej.com/"
            
            episodes_div = soup.find('div', class_='SeasonsEpisodes', attrs={'data-serie': season_id})
            if episodes_div:
                episode_links = episodes_div.find_all('a')
                for link in episode_links:
                    episode_number = link.find('em').text.strip() if link.find('em') else 'N/A'
                    episode_title = link.get('title', 'N/A')
                    relative_url = link.get('href', '')
                    
                    # بناء الرابط المطلق
                    if relative_url.startswith('./'):
                        episode_url = base_url_for_episodes + relative_url.lstrip('./')
                    else:
                        episode_url = relative_url # في حال كان الرابط مطلقًا بالفعل

                    seasons_data[season_name].append({
                        'رقم الحلقة': episode_number,
                        'عنوان الحلقة': episode_title,
                        'رابط الحلقة': episode_url
                    })

    # طباعة البيانات المستخرجة
    for season, episodes in seasons_data.items():
        print(f"**{season}:**")
        if not episodes:
            print("  لا توجد حلقات متاحة لهذا الموسم.")
        else:
            for episode in episodes:
                print(f"  - الحلقة {episode['رقم الحلقة']}: {episode['عنوان الحلقة']} (الرابط: {episode['رابط الحلقة']})")
        print("\n")

except requests.exceptions.ConnectionError as e:
    print(f"حدث خطأ في الاتصال: الموقع غير متاح أو لا يمكن الوصول إليه. الرجاء التأكد من أن الرابط صحيح ويعمل: {e}")
except requests.exceptions.Timeout as e:
    print(f"انتهت مهلة الطلب: استغرق الموقع وقتًا طويلاً للاستجابة. قد يكون الموقع بطيئًا أو غير متاح: {e}")
except requests.exceptions.RequestException as e:
    print(f"حدث خطأ عام أثناء جلب المحتوى من الرابط: {e}")
except Exception as e:
    print(f"حدث خطأ غير متوقع: {e}")