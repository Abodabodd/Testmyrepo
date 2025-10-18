import requests
from bs4 import BeautifulSoup

def simulate_load_links(episode_url):
    """
    يحاكي دالة loadLinks المعدلة لجلب روابط الفيديو النهائية من صفحة الحلقة.
    """
    print(f"[*] يتم فحص رابط الحلقة: {episode_url}")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'ar-EG,ar;q=0.9,en-US;q=0.8,en;q=0.7'
    }
    
    main_url = "https://ak.sv"

    try:
        # --- الخطوة 1: طلب صفحة الحلقة الأولية لجلب "المفاتيح" ---
        print("\n[1] يتم طلب صفحة الحلقة الأولية...")
        response_step1 = requests.get(episode_url, headers=headers)
        response_step1.encoding = 'utf-8'
        response_step1.raise_for_status()
        soup_step1 = BeautifulSoup(response_step1.content, 'html.parser')

        # استخراج "المفتاحين" اللازمين: رابط المشاهدة ومعرف الصفحة
        print("  [+] يتم البحث عن مسار المشاهدة ومعرف الصفحة...")
        watch_path_element = soup_step1.select_one("a.link-show")
        page_id_element = soup_step1.select_one("input#page_id")

        if not watch_path_element or not page_id_element:
            print("[x] خطأ: لم يتم العثور على المعلومات اللازمة لبناء رابط المشاهدة.")
            print("[-] قد يكون الموقع قد تغير أو أن الصفحة لا تحتوي على فيديو.")
            return
            
        watch_path = watch_path_element.get('href')
        page_id = page_id_element.get('value')
        
        print(f"  [+] تم العثور على مسار المشاهدة: {watch_path}")
        print(f"  [+] تم العثور على معرف الصفحة: {page_id}")

        # --- الخطوة 2: بناء رابط المشاهدة النهائي وطلبه ---
        # يقوم ببناء الرابط بنفس طريقة Aniyomi
        watch_url = f"{main_url}/watch{watch_path.split('watch')[1]}/{page_id}"
        print(f"\n[2] تم بناء رابط المشاهدة النهائي: {watch_url}")

        # **مهم جداً:** إضافة Referer، وهو رابط صفحة الحلقة الأصلية
        headers['Referer'] = episode_url
        
        print("  [+] يتم إرسال الطلب الثاني مع Referer...")
        response_step2 = requests.get(watch_url, headers=headers)
        response_step2.encoding = 'utf-8'
        response_step2.raise_for_status()
        soup_step2 = BeautifulSoup(response_step2.content, 'html.parser')
        
        # --- الخطوة 3: استخراج روابط الفيديو النهائية من الصفحة الجديدة ---
        print("\n[*] يتم البحث عن روابط الفيديو النهائية في الصفحة الجديدة...")
        video_sources = soup_step2.select("source[src]")
        
        if not video_sources:
            print("[!] لم يتم العثور على أي روابط فيديو (<source>) في صفحة المشاهدة.")
            print("[-] قد يكون الفيديو مدمجًا في iframe أو أن هناك مشكلة أخرى.")
            return

        print(f"\n[نجاح!] تم العثور على {len(video_sources)} روابط فيديو:")
        
        for source in video_sources:
            video_url = source.get('src')
            # في موقع أكوام، الجودة تكون في attribute اسمه 'size'
            quality = source.get('size', 'جودة غير معروفة')
            
            print(f"  - الجودة: {quality}")
            print(f"    الرابط: {video_url}\n")
            
    except requests.exceptions.RequestException as e:
        print(f"[x] حدث خطأ في الشبكة: {e}")
    except Exception as e:
        print(f"[x] حدث خطأ غير متوقع: {e}")


# --- نقطة بداية تشغيل الكود ---
if __name__ == "__main__":
    test_episode_url = "https://ak.sv/episode/467/fire-and-blood-%D8%A7%D9%84%D8%A7%D8%AE%D9%8A%D8%B1%D8%A9"
    simulate_load_links(test_episode_url)
    print("\n[Program finished]")