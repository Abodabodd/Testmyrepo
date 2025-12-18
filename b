import requests

url = "https://sri.oakfieldproductionstudio.sbs/v4/x6b/pnhxiz/index-f1-v1-a1.txt"

headers = {
    "Referer": "https://watch.strp2p.site/",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36"
}

try:
    r = requests.get(url, headers=headers, timeout=10)
    r.raise_for_status()

    content = r.text
    print("===== CONTENT OF TXT =====")
    print(content)

except Exception as e:
    print("Error:", e)
