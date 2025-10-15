import cloudscraper
from bs4 import BeautifulSoup
import re
import warnings
import base64

# تجاهل التحذيرات غير الضرورية
warnings.filterwarnings("ignore", category=FutureWarning, module='soupsieve')

BASE_URL = "https://got.animerco.org"

def get_servers_from_episode_url(episode_url):
    """
    يأخذ رابط حلقة ويستخرج قائمة بسيرفرات المشاهدة وروابط التحميل النهائية.
    """
    scraper = cloudscraper.create_scraper()
    servers = {'watch': [], 'download': []}
    
    try:
        print(f"\n[*] جارِ جلب بيانات الحلقة: {episode_url}")
        response = scraper.get(episode_url, headers={'Referer': BASE_URL})
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')

        # --- استخراج Nonce اللازم لطلبات AJAX ---
        script_content = soup.find("script", id="dt_main_ajax-js-extra")
        if not script_content or not script_content.string:
            print("[!] لم يتم العثور على معلومات AJAX (nonce).")
            return servers
            
        nonce_match = re.search(r'"nonce":"([a-f0-9]+)"', script_content.string)
        if not nonce_match:
            print("[!] لم يتم العثور على 'nonce'.")
            return servers
        nonce = nonce_match.group(1)

        # --- 1. جلب سيرفرات المشاهدة (عبر AJAX) ---
        ajax_url = f"{BASE_URL}/wp-admin/admin-ajax.php"
        viewing_server_buttons = soup.select("ul.server-list li a.option")
        
        for button in viewing_server_buttons:
            post_id = button.get('data-post')
            server_num = button.get('data-nume')
            server_type = button.get('data-type')
            server_name = button.select_one("span.server").text.strip()
            
            if not all([post_id, server_num, server_type]):
                continue
            
            payload = {'action': 'player_ajax', 'post': post_id, 'nume': server_num, 'type': server_type, 'nonce': nonce}
            try:
                ajax_response = scraper.post(ajax_url, data=payload, headers={'Referer': episode_url}).json()
                embed_url = ajax_response.get('embed_url', '')
                # تنظيف الرابط من وسوم iframe إذا وجدت
                clean_url = re.sub(r'<iframe[^>]+src=["\']|["\'].*', '', embed_url).strip()
                if clean_url:
                    servers['watch'].append({'server': server_name, 'url': clean_url})
            except Exception as e:
                print(f"    - فشل في جلب سيرفر المشاهدة '{server_name}': {e}")

        # --- 2. جلب روابط التحميل النهائية ---
        download_rows = soup.select("div#download table tbody tr")
        for row in download_rows:
            link_tag = row.select_one("a")
            if link_tag:
                intermediate_url = link_tag.get('href')
                quality = row.select_one("td:nth-child(3)").text.strip()
                try:
                    wait_page_resp = scraper.get(intermediate_url, headers={'Referer': episode_url})
                    wait_page_soup = BeautifulSoup(wait_page_resp.text, 'html.parser')
                    encoded_url = wait_page_soup.select_one("a#link[data-url]")['data-url']
                    final_url = base64.b64decode(encoded_url).decode('utf-8')
                    servers['download'].append({'quality': quality, 'url': final_url})
                except Exception as e:
                    print(f"    - فشل في تخطي صفحة انتظار التحميل: {e}")
                    
    except Exception as e:
        print(f"\n[!] حدث خطأ غير متوقع: {e}")
        
    return servers

# --- بداية تشغيل البرنامج ---
if __name__ == "__main__":
    # ضع رابط أي حلقة أو فيلم هنا للاختبار
    target_url = "https://got.animerco.org/episodes/one-punch-man-season-3-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-0/"
    # مثال آخر لفيلم
    # target_url = "https://got.animerco.org/movies/one-piece-film-gold/"
    
    # استدعاء الدالة
    all_servers = get_servers_from_episode_url(target_url)
    
    # طباعة النتائج بشكل منظم
    if all_servers['watch']:
        print("\n===============================")
        print("     سيرفرات المشاهدة")
        print("===============================")
        for server_info in all_servers['watch']:
            print(f"- سيرفر '{server_info['server']}': {server_info['url']}")
    else:
        print("\n[!] لم يتم العثور على سيرفرات مشاهدة.")

    if all_servers['download']:
        print("\n===============================")
        print("       روابط التحميل")
        print("===============================")
        for link_info in all_servers['download']:
            print(f"- جودة '{link_info['quality']}': {link_info['url']}")
    else:
        print("\n[!] لم يتم العثور على روابط تحميل.")