import re
import json
import time
import hashlib
import requests

# ------------------------------------------------------------------------------
# ضع قيم كوكيزك هنا (استبدل "..." بالقيمة الكاملة لكل كوكي كما في المتصفح)
# ------------------------------------------------------------------------------

COOKIES = {
    # أمثلة على أسماء كوكيز مهمة ليوتيوب — استبدل القيم بالقيم الحقيقية لديك
    "SAPISID": "nUW-CCOinWiuvSLj/AWhiS5lC7jJJ7fKvT",
    "APISID": "G9a7RJIS2wdzrITs/AGbzLIXyu2u0ehmXk",
    "HSID": "AOdGGvoND51RUO80o",
    "SSID": "ANrvEajfCaK4PVV5S",
    "SID": "g.a0003gg5DShNlyHCn_2XpWBm-LsCSqFAcmtP37y05z0jO49Nr9g4-ds3e3bVzLtDZSRFJEw9VQACgYKAfcSARASFQHGX2MitIMgJhCNDBBKbtV6IdXJIRoVAUF8yKqCQUS_ztfqc4khGU73Lem20076",

    # احذف أو أضف أي كوكيز آخر حسب حاجتك
}

# ------------------------------------------------------------------------------
# إعداد العميل (يمكن تغييره إلى ANDROID/TVHTML5 إن رغبت)
# ------------------------------------------------------------------------------
WEB_SAFARI_CONTEXT = {
    "client": {
        "hl": "en",
        "gl": "US",
        "clientName": "WEB",
        "clientVersion": "2.20240725.01.00",
        "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                     "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
    },
    "user": {},
    "request": {}
}

# أصل الموقع المطلوب عند توليد SAPISIDHASH
ORIGIN = "https://www.youtube.com"

class ExtractorError(Exception):
    pass

def extract_video_id(url):
    patterns = [r'(?:v=|\/|embed\/|shorts\/|v%3D|be\/)([a-zA-Z0-9_-]{11})']
    for p in patterns:
        if match := re.search(p, url):
            return match.group(1)
    raise ExtractorError("لم يتم العثور على معرف فيديو صالح.")

def build_cookie_header(cookie_dict):
    """بناء سلسلة Cookie لرأس HTTP من قاموس الكوكيز."""
    parts = []
    for k, v in cookie_dict.items():
        if v is None or v == "":
            continue
        parts.append(f"{k}={v}")
    return "; ".join(parts)

def build_sapisidhash(sap_cookie_value, origin=ORIGIN):
    """
    توليد SAPISIDHASH كما تستخدمه google:
    SAPISIDHASH <timestamp>_<sha1(timestamp + ' ' + SAPISID + ' ' + origin)>
    """
    ts = str(int(time.time()))
    to_hash = f"{ts} {sap_cookie_value} {origin}"
    sha1 = hashlib.sha1(to_hash.encode("utf-8")).hexdigest()
    return f"SAPISIDHASH {ts}_{sha1}"

# ==============================================================================
# الدالة الرئيسية (معدلة لاستقبال كوكيز واستخدام Authorization إن أمكن)
# ==============================================================================
def get_hls_manifest_url(url, cookies=COOKIES):
    session = requests.Session()

    # 1) ضبط رؤوس أساسية
    session.headers.update({
        "User-Agent": WEB_SAFARI_CONTEXT["client"]["userAgent"],
        "Accept-Language": "en-US,en;q=0.5",
        # X-Requested-With / X-Origin يمكن إضافتها لاحقًا
    })

    # 2) تحميل الكوكيز إلى جلسة requests
    #    - نضيفها إلى session.cookies وكذلك كرأس Cookie (احتياطاً)
    clean_cookies = {k: v for k, v in cookies.items() if v and v != "..."}
    if clean_cookies:
        session.cookies.update(clean_cookies)
        cookie_header = build_cookie_header(clean_cookies)
        session.headers.update({"Cookie": cookie_header})
        print(f"🔐 تم تحميل {len(clean_cookies)} كوكيز إلى الجلسة.")
    else:
        print("⚠️ لا توجد كوكيز صالحة في القاموس (تأكد من استبدال القيم).")

    # 3) إذا كانت SAPISID موجودة فنبني Authorization header
    sapisid_val = clean_cookies.get("SAPISID") or clean_cookies.get("SAPISID".lower())
    if sapisid_val:
        auth_value = build_sapisidhash(sapisid_val, origin=ORIGIN)
        # رؤوس مطلوبة عادةً مع SAPISIDHASH
        session.headers.update({
            "Authorization": auth_value,
            "Origin": ORIGIN,
            "X-Goog-AuthUser": "0",
            # بعض الخوادم تتطلب X-Origin بدلاً من Origin أو بالإضافة إليها
            "X-Origin": ORIGIN
        })
        print("🔑 تم توليد رأس Authorization (SAPISIDHASH) وإضافته إلى الرؤوس.")
    else:
        print("⚠️ لم تُعطَ قيمة SAPISID صالحة — Authorization لن يُنشأ.")

    # الآن نمضي في بقية خطوات استخراج ytcfg + استدعاء player
    try:
        video_id = extract_video_id(url)
        print(f"🎬 الهدف: فيديو بمعرف {video_id} (باستخدام WEB client مع كوكيز)")
    except ExtractorError as e:
        print(e); return

    print("\n--- [المرحلة 1: استخراج الإعدادات الديناميكية من صفحة /watch] ---")
    try:
        watch_url = f"https://www.youtube.com/watch?v={video_id}&hl=en"
        print(f"  - تحميل HTML من: {watch_url}")
        watch_resp = session.get(watch_url)
        watch_resp.raise_for_status()
        watch_html = watch_resp.text

        ytcfg_match = re.search(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;', watch_html)
        if not ytcfg_match:
            # محاولة استخراج بديلة لمسار INNERTUBE_API_KEY
            alt_key = re.search(r'INNERTUBE_API_KEY\"\s*:\s*\"(.+?)\"', watch_html)
            if alt_key:
                ytcfg_data = {"INNERTUBE_API_KEY": alt_key.group(1)}
                visitor_data = re.search(r'"VISITOR_DATA":"(.*?)"', watch_html)
                ytcfg_data["VISITOR_DATA"] = visitor_data.group(1) if visitor_data else ""
            else:
                raise ExtractorError("لم يتم العثور على 'ytcfg'.")
        else:
            ytcfg_data = json.loads(ytcfg_match.group(1))

        dynamic_api_key = ytcfg_data.get("INNERTUBE_API_KEY")
        if not dynamic_api_key:
            raise ExtractorError("لم يتم العثور على 'INNERTUBE_API_KEY' في ytcfg.")
        visitor_data = ytcfg_data.get("VISITOR_DATA", "")
        print("  - ✅ تم استخراج مفتاح API وبصمة الزائر (VISITOR_DATA) بنجاح.")

    except Exception as e:
        print(f"  - ❌ فشل في الحصول على الإعدادات: {e}")
        return

    print("\n--- [المرحلة 2: استدعاء API المشغل `v1/player`] ---")
    api_url = f"https://www.youtube.com/youtubei/v1/player?key={dynamic_api_key}"

    # استخدام نسخة من السياق (حتى لا نعدل النسخة الأصلية عن طريق الخطأ)
    final_context = json.loads(json.dumps(WEB_SAFARI_CONTEXT))
    final_context["client"]["visitorData"] = visitor_data

    payload = {"context": final_context, "videoId": video_id}

    try:
        print("  - إرسال طلب POST إلى player...")
        response = session.post(api_url, json=payload)
        response.raise_for_status()
        api_response_json = response.json()
        print("  - ✅ تم استلام استجابة JSON بنجاح.")
    except Exception as e:
        print(f"  - ❌ فشل طلب الـ API: {e}")
        # اطبع بعض الرد للمساعدة في التشخيص (إن وُجد)
        try:
            print("  - محتوى الخطأ (إذا وُجد):", getattr(e, "response", None) and e.response.text)
        except Exception:
            pass
        return

    print("\n--- [المرحلة 3: البحث عن hlsManifestUrl] ---")
    streaming_data = api_response_json.get("streamingData")
    if not streaming_data:
        print("  - ❌ لم يتم العثور على قسم 'streamingData'.")
        # طباعة أقسام مهمة لمساعدة التشخيص
        if "playabilityStatus" in api_response_json:
            print("    playabilityStatus:", api_response_json.get("playabilityStatus"))
        return

    hls_manifest_api_url = streaming_data.get("hlsManifestUrl")
    if not hls_manifest_api_url:
        print("  - ❌ الخادم لم يرسل 'hlsManifestUrl' لهذا العميل. قد يكون الفيديو لا يدعم HLS أو يتطلب عميلاً آخر.")
        # عرض adaptiveFormats إن وجدت
        if "adaptiveFormats" in streaming_data:
            print("  - نقاط الوصول البديلة (adaptiveFormats) موجودة:")
            for fmt in streaming_data.get("adaptiveFormats", []):
                print("    -", fmt.get("mimeType"), fmt.get("url", fmt.get("signatureCipher", "<cipher>"))[:120])
        return

    print(f"  - ✅ تم العثور على رابط API بناء الـ Manifest:\n    {hls_manifest_api_url}")

    print("\n--- [المرحلة 4: طلب وبناء ملف m3u8 النهائي] ---")
    try:
        print(f"  - إرسال طلب GET إلى رابط الـ API...")
        # نستخدم نفس الجلسة (بما فيها الكوكيز والرؤوس) لطلب ملف الـ m3u8
        manifest_response = session.get(hls_manifest_api_url)
        manifest_response.raise_for_status()
        m3u8_content = manifest_response.text

        print("  - ✅ تم استلام محتوى ملف m3u8 بنجاح!")
        print("\n" + "="*24 + " 📜 محتوى ملف M3U8 النهائي 📜 " + "="*24)
        print(m3u8_content[:10000])  # طباعة أول جزء لتجنب فيضان المخرجات

        # استخراج الروابط من داخل ملف M3U8 كمثال
        print("\n--- [المرحلة 5: استخراج الروابط من داخل M3U8] ---")
        media_urls = re.findall(r'^(https?://.*)$', m3u8_content, re.MULTILINE)
        if media_urls:
            print(f"  - ✅ تم العثور على {len(media_urls)} رابط وسائط داخل الملف:")
            for i, media_url in enumerate(media_urls):
                print(f"    رابط {i+1}: {media_url[:200]}...")
        else:
            print("  - ⚠️ لم يتم العثور على روابط وسائط مباشرة داخل الملف.")

    except Exception as e:
        print(f"  - ❌ فشل في الحصول على محتوى M3U8: {e}")

# ==============================================================================
# تنفيذ البرنامج
# ==============================================================================
if __name__ == "__main__":
    url_input = input("ضع رابط يوتيوب: ").strip()
    if url_input:
        get_hls_manifest_url(url_input, cookies=COOKIES)
    else:
        print("لم يتم إدخال رابط.")
