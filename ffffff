import re
import requests
import json

# رابط الحلقة
url = "https://shhahid4u.cam/watch/%D9%85%D8%B3%D9%84%D8%B3%D9%84-el-turco-%D8%A7%D9%84%D9%85%D9%88%D8%B3%D9%85-%D8%A7%D9%84%D8%A7%D9%88%D9%84-%D8%A7%D9%84%D8%AD%D9%84%D9%82%D8%A9-3-%D9%85%D8%AA%D8%B1%D8%AC%D9%85%D8%A9"

# تهيئة رؤوس الطلب لتفادي الحظر
headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/128.0.0.0 Safari/537.36"
}

# جلب الصفحة
response = requests.get(url, headers=headers)
html = response.text

# البحث عن متغير servers في السكربت
match = re.search(r"let\s+servers\s*=\s*JSON\.parse\('(.+?)'\);", html)

if match:
    # فك ترميز النص واستبدال الرموز
    json_text = match.group(1)
    json_text = json_text.encode('utf-8').decode('unicode_escape')
    
    # تحويل النص إلى JSON فعلي
    servers = json.loads(json_text)
    
    print("✅ تم العثور على السيرفرات التالية:\n")
    for s in servers:
        print(f"{s['name']}: {s['url']}")
else:
    print("❌ لم يتم العثور على أي بيانات للسيرفرات في الصفحة.")
