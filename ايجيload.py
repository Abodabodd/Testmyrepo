import requests, re, sys
from bs4 import BeautifulSoup
from urllib.parse import urljoin
from collections import deque
from concurrent.futures import ThreadPoolExecutor, as_completed

# ----------------- الإعدادات -----------------
initial_url = "https://a.egydead.space/episode/%d8%a7%d9%86%d9%85%d9%8a-one-piece-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-335-%d9%85%d8%aa%d8%b1%d8%ac%d9%85%d8%a9/"
HEADERS = {"User-Agent": "Mozilla/5.0"}
TIMEOUT = 12
MAX_WORKERS = 8    # زِد لخيوط أكثر (أسرع لكن يستهلك عرض نطاق)
# --------------------------------------------

# ---------- دوال مساعدة قصيرة ----------
def normalize(link, base):
    if not link or link.strip().startswith(('#', 'javascript:')): return None
    return urljoin(base, link.strip())

re_season = re.compile(r'الموسم\s+(\d+)', re.I)
re_episode = re.compile(r'الحلقة\s*(\d+)|Episode\s*(\d+)|EP\s*(\d+)', re.I)

def season_key(title):
    m = re_season.search(title or "")
    return int(m.group(1)) if m else 9999

def episode_key(title):
    m = re_episode.search(title or "")
    if not m: return 9999
    for g in m.groups():
        if g: return int(g)
    return 9999

def fetch(session, url):
    try:
        r = session.get(url, headers=HEADERS, timeout=TIMEOUT)
        r.raise_for_status()
        return url, r.text, r.url
    except Exception as e:
        return url, None, None

def batch_fetch(urls, session, workers=MAX_WORKERS):
    out = {}
    with ThreadPoolExecutor(max_workers=min(workers, max(1, len(urls)))) as ex:
        futs = {ex.submit(fetch, session, u): u for u in urls}
        for f in as_completed(futs):
            u, html, final = f.result()
            out[u] = (html, final)
    return out

def extract_episodes_from_soup(base, soup):
    res = []
    cont = soup.find("div", class_="episodes-list")
    if not cont: return []
    eps_div = cont.find("div", class_="EpsList") or cont.find("ul")
    if not eps_div: return []
    for li in eps_div.find_all("li"):
        a = li.find("a")
        if not a: continue
        title = (a.get("title") or a.get_text(strip=True)).strip()
        link = normalize(a.get("href",""), base)
        if link and not any(link==e["link"] for e in res):
            res.append({"title": title, "link": link})
    return sorted(res, key=lambda e: episode_key(e["title"]))

def parse_og(soup, base_url):
    t = soup.find('meta', property='og:title')
    img = soup.find('meta', property='og:image')
    return (t['content'].strip() if t and t.get('content') else "عنوان غير معروف",
            normalize(img.get('content'), base_url) if img and img.get('content') else None)

# ---------- منطق الاكتشاف (مواسم) سريع ومتوازي ----------
def discover_seasons(start_url, session):
    discovered = []
    seen = set([start_url])
    q = deque([start_url])

    while q:
        batch = []
        while q and len(batch) < MAX_WORKERS:
            batch.append(q.popleft())

        fetched = batch_fetch(batch, session)
        for url in batch:
            html, final = fetched.get(url, (None, None))[0:2]
            if not html: 
                continue
            soup = BeautifulSoup(html, "html.parser")
            title, img = parse_og(soup, final or url)
            if not any(s['link']==url for s in discovered):
                discovered.append({"title": title, "link": url, "image": img})
            # اكتشاف روابط مواسم أخرى
            cont = soup.find('div', class_='seasons-list')
            if cont:
                ul = cont.find('ul')
                if ul:
                    for li in ul.find_all('li', class_='movieItem'):
                        a = li.find('a')
                        if not a: continue
                        link = normalize(a.get('href',''), url)
                        if link and link not in seen:
                            seen.add(link)
                            q.append(link)
    # فرز قبل الإرجاع
    return sorted(discovered, key=lambda s: season_key(s['title']))

# ---------- المعالجة الرئيسية ----------
def main():
    session = requests.Session()
    start_html, actual = None, None

    u, html, final = fetch(session, initial_url)
    if not html:
        print("فشل في جلب صفحة البداية"); sys.exit(1)
    start_html, actual = html, final or initial_url
    soup = BeautifulSoup(start_html, "html.parser")

    is_episode = "/episode/" in actual
    is_season = "/season/" in actual

    if not is_episode and not is_season:
        title, img = parse_og(soup, actual)
        story = (soup.find("div", class_="singleStory").get_text(strip=True) if soup.find("div", class_="singleStory") else None)
        print(f"\n🎥 فيلم: {title}\n📝 {story or 'لا وصف'}\n🖼 {img or 'لا صورة'}\n🔗 {actual}\n")
        return

    # محاولة استخراج رابط الموسم إن بدأنا من حلقة
    start_season = None
    if is_episode:
        bc = soup.find('div', class_='breadcrumbs-single')
        if bc:
            lis = bc.find('ul').find_all('li')
            if len(lis) >= 3:
                tag = lis[-2].find('a')
                if tag and '/season/' in (tag.get('href') or ''):
                    start_season = normalize(tag.get('href'), actual)

    if not start_season and is_season:
        start_season = actual

    if not start_season:
        print("لم أستطع تحديد موسم البداية"); return

    seasons = discover_seasons(start_season, session)

    # تأكد: إن لم يظهر موسم البداية في القوائم أضفه
    if not any(s['link']==start_season for s in seasons):
        # جلب صفحة الموسم إذا لم تكن موجودة
        html_map = batch_fetch([start_season], session)
        html = html_map[start_season][0] if start_season in html_map else None
        if html:
            t, img = parse_og(BeautifulSoup(html, "html.parser"), start_season)
            seasons.insert(0, {"title": t, "link": start_season, "image": img})

    # جلب صفحات المواسم بشكل متوازي ثم استخراج الحلقات
    season_urls = [s['link'] for s in seasons]
    fetched = batch_fetch(season_urls, session)
    results = []
    for s in seasons:
        html = fetched.get(s['link'], (None, None))[0]
        if not html:
            results.append({"season_title": s['title'], "season_link": s['link'], "season_image": s.get('image'), "episodes": []})
            continue
        soup_sea = BeautifulSoup(html, "html.parser")
        episodes = extract_episodes_from_soup(s['link'], soup_sea)
        results.append({"season_title": s['title'], "season_link": s['link'], "season_image": s.get('image'), "episodes": episodes})

    # طباعة مُلخّصة
    print("\n=== النتائج ===")
    for s in results:
        print(f"\n{s['season_title']}\n{ s.get('season_image') or 'لا صورة' }\n{s['season_link']}")
        if s['episodes']:
            for e in s['episodes']:
                print(f" - {e['title']}: {e['link']}")
        else:
            print(" (لا توجد حلقات)")

if __name__ == "__main__":
    main()