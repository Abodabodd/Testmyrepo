import requests
from bs4 import BeautifulSoup
from concurrent.futures import ThreadPoolExecutor
import re

# رابط الفيلم الأصلي
URL = "https://mycima.page/%d9%81%d9%8a%d9%84%d9%85-schlitter-2023-%d9%85%d8%aa%d8%b1%d8%ac%d9%85-%d8%a7%d9%88%d9%86-%d9%84%d8%a7%d9%8a%d9%86/"

# رأس الطلب (مهم لتجاوز الحظر)
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Referer": "https://mycima.page/"
}

def fetch_iframe_src(govid_url, server_name):
    """
    يزور رابط govid ويستخرج رابط الـ iframe النهائي.
    (يُستخدم بالتوازي)
    """
    try:
        response = requests.get(govid_url, headers=HEADERS, timeout=10)
        response.raise_for_status()

        govid_soup = BeautifulSoup(response.content, 'html.parser')
        iframe_tag = govid_soup.find('iframe')

        if iframe_tag and 'src' in iframe_tag.attrs:
            return server_name, iframe_tag['src']
        
        return server_name, f"Error: Could not find final iframe src."

    except requests.exceptions.RequestException as e:
        return server_name, f"Error fetching {govid_url} (Connection error)"

def extract_all_links(url, headers):
    """
    يقوم باستخراج روابط المشاهدة (عبر التتبع) وروابط التحميل (المباشرة).
    """
    watch_links = []
    download_links = []
    
    try:
        # جلب الصفحة الرئيسية
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')

        # ===================================================
        # 1. استخراج روابط المشاهدة الوسيطة (لتتبعها لاحقاً)
        # ===================================================
        govid_tasks = []
        watch_list_ul = soup.find('ul', id='watch')
        
        if watch_list_ul:
            for li in watch_list_ul.find_all('li', {'data-watch': re.compile(r'https://govid\.site/play/')}):
                govid_link = li.get('data-watch')
                # استخراج اسم السيرفر النظيف (نص الـ li مع تجاهل الأيقونة <i>)
                clean_name = li.get_text(strip=True).replace(' ', '')
                if govid_link:
                    govid_tasks.append((govid_link, clean_name))

        # ===================================================
        # 2. استخراج روابط التحميل (مباشرة من الصفحة)
        # ===================================================
        download_list_ul = soup.find('ul', class_='List--Download--Wecima--Single')
        
        if download_list_ul:
            for li_tag in download_list_ul.find_all('li'):
                a_tag = li_tag.find('a', href=True)
                if a_tag:
                    link = a_tag['href']
                    # اسم السيرفر موجود داخل وسم <quality>
                    quality_tag = a_tag.find('quality')
                    server_name = quality_tag.text.strip() if quality_tag else "غير محدد"
                    download_links.append((server_name, link))

        # ===================================================
        # 3. تتبع روابط المشاهدة بالتوازي (للتسريع)
        # ===================================================
        if govid_tasks:
            print(f"جاري معالجة {len(govid_tasks)} رابط مشاهدة بالتوازي...")
            with ThreadPoolExecutor(max_workers=5) as executor:
                watch_links = list(executor.map(lambda t: fetch_iframe_src(t[0], t[1]), govid_tasks))

        # ===================================================
        # 4. طباعة النتائج
        # ===================================================

        print("\n" + "="*70)
        print(">> الروابط المباشرة للمشاهدة (تم تتبعها من govid.site) <<")
        print("="*70)
        
        if watch_links:
            for name, link in watch_links:
                print(f"| السيرفر: {name:<12} | الرابط: {link}")
        else:
            print("لم يتم استخراج أي روابط مشاهدة مباشرة.")
        
        print("\n" + "="*70)
        print(">> روابط التحميل المباشرة <<")
        print("="*70)
        
        if download_links:
            for name, link in download_links:
                print(f"| السيرفر: {name:<12} | الرابط: {link}")
        else:
            print("لم يتم العثور على روابط تحميل.")
        
        print("="*70)

    except requests.exceptions.HTTPError as e:
        print(f"خطأ HTTP: تأكد من أن الموقع متاح. {e}")
    except requests.exceptions.RequestException as e:
        print(f"خطأ في الاتصال بالشبكة: {e}")

# تشغيل الدالة
extract_all_links(URL, HEADERS)