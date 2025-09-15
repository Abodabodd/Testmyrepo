package com.arabseed

import android.util.Log
// لقد قمت بحذف السطر الخاطئ من هنا
import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import org.jsoup.Jsoup
import com.lagradost.cloudstream3.network.CloudflareKiller
import kotlinx.serialization.Serializable

class Arabseed : MainAPI() {
    override var mainUrl = "https://a.asd.homes"
    override var name = "Arabseed"
    override var lang = "ar"
    override val hasMainPage = true
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries, TvType.Anime)
    private fun String.toAbsolute(): String {
        if (this.isBlank()) return ""
        return when {
            this.startsWith("http") -> this
            this.startsWith("//") -> "https:$this"
            else -> mainUrl.trimEnd('/') + "/" + this.trimStart('/')
        }
    }

    private fun getPoster(element: org.jsoup.nodes.Element): String? {
        return element.selectFirst("img")?.let { img ->
            img.attr("data-src").ifBlank { img.attr("src") }.toAbsolute()
        }
    }

    // ================== Search ==================
    override suspend fun search(query: String): List<SearchResponse> {
        val url = "$mainUrl/find/?word=${query.trim().replace(" ", "+")}"
        val document = app.get(url).document
        return document.select("ul.blocks__ul > li").mapNotNull {
            val a = it.selectFirst("a.movie__block") ?: return@mapNotNull null
            val href = a.attr("href").toAbsolute()
            val title = a.attr("title").ifBlank { a.selectFirst("h3")?.text() } ?: return@mapNotNull null
            val posterUrl = getPoster(a)
            val isMovie = href.contains("/%d9%81%d9%8a%d9%84%d9%85-") // /فيلم-
            val tvType = if (isMovie) TvType.Movie else TvType.TvSeries

            newMovieSearchResponse(title, href, tvType) {
                this.posterUrl = posterUrl
            }
        }
    }

    // ================== Main Page ==================
    override val mainPage = mainPageOf(
        "$mainUrl/main0/" to "الرئيسية",
        "$mainUrl/recently/" to "مضاف حديثا",
        "$mainUrl/trend/" to "الأكثر مشاهدة",
        "$mainUrl/movies/" to "أفلام",
        "$mainUrl/series/" to "مسلسلات"
    )

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val url = if (page > 1) "${request.data}page/$page/" else request.data
        val document = app.get(url).document
        val items = document.select(".movie__block, .series__box > a").mapNotNull {
            val title = it.selectFirst("h3")?.text() ?: return@mapNotNull null
            val href = it.attr("href").toAbsolute()
            val posterUrl = getPoster(it)
            newMovieSearchResponse(title, href, TvType.Movie) { // Defaulting to movie, load will determine correct type
                this.posterUrl = posterUrl
            }
        }
        return newHomePageResponse(request.name, items)
    }

    @Serializable
    data class AjaxResponse(
        val html: String?,
        val hasmore: Boolean?
    )

    // ================== Load ==================
    override suspend fun load(url: String): LoadResponse {
        val doc = app.get(url).document
        val title = doc.selectFirst("h1.post__name")?.text()?.trim() ?: "غير معروف"
        val poster = doc.selectFirst(".poster__side .poster__single img, .single__cover img")
            ?.attr("src")?.toAbsolute()
        val synopsis = doc.selectFirst(".post__story > p")?.text()?.trim()

        val episodes = mutableListOf<Episode>()

        // Initial episodes on page
        doc.select("ul.episodes__list li a").forEach { epEl ->
            val epHref = epEl.attr("href").toAbsolute()
            val epTitle = epEl.selectFirst(".epi__num")?.text()?.trim() ?: epEl.text().trim()
            val epNum = epTitle.let { Regex("""\d+""").find(it)?.value?.toIntOrNull() }
            episodes.add(newEpisode(epHref) {
                name = epTitle
                episode = epNum
                posterUrl = poster // Assign series poster to episode
            })
        }

        // AJAX load more episodes
        doc.selectFirst("div.load__more__episodes")?.let { loadMoreButton ->
            val seasonId = loadMoreButton.attr("data-id")
            val csrfToken = doc.select("script").html()
                .let { Regex("""'csrf__token':\s*"([^"]+)""").find(it)?.groupValues?.get(1) }

            if (seasonId.isNotBlank() && !csrfToken.isNullOrBlank()) {
                var hasMore = true
                while (hasMore) {
                    try {
                        val response = app.post(
                            "$mainUrl/season__episodes/",
                            data = mapOf(
                                "season_id" to seasonId,
                                "offset" to episodes.size.toString(),
                                "csrf_token" to csrfToken
                            ),
                            referer = url,
                            headers = mapOf("X-Requested-With" to "XMLHttpRequest")
                        ).parsedSafe<AjaxResponse>()

                        if (response?.html.isNullOrBlank() || response?.hasmore != true) {
                            hasMore = false
                        } else {
                            val newEpisodesDoc = Jsoup.parse(response.html)
                            val newEpisodeElements = newEpisodesDoc.select("li a")

                            if (newEpisodeElements.isEmpty()) {
                                hasMore = false
                            } else {
                                newEpisodeElements.forEach { epEl ->
                                    val epHref = epEl.attr("href").toAbsolute()
                                    val epTitle = epEl.selectFirst(".epi__num")?.text()?.trim()
                                        ?: epEl.text().trim()
                                    val epNum = epTitle.let { Regex("""\d+""").find(it)?.value?.toIntOrNull() }

                                    episodes.add(newEpisode(epHref) {
                                        name = epTitle
                                        episode = epNum
                                        posterUrl = poster // Assign series poster to episode
                                    })
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(name, "AJAX load more error", e)
                        hasMore = false
                    }
                }
            }
        }

        val isTvSeries = episodes.isNotEmpty() || url.contains("/selary/")

        return if (isTvSeries) {
            newTvSeriesLoadResponse(title, url, TvType.TvSeries, episodes.distinctBy { it.data }.reversed()) {
                this.posterUrl = poster
                this.plot = synopsis
            }
        } else {
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = poster
                this.plot = synopsis
            }
        }
    }

    @Serializable
    data class ServerResponse(val server: String?)

    // ================== Load Links ==================
    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val episodePageDoc = app.get(data).document
        val watchUrl = episodePageDoc.selectFirst("a.btton.watch__btn")?.attr("href")?.toAbsolute()
            ?: return false

        val watchPageDoc = app.get(watchUrl, referer = data).document
        val csrfToken = watchPageDoc.select("script").html()
            .let { Regex("""'csrf__token':\s*"([^"]+)""").find(it)?.groupValues?.get(1) }
            ?: return false
        val postId = watchPageDoc.selectFirst(".servers__list li")?.attr("data-post") ?: return false

        // Iterate through each quality switcher
        watchPageDoc.select(".quality__swither ul.qualities__list li").apmap { qualityElement ->
            val quality = qualityElement.attr("data-quality")

            // Get servers for this quality via AJAX
            val serversHtml = app.post(
                "$mainUrl/get__quality__servers/",
                data = mapOf("post_id" to postId, "quality" to quality, "csrf_token" to csrfToken),
                referer = watchUrl,
                headers = mapOf("X-Requested-With" to "XMLHttpRequest")
            ).parsedSafe<AjaxResponse>()?.html ?: return@apmap

            Jsoup.parse(serversHtml).select("li").apmap { serverElement ->
                val serverId = serverElement.attr("data-server")
                val serverName = serverElement.selectFirst("span")?.text()?.trim() ?: "Server"

                try {
                    app.post(
                        "$mainUrl/get__watch__server/",
                        data = mapOf(
                            "post_id" to postId,
                            "quality" to quality,
                            "server" to serverId,
                            "csrf_token" to csrfToken
                        ),
                        referer = watchUrl,
                        headers = mapOf("X-Requested-With" to "XMLHttpRequest")
                    ).parsedSafe<ServerResponse>()?.server?.let { iframeUrl ->
                        // Add quality to the name when calling the extractor
                        loadExtractor(iframeUrl, watchUrl, subtitleCallback) { link ->
                            callback(
                                link.copy(name = "$name - $serverName - ${quality}p")
                            )
                        }
                    }
                } catch (e: Exception) {
                    Log.e(name, "Failed to get server URL for quality $quality", e)
                }
            }
        }

        return true
    }
}
