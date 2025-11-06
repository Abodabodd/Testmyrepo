import requests
from bs4 import BeautifulSoup

# الرابط الأولي لصفحة المشاهدة (watch.php)
watch_url = "https://amd.brstej.com/watch.php?vid=d1c18fbc9"
base_url = "https://amd.brstej.com" # المسار الأساسي للموقع لبناء الروابط المطلقة

try:
    print(f"**الخطوة 1: جلب رابط التشغيل (Play Link) من صفحة المشاهدة:**")
    print(f"جلب المحتوى من: {watch_url}")
    
    # جلب محتوى صفحة watch.php
    response_watch = requests.get(watch_url, timeout=15)
    response_watch.raise_for_status()
    html_content_watch = response_watch.text
    
    soup_watch = BeautifulSoup(html_content_watch, 'html.parser')
    
    # البحث عن رابط التشغيل (Play Link) في صفحة watch.php
    # هذا هو العنصر <a> الذي يحتوي على الفئة 'xtgo' (كان موجودًا في صفحة watch.php سابقًا)
    play_link_element = soup_watch.find('a', class_='xtgo')

    play_url = None
    if play_link_element and 'href' in play_link_element.attrs:
        relative_play_url = play_link_element['href']
        # بناء الرابط المطلق لصفحة التشغيل
        if relative_play_url.startswith('/'):
            play_url = base_url + relative_play_url
        else:
            play_url = relative_play_url
        print(f"تم العثور على رابط صفحة التشغيل: {play_url}")
    else:
        print("لم يتم العثور على رابط صفحة التشغيل (Play Link) في صفحة المشاهدة.")
        exit() # لا يمكن المتابعة بدون رابط التشغيل


    print(f"\n**الخطوة 2: استخراج روابط المشاهدة الفعلية من صفحة التشغيل:**")
    print(f"جلب المحتوى من: {play_url}")

    # جلب محتوى صفحة play.php (التي وجدناها في الخطوة الأولى)
    response_play = requests.get(play_url, timeout=15)
    response_play.raise_for_status()
    html_content_play = response_play.text
    
    soup_play = BeautifulSoup(html_content_play, 'html.parser')
    
    extracted_watch_links = []

    # البحث عن روابط المشاهدة من أزرار "Watch Servers" أولاً
    watch_buttons_container = soup_play.find('div', id='WatchServers')
    if watch_buttons_container:
        watch_buttons = watch_buttons_container.find_all('button', class_='watchButton')
        if watch_buttons:
            for button in watch_buttons:
                server_name = button.text.strip()
                embed_url = button.get('data-embed-url')
                if embed_url:
                    extracted_watch_links.append(f"{server_name}: {embed_url}")

    # إذا لم يتم العثور على روابط من الأزرار، نبحث عن رابط iframe كبديل
    if not extracted_watch_links:
        player_holder = soup_play.find('div', id='Playerholder')
        if player_holder:
            iframe_tag = player_holder.find('iframe')
            if iframe_tag and 'src' in iframe_tag.attrs:
                iframe_src = iframe_tag['src']
                extracted_watch_links.append(f"رابط المشاهدة المضمن (iframe): {iframe_src}")
    else: # إذا وجدت أزرار، لا يزال بإمكانك التحقق من iframe إذا أردت روابط إضافية (أو تجاهله)
        player_holder = soup_play.find('div', id='Playerholder')
        if player_holder:
            iframe_tag = player_holder.find('iframe')
            if iframe_tag and 'src' in iframe_tag.attrs:
                iframe_src = iframe_tag['src']
                # تجنب إضافة رابط iframe إذا كان هو نفسه أحد روابط الأزرار
                if iframe_src not in [link.split(': ')[1] for link in extracted_watch_links if ': ' in link]:
                    extracted_watch_links.append(f"رابط المشاهدة المضمن (iframe): {iframe_src}")

    # 5. طباعة الروابط المستخرجة النهائية
    if extracted_watch_links:
        print("\n**روابط المشاهدة النهائية المستخرجة:**")
        for link in extracted_watch_links:
            print(link)
    else:
        print("\nلم يتم العثور على أي روابط مشاهدة في صفحة التشغيل.")

except requests.exceptions.ConnectionError as e:
    print(f"خطأ في الاتصال: تأكد من اتصالك بالإنترنت. فشل الوصول إلى: {e.request.url}")
except requests.exceptions.Timeout as e:
    print(f"انتهت مهلة الطلب: استغرق الرابط {e.request.url} وقتًا طويلاً للاستجابة.")
except requests.exceptions.HTTPError as e:
    print(f"خطأ في استجابة HTTP من {e.request.url}: {e}")
except requests.exceptions.RequestException as e:
    print(f"خطأ عام أثناء جلب المحتوى: {e}")
except Exception as e:
    print(f"حدث خطأ غير متوقع: {e}")