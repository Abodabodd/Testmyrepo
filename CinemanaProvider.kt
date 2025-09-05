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
)
