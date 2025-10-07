import re

def convert_to_direct_download(url):
    """
    يحول رابط preview من Google Drive إلى رابط تحميل مباشر
    """
    # البحث عن ID داخل الرابط
    match = re.search(r"/file/d/([0-9A-Za-z_-]{10,})", url)
    if not match:
        return None
    file_id = match.group(1)
    
    # تكوين رابط التحميل المباشر
    direct_url = f"https://drive.usercontent.google.com/download?id={file_id}&export=download&confirm=t"
    return direct_url

# مثال
preview_url = "https://drive.google.com/file/d/1Pk56A0la0_SufhDDxeOwltT9k4y7cbPw/preview"
download_url = convert_to_direct_download(preview_url)

print("Direct download URL:")
print(download_url)
