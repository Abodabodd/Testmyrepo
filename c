package com.akwam

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.ExtractorLinkType
import com.lagradost.cloudstream3.utils.Qualities
import com.lagradost.cloudstream3.utils.loadExtractor
import org.jsoup.Jsoup
import java.net.URLEncoder
import com.lagradost.cloudstream3.utils.newExtractorLink
import com.lagradost.cloudstream3.utils.getQualityFromName
import org.jsoup.nodes.Element
import com.lagradost.cloudstream3.utils.AppUtils.toJson
import com.lagradost.cloudstream3.utils.AppUtils.parseJson
import kotlin.Pair
import kotlinx.coroutines.async


class Akwam : MainAPI() {
    data class PosterData(val posterUrl: String?)

    override var mainUrl = "https://ak.sv"
    override var name = "Akwam"
    override val hasMainPage = true
    override var lang = "ar"
    override val supportedTypes = setOf(
        TvType.Movie,
        TvType.TvSeries,
        TvType.Anime,
        TvType.AsianDrama
    )


    private fun getPoster(element: Element?): String? {
        return element?.selectFirst("img")?.let {
            it.attr("data-src").ifBlank { it.attr("src") }
        }
    }

   
    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        if (!request.data.isNullOrBlank()) {
            val base = request.data.trim()
            val pageUrl = if (page > 1) {
                when {
                    base.endsWith("/page/") -> "$base$page/"
                    base.contains("?") -> "$base&page=$page"
                    else -> "$base?page=$page"
                }
            } else base

            val doc = kotlinx.coroutines.withTimeoutOrNull(10_000L) {
                try { app.get(pageUrl).document } catch (e: Exception) { null }
            } ?: throw ErrorLoadingException("failed to load category page")

            val list = doc.select("div.col-lg-auto.col-md-4.col-6").mapNotNull { el ->
                val a = el.selectFirst("h3.entry-title a") ?: return@mapNotNull null
                val title = a.text().trim().takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                val href = el.selectFirst("a")?.attr("abs:href") ?: return@mapNotNull null
                val poster = getPoster(el)
                val urlWithPoster = "$href#${poster ?: ""}"
                newAnimeSearchResponse(name = title, url = urlWithPoster) {
                    this.posterUrl = poster
                }
            }

            if (list.isEmpty()) throw ErrorLoadingException()
            return HomePageResponse(listOf(HomePageList(request.name ?: "قائمة", list)))
        }

        val urls = listOf(
            "$mainUrl/movies" to "أحدث الأفلام",
            "$mainUrl/series" to "أحدث المسلسلات",
            "$mainUrl/shows" to "العروض",
            "$mainUrl/series?section=29&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "مسلسلات عربي",
            "$mainUrl/series?section=32&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "مسلسلات تركي",
            "$mainUrl/series?section=33&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "مسلسلات اسيوية",
            "$mainUrl/series?section=30&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "مسلسلات اجنبي",
            "$mainUrl/series?section=31&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "مسلسلات هندي",
            "$mainUrl/movies?section=29&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "أفلام عربي",
            "$mainUrl/movies?section=32&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "أفلام تركي",
            "$mainUrl/movies?section=33&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "أفلام اسيوية",
            "$mainUrl/movies?section=30&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "أفلام اجنبي",
            "$mainUrl/movies?section=31&category=0&rating=0&year=0&language=0&formats=0&quality=0" to "أفلام هندي"
        )

        val items = ArrayList<HomePageList>()
        for ((baseUrl, titleName) in urls) {
            try {
                val fullUrl = if (page > 1) {
                    if (baseUrl.contains("?")) "$baseUrl&page=$page" else "$baseUrl?page=$page"
                } else baseUrl

                val doc = try { app.get(fullUrl).document } catch (_: Exception) { null } ?: continue

                val list = doc.select("div.col-lg-auto.col-md-4.col-6").mapNotNull { el ->
                    val a = el.selectFirst("h3.entry-title a") ?: return@mapNotNull null
                    val title = a.text().trim().takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                    val href = el.selectFirst("a")?.attr("abs:href") ?: return@mapNotNull null
                    val poster = getPoster(el)
                    val urlWithPoster = "$href#${poster ?: ""}"
                    newAnimeSearchResponse(name = title, url = urlWithPoster) {
                        this.posterUrl = poster
                    }
                }
                if (list.isNotEmpty()) items.add(HomePageList(titleName, list))
            } catch (_: Exception) {
            }
        }

        if (items.isEmpty()) throw ErrorLoadingException()
        return HomePageResponse(items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val q = URLEncoder.encode(query, "utf-8")
        val url = "$mainUrl/search?q=$q"
        val document = app.get(url).document
        return document.select("div.col-lg-auto.col-md-4.col-6").mapNotNull {
            val title = it.selectFirst("h3.entry-title a")?.text() ?: return@mapNotNull null
            val href = it.selectFirst("a")?.attr("href") ?: return@mapNotNull null
            val poster = getPoster(it)
            // التعديل: نمرر البوستر في الرابط نفسه
            val urlWithPoster = "$href#${poster ?: ""}"
            newMovieSearchResponse(name = title, url = urlWithPoster, type = TvType.Movie) {
                this.posterUrl = poster
            }
        }
    }
    private fun getEpisodeNumberFromString(name: String): Int? {
        return Regex("""\d+""").findAll(name).lastOrNull()?.value?.toIntOrNull()
    }

    override suspend fun load(url: String): LoadResponse {
        val parts = url.split("#")
        val pageUrl = parts[0]
        val poster = parts.getOrNull(1)?.ifBlank { null }

        val defaultHeaders = mapOf("Referer" to mainUrl)
        val mainDoc = app.get(pageUrl, headers = defaultHeaders).document

        val title = mainDoc.selectFirst("h1.entry-title")?.text()?.trim() ?: "Unknown"
        val plot = mainDoc.selectFirst("h2:contains(قصة المسلسل) + div > p")?.text()?.trim()
            ?: mainDoc.selectFirst("meta[name=description]")?.attr("content")?.trim()

        val rating = mainDoc.selectFirst("span.mx-2:contains(/)")
            ?.text()?.substringBefore("/")?.trim()?.toRatingInt()

        val tags = mainDoc.select("div.font-size-16.text-white a[href*='/genre/'], div.font-size-16.text-white a[href*='/category/']")
            .map { it.text() }

        val year = mainDoc.select("div.font-size-16.text-white a[href*='/year/']").firstOrNull()?.text()?.toIntOrNull()

      
        val recommendations = mainDoc.select("div.widget-body div[class*='col-']").mapNotNull {
            val recTitle = it.selectFirst("h3 a")?.text()?.trim() ?: return@mapNotNull null
            val recHref = it.selectFirst("a")?.attr("href") ?: return@mapNotNull null
            val recPoster = getPoster(it)
            val urlWithPoster = "$recHref#${recPoster ?: ""}"
            newMovieSearchResponse(recTitle, urlWithPoster, TvType.Movie) {
                this.posterUrl = recPoster
            }
        }

        val seasonsMap = linkedMapOf<String, Pair<String, String>>()
        val currentSeasonName = mainDoc.selectFirst("h1.entry-title")?.text()?.trim() ?: title
        seasonsMap[pageUrl] = Pair(currentSeasonName, pageUrl)

        val seasonSelector = "div.widget-body > a.btn[href*='/series/']"
        mainDoc.select(seasonSelector).forEach { a ->
            val href = a.attr("href")
            if (href.isNotBlank()) {
                val seasonUrl = if (href.startsWith("http")) href else "$mainUrl$href"
                val seasonName = a.text().trim()
                if (!seasonsMap.containsKey(seasonUrl)) {
                    seasonsMap[seasonUrl] = Pair(seasonName, seasonUrl)
                }
            }
        }

        val directEpisodes = mainDoc.select("div#series-episodes div[class*='col-']")
        val isSeries = seasonsMap.size > 1 || directEpisodes.isNotEmpty()

        if (!isSeries) {
            return newMovieLoadResponse(name = title, url = pageUrl, type = TvType.Movie, dataUrl = pageUrl) {
                this.posterUrl = poster
                this.backgroundPosterUrl = poster
                this.plot = plot
                this.year = year
                this.tags = tags
                this.rating = rating
                this.recommendations = recommendations // <-- إضافة التوصيات هنا
            }
        }

        val sortedSeasons = seasonsMap.values.sortedBy { getSeasonNumber(it.first) }
        val allEpisodes = mutableListOf<Episode>()
        val docCache = mutableMapOf(pageUrl to mainDoc)

        for ((seasonName, seasonUrl) in sortedSeasons) {
            val seasonNumber = getSeasonNumber(seasonName)
            val seasonDoc = docCache.getOrPut(seasonUrl) {
                app.get(seasonUrl, headers = defaultHeaders).document
            }
            seasonDoc.select("div#series-episodes div.col-lg-4, div#series-episodes div.col-md-6").forEach { episodeContainer ->
                val episodeLink = episodeContainer.selectFirst("a[href*='/episode/']") ?: return@forEach
                val epUrl = episodeLink.attr("abs:href")
                val epName = episodeLink.selectFirst("h2")?.text()?.trim() ?: episodeLink.text().trim()
                val epPoster = getPoster(episodeContainer)
                if (epUrl.isNotBlank() && epName.isNotBlank()) {
                    allEpisodes.add(newEpisode(epUrl) {
                        name = epName
                        this.season = seasonNumber
                        this.episode = getEpisodeNumberFromString(epName)
                        this.posterUrl = epPoster
                    })
                }
            }
        }

        if (allEpisodes.isEmpty()) {
            return newMovieLoadResponse(name = title, url = pageUrl, type = TvType.Movie, dataUrl = pageUrl) {
                this.posterUrl = poster
                this.backgroundPosterUrl = poster
                this.plot = plot
                this.year = year
                this.tags = tags
                this.rating = rating
                this.recommendations = recommendations // <-- إضافة التوصيات هنا
            }
        }

        return newTvSeriesLoadResponse(
            name = title,
            url = pageUrl,
            type = TvType.TvSeries,
            episodes = allEpisodes
        ) {
            this.posterUrl = poster
            this.backgroundPosterUrl = poster
            this.plot = plot
            this.year = year
            this.tags = tags
            this.rating = rating
            this.recommendations = recommendations // <-- إضافة التوصيات هنا
        }
    }
    private fun getSeasonNumber(seasonName: String): Int {
        val map = mapOf("الاول" to 1, "الأول" to 1, "الثاني" to 2, "الثالث" to 3, "الرابع" to 4, "الخامس" to 5, "السادس" to 6, "السابع" to 7, "الثامن" to 8, "التاسع" to 9, "العاشر" to 10, "الحادي عشر" to 11, "الثاني عشر" to 12, "الثالث عشر" to 13, "الرابع عشر" to 14, "الخامس عشر" to 15, "السادس عشر" to 16, "السابع عشر" to 17, "الثامن عشر" to 18, "التاسع عشر" to 19, "العشرون" to 20, "الحادي والعشرون" to 21, "الثاني والعشرون" to 22, "الثالث والعشرون" to 23, "الرابع والعشرون" to 24, "الخامس والعشرون" to 25, "السادس والعشرون" to 26, "السابع والعشرون" to 27, "الثامن والعشرون" to 28, "التاسع والعشرون" to 29, "الثلاثون" to 30)
        val lower = seasonName.lowercase()
        for ((k, v) in map) {
            if (lower.contains(k)) return v
        }
        val nums = Regex("\\d+").findAll(seasonName).map { it.value.toIntOrNull() ?: 0 }.toList()
        if (nums.isNotEmpty()) return nums.last()
        return 999
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        // data = episode page URL (absolute)
        val episodeUrl = data

        try {
            val step1Doc = try {
                app.get(episodeUrl).document
            } catch (e: Exception) {
                return false
            }

            val watchPathElement = step1Doc.selectFirst("a.link-show")
            val pageIdElement = step1Doc.selectFirst("input#page_id")

            if (watchPathElement == null || pageIdElement == null) {
                return false
            }

            val watchPath = watchPathElement.attr("href").ifBlank { watchPathElement.attr("abs:href") }
            val pageId = pageIdElement.attr("value").ifBlank { pageIdElement.attr("data-value") }

            if (watchPath.isBlank() || pageId.isBlank()) {
                return false
            }

            val main = mainUrl.trimEnd('/')
            val watchSuffix = run {
                val idx = watchPath.indexOf("watch")
                if (idx >= 0) watchPath.substring(idx + "watch".length) else watchPath
            }.trim()
            val watchUrl = (main + "/watch" + watchSuffix.trimEnd('/') + "/" + pageId).replace("//watch", "/watch")
                .replace(":/", "://")

            val step2Doc = try {
                app.get(watchUrl).document
            } catch (e1: Exception) {
                try {
                    app.get(watchUrl, headers = mapOf("Referer" to episodeUrl)).document
                } catch (e2: Exception) {
                    return false
                }
            }

            val sourceElements = step2Doc.select("source[src]")

            if (sourceElements.isEmpty()) {
                return false
            }

            val seen = mutableSetOf<String>()
            for (srcEl in sourceElements) {
                val rawVideoUrl = srcEl.attr("abs:src").ifBlank { srcEl.attr("src") }.trim()
                val videoUrl = rawVideoUrl.replace(" ", "%20")

                if (videoUrl.isBlank()) continue
                if (!seen.add(videoUrl)) continue

                val qualityAttr = srcEl.attr("size").ifBlank { srcEl.attr("label") }.ifBlank { "direct" }

                callback(
                    newExtractorLink(source = this.name, name = name, url = videoUrl) {
                        this.referer = episodeUrl
                        this.quality = getQualityFromName(qualityAttr)
                        this.type = ExtractorLinkType.VIDEO
                    }
                )
            }

            return true
        } catch (e: Exception) {
            return false
        }
    }
}

