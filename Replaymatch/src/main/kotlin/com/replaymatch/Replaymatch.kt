package com.replaymatch

import android.content.Intent
import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.newExtractorLink
import com.lagradost.cloudstream3.utils.loadExtractor
import com.lagradost.cloudstream3.mvvm.logError
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.Qualities
import org.jsoup.nodes.Element
import java.net.URLEncoder
import androidx.preference.PreferenceManager
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope

// تعريف محلي لـ MainCategory إذا لم تكن متوفرة في مكتبتك
data class MainCategory(val name: String, val data: String)

/**
 * FullMatchShowsProvider
 *  - يتطلب context لقراءة الإعدادات
 *  - استخدم registerMainAPI(FullMatchShowsProvider(context)) في Plugin
 */
class FullMatchShowsProvider() : MainAPI() {
    override var name = "FullMatchShows"
    override var mainUrl = "https://fullmatchshows.com"
    override var lang = "en"
    override val hasMainPage = true
    override val supportedTypes = setOf(TvType.Movie)

    // كل الفئات الممكنة
    private val categories = listOf(
        MainCategory("Premier League", "$mainUrl/leagues/premier-league/"),
        MainCategory("La liga", "$mainUrl/leagues/la-liga/"),
        MainCategory("Champions League", "$mainUrl/leagues/champions-league/"),
        MainCategory("Europa League", "$mainUrl/leagues/europa-league/"),
        MainCategory("FA Cup", "$mainUrl/leagues/fa-cup/"),
        MainCategory("BundesLiga", "$mainUrl/leagues/bundesliga/"),
        MainCategory("DFB Pokal", "$mainUrl/leagues/dfb-pokal/"),
        MainCategory("Serie A", "$mainUrl/leagues/serie-a/"),
        MainCategory("Coppa Italia", "$mainUrl/leagues/coppa-italia/"),
        MainCategory("Saudi Pro League", "$mainUrl/leagues/saudi-pro-league/")
    )

    // خريطة اسم الفئة -> مفتاح Preference
    private val categoryKeyMap = mapOf(
        "Premier League" to "show_premier_league",
        "La liga" to "show_la_liga",
        "Champions League" to "show_champions_league",
        "Europa League" to "show_europa_league",
        "FA Cup" to "show_fa_cup",
        "BundesLiga" to "show_bundesliga",
        "DFB Pokal" to "show_dfb_pokal",
        "Serie A" to "show_serie_a",
        "Coppa Italia" to "show_coppa_italia",
        "Saudi Pro League" to "show_saudi_pro"
    )

    // قراءة حالة التفعيل من SharedPreferences الافتراضي (الذي تستخدمه إعدادات النظام)
    private fun isCategoryEnabled(categoryName: String): Boolean {
        val prefs = PreferenceManager.getDefaultSharedPreferences(context)
        val key = categoryKeyMap[categoryName] ?: return true
        return prefs.getBoolean(key, true)
    }

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val document = app.get(if (page == 1) mainUrl else "$mainUrl/page/$page/").document
        val mainPageItems = parsePostItems(document.select("ul#posts-container li.post-item"))

        val lists = mutableListOf(
            HomePageList("Latest Matches", mainPageItems)
        )

        // صفحة 1: عرض إعدادات و الفئات المفعلة
        if (page == 1) {
            // عنصر لفتح الإعدادات (سيتم التقاط الرابط appsettings://fullmatch داخل load)
            val settingsItem = newMovieSearchResponse(
                name = "Extension Settings",
                url = "appsettings://fullmatch",
                type = TvType.Movie
            ) {
                posterUrl = ""
            }
            lists.add(0, HomePageList("Settings", listOf(settingsItem)))

            // جلب كل فئة إذا كانت مفعّلة في الإعدادات
            categories.forEach { category ->
                try {
                    if (!isCategoryEnabled(category.name)) {
                        // تم تعطيل الفئة من قبل المستخدم
                        println("Skipping category: ${category.name} (disabled in settings)")
                        return@forEach
                    }
                    val catDoc = app.get(category.data).document
                    val items = parsePostItems(catDoc.select("ul#posts-container li.post-item"))
                    lists.add(HomePageList(category.name, items.take(10)))
                } catch (e: Exception) {
                    logError(e)
                }
            }
        }

        return HomePageResponse(lists)
    }

    override suspend fun load(url: String): LoadResponse? {
        // إذا كان رابط الإعدادات الخاص، افتح Activity الإعدادات
        if (url.startsWith("appsettings://")) {
            try {
                // إذا تريد الاعتماد على واجهة CloudStream الداخلية بدل Activity، تابع التعليقات أدناه.
                val intent = Intent(context, FullMatchSettingsActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            } catch (e: Exception) {
                logError(e)
            }
            return null
        }

        val document = app.get(url).document

        val title = document.selectFirst("h1.post-title.entry-title")?.text() ?: return null
        val posterUrl = fixUrl(document.selectFirst("figure.single-featured-image img")?.attr("src") ?: "")
        val plot = document.select("div.entry-content.entry.clearfix p").joinToString("\n") { it.text().trim() }
        val tags = document.select("div.post-bottom-meta.post-bottom-tags a").map { it.text().trim() }

        val year = Regex("""\d{4}""").find(title)?.value?.toIntOrNull()

        val recommendations = document.select("#related-posts .related-item").mapNotNull {
            val recTitleElement = it.selectFirst("h3.post-title a") ?: return@mapNotNull null
            val recTitle = recTitleElement.text()
            val recUrl = fixUrl(recTitleElement.attr("href"))
            val recPosterUrl = fixUrl(it.selectFirst("a.post-thumb img")?.attr("src") ?: "")
            val recYear = Regex("""\d{4}""").find(recTitle)?.value?.toIntOrNull()

            newMovieSearchResponse(
                name = recTitle,
                url = recUrl,
                type = TvType.Movie
            ) {
                this.posterUrl = recPosterUrl
                this.year = recYear
            }
        }

        return newMovieLoadResponse(
            name = title,
            url = url,
            type = TvType.Movie,
            dataUrl = url
        ) {
            this.posterUrl = posterUrl
            this.plot = plot
            this.tags = tags
            this.year = year
            this.recommendations = recommendations
        }
    }

    // تحويل عناصر HTML إلى SearchResponse
    private fun parsePostItems(elements: List<Element>): List<SearchResponse> {
        return elements.mapNotNull {
            val titleElement = it.selectFirst("h2.post-title a") ?: return@mapNotNull null
            val title = titleElement.text()
            val url = fixUrl(titleElement.attr("href"))
            val posterUrl = fixUrl(it.selectFirst("a.post-thumb img")?.attr("src") ?: "")
            val year = Regex("""\d{4}""").find(title)?.value?.toIntOrNull()

            newMovieSearchResponse(
                name = title,
                url = url,
                type = TvType.Movie
            ) {
                this.posterUrl = posterUrl
                this.year = year
            }
        }
    }

    // تبعيتان للبحث: التوافق القديم وإصدار يدعم pagination
    override suspend fun search(query: String): List<SearchResponse> {
        return search(query, 1)?.items ?: emptyList()
    }

    override suspend fun search(query: String, page: Int): SearchResponseList? = coroutineScope {
        val encoded = URLEncoder.encode(query, "utf-8")

        val candidates = listOf(
            if (page <= 1) "$mainUrl/?s=$encoded" else "$mainUrl/page/$page/?s=$encoded",
            if (page <= 1) "$mainUrl/search/$encoded/" else "$mainUrl/search/$encoded/page/$page/"
        )

        val resultsPerPattern = candidates.map { url ->
            async {
                runCatching {
                    val doc = app.get(url).document
                    val items = parsePostItems(doc.select("ul#posts-container li.post-item"))
                    println("Search: tried $url -> found ${items.size} items")
                    items
                }.getOrDefault(emptyList())
            }
        }.awaitAll()

        val merged = resultsPerPattern.firstOrNull { it.isNotEmpty() } ?: emptyList()
        newSearchResponseList(merged, merged.isNotEmpty())
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        println("=== loadLinks START ===")
        println("Match page URL: $data")

        val matchPageDocument = app.get(data).document
        var foundLinks = false

        val buttons = matchPageDocument.select("a.myButton")
        if (buttons.isEmpty()) {
            println("⚠️ لم يتم العثور على أزرار 'myButton' في صفحة المباراة.")
        }

        buttons.forEach { button ->
            val buttonUrlRaw = button.attr("href").trim()
            val buttonText = button.text().trim()

            println("\n--- Processing button ---")
            println("Text: '$buttonText'")
            println("Raw URL: '$buttonUrlRaw'")

            if (buttonUrlRaw.isBlank()) {
                println("❌ الزر لا يحتوي رابط، تجاوز...")
                return@forEach
            }

            val buttonUrl = fixUrl(buttonUrlRaw)
            println("Resolved URL: '$buttonUrl'")

            // ===== إرسال الرابط مباشرة لكل المستخرجين =====
            try {
                println("🔹 محاولة loadExtractor على الزر مباشرة: $buttonUrl")
                loadExtractor(buttonUrl, data, subtitleCallback, callback)
                println("✅ loadExtractor نجح على الزر: $buttonUrl")
                foundLinks = true
            } catch (e: Exception) {
                println("❌ loadExtractor فشل على الزر: $buttonUrl")
                logError(e)
            }

            try {
                println("🔹 محاولة ExternalEarnVidsExtractor على الزر: $buttonUrl")
                val customLink = ExternalEarnVidsExtractor.extract(buttonUrl, data)
                if (!customLink.isNullOrBlank()) {
                    println("✅ ExternalEarnVidsExtractor نجح: $customLink")
                    callback.invoke(
                        newExtractorLink(
                            source = this@FullMatchShowsProvider.name,
                            name = "$buttonText (Custom)",
                            url = customLink
                        ) {
                            referer = data
                            quality = Qualities.Unknown.value
                        }
                    )
                    foundLinks = true
                } else {
                    println("⚠️ ExternalEarnVidsExtractor لم يجد رابط صالح على الزر")
                }
            } catch (e: Exception) {
                println("❌ ExternalEarnVidsExtractor فشل على الزر")
                logError(e)
            }

            // ===== جلب صفحة الزر وفحص iframes إن وجدت =====
            try {
                val hostPageDocument = app.get(buttonUrl, referer = data).document
                val iframes = hostPageDocument.select("iframe[src]")

                if (iframes.isEmpty()) {
                    println("⚠️ لم يتم العثور على iframe في صفحة الزر: $buttonUrl")
                } else {
                    println("✅ عدد iframes الموجود: ${iframes.size}")
                }

                iframes.forEach { iframe ->
                    val iframeSrcRaw = iframe.attr("src").trim()
                    val iframeSrc = fixUrl(iframeSrcRaw)
                    println("Found iframe src: '$iframeSrcRaw' -> resolved: '$iframeSrc'")

                    if (iframeSrc.isBlank()) {
                        println("❌ iframe بدون src، تجاهل")
                        return@forEach
                    }

                    // إرسال iframe لكل المستخرجين
                    try {
                        println("🔹 محاولة loadExtractor على iframe: $iframeSrc")
                        loadExtractor(iframeSrc, buttonUrl, subtitleCallback, callback)
                        println("✅ loadExtractor نجح على iframe: $iframeSrc")
                        foundLinks = true
                    } catch (e: Exception) {
                        println("❌ loadExtractor فشل على iframe: $iframeSrc")
                        logError(e)
                    }

                    try {
                        println("🔹 محاولة ExternalEarnVidsExtractor على iframe: $iframeSrc")
                        val customLink = ExternalEarnVidsExtractor.extract(iframeSrc, buttonUrl)
                        if (!customLink.isNullOrBlank()) {
                            println("✅ ExternalEarnVidsExtractor نجح على iframe: $customLink")
                            callback.invoke(
                                newExtractorLink(
                                    source = this@FullMatchShowsProvider.name,
                                    name = "$buttonText (Custom Iframe)",
                                    url = customLink
                                ) {
                                    referer = buttonUrl
                                    quality = Qualities.Unknown.value
                                }
                            )
                            foundLinks = true
                        } else {
                            println("⚠️ ExternalEarnVidsExtractor لم يجد رابط صالح على iframe")
                        }
                    } catch (e: Exception) {
                        println("❌ ExternalEarnVidsExtractor فشل على iframe")
                        logError(e)
                    }
                }
            } catch (e: Exception) {
                println("❌ خطأ عند جلب صفحة الزر: $buttonUrl")
                logError(e)
            }
        }

        println("\n=== loadLinks END | FoundLinks = $foundLinks ===")
        return foundLinks
    }

    // تحويل روابط نسبية إلى مطلقة اعتمادًا على mainUrl
    private fun fixUrl(url: String): String {
        val trimmed = url.trim()
        if (trimmed.isBlank()) return ""
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
        return when {
            trimmed.startsWith("//") -> "https:$trimmed"
            trimmed.startsWith("/") -> mainUrl.trimEnd('/') + trimmed
            else -> mainUrl.trimEnd('/') + "/" + trimmed
        }
    }
}
