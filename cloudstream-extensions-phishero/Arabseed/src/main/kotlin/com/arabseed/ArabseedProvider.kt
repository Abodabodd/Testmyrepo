package com.arabseed

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import org.jsoup.nodes.Element

class ArabSeed : MainAPI() {
    override var mainUrl = "https://a.asd.homes"
    override var name = "ArabSeed"
    override var lang = "ar"
    override val hasMainPage = true
    override val usesWebView = false
    override val supportedTypes = setOf(TvType.TvSeries, TvType.Movie, TvType.Cartoon, TvType.Anime)

    val iconUrl = "https://a.asd.homes/wp-content/themes/ArabSeed/assets/img/logo.webp"

    private fun String.getIntFromText(): Int? {
        return Regex("""\d+""").find(this)?.value?.toIntOrNull()
    }

    private fun String.getYearFromTitle(): Int? {
        return Regex("""\((\d{4})\)""").find(this)?.groupValues?.getOrNull(1)?.toIntOrNull()
    }

    // ✅ الآن يرجع SearchQuality? بدل Int
    private fun getQuality(qualityString: String?): SearchQuality? {
        return when (qualityString?.uppercase()) {
            "WEB-DL" -> SearchQuality.HD
            "BLURAY" -> SearchQuality.HD
            "1080P" -> SearchQuality.HD
            "720P" -> SearchQuality.SD
            "480P" -> SearchQuality.SD
            "360P" -> SearchQuality.SD
            "2160P", "4K" -> SearchQuality.UHD
            else -> null
        }
    }

    private fun Element.toSearchResponse(): SearchResponse? {
        val linkElement = selectFirst("a.movie__block") ?: return null
        val url = linkElement.attr("href")

        val title = linkElement.select("div.post__info h3").text()
        val posterUrl = linkElement.select("div.post__image img").attr("src").ifEmpty {
            linkElement.select("div.post__image img").attr("data-src")
        }

        val categoryText = linkElement.select("div.post__category").text()
        val isSeries = title.contains("مسلسل", true) || categoryText.contains("مسلسلات", true)
        val isAnime = title.contains("انمي", true) || categoryText.contains("انمي", true)
        val isCartoon = title.contains("كرتون", true) || categoryText.contains("كرتون", true)

        val tvType = when {
            isSeries -> TvType.TvSeries
            isAnime -> TvType.Anime
            isCartoon -> TvType.Cartoon
            else -> TvType.Movie
        }

        val year = title.getYearFromTitle()
        val quality = getQuality(linkElement.select("div.__quality").text())

        return if (tvType == TvType.Movie) {
            newMovieSearchResponse(title, url, TvType.Movie) {
                this.posterUrl = posterUrl
                this.year = year
                this.quality = quality
            }
        } else {
            newTvSeriesSearchResponse(title, url, tvType) {
                this.posterUrl = posterUrl
                this.year = year
                this.quality = quality
            }
        }
    }

    override val mainPage = mainPageOf(
        "$mainUrl/main1/" to "الرئيسية",
        "$mainUrl/recently/" to "مضاف حديثا",
        "$mainUrl/trend/" to "تريند",
        "$mainUrl/movies/" to "الافلام",
        "$mainUrl/series/" to "المسلسلات",
        "$mainUrl/category/%d8%a7%d9%86%d9%85%d9%8a/" to "انمي"
    )

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val urlToFetch = if (request.data.endsWith("/")) {
            "${request.data}page/$page/"
        } else {
            "${request.data}/page/$page/"
        }

        val doc = app.get(urlToFetch, timeout = 120).document
        val items = doc.select("ul.movie__blocks__ul.boxs__wrapper li").mapNotNull { it.toSearchResponse() }

        return newHomePageResponse(request.name, items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val url = "$mainUrl/find/?word=$query"
        val doc = app.get(url).document
        return doc.select("ul.movie__blocks__ul.boxs__wrapper li").mapNotNull { it.toSearchResponse() }
    }

    override suspend fun load(url: String): LoadResponse {
        val doc = app.get(url).document

        val title = doc.select("h1.post__name").text()
        val posterUrl = doc.select("div.poster__single img").attr("src").ifEmpty {
            doc.select("meta[property=\"og:image\"]").attr("content")
        }
        val synopsis = doc.select("p.post__content").text()
        val year = title.getYearFromTitle()

        val detectedTvType = if (title.contains("مسلسل", true)) TvType.TvSeries else TvType.Movie

        return if (detectedTvType == TvType.Movie) {
            newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = posterUrl
                this.plot = synopsis
                this.year = year
            }
        } else {
            val episodes = doc.select("ul.episodes__list li a").map {
                newEpisode(it.attr("href")) {
                    name = it.text()
                    episode = it.text().getIntFromText()
                }
            }
            newTvSeriesLoadResponse(title, url, TvType.TvSeries, episodes) {
                this.posterUrl = posterUrl
                this.plot = synopsis
                this.year = year
            }
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val doc = app.get(data).document
        val iframeSrc = doc.select("div.player__iframe iframe").attr("src")

        if (iframeSrc.isNotEmpty()) {
            callback.invoke(
                newExtractorLink(
                    name = "ArabSeed",
                    source = name,
                    url = iframeSrc,
                    type = INFER_TYPE
                )
            )
        }
        return true
    }
}
