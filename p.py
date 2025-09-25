#!/usr/bin/env python3
# decode_android.py
# شغّل في Pydroid3 أو Termux: python decode_android.py
# يحمِل صفحة ويب مع Referer، يبحث عن السلسلة المشفّرة ويفكّها

import requests
import re
import base64
from pathlib import Path
import sys

# ------------ إعدادات إفتراضية (غيّرها إن أردت) ------------
URL = "https://cimanow.cc/%d9%81%d9%8a%d9%84%d9%85-the-fantastic-four-first-steps-2025-%d9%85%d8%aa%d8%b1%d8%ac%d9%85/watching/"
REFERER = "https://rm.freex2line.online/2020/02/blog-post.html/"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115 Mobile Safari/537.36",
    "Referer": REFERER
}
OUTPUT_FILE = "output.html"
# -----------------------------------------------------------

def normalize_base64_dot_sequence(s):
    # احتفظ فقط بحروف base64 و '.' لأن المقاطع مفصولة بنقاط
    cleaned = re.sub(r"[^A-Za-z0-9+/=\.]", "", s)
    cleaned = re.sub(r"\.{2,}", ".", cleaned).strip(".")
    return cleaned

def safe_b64decode(s):
    s2 = s.strip()
    if not s2:
        return ""
    pad = (-len(s2)) % 4
    s2 += "=" * pad
    try:
        return base64.b64decode(s2).decode('latin-1')
    except Exception:
        return ""

def decode_hide_string(hide_str):
    hide_str = normalize_base64_dot_sequence(hide_str)
    parts = [p for p in hide_str.split('.') if p]
    chars = []
    for p in parts:
        decoded = safe_b64decode(p)
        if not decoded:
            continue
        digits = re.sub(r'\D', '', decoded)
        if not digits:
            continue
        try:
            code_point = int(digits) - 87653
            if 0 <= code_point <= 0x10FFFF:
                chars.append(chr(code_point))
        except Exception:
            continue
    combined = "".join(chars)
    try:
        final = combined.encode('latin-1').decode('utf-8')
    except Exception:
        final = combined
    return final

def extract_hide_from_quotes(raw):
    # يتعامل مع hide_my_HTML_ = '...' + "..." + '...';
    pattern = re.compile(
        r"hide_my_HTML_\s*=\s*((?:'[^']*'|\"[^\"]*\")(?:\s*\+\s*(?:'[^']*'|\"[^\"]*\"))*)\s*;",
        re.DOTALL
    )
    m = pattern.search(raw)
    if not m:
        return None
    raw_group = m.group(1)
    parts = re.findall(r"'([^']*)'|\"([^\"]*)\"", raw_group, re.DOTALL)
    combined = "".join(p[0] or p[1] for p in parts)
    return combined

def find_odc_candidates(page_text):
    # يبحث عن سلاسل طويلة تبدأ بـ ODc وتحتوي نقاط '.' (نماذج عديدة في صفحاتك)
    candidates = set()
    # أولاً، ابحث عن أي سلسلة داخل سكربت تحتوي "ODc" و '.' و تكون طويلة
    for script in re.findall(r"<script[^>]*>(.*?)</script>", page_text, re.DOTALL | re.IGNORECASE):
        if "ODc" in script:
            # اجمع تسلسل طويل من أحرف base64 والنقاط والـ plus والاقتباسات
            # سنبحث عن كل تجمُّع قد يحتوي على المقاطع: مثال 'ODc3Njg.ODc3NTI...' + '...'
            for m in re.finditer(r"(?:['\"](?:ODc[A-Za-z0-9+/=\.]{20,})['\"](?:\s*\+\s*['\"][A-Za-z0-9+/=\.]{1,}['\"])*|\bODc[A-Za-z0-9+/=\.]{20,}\b)", script):
                cand = m.group(0)
                # نزيل اقتباسات و + و مسافات
                cand = re.sub(r"['\"\s\+]", "", cand)
                # بعض النصوص قد تحتوي على حرف 'O' زائد مفصول بنقطة في النهاية -> ننظف
                cand = re.sub(r"\bO\b", "", cand)
                # أبقي المحتوى الطويل فقط
                if len(cand) > 50 and "ODc" in cand:
                    candidates.add(cand)
    return list(candidates)

def fetch_page(url):
    try:
        r = requests.get(url, headers=HEADERS, timeout=20)
        return r
    except Exception as e:
        print("خطأ عند جلب الصفحة:", e)
        return None

def main():
    url = URL
    if len(sys.argv) > 1:
        url = sys.argv[1]
    print("جلب:", url)
    resp = fetch_page(url)
    if not resp:
        return
    print("Status code:", resp.status_code)
    print("--- Headers ---")
    for k, v in resp.headers.items():
        print(f"{k}: {v}")
    print("--------------\n")

    text = resp.text

    results = []

    # محاولة 1: استخراج hide_my_HTML_ بالصورة المعتادة
    h = extract_hide_from_quotes(text)
    if h:
        print("وجدت تعريف hide_my_HTML_ مباشرة.")
        results.append(h)
    else:
        # محاولة 2: البحث عن أي سلاسل ODc مشبوهة داخل سكربتات
        candidates = find_odc_candidates(text)
        if candidates:
            print(f"وجدت {len(candidates)} مرشح(مرشحين) لسلاسل مشفرة.")
            results.extend(candidates)

    if not results:
        print("لم أجد أي سلاسل مشفرة قابلة للاستخراج.")
        return

    final_outputs = []
    for i, seq in enumerate(results, start=1):
        print(f"\n--- فك السلسلة #{i} (طول: {len(seq)}) ---")
        decoded = decode_hide_string(seq)
        if decoded:
            # اطبع أول 2000 حرف (يمكن تغييره)
            print(decoded[:2000])
            final_outputs.append(decoded)
        else:
            print("(لم يُنتج أي محتوى — قد تكون السلسلة ناقصة أو مختلفة النمط)")

    if final_outputs:
        merged = "\n".join(final_outputs)
        Path(OUTPUT_FILE).write_text(merged, encoding="utf-8")
        print(f"\nتم حفظ الناتج الكامل في: {Path(OUTPUT_FILE).resolve()}")

if __name__ == "__main__":
    main()
