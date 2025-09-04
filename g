package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*

class ShabakatyCinemanaProvider : MainAPI() {
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var name = "Shabakaty Cinemana"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)
    override val lang = "ar"

    // نرجع صفحة رئيسية فارغة مؤقتًا
    override suspend fun getMainPage(
        page: Int,
        request: MainPageRequest
    ): HomePageResponse {
        return newHomePageResponse(emptyList())
    }

    // البحث مؤقتًا يرجع نتيجة وهمية عشان يبان أنه شغال
    override suspend fun search(query: String): List<SearchResponse> {
        return listOf(
            newMovieSearchResponse(
                "فيلم تجريبي",
                "https://cinemana.shabakaty.com"
            ) {
                this.posterUrl = null
            }
        )
    }
}        return newHomePageResponse(items)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val moviesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Movies&videoTitle=$query"
        val movies = app.get(moviesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()

        val seriesUrl = "$mainUrl/api/android/AdvancedSearch?level=0&type=Series&videoTitle=$query"
        val series = app.get(seriesUrl).parsedSafe<List<CinemanaItem>>()?.map { it.toSearchResponse() } ?: emptyList()

        return (movies + series) as List<SearchResponse>
    }

    override suspend fun load(url: String): LoadResponse? {
        val videoId = url
        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$videoId"
        val details = app.get(detailsUrl).parsed<CinemanaItem>()

        val title = details.enTitle ?: return null
        val posterUrl = details.imgObjUrl
        val year = details.year?.toIntOrNull()
        val plot = details.enContent
        val scoreInt = details.stars?.let { (it.toFloat() / 2 * 10).toInt() }
        val recommendations = mutableListOf<SearchResponse>()

        if (details.videoType == 2) {
            val episodesUrl = "$mainUrl/api/android/videoSeason/id/$videoId"
            val episodes = app.get(episodesUrl).parsedSafe<List<CinemanaEpisode>>()?.map {
                newEpisode(it) {
                    this.name = "الموسم ${it.season} - الحلقة ${it.episodeNummer}"
                    this.episode = it.episodeNummer?.toIntOrNull()
                    this.season = it.season?.toIntOrNull()
                    this.data = it.nb
                }
            }?.sortedWith(compareBy({ it.season }, { it.episode })) ?: emptyList()

            return newTvSeriesLoadResponse(title, url, TvType.TvSeries, episodes) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = scoreInt
                this.recommendations = recommendations
                this.contentRating = null
            }
        } else {
            return newMovieLoadResponse(title, url, TvType.Movie, url) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = scoreInt
                this.recommendations = recommendations
                this.contentRating = null
            }
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val videoId = data
        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$videoId"
        val subtitlesUrl = "$mainUrl/api/android/translationFiles/id/$videoId"

        app.get(videosUrl).parsedSafe<List<CinemanaVideo>>()?.forEach { video ->
            // تم التغيير: نقل المعاملات إلى داخل الكتلة
            newExtractorLink(
                source = this.name,
                name = video.resolution ?: this.name,
                url = video.videoUrl,
            ) {
                this.referer = "$mainUrl/"
                this.quality = video.resolution?.filter { it.isDigit() }?.toIntOrNull() ?: 0
            }.let { callback(it) }
        }

        app.get(subtitlesUrl).parsedSafe<CinemanaSubtitleHolder>()?.translations?.forEach { sub ->
            val lang = sub.name ?: "Unknown"
            subtitleCallback(
                SubtitleFile(
                    lang,
                    sub.file
                )
            )
        }

        return true
    }

    @Serializable
    data class CinemanaItem(
        val nb: String? = null,
        @SerialName("en_title") val enTitle: String? = null,
        val imgObjUrl: String? = null,
        val year: String? = null,
        @SerialName("en_content") val enContent: String? = null,
        val stars: String? = null,
        val videoType: Int? = null
    ) {
        fun toSearchResponse(): Any {
            val Cinemana = null
            val validUrl = nb ?: return {
                newMovieSearchRespons(
                    "Error", "error",
                    this@CinemanaItem.toString().toString(), TvType.Movie, null
                )
            } as SearchResponse
            return (if (this.videoType == 2) {
                newTvSeriesSearchResponse(name = enTitle ?: "No Title", url = validUrl, apiName = this@CinemanaItem.toString(), }else {
                val movieSearchResponse = MovieSearchResponse(
                    name = enTitle ?: "No Title",
                    url = validUrl,
                    apiName = this@CinemanaItem.toString(),
                    type = TvType.Movie,
                    posterUrl = imgObjUrl,
                    year = this@CinemanaItem.year?.toIntOrNull()
                )
                movieSearchResponse
            })
        }
    }


    @Serializable
    data class CinemanaEpisode(
        val nb: String,
        val episodeNummer: String?,
        val season: String?
    )

    @Serializable
    data class CinemanaVideo(
        val videoUrl: String,
        val resolution: String?
    )

    @Serializable
    data class CinemanaSubtitleHolder(
        val translations: List<CinemanaSubtitleFile>?
    )

    @Serializable
    data class CinemanaSubtitleFile(
        val file: String,
        val name: String?
    )
}

private fun ShabakatyCinemanaProvider.CinemanaItem.newTvSeriesSearchResponse(
    name: String,
    url: String,
    apiName: String,
    type: TvType?,


    ) {
}
private fun ShabakatyCinemanaProvider.CinemanaItem.newMovieSearchRespons(
    name: String,
    url: String,
    apiName: String,
    type: TvType?,
    posterUrl: String?,

) {
}
