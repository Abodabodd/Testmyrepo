import requests
import re

def unpack_js(packed_js):
    """
    يقوم بفك تعمية شيفرة JavaScript التي تتبع نمط (p,a,c,k,e,d).
    """
    try:
        match = re.search(r"eval\(function\(p,a,c,k,e,d\)\{(.*)\}\('(.*)',(\d+),(\d+),'(.*)'\.split\('\|'\)\)\)", packed_js, re.DOTALL)
        if not match:
            return None

        unpacker_logic, payload, base_str, count_str, dictionary_str = match.groups()
        base = int(base_str)
        count = int(count_str)
        dictionary = dictionary_str.split('|')

        def _int_to_base_str(n, base):
            if n < base:
                return "0123456789abcdefghijklmnopqrstuvwxyz"[n]
            else:
                return _int_to_base_str(n // base, base) + "0123456789abcdefghijklmnopqrstuvwxyz"[n % base]

        lookup = {}
        for i in range(count - 1, -1, -1):
            key = _int_to_base_str(i, base)
            value = dictionary[i] or key
            lookup[key] = value
        
        unpacked = re.sub(r'\b\w+\b', lambda m: lookup.get(m.group(0), m.group(0)), payload)
        
        return unpacked
    except Exception as e:
        print(f"[!] حدث خطأ أثناء فك التعمية: {e}")
        return None

def get_video_url(embed_url, referer_url):
    """
    يستخرج رابط الفيديو الحقيقي من صفحة التضمين.
    """
    headers = {
        "Referer": referer_url,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36"
    }

    try:
        print(f"[*] جاري جلب محتوى الصفحة من: {embed_url}")
        response = requests.get(embed_url, headers=headers, timeout=15)
        response.raise_for_status()
        html_content = response.text
        print("[+] تم جلب محتوى الصفحة بنجاح.")

        print("[*] جاري البحث عن الشيفرة المعماة (eval)...")
        packed_js_match = re.search(r'eval\(function\(p,a,c,k,e,d\){.*?}\(.*\)\)', html_content, re.DOTALL)
        
        if not packed_js_match:
            print("[!] لم يتم العثور على شيفرة JavaScript المعماة.")
            return None
        
        packed_js_code = packed_js_match.group(0)
        print("[+] تم العثور على الشيفرة المعماة.")

        print("[*] جاري فك تعمية الشيفرة...")
        unpacked_js = unpack_js(packed_js_code)
        
        if not unpacked_js:
            print("[!] فشل فك تعمية الشيفرة.")
            return None
            
        print("[+] تم فك الشيفرة بنجاح.")

        print("[*] جاري استخراج رابط الفيديو...")
        # --- هذا هو السطر الذي تم تعديله ---
        # يبحث الآن عن أي رابط يبدأ بـ http أو https داخل file:"..."
        video_match = re.search(r'file\s*:\s*"(https?://.*?)"', unpacked_js)
        
        if not video_match:
            print("[!] لم يتم العثور على رابط الفيديو داخل الشيفرة.")
            print("\n--- محتوى الشيفرة بعد فكها ---")
            print(unpacked_js)
            print("----------------------------\n")
            return None
        
        video_url = video_match.group(1)
        print("[+] تم استخراج الرابط بنجاح!")
        
        return video_url

    except requests.exceptions.RequestException as e:
        print(f"[!] خطأ في الاتصال: {e}")
        return None
    except Exception as e:
        print(f"[!] حدث خطأ غير متوقع: {e}")
        return None

# --- بداية تشغيل الكود ---
if __name__ == "__main__":
    # ضع هنا الرابط والريفرير المطلوبين
    url_to_fetch = "https://ss.hd-vk.com/embed-6r83n57hfo5l.html"
    # الريفرير مهم جداً، قد لا يعمل الرابط بدونه
    referer_url = "https://amd.brstej.com/" 
    
    print("="*50)
    video_link = get_video_url(url_to_fetch, referer_url)
    print("="*50)

    if video_link:
        print("\n✅ رابط الفيديو هو:")
        print(video_link)
    else:
        print("\n❌ فشلت عملية استخراج رابط الفيديو.")
