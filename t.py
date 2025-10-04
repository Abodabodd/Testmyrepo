# تحتاج تثبيت: pip install playwright
# ثم مرة واحدة: playwright install

from playwright.sync_api import sync_playwright
import re
import time

vcode = "XiB7NrWNjVeohgmA"
url = f"https://videa.hu/player?v={vcode}"

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)  # headless=False لو تريد رؤية المتصفح
    context = browser.new_context()  # يحفظ الكوكيز تلقائيا
    page = context.new_page()

    def on_request(request):
        if "/player/xml" in request.url or "/player/setcookie" in request.url or "player" in request.url:
            print("\n--- REQUEST ---")
            print("URL:", request.url)
            print("Method:", request.method)
            print("Headers:", request.headers)
            # ممكن طباعة post data إن وُجد
            try:
                post = request.post_data
                if post:
                    print("Post data:", post)
            except Exception:
                pass

    def on_response(response):
        try:
            if "/player/xml" in response.url:
                print("\n*** RESPONSE for", response.url, "***")
                print("Status:", response.status)
                # قد يكون XML أو فارغ
                text = response.text()
                print("Response body preview:", text[:2000])
        except Exception as e:
            print("response read error:", e)

    page.on("request", on_request)
    page.on("response", on_response)

    print("فتح الصفحة...")
    page.goto(url, wait_until="networkidle")
    # انتظر قليلا لالتقاط أي طلبات لاحقة
    time.sleep(5)

    # لو تريد استخراج _xt من الـ HTML مباشرة:
    content = page.content()
    m = re.search(r'var _xt\s*=\s*"([^"]+)"', content)
    print("\nالمحتوى: _xt =", m.group(1) if m else None)

    browser.close()
