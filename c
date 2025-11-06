package com.bristeg

import android.util.Log
import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.Qualities
import org.jsoup.nodes.Element
import com.lagradost.cloudstream3.utils.newExtractorLink
import kotlinx.coroutines.GlobalScope
import com.lagradost.cloudstream3.network.WebViewResolver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

import com.lagradost.cloudstream3.utils.JsUnpacker
class BrstejProvider : MainAPI() {
    // تعريف TAG ثابت لاستخدامه في Logcat
    companion object {
        private const val TAG = "BRSTEJ_DEBUG"
    }

    override var mainUrl = "https://amd.brstej.com"
    override var name = "برستيج"
    override val hasMainPage = true
    override var lang = "ar"
    override val supportedTypes = setOf(
        TvType.TvSeries,
        TvType.Movie
    )

    private fun cleanPosterUrl(url: String?): String? {
        if (url == null || url.isBlank()) return null
        var u = url.trim()
        val wpProxy = Regex("""https?://i\d+\.wp\.com/(.+)""")
        val m = wpProxy.find(u)
        if (m != null) {
            u = m.groupValues[1]
            if (!u.startsWith("http://") && !u.startsWith("https://")) {
                u = "https://$u"
            }
        }
        u = u.split("?")[0]
        if (u.startsWith("//")) u = "https:$u"
        if (!u.startsWith("http://") && !u.startsWith("https://")) {
            val base = mainUrl.trimEnd('/')
            when {
                u.startsWith("/") -> u = "$base$u"
                else -> u = "$base/$u"
            }
        }
        return u
    }

    // ================== التعديل هنا ==================
    private fun Element.toSearchResponse(): SearchResponse? {
        Log.d(TAG, "-> toSearchResponse: بدء معالجة عنصر")

        // 1. استهداف رابط العنوان لأنه أكثر موثوقية
        val titleLinkElement = this.selectFirst("div.caption h3 a") ?: run {
            Log.w(
                TAG,
                "toSearchResponse: لم يتم العثور على رابط العنوان (div.caption h3 a)، سيتم تخطي العنصر."
            )
            return null
        }

        val href = titleLinkElement.attr("href")
        if (href.isBlank() || href == "#modal-login-form") {
            Log.w(TAG, "toSearchResponse: الرابط فارغ أو رابط تسجيل دخول، سيتم تخطي العنصر.")
            return null
        }
        Log.d(TAG, "toSearchResponse: تم العثور على الرابط الصحيح: $href")

        val title = titleLinkElement.attr("title")?.trim() ?: titleLinkElement.text().trim()
        if (title.isBlank()) {
            Log.w(TAG, "toSearchResponse: لم يتم العثور على العنوان، سيتم تخطي العنصر.")
            return null
        }
        Log.d(TAG, "toSearchResponse: تم العثور على العنوان: $title")

        // 2. البحث عن البوستر في مكانه الأصلي
        val img = this.selectFirst("div.pm-video-thumb img")
        val rawPoster = img?.attr("data-echo") ?: img?.attr("data-original") ?: img?.attr("src")
        val posterUrl = cleanPosterUrl(rawPoster)
        Log.d(
            TAG,
            "toSearchResponse: رابط البوستر الخام: $rawPoster -> رابط البوستر النظيف: $posterUrl"
        )

        return newTvSeriesSearchResponse(title, href, TvType.TvSeries) {
            this.posterUrl = posterUrl
        }
    }
    // ================== نهاية التعديل ==================

    override val mainPage = mainPageOf(
        "index.php" to "الرئيسية",
        "category818.php?cat=prss7-2025" to "مسلسلات برستيج",
        "category.php?cat=movies2-2224" to "افلام",
        "category.php?cat=ramdan1-2024" to "مسلسلات رمضان 2024",
        "newvideo.php" to "أخر الاضافات"
    )

    override suspend fun getMainPage(
        page: Int,
        request: MainPageRequest
    ): HomePageResponse {
        Log.d(TAG, "===> getMainPage: بدء التنفيذ لـ '${request.name}'، صفحة: $page")
        val url = "$mainUrl/${request.data}" + (if (page > 1) "&page=$page" else "")
        Log.d(TAG, "getMainPage: الرابط الذي سيتم جلبه: $url")

        try {
            val document = app.get(url).document
            Log.d(TAG, "getMainPage: تم جلب الصفحة بنجاح. عنوان الصفحة: ${document.title()}")

            val selector =
                "ul[class*='pm-ul-browse-videos'] > li, ul[class*='pm-ul-carousel-videos'] > li"
            Log.d(TAG, "getMainPage: سيتم استخدام المحدد (selector): $selector")

            val items = document.select(selector)
            Log.d(TAG, "getMainPage: تم العثور على ${items.size} عنصر باستخدام المحدد.")

            if (items.isEmpty()) {
                Log.w(
                    TAG,
                    "getMainPage: تحذير: لم يتم العثور على أي عناصر. قد تكون الصفحة فارغة أو المحدد غير صحيح."
                )
            }

            val home = items.mapNotNull {
                it.toSearchResponse()
            }
            Log.d(TAG, "getMainPage: تم تحويل ${home.size} عنصر بنجاح.")

            return newHomePageResponse(request.name, home)
        } catch (e: Exception) {
            Log.e(TAG, "getMainPage: حدث خطأ فادح أثناء جلب أو تحليل الصفحة!", e)
            throw e
        }
    }

    override suspend fun search(query: String): List<SearchResponse> {
        Log.d(TAG, "===> search: بدء البحث عن: '$query'")
        val url = "$mainUrl/search.php?keywords=$query"
        Log.d(TAG, "search: الرابط الذي سيتم جلبه: $url")

        try {
            val document = app.get(url).document
            Log.d(TAG, "search: تم جلب صفحة البحث بنجاح. عنوان الصفحة: ${document.title()}")

            val selector = "ul.pm-ul-browse-videos > li"
            Log.d(TAG, "search: سيتم استخدام المحدد (selector): $selector")

            val items = document.select(selector)
            Log.d(TAG, "search: تم العثور على ${items.size} نتيجة بحث.")

            if (items.isEmpty()) {
                Log.w(TAG, "search: تحذير: لم يتم العثور على أي نتائج بحث.")
            }

            val results = items.mapNotNull {
                it.toSearchResponse()
            }
            Log.d(TAG, "search: تم تحويل ${results.size} نتيجة بنجاح.")
            return results
        } catch (e: Exception) {
            Log.e(TAG, "search: حدث خطأ فادح أثناء البحث!", e)
            throw e
        }
    }


    private fun buildAbsoluteUrl(href: String?, base: String = mainUrl): String {
        if (href.isNullOrBlank()) return ""
        var h = href.trim()
        if (h.startsWith("http://") || h.startsWith("https://")) return h
        // إزالة بادئة ./ إن وُجدت
        if (h.startsWith("./")) h = h.removePrefix("./")
        // حالة "/path..."
        val baseTrim = base.trimEnd('/')
        return if (h.startsWith("/")) "$baseTrim$h" else "$baseTrim/$h"
    }

    // الآن الدالة معلّقة (suspend) لأنها تستدعي resolveUsingWebView الذي هو suspend


    override suspend fun load(url: String): LoadResponse? {
        try {
            val document = app.get(url, timeout = 15).document
            val title =
                document.selectFirst("div.pm-video-heading h1")?.text()?.trim() ?: return null
            val poster =
                cleanPosterUrl(document.selectFirst("meta[property=og:image]")?.attr("content"))
            val description =
                document.selectFirst("div.pm-video-description > div.txtv")?.text()?.trim()
            val tags = document.select("dl.dl-horizontal p a span").map { it.text() }

            val isSeries = document.selectFirst("div.SeasonsBox") != null

            if (isSeries) {
                val episodes = mutableListOf<Episode>()

                // اجلب قائمة المواسم
                val seasonListItems = document.select("div.SeasonsBoxUL ul li")
                for (seasonLi in seasonListItems) {
                    val seasonName = seasonLi.text().trim()
                    val seasonId = seasonLi.attr("data-serie")
                    val seasonNum = seasonId.toIntOrNull()

                    if (seasonId.isNullOrBlank()) continue

                    // ابحث عن الحلقات الموافقة لمعرف الموسم
                    val episodesSelector = "div.SeasonsEpisodes[data-serie='${seasonId}'] a"
                    document.select(episodesSelector).forEach { epElement ->
                        val epUrlRaw = epElement.attr("href")
                        if (epUrlRaw.isBlank()) return@forEach

                        val epUrl = buildAbsoluteUrl(epUrlRaw)
                        val epName = epElement.attr("title").ifBlank { epElement.text() }
                        val epNum = epElement.selectFirst("em")?.text()?.toIntOrNull()

                        episodes.add(
                            newEpisode(epUrl) {
                                data = epUrl
                                name = epName
                                season = seasonNum
                                episode = epNum
                            }
                        )
                    }
                }

                // فرز حسب الموسم ثم رقم الحلقة
                val sorted = episodes.sortedWith(compareBy<Episode> { it.season ?: Int.MAX_VALUE }
                    .thenBy { it.episode ?: Int.MAX_VALUE })

                return newTvSeriesLoadResponse(title, url, TvType.TvSeries, sorted) {
                    this.posterUrl = poster
                    this.plot = description
                    this.tags = tags
                }
            } else {
                return newMovieLoadResponse(title, url, TvType.Movie, url) {
                    this.posterUrl = poster
                    this.plot = description
                    this.tags = tags
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }


    // ----- resolveEmbedWithUnpack محسّنة مع فحص مباشر وجميع لوجات التشخيص -----
    // ضع هذه الدوال داخل نفس الكلاس BrstejProvider

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        Log.d(TAG, "loadLinks ▶ start — data=$data")

        // ------------------ بداية الدوال المدمجة ------------------

        // دالة فك التعمية (نفس منطق بايثون)
        // دالة فك التعمية - النسخة النهائية والصحيحة
        // دالة فك التعمية - النسخة النهائية التي تحاكي منطق بايثون الصحيح
        fun unpackJs(packedJs: String): String? {
            try {
                Log.d(TAG, "unpackJs ▶ trying to unpack content length=${packedJs.length}")

                // نمط مرن لالتقاط الوسائط
                val regex = Regex("""eval\(function\(p,a,c,k,e,d\)\{(.*)\}\((.*?),(\d+),(\d+),'(.*?)'\.split\('\|'\)\)\)""", RegexOption.DOT_MATCHES_ALL)
                val m = regex.find(packedJs) ?: run {
                    Log.w(TAG, "unpackJs ▶ regex did not match the packed pattern")
                    return null
                }

                val payloadWithQuotes = m.groupValues[2]
                val payload = payloadWithQuotes.removeSurrounding("'").removeSurrounding("\"")
                val base = m.groupValues[3].toIntOrNull() ?: return null
                val count = m.groupValues[4].toIntOrNull() ?: return null
                val dictionary = m.groupValues[5].split("|")

                Log.d(TAG, "unpackJs ▶ captured base=$base count=$count dictLen=${dictionary.size} payloadLen=${payload.length}")


                fun intToBaseStr(n: Int, baseNum: Int): String {
                    val digits = "0123456789abcdefghijklmnopqrstuvwxyz"
                    return if (n < baseNum) digits.getOrNull(n)?.toString() ?: ""
                    else intToBaseStr(n / baseNum, baseNum) + (digits.getOrNull(n % baseNum) ?: "")
                }

                // --- المنطق الصحيح: بناء جدول البحث أولاً ---
                val lookup = mutableMapOf<String, String>()
                for (i in (count - 1) downTo 0) {
                    val key = try { intToBaseStr(i, base) } catch (e: Exception) { i.toString() }
                    val value = dictionary.getOrNull(i)?.ifBlank { key } ?: key
                    lookup[key] = value
                }

                // --- المنطق الصحيح: استبدال في خطوة واحدة باستخدام لامدا ---
                val tokenRegex = Regex("""\b\w+\b""")
                val unpacked = tokenRegex.replace(payload) { matchResult ->
                    lookup[matchResult.value] ?: matchResult.value
                }

                if (unpacked.isBlank() || !unpacked.contains("http")) {
                    Log.w(TAG, "unpackJs ▶ Unpacked result seems invalid or doesn't contain links.")
                    return null
                }

                Log.d(TAG, "unpackJs ▶ unpack success, length=${unpacked.length}")
                return unpacked

            } catch (e: Exception) {
                Log.e(TAG, "unpackJs ▶ exception", e)
                return null
            }
        }
        // دالة استخراج الرابط من صفحة التضمين
        suspend fun extractFromEmbed(embedUrl: String, referer: String) {
            try {
                Log.d(TAG, "extractFromEmbed: GET $embedUrl")
                val embedText = app.get(embedUrl, referer = referer, timeout = 15).text

                val packedJsMatch = Regex(
                    """eval\(function\(p,a,c,k,e,d\)\s*\{[\s\S]+?\}\s*\([\s\S]+?\)\)""",
                    RegexOption.DOT_MATCHES_ALL
                ).find(embedText)

                if (packedJsMatch == null) {
                    Log.w(
                        TAG,
                        "extractFromEmbed: no packed eval(...) found, sending fallback for $embedUrl"
                    )
                    callback(
                        newExtractorLink(
                            this.name,
                            "${this.name} - embed (fallback)",
                            embedUrl
                        ) {
                            this.referer = referer
                            this.quality = Qualities.Unknown.value
                        })
                    return
                }

                val packedJsCode = packedJsMatch.value
                Log.d(TAG, "extractFromEmbed: found packed script length=${packedJsCode.length}")

                // محاولة 1: JsUnpacker المدمجة
                var unpacked = try {
                    JsUnpacker(packedJsCode).unpack()
                } catch (e: Exception) {
                    null
                }

                // محاولة 2: الدالة اليدوية كخطة بديلة
                if (unpacked.isNullOrBlank()) {
                    Log.d(TAG, "extractFromEmbed: JsUnpacker failed, trying python-style unpacker")
                    unpacked = unpackJs(packedJsCode)
                }

                if (unpacked.isNullOrBlank()) {
                    Log.w(TAG, "extractFromEmbed: unpacking failed for $embedUrl, sending fallback")
                    callback(
                        newExtractorLink(
                            this.name,
                            "${this.name} - embed (fallback)",
                            embedUrl
                        ) {
                            this.referer = referer
                            this.quality = Qualities.Unknown.value
                        })
                    return
                }

                Log.d(TAG, "extractFromEmbed: unpacked length=${unpacked.length}")

                val fileMatch = Regex("""file\s*:\s*"(https?://.*?)"""").find(unpacked)
                if (fileMatch != null) {
                    val videoUrl = fileMatch.groupValues[1]
                    Log.i(TAG, "extractFromEmbed: extracted video url -> $videoUrl")
                    callback(newExtractorLink(this.name, "${this.name} (unpacked)", videoUrl) {
                        this.referer = embedUrl
                        this.quality = Qualities.Unknown.value
                    })
                } else {
                    Log.w(
                        TAG,
                        "extractFromEmbed: no file found in unpacked script, sending fallback for $embedUrl"
                    )
                    callback(
                        newExtractorLink(
                            this.name,
                            "${this.name} - embed (fallback)",
                            embedUrl
                        ) {
                            this.referer = referer
                            this.quality = Qualities.Unknown.value
                        })
                }
            } catch (e: Exception) {
                Log.e(TAG, "extractFromEmbed: unexpected error for $embedUrl", e)
                callback(
                    newExtractorLink(
                        this.name,
                        "${this.name} - embed (error fallback)",
                        embedUrl
                    ) {
                        this.referer = referer
                        this.quality = Qualities.Unknown.value
                    })
            }
        }
        // ------------------ نهاية الدوال المدمجة ------------------

        try {
            val watchDoc = app.get(data, referer = mainUrl, timeout = 15).document
            val playHrefRaw = watchDoc.selectFirst("a.xtgo")?.attr("href") ?: return false
            val playUrl = buildAbsoluteUrl(playHrefRaw)
            val playDoc = app.get(playUrl, referer = data, timeout = 15).document

            val processedUrls = mutableSetOf<String>()

            // استخدم coroutineScope لضمان تشغيل كل شيء في الخلفية دون حجب الخيط الرئيسي
            kotlinx.coroutines.coroutineScope {
                // 1. استخراج الروابط من أزرار السيرفرات
                playDoc.select("div#WatchServers button.watchButton, div#WatchServers button.watchbutton")
                    .forEach { btn ->
                        val embedUrl = btn.attr("data-embed-url")?.let { buildAbsoluteUrl(it) }
                        if (!embedUrl.isNullOrBlank() && processedUrls.add(embedUrl)) { // .add() returns true if item was added
                            Log.d(TAG, "loadLinks: Found button embedUrl='$embedUrl'")
                            launch { extractFromEmbed(embedUrl, playUrl) }
                        }
                    }

                // 2. استخراج الرابط من الـ iframe إذا وُجد
                val iframeSrc = playDoc.selectFirst("div#Playerholder iframe")?.attr("src")
                    ?.let { buildAbsoluteUrl(it) }
                if (!iframeSrc.isNullOrBlank() && processedUrls.add(iframeSrc)) {
                    Log.d(TAG, "loadLinks: Found iframe src='$iframeSrc'")
                    launch { extractFromEmbed(iframeSrc, playUrl) }
                }
            }

            return processedUrls.isNotEmpty()
        } catch (e: Exception) {
            Log.e(TAG, "loadLinks: top-level error", e)
            return false
        }
    }
}
