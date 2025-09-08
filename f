package com.example.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*
import org.json.JSONObject

class CinemanaProvider : MainAPI() {
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var name = "Shabakaty Cinemana"
    override val hasMainPage = true
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override val mainPage = mainPageOf(
        // Movies
        "Latest Movies" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/desc/pageNumber/%d",
        "Oldest Movies" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/asc/pageNumber/%d",
        "Movies Year ↑" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/r_asc/pageNumber/%d",
        "Movies Year ↓" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/r_desc/pageNumber/%d",
        "Movies A-Z" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/title_asc/pageNumber/%d",
        "Movies Z-A" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/title_desc/pageNumber/%d",
        "Movies Views ↑" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/views_asc/pageNumber/%d",
        "Movies Views ↓" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/views_desc/pageNumber/%d",
        "Movies IMDB ↑" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/stars_asc/pageNumber/%d",
        "Movies IMDB ↓" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/1/sortParam/stars_desc/pageNumber/%d",

        // Series
        "Latest Series" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/desc/pageNumber/%d",
        "Oldest Series" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/asc/pageNumber/%d",
        "Series Year ↑" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/r_asc/pageNumber/%d",
        "Series Year ↓" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/r_desc/pageNumber/%d",
        "Series A-Z" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/title_asc/pageNumber/%d",
        "Series Z-A" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/title_desc/pageNumber/%d",
        "Series Views ↑" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/views_asc/pageNumber/%d",
        "Series Views ↓" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/views_desc/pageNumber/%d",
        "Series IMDB ↑" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/stars_asc/pageNumber/%d",
        "Series IMDB ↓" to "$mainUrl/api/android/video/V/2/itemsPerPage/30/level/0/videoKind/2/sortParam/stars_desc/pageNumber/%d"
    )

    override suspend fun getMainPage(
        page: Int,
        request: MainPageRequest
    ): HomePageResponse {
        val url = request.data.format(page)
        val response = app.get(url).text
        val json = JSONObject(response)
        val items = json.getJSONArray("items")

        val list = ArrayList<SearchResponse>()
        for (i in 0 until items.length()) {
            val obj = items.getJSONObject(i)
            val id = obj.getInt("id")
            val title = obj.getString("title")
            val poster = obj.optString("posterPath")
            val isSeries = obj.optInt("videoKind") == 2

            if (isSeries) {
                list.add(
                    TvSeriesSearchResponse(
                        name = title,
                        url = "$mainUrl/api/android/allVideoInfo/id/$id",
                        apiName = this.name,
                        type = TvType.TvSeries,
                        posterUrl = poster
                    )
                )
            } else {
                list.add(
                    MovieSearchResponse(
                        name = title,
                        url = "$mainUrl/api/android/allVideoInfo/id/$id",
                        apiName = this.name,
                        type = TvType.Movie,
                        posterUrl = poster
                    )
                )
            }
        }

        return newHomePageResponse(request.name, list)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val url =
            "$mainUrl/api/android/video/V/2/itemsPerPage/20/video_title_search/${query.encodeUrl()}/itemsPerPage/20/pageNumber/0/level/0"
        val response = app.get(url).text
        val json = JSONObject(response)
        val items = json.getJSONArray("items")

        val results = ArrayList<SearchResponse>()
        for (i in 0 until items.length()) {
            val obj = items.getJSONObject(i)
            val id = obj.getInt("id")
            val title = obj.getString("title")
            val poster = obj.optString("posterPath")
            val isSeries = obj.optInt("videoKind") == 2

            if (isSeries) {
                results.add(
                    TvSeriesSearchResponse(
                        name = title,
                        url = "$mainUrl/api/android/allVideoInfo/id/$id",
                        apiName = this.name,
                        type = TvType.TvSeries,
                        posterUrl = poster
                    )
                )
            } else {
                results.add(
                    MovieSearchResponse(
                        name = title,
                        url = "$mainUrl/api/android/allVideoInfo/id/$id",
                        apiName = this.name,
                        type = TvType.Movie,
                        posterUrl = poster
                    )
                )
            }
        }

        return results
    }

    override suspend fun load(url: String): LoadResponse {
        val response = app.get(url).text
        val json = JSONObject(response)

        val id = json.getInt("id")
        val title = json.getString("title")
        val poster = json.optString("posterPath")
        val description = json.optString("story")
        val isSeries = json.optInt("videoKind") == 2

        return if (isSeries) {
            TvSeriesLoadResponse(
                name = title,
                url = url,
                apiName = this.name,
                type = TvType.TvSeries,
                posterUrl = poster,
                plot = description,
                episodes = listOf(
                    Episode(
                        data = "$mainUrl/api/android/checkVideoParentalLevel/id/$id",
                        name = title
                    )
                )
            )
        } else {
            MovieLoadResponse(
                name = title,
                url = url,
                apiName = this.name,
                type = TvType.Movie,
                posterUrl = poster,
                plot = description
            )
        }
    }

    override suspend fun loadLinks(
        data: String,
        isCasting: Boolean,
        subtitleCallback: (SubtitleFile) -> Unit,
        callback: (ExtractorLink) -> Unit
    ): Boolean {
        val response = app.get(data).text
        val json = JSONObject(response)
        val link = json.optString("videoUrl")

        if (link.isNotEmpty()) {
            callback.invoke(
                ExtractorLink(
                    source = this.name,
                    name = "Cinemana",
                    url = link,
                    referer = mainUrl,
                    quality = Qualities.Unknown.value,
                    isM3u8 = link.contains(".m3u8")
                )
            )
            return true
        }
        return false
    }
}
