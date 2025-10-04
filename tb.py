# videa_decode.py
# يحتاج: pip install playwright
# ثم مرة واحدة: playwright install

from playwright.sync_api import sync_playwright
import time, json, sys, os

VCODE = "XiB7NrWNjVeohgmA"   # غيّرها إذا لزم
URL = f"https://videa.hu/player?v={VCODE}"

def save_text(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"حفظت الناتج في: {path}")

with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)  # اجعلها False لتشاهد المتصفّح أثناء التطوير
    ctx = browser.new_context()
    page = ctx.new_page()

    print("فتح الصفحة...")
    page.goto(URL, wait_until="networkidle")
    time.sleep(2)

    # التقاط آخر نص تم استقباله من /player/xml (قد يحدث كـ GET أو POST)
    xml_response_text = None

    def on_response(response):
        nonlocal xml_response_text
        try:
            url = response.url
            if "/player/xml" in url:
                # نخزن النص الكامل (يمكن أن يكون مشفّر)
                try:
                    text = response.text()
                except Exception as e:
                    text = f"<error reading response text: {e}>"
                print(f"التقاط استجابة /player/xml — الحالة: {response.status} — طول النص: {len(text) if isinstance(text, str) else '؟'}")
                xml_response_text = text
        except Exception as e:
            print("on_response error:", e)

    page.on("response", on_response)

    # أعد محاولة جلب XML (ستستخدم نفس سياق المتصفح)
    print("طلب /player/xml داخل المتصفّح...")
    page.evaluate(f"""() => fetch("/player/xml?platform=desktop&v={VCODE}&lang=hu&start=0", {{credentials:'same-origin'}}).then(r=>r.text())""")
    time.sleep(2)

    # إذا لم يتم التقاط النص تلقائياً، حاول أن نطلبه ونخزن النتيجة يدوياً
    if not xml_response_text:
        print("لم يتم التقاط استجابة تلقائياً — نجرب fetch ونخزّن النتيجة يدوياً...")
        xml_response_text = page.evaluate(f"""() => (async function(){{
            try {{
                let r = await fetch("/player/xml?platform=desktop&v={VCODE}&lang=hu&start=0", {{credentials:'same-origin'}});
                return r.status + "|||" + await r.text();
            }} catch(e) {{
                return "ERROR|||" + String(e);
            }}
        }})()""")

        if isinstance(xml_response_text, str) and xml_response_text.startswith("ERROR|||"):
            print("فشل fetch داخل الصفحة:", xml_response_text)
            xml_response_text = None
        elif isinstance(xml_response_text, str) and "|||" in xml_response_text:
            # فصل الحالة عن الجسم
            status, body = xml_response_text.split("|||", 1)
            print("حالة fetch:", status)
            xml_response_text = body

    if not xml_response_text:
        print("لم نجد نصاً من /player/xml — افحص DevTools يدوياً.")
        browser.close()
        sys.exit(1)

    # الآن xml_response_text غالبًا مشفّر. نحاول تشغيل دوال فكّ منتشرة في نافذة الصفحة
    print("طول النص المستلم:", len(xml_response_text))
    # نمرّر النص إلى سياق الصفحة ونجرّب استدعاء دوال مرشّحة لفكّ التشفير
    decode_script = r"""
    (function(enc){
        // enc = النص المشفّر
        let tries = [];

        // أولاً: إن وُجدت دوال معروفة نجرّبها مباشرة إذا كانت تستقبل نصاً.
        const candidate_names = [
            'videaGetPlaybackData',
            'decodePlaybackResponse',
            'decodeResponse',
            'decode',
            'decrypt',
            'unpack',
            'parsePlayback',
            'uncompress',
            'gunzip',
            'inflate'
        ];

        function tryCall(fn) {
            try {
                let out = fn(enc);
                if (out && (typeof out === 'string' || (typeof out === 'object' && out !== null))) {
                    return out;
                }
            } catch(e) {
                // ignore
            }
            return null;
        }

        // 1) جرب أسماء مرشّحة شهيرة
        for (let name of candidate_names) {
            try {
                if (typeof window[name] === 'function') {
                    let res = tryCall(window[name]);
                    if (res) return {method: 'named', name: name, result: res};
                }
            } catch(e) {}
        }

        // 2) جرب دوال في window تحتوي في نصّها على دلائل فكّ التشفير (atob, CryptoJS, decrypt, inflate)
        for (let k of Object.getOwnPropertyNames(window)) {
            try {
                let v = window[k];
                if (typeof v === 'function') {
                    let s = v.toString();
                    if (/atob|CryptoJS|decrypt|inflate|gunzip|fromCharCode|pako/i.test(s)) {
                        try {
                            let res = tryCall(v);
                            if (res) return {method: 'auto-found', name: k, result: res};
                        } catch(e) {}
                    }
                }
            } catch(e) {}
        }

        // 3) أخيراً، جرّب التحويل البسيط base64 (atob)
        try {
            let decoded = null;
            try {
                decoded = atob(enc);
            } catch(e) {
                // قد تكون base64 url-safe -> تحويل
                let safe = enc.replace(/-/g, '+').replace(/_/g, '/');
                try {
                    decoded = atob(safe);
                } catch(e2) {
                    decoded = null;
                }
            }
            if (decoded) return {method: 'atob', name: 'atob', result: decoded};
        } catch(e) {}

        return {method: 'none', message: 'لم يتم فكّ التشفير تلقائياً'};
    })
    """

    print("محاولة فكّ النص داخل صفحة المتصفح باستخدام دوال الصفحة...")
    try:
        decode_try = page.evaluate(decode_script + "(arguments[0])", xml_response_text)
    except Exception as e:
        print("خطأ عند محاولة evaluate:", e)
        decode_try = None

    if not decode_try:
        print("لم نتمكن من فكّ النص داخل الصفحة تلقائياً.")
        browser.close()
        sys.exit(1)

    print("نتيجة المحاولة:", json.dumps(decode_try if isinstance(decode_try, dict) else {"result": str(decode_try)}, ensure_ascii=False, indent=2)[:4000])

    # إذا كانت النتيجة نصية كبيرة، نحفظها
    if isinstance(decode_try, dict) and 'result' in decode_try:
        result = decode_try['result']
        # لو عاد كائن JSON أو XML في شكل نصّي
        if isinstance(result, (dict, list)):
            result_text = json.dumps(result, ensure_ascii=False, indent=2)
        else:
            result_text = str(result)
        save_text("out_decoded.xml", result_text)
    else:
        print("لا توجد نتيجة قابلة للحفظ.")
    browser.close()
    print("انتهى.")
