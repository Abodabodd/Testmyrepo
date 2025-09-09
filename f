package com.arabseed

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.extractors.ExtractorApi
import com.lagradost.cloudstream3.utils.AppUtils.parseJson
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.Qualities
import com.lagradost.cloudstream3.utils.Qualities.Companion.toSearchQuality
import com.lagradost.cloudstream3.utils.loadExtractor
import com.lagradost.cloudstream3.ui.search.SearchQuality
import com.lagradost.cloudstream3.utils.JsUnpacker
import org.jsoup.nodes.Element

// استيرادات الدوال المساعدة
import com.lagradost.cloudstream3.newMovieSearchResponse
import com.lagradost.cloudstream3.newMovieLoadResponse
import com.lagradost.cloudstream3.newTvSeriesLoadResponse
import com.lagradost.cloudstream3.newEpisode
import com.lagradost.cloudstream3.newExtractorLink
import com.lagradost.cloudstream3.newHomePageResponse
import com.lagradost.cloudstream3.HomePageList
import com.lagradost.cloudstream3.utils.INFER_TYPE


class ArabSeed : MainAPI() {
    override var lang = "ar"
    override var mainUrl = "https://a.asd.homes"
    override var name = "ArabSeed"
    override val usesWebView = false
    override val hasMainPage = true
    override val supportedTypes = setOf(TvType.TvSeries, TvType.Movie, TvType.Cartoon, TvType.Anime)
    override val iconUrl = "https://a.asd.homes/wp-content/themes/ArabSeed/assets/img/logo.webp"

    private fun String.getIntFromText(): Int? {
        return Regex("""\d+""").find(this)?.groupValues?.firstOrNull()?.toIntOrNull()
    }

    private fun String.getYearFromTitle(): Int? {
        return Regex("""\((\d{4})\)""").find(this)?.groupValues?.getOrNull(1)?.toIntOrNull()
    }

    private fun getSearchQualityFromString(qualityString: String?): SearchQuality? {
        val quality = when (qualityString?.uppercase()) {
            "WEB-DL" -> Qualities.WEB_DL
            "BLURAY" -> Qualities.BluRay
            "HD" -> Qualities.HD
            "4K" -> Qualities.P4K
            "1080P" -> Qualities.P1080
            "720P" -> Qualities.P720
            "480P" -> Qualities.P480
            "360P" -> Qualities.P360
            else -> Qualities.Unknown
        }
        return if (quality != Qualities.Unknown) quality.toSearchQuality() else null
    }

    private fun Element.toSearchResponse(): SearchResponse? {
        val linkElement = select("a.movie__block") ?: return null
        val url = linkElement.attr("href") ?: return null

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
        val quality = getSearchQualityFromString(linkElement.select("div.__quality").text())

        return newMovieSearchResponse(
            name = title,
            url = url,
            apiName = this@ArabSeed.name,
            type = tvType,
            posterUrl = posterUrl,
            year = year,
            quality = quality,
        )
    }

    override val mainPage = mainPageOf(
        "$mainUrl/main1/" to "الرئيسية",
        "$mainUrl/recently/" to "مضاف حديثا",
        "$mainUrl/trend/" to "تريند",
        "$mainUrl/movies/" to "الافلام",
        "$mainUrl/series/" to "المسلسلات",
        "$mainUrl/category/%d9%85%d8%b3%d9%84%d8%b3%d9%84%d8%a7%d8%aa-%d8%b1%d9%85%d8%b6%d8%a7%d9%86/" to "رمضان",
        "$mainUrl/category/%d9%85%d8%b3%d9%84%d8%b3%d9%84%d8%a7%d8%aa-%d8%b1%d9%85%d8%b6%d8%a7%d9%86/ramadan-series-2025/" to "مسلسلات رمضان 2025",
        "$mainUrl/category/%d8%a7%d9%81%d9%84%d8%a7%d9%85-%d8%a7%d9%86%d9%8a%d9%85%d9%8a%d8%b4%d9%86/" to "افلام انيميشن",
        "$mainUrl/category/wwe-shows/" to "مصارعه",
        "$mainUrl/category/cartoon-series/" to "مسلسلات كرتون",
        "$mainUrl/category/%d8%a7%d9%86%d9%85%d9%8a/" to "انمي"
    )

    override suspend fun getMainPage(page: Int, request : MainPageRequest): HomePageResponse {
        val urlToFetch = if (request.data.endsWith("/")) {
            "${request.data}page/$page/"
        } else {
            "${request.data}/page/$page/"
        }

        val doc = app.get(urlToFetch, timeout = 120).document

        val sliderList = doc.select("div.swiper-slide div.slider__single").mapNotNull { element ->
            element.toSearchResponse()
        }

        val otherBlocks = doc.select("ul.movie__blocks__ul.boxs__wrapper li").mapNotNull { element ->
            element.toSearchResponse()
        }

        return newHomePageResponse(
            request.name,
            sliderList + otherBlocks
        )
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val url = "$mainUrl/find/?word=$query"
        val doc = app.get(url).document

        return doc.select("ul.movie__blocks__ul.boxs__wrapper li").mapNotNull {
            it.toSearchResponse()
        }
    }

    override suspend fun load(url: String): LoadResponse {
        val doc = app.get(url, timeout = 120).document

        val title = doc.select("h1.post__name").text()
        val posterUrl = doc.select("div.poster__single img").attr("src").ifEmpty {
            doc.select("meta[property=\"og:image\"]").attr("content")
        }
        val rating = doc.select("div.star__rating").attr("data-avg").toFloatOrNull()?.times(10)?.toInt()
        val synopsis = doc.select("p.post__content").text()
        val year = title.getYearFromTitle()
        val tags = doc.select("ul.tags__list li a").map { it.text() }

        val recommendations = doc.select("ul.movie__blocks__ul.boxs__wrapper li").mapNotNull { element ->
            element.toSearchResponse()
        }

        val watchLink = doc.select("a.btton.watch__btn").attr("href")

        val detectedTvType = when {
            tags.any { it.contains("مسلسل", true) } || title.contains("مسلسل", true) -> TvType.TvSeries
            tags.any { it.contains("مصارعه", true) } || title.contains("WWE", true) -> TvType.TvSeries
            tags.any { it.contains("كرتون", true) } || title.contains("كرتون", true) -> TvType.Cartoon
            tags.any { it.contains("انمي", true) } || title.contains("انمي", true) -> TvType.Anime
            else -> TvType.Movie
        }

        return if (detectedTvType == TvType.Movie) {
            newMovieLoadResponse(
                title,
                url,
                detectedTvType,
                watchLink
            ) {
                this.posterUrl = posterUrl
                this.recommendations = recommendations
                this.plot = synopsis
                this.tags = tags
                this.rating = rating
                this.year = year
            }
        } else {
            val episodes = arrayListOf<Episode>()

            val seasonList = doc.select("#seasons__list li")
            if(seasonList.isNotEmpty()) {
                seasonList.apmap { season ->
                    val seasonNumber = season.attr("data-term")?.getIntFromText() ?: 0
                    app.post(
                        "$mainUrl/wp-content/themes/ArabSeed/Ajaxat/Single/Episodes.php",
                        data = mapOf("season_id" to season.attr("data-term").toString(), "csrf_token" to "d0ab06a2cb")
                    ).document.select("a").apmap {
                        episodes.add(newEpisode(it.attr("href")) {
                            name = it.text()
                            episode = it.text().getIntFromText()
                            this.season = seasonNumber
                        })
                    }
                }
            } else {
                doc.select("ul.episodes__list li a").apmap {
                    episodes.add(newEpisode(it.attr("href")) {
                        name = it.select(".epi__num").text().ifEmpty { it.text() }
                        episode = it.select(".epi__num b").text().getIntFromText() ?: it.select(".epi__num").text().getIntFromText()
                        this.season = 0
                    })
                }
            }

            newTvSeriesLoadResponse(title, url, detectedTvType, episodes.distinct().sortedBy { it.episode }) {
                this.posterUrl = posterUrl
                this.tags = tags
                this.plot = synopsis
                this.recommendations = recommendations
                this.rating = rating
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
        val watchPageDoc = app.get(data, headers = mapOf("Referer" to mainUrl)).document

        val csrfToken = watchPageDoc.select("script:contains(csrf__token)").first()?.data()
            ?.substringAfter("csrf__token': \"")?.substringBefore("\"") ?: "d0ab06a2cb"

        val iframeSrc = watchPageDoc.select("div.player__iframe iframe").attr("src")

        if (iframeSrc.isEmpty()) {
            println("ArabSeed: No iframe source found on watch page: $data. Trying direct download links.")
            watchPageDoc.select(".downloads__links__list li a").apmap { downloadLinkElement ->
                val linkHref = downloadLinkElement.attr("href")
                val linkName = downloadLinkElement.select(".text h4").text()
                val linkQuality = downloadLinkElement.select(".text p").text().getIntFromText() ?: Qualities.Unknown.value

                if (linkHref.isNotEmpty()) {
                    callback.invoke(
                        newExtractorLink(
                            source = this.name,
                            name = linkName,
                            url = linkHref,
                            referer = mainUrl,
                            quality = linkQuality
                        )
                    )
                }
            }
            return false
        }

        // استخدام loadExtractor للمشغل الأساسي (Vidmoly)
        // يجب أن نستخدم Extractor المدمج هنا
        when {
            iframeSrc.contains("vidmoly.net") -> Vidmoly().getUrl(iframeSrc, data, subtitleCallback, callback)
            iframeSrc.contains("istreamcdn.com") -> Istreamcdn().getUrl(iframeSrc, data, subtitleCallback, callback)
            else -> loadExtractor(iframeSrc, data, subtitleCallback, callback)
        }


        val postId = watchPageDoc.select("div.watch__area").first()?.attr("data-post-id")
            ?: watchPageDoc.select(".servers__list li[data-post]").first()?.attr("data-post")

        if (postId != null) {
            watchPageDoc.select(".servers__list ul li").apmap { serverElement ->
                val serverId = serverElement.attr("data-server")
                val serverName = serverElement.select("span").text().ifEmpty { "سيرفر ${serverId}" }
                val currentQuality = watchPageDoc.select(".quality__swither li.active").attr("data-quality").toIntOrNull() ?: Qualities.Unknown.value

                val ajaxUrl = "$mainUrl/wp-content/themes/ArabSeed/Ajaxat/Single/Server.php"

                val ajaxResponse = app.post(
                    ajaxUrl,
                    data = mapOf(
                        "post_id" to postId,
                        "server" to serverId,
                        "quality" to currentQuality.toString(),
                        "csrf_token" to csrfToken
                    ),
                    headers = mapOf("Referer" to data, "X-Requested-With" to "XMLHttpRequest")
                )

                val serverLinkJson = ajaxResponse.parsed<Map<String, String>>()
                val actualServerLink = serverLinkJson["server"]

                if (actualServerLink != null && actualServerLink.isNotEmpty()) {
                    // هنا أيضًا يجب أن نستخدم Extractor المدمج أو loadExtractor
                    when {
                        actualServerLink.contains("vidmoly.net") -> Vidmoly().getUrl(actualServerLink, data, subtitleCallback, callback)
                        actualServerLink.contains("istreamcdn.com") -> Istreamcdn().getUrl(actualServerLink, data, subtitleCallback, callback)
                        else -> loadExtractor(actualServerLink, data, subtitleCallback, callback)
                    }
                }
            }
        }
        return true
    }

    // ========================================================================
    // Extractorات المدمجة داخل ArabSeedProvider
    // ========================================================================

    // Extractor Vidmoly المدمج
    internal class Vidmoly : ExtractorApi() {
        override val name = "Vidmoly"
        override val mainUrl = "https://vidmoly.net"
        override val requiresReferer = false

        override suspend fun getUrl(
            url: String,
            referer: String?,
            subtitleCallback: (SubtitleFile) -> Unit,
            callback: (ExtractorLink) -> Unit
        ) {
            val doc = app.get(url).document
            val scriptContent = doc.select("body > script").map { it.data() }.firstOrNull { it.contains("sources") }

            val unpackedScript = scriptContent?.let { JsUnpacker(it).unpack() }

            val m3u8 = Regex("sources:\\[\\{file:\"(.*?m3u8.*?)\"").find(unpackedScript ?: scriptContent ?: return)?.groupValues?.get(1)

            if (m3u8 != null) {
                callback.invoke(
                    newExtractorLink(
                        source = this.name,
                        name = "Vidmoly",
                        url = m3u8,
                        referer = referer ?: mainUrl,
                        quality = Qualities.Unknown.value,
                        isM3u8 = m3u8.contains(".m3u8")
                    )
                )
            }
        }
    }

    // Extractor Istreamcdn المدمج
    internal class Istreamcdn : ExtractorApi() {
        override val name = "IStreamCDN"
        override val mainUrl = "https://istreamcdn.com"
        override val requiresReferer = false

        override suspend fun getUrl(
            url: String,
            referer: String?,
            subtitleCallback: (SubtitleFile) -> Unit,
            callback: (ExtractorLink) -> Unit
        ) {
            val src = app.get(url, allowRedirects = false).headers["location"]
            if (src != null) {
                callback.invoke(
                    newExtractorLink(
                        name = name,
                        source = name,
                        url = src,
                        type = INFER_TYPE
                    ) {
                        this.referer = ""
                        this.quality = Qualities.Unknown.value
                    }
                )
            }
        }
    }
}
