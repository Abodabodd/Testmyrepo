# youtube_request.py
import requests
import brotli    # اذا لم يكن مُثبتًا: pip install brotli
from pprint import pprint

URL = "https://www.youtube.com/"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    # بعض مواقع تستخدم هذه الحقول كـ client hints — يمكن تضمينها كما في متصفحك
    "Sec-CH-UA": "\"Chromium\";v=\"142\", \"Google Chrome\";v=\"142\", \"Not_A Brand\";v=\"99\"",
    "Sec-CH-UA-Platform": "\"Windows\"",
    "Sec-CH-UA-Mobile": "?0",
    "Sec-CH-UA-Arch": "\"x86\"",
    "Sec-CH-UA-Bitness": "\"64\"",
    "Sec-CH-UA-Full-Version": "\"142.0.7444.61\"",
    "Sec-CH-UA-Full-Version-List": "\"Chromium\";v=\"142.0.7444.61\", \"Google Chrome\";v=\"142.0.7444.61\", \"Not_A Brand\";v=\"99.0.0.0\"",
    "Accept-Language": "en-US,en;q=0.9",
    "Upgrade-Insecure-Requests": "1",
    # قد تضيف Referer أو Origin إذا رغبت:
    "Referer": "https://www.youtube.com/",
    # أي رؤوس إضافية من الـ list يمكنك إضافتها هنا عند الحاجة
}

def fetch_youtube(url: str):
    # نستخدم stream=False ليُعيد المحتوى كاملًا
    r = requests.get(url, headers=HEADERS, timeout=30)
    print(f"Status: {r.status_code} {r.reason}")
    print("--- Response headers (partial) ---")
    # اطبع بعض الرؤوس المفيدة
    for k in ("content-type", "content-encoding", "date", "cache-control", "server"):
        if k in r.headers:
            print(f"{k}: {r.headers[k]}")

    content = None
    encoding = r.headers.get("Content-Encoding", "").lower()

    # إذا كانت الإجابة مضغوطة بـ br (Brotli) نفك الضغط يدويًا
    if "br" in encoding:
        try:
            content = brotli.decompress(r.content).decode("utf-8", errors="replace")
        except Exception as e:
            print("Failed to decompress brotli:", e)
            # كنسخ احتياطي حاول استخدام requests text إن أمكن
            try:
                content = r.text
            except Exception:
                content = r.content.decode("utf-8", errors="replace")
    else:
        # requests عادةً يتعامل مع gzip/deflate تلقائيًا؛ نستخدم .text للوصول إلى المحتوى المفكوك
        content = r.text

    print("--- Body length:", len(content))
    print("--- First 1000 chars of the body ---")
    print(content[:1000])

    # لو أردت حفظ الصفحة كاملًا:
    # with open("youtube_homepage.html", "w", encoding="utf-8") as f:
    #     f.write(content)

if __name__ == "__main__":
    fetch_youtube(URL)
