package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class CinemanaProvider : MainAPI() {
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var name = "Cinemana"
    override val hasQuickSearch = true
    override val hasMainPage = true
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    // أيقونة الإضافة
    override val icon = "https://cinemana.shabakaty.com/assetsUI/img/favicon.png"

    // البحث
    override suspend fun search(query: String): List<SearchResponse> {
        val url = "$mainUrl/api/v2/movies/search?q=$query"
        val results = app.get(url).parsedSafe<List<CinemanaItem>>() ?: return emptyList()

        return results.mapNotNull { item ->
            MovieSearchResponse(
                name = item.enTitle ?: item.arTitle ?: "Unknown",
                url = "$mainUrl/api/v2/movies/${item.nb}",
                apiName = this.name,
                type = TvType.Movie,
                posterUrl = item.poster,
                year = item.year?.toIntOrNull()
            )
        }
    }

    // تحميل التفاصيل
    override suspend fun load(url: String): LoadResponse? {
        val details = app.get(url).parsedSafe<CinemanaItem>() ?: return null

        return MovieLoadResponse(
            name = details.enTitle ?: details.arTitle ?: "Unknown",
            url = url,
            apiName = this.name,
            type = TvType.Movie,
            posterUrl = details.poster,
            year = details.year?.toIntOrNull(),
            plot = details.enContent ?: details.arContent,
            rating = details.stars?.toFloatOrNull(),
            trailerUrl = details.trailer,
        )
    }

    // الروابط (الفيديو + الترجمة)
    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val item = app.get(data).parsedSafe<CinemanaItem>() ?: return false

        // ملف الفيديو
        item.fileFile?.let { file ->
            callback.invoke(
                ExtractorLink(
                    source = this.name,
                    name = "Cinemana",
                    url = "https://cnth2.shabakaty.com/vascin-video-files/$file",
                    referer = mainUrl,
                    quality = Qualities.Unknown.value,
                    type = ExtractorLinkType.M3U8
                )
            )
        }

        // ملفات الترجمة
        item.translations?.forEach { sub ->
            subtitleCallback.invoke(
                SubtitleFile(sub.name ?: "Arabic", sub.file)
            )
        }

        return true
    }
}

@Serializable
data class CinemanaItem(
    val nb: String? = null,
    @SerialName("en_title") val enTitle: String? = null,
    @SerialName("ar_title") val arTitle: String? = null,
    val stars: String? = null,
    @SerialName("en_content") val enContent: String? = null,
    @SerialName("ar_content") val arContent: String? = null,
    val year: String? = null,
    val kind: String? = null,
    @SerialName("imgObjUrl") val poster: String? = null,
    val trailer: String? = null,
    val fileFile: String? = null,
    val translations: List<CinemanaSubtitleFile>? = null,
)

@Serializable
data class CinemanaSubtitleFile(
    val file: String,
    val name: String? = null,
)    override suspend fun load(url: String): LoadResponse? {
        val details = app.get("$mainUrl/api/android/allVideoInfo/id/$url").parsedSafe<CinemanaItem>() ?: return null
        val title = details.enTitle ?: "Unknown"
        val poster = details.imgObjUrl
        val type = if (details.videoType == 2) TvType.TvSeries else TvType.Movie

        return if (type == TvType.TvSeries) {
            val episodes = app.get("$mainUrl/api/android/videoSeason/id/$url").parsedSafe<List<CinemanaEpisode>>() ?: emptyList()
            val eps = episodes.map { ep ->
                newEpisode(ep.nb) {
                    this.name = "الموسم ${ep.season} - الحلقة ${ep.episodeNummer}"
                    this.episode = ep.episodeNummer?.toIntOrNull()
                    this.season = ep.season?.toIntOrNull()
                    this.data = ep.nb
                }
            }.sortedWith(compareBy({ it.season }, { it.episode }))

            newTvSeriesLoadResponse(title, url, type, eps) {
                this.posterUrl = poster
            }
        } else {
            newMovieLoadResponse(title, url, type, url) {
                this.posterUrl = poster
            }
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val videos = app.get("$mainUrl/api/android/transcoddedFiles/id/$data").parsedSafe<List<CinemanaVideo>>() ?: return false
        videos.forEach { video ->
            callback(
                newExtractorLink(
                    source = name,
                    name = video.resolution ?: "Default",
                    url = video.videoUrl
                )
            )
        }

        val subs = app.get("$mainUrl/api/android/translationFiles/id/$data").parsedSafe<CinemanaSubtitleHolder>()
        subs?.translations?.forEach { sub ->
            subtitleCallback(SubtitleFile(sub.name ?: "Unknown", sub.file))
        }

        return true
    }

    // =========================
    // DTOs
    // =========================
    @Serializable
    data class CinemanaItem(
        val nb: String? = null,
        @SerialName("en_title") val enTitle: String? = null,
        val imgObjUrl: String? = null,
        val videoType: Int? = null,
        val year: String? = null,
        @SerialName("en_content") val enContent: String? = null,
        val stars: String? = null
    )

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

    // =========================
    // Mapper
    // =========================
    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val id = nb ?: return newMovieSearchResponse("Unknown", "error", TvType.Movie)
        return if (videoType == 2) {
            newTvSeriesSearchResponse(enTitle ?: "Unknown", id, TvType.TvSeries) {
                this.posterUrl = imgObjUrl
            }
        } else {
            newMovieSearchResponse(enTitle ?: "Unknown", id, TvType.Movie) {
                this.posterUrl = imgObjUrl
            }
        }
    }
}
