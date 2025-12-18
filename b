import requests

url = "https://watch.strp2p.site/12c3899e-20c0-4d35-942e-92f2ea124260"

headers = {
    "Referer": "https://watch.strp2p.site/",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
}

def is_mp4(url):
    try:
        # 1️⃣ محاولة HEAD
        r = requests.head(url, headers=headers, allow_redirects=True, timeout=10)
        content_type = r.headers.get("Content-Type", "").lower()

        print("Content-Type:", content_type)

        if "video/mp4" in content_type:
            return True

        # 2️⃣ قراءة أول 32 بايت (ftyp box)
        r = requests.get(url, headers=headers, stream=True, timeout=10)
        first_bytes = r.raw.read(32)

        if b"ftyp" in first_bytes:
            return True

        return False

    except Exception as e:
        print("Error:", e)
        return False


if __name__ == "__main__":
    if is_mp4(url):
        print("✅ الرابط هو MP4")
    else:
        print("❌ الرابط ليس MP4")
