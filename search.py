import cloudscraper
from bs4 import BeautifulSoup
import warnings

# تجاهل التحذيرات غير الضرورية
warnings.filterwarnings("ignore", category=FutureWarning, module='soupsieve')

BASE_URL = "https://got.animerco.org"

def search_animerco(query):
    """
    يبحث في موقع Animerco عن كلمة معينة ويطبع النتائج.
    """
    scraper = cloudscraper.create_scraper()
    search_url = f"{BASE_URL}/?s={query.replace(' ', '+')}"
    
    results = []
    
    try:
        print(f"\n[*] جارِ البحث عن '{query}' في: {search_url}")
        response = scraper.get(search_url)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # --- استخراج نتائج البحث ---
        # كل نتيجة موجودة داخل <div class="search-card">
        search_results = soup.select("div.search-card")
        
        if not search_results:
            return []

        for item in search_results:
            link_tag = item.select_one("a.image")
            info_tag = item.select_one("div.info")
            
            if not link_tag or not info_tag:
                continue

            # استخراج البيانات
            url = link_tag.get('href')
            poster_url = link_tag.get('data-src')
            title = info_tag.select_one("h3").text.strip()
            
            # إضافة النتيجة إلى القائمة
            results.append({
                'title': title,
                'url': url,
                'poster_url': poster_url
            })
            
        return results

    except Exception as e:
        print(f"\n[!] حدث خطأ أثناء البحث: {e}")
        return []

# --- بداية تشغيل البرنامج ---
if __name__ == "__main__":
    while True:
        search_query = input("\n> أدخل كلمة البحث (أو اكتب 'exit' للخروج): ")
        if search_query.lower() == 'exit':
            break
        
        if not search_query.strip():
            print("[!] الرجاء إدخال كلمة للبحث.")
            continue
            
        search_results = search_animerco(search_query)
        
        if not search_results:
            print(f"\n[!] لم يتم العثور على نتائج للبحث عن '{search_query}'.")
        else:
            print("\n===============================")
            print(f"      نتائج البحث عن '{search_query}'")
            print("===============================")
            for result in search_results:
                print(f"الاسم: {result['title']}")
                print(f"الرابط: {result['url']}")
                print(f"رابط الصورة: {result['poster_url']}")
                print("-------------------------------")
            print(f"\n[*] تم العثور على {len(search_results)} نتيجة.")