import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse # تستخدم لاستخراج الدومين إذا احتجت إليه لاحقًا، ولكن ليست ضرورية للتكرار بين المشاهدة/التحميل

# 1. URL الذي تريد جلب محتواه الأولي والذي يحتوي على زر المشاهدة
url = "https://a.egydead.space/episode/%d9%85%d8%b3%d9%84%d8%b3%d9%84-game-of-thrones-%d8%a7%d9%84%d9%85%d9%88%d8%b3%d9%85-%d8%a7%d9%84%d8%b3%d8%a7%d8%a8%d8%b9-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-1/"

# رؤوس (Headers) لمحاكاة متصفح حقيقي.
headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Referer": url
}

try:
    session = requests.Session()

    print("جاري جلب الصفحة الأولية...")
    initial_response = session.get(url, headers=headers, timeout=15)
    initial_response.raise_for_status()

    post_data = {"View": "1"}

    print("جاري محاكاة النقر على زر 'المشاهده والتحميل'...")
    watch_download_response = session.post(url, data=post_data, headers=headers, timeout=15)
    watch_download_response.raise_for_status()

    soup = BeautifulSoup(watch_download_response.text, 'html.parser')

    # قائمة لتخزين سيرفرات المشاهدة الفريدة
    unique_watch_servers = []
    # مجموعة لتتبع روابط المشاهدة التي تمت إضافتها بالفعل
    # هذه المجموعة ستستخدم أيضًا لمنع تكرار روابط المشاهدة في قائمة التحميل
    all_seen_links = set()

    # 5. استخراج سيرفرات المشاهدة
    print("\n========== سيرفرات المشاهدة ==========\n")
    watch_servers_list = soup.find('ul', class_='serversList')
    if watch_servers_list:
        for server_li in watch_servers_list.find_all('li'):
            server_name_tag = server_li.find('p')
            server_name = server_name_tag.text.strip() if server_name_tag else "غير معروف"
            server_link = server_li.get('data-link')
            
            if server_link and server_link not in all_seen_links:
                unique_watch_servers.append({"name": server_name, "link": server_link})
                all_seen_links.add(server_link)

        if unique_watch_servers:
            for server in unique_watch_servers:
                print(f"الاسم: {server['name']}, الرابط: {server['link']}")
        else:
            print("لم يتم العثور على سيرفرات مشاهدة.")
    else:
        print("لم يتم العثور على قائمة سيرفرات المشاهدة.")

    # قائمة لتخزين سيرفرات التحميل الفريدة (بعد استبعاد تلك الموجودة في المشاهدة)
    unique_download_servers = []

    # 6. استخراج سيرفرات التحميل
    print("\n========== سيرفرات التحميل (مع استبعاد المكررة في المشاهدة) ==========\n")
    download_servers_list = soup.find('ul', class_='donwload-servers-list')
    if download_servers_list:
        for server_li in download_servers_list.find_all('li'):
            server_name_tag = server_li.find('span', class_='ser-name')
            server_name = server_name_tag.text.strip() if server_name_tag else "غير معروف"

            server_info_tag = server_li.find('div', class_='server-info')
            server_quality = server_info_tag.find('em').text.strip() if server_info_tag and server_info_tag.find('em') else "غير معروف"

            server_link_tag = server_li.find('a', class_='ser-link')
            server_link = server_link_tag.get('href') if server_link_tag else None

            # تحقق مما إذا كان رابط التحميل هذا موجودًا بالفعل في مجموعة الروابط التي تمت رؤيتها (من المشاهدة أو التحميل السابق)
            if server_link and server_link not in all_seen_links:
                unique_download_servers.append({"name": server_name, "quality": server_quality, "link": server_link})
                all_seen_links.add(server_link) # أضف الرابط إلى المجموعة لتجنب تكراره لاحقًا أيضًا

        if unique_download_servers:
            for server in unique_download_servers:
                print(f"الاسم: {server['name']} ({server['quality']}), الرابط: {server['link']}")
        else:
            print("لم يتم العثور على سيرفرات تحميل فريدة بعد التصفية.")
    else:
        print("لم يتم العثور على قائمة سيرفرات التحميل.")

except requests.exceptions.Timeout:
    print(f"خطأ: انتهت مهلة الاتصال بالرابط {url}. قد يكون الخادم بطيئًا أو غير متاح.")
except requests.exceptions.HTTPError as err:
    print(f"خطأ HTTP: {err}")
    print(f"الرابط: {url}")
    print(f"رمز الحالة: {err.response.status_code}")
    if err.response.status_code == 403:
        print("تم رفض الوصول (403 Forbidden). قد تحتاج إلى إضافة مزيد من رؤوس الطلب أو التعامل مع حماية الموقع.")
except requests.exceptions.ConnectionError as err:
    print(f"خطأ في الاتصال: {err}. تأكد من أنك متصل بالإنترنت وأن الرابط صحيح.")
except requests.exceptions.RequestException as err:
    print(f"حدث خطأ غير متوقع: {err}")
except Exception as e:
    print(f"حدث خطأ أثناء تحليل المحتوى: {e}")