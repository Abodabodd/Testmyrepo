package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.ExtractorLink
import com.lagradost.cloudstream3.utils.newExtractorLink
import com.lagradost.cloudstream3.utils.getQualityFromName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import android.util.Log

// *** تعريف Score (داخل الإضافة) - يجب أن يعمل هذا الآن ***
@Serializable
data class Score(
    val float: Float,
    val int: Double,
    val text: String? = null
) {
    companion object {
        fun from10(score: Float?): Score? {
            return score?.let { Score(it, 10.0, null) }
        }
    }
}


class CinemanaProvider : MainAPI() {
    override var name = "Shabakaty Cinemana slow (\uD83C\uDDEE\uD83C\uDDF6)"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)
    override val hasMainPage = true

    // *** تعريف mainPage لجميع التبويبات المطلوبة ***
    override val mainPage = listOf(
        MainPageData("NEWLY_ADDED_HOMEPAGE", "أحدث الإضافات"),
        MainPageData("CATEGORIES_HOMEPAGE", "الفئات"),

        // قوائم الأفلام المصنفة
        MainPageData("MOVIES_SORTED_DESC", "أفلام - الملفات الحديثة"),
        MainPageData("MOVIES_SORTED_ASC", "أفلام - الملفات القديمة"),
        MainPageData("MOVIES_SORTED_R_DESC", "أفلام - سنة الإصدار الأحدث"),
        MainPageData("MOVIES_SORTED_R_ASC", "أفلام - سنة الإصدار الأقدم"),
        MainPageData("MOVIES_SORTED_TITLE_DESC", "أفلام - أبجديًا تنازليًا"),
        MainPageData("MOVIES_SORTED_TITLE_ASC", "أفلام - أبجديًا تصاعديًا"),
        MainPageData("MOVIES_SORTED_VIEWS_DESC", "أفلام - الأكثر مشاهدة"),
        MainPageData("MOVIES_SORTED_VIEWS_ASC", "أفلام - الأقل مشاهدة"),
        MainPageData("MOVIES_SORTED_STARS_DESC", "أفلام - أعلى تقييم IMDb"),
        MainPageData("MOVIES_SORTED_STARS_ASC", "أفلام - أقل تقييم IMDb"),

        // قوائم المسلسلات المصنفة
        MainPageData("SERIES_SORTED_DESC", "مسلسلات - الملفات الحديثة"),
        MainPageData("SERIES_SORTED_ASC", "مسلسلات - الملفات القديمة"),
        MainPageData("SERIES_SORTED_R_DESC", "مسلسلات - سنة الإصدار الأحدث"),
        MainPageData("SERIES_SORTED_R_ASC", "مسلسلات - سنة الإصدار الأقدم"),
        MainPageData("SERIES_SORTED_TITLE_DESC", "مسلسلات - أبجديًا تنازليًا"),
        MainPageData("SERIES_SORTED_TITLE_ASC", "مسلسلات - أبجديًا تصاعديًا"),
        MainPageData("SERIES_SORTED_VIEWS_DESC", "مسلسلات - الأكثر مشاهدة"),
        MainPageData("SERIES_SORTED_VIEWS_ASC", "مسلسلات - الأقل مشاهدة"),
        MainPageData("SERIES_SORTED_STARS_DESC", "مسلسلات - أعلى تقييم IMDb"),
        MainPageData("SERIES_SORTED_STARS_ASC", "مسلسلات - أقل تقييم IMDb")
    )


    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val items = mutableListOf<HomePageList>()
        val pageNum = page - 1
        val itemsPerPage = 24

        val requestKey = request.data // هذا هو المفتاح الداخلي مثل "NEWLY_ADDED_HOMEPAGE"
        val requestName = request.name // هذا هو النص الذي يظهر في UI (مثل "أحدث الإضافات")
        Log.d(name, "getMainPage called with requestKey: $requestKey, requestName: $requestName, page: $page")

        when (requestKey) {
            "NEWLY_ADDED_HOMEPAGE" -> {
                val newlyVideosUrl = "$mainUrl/api/android/newlyVideosItems/level/0/offset/${pageNum * itemsPerPage}/itemsPerPage/$itemsPerPage/"
                Log.d(name, "Fetching newly added videos (page $page) from: $newlyVideosUrl")
                val newlyVideosResponse = app.get(newlyVideosUrl).parsedSafe<List<Map<String, Any>>>()
                val newlyVideos = newlyVideosResponse?.mapNotNull { it.toCinemanaItem().toSearchResponse() } ?: emptyList()
                items.add(HomePageList(requestName, newlyVideos))
                Log.d(name, "Added ${newlyVideos.size} newly added videos for page $page.")
            }
            "CATEGORIES_HOMEPAGE" -> {
                val videoGroupsUrl = "$mainUrl/api/android/videoGroups/lang/ar/level/0"
                Log.d(name, "Fetching video groups (page $page) from: $videoGroupsUrl")
                val videoGroupsResponse = app.get(videoGroupsUrl).parsedSafe<List<VideoGroup>>()

                videoGroupsResponse?.forEach { group ->
                    val groupId = group.id ?: return@forEach
                    val groupTitle = group.title ?: "مجموعة غير معروفة"

                    val groupContentUrl = "$mainUrl/api/android/videoListPagination/groupID/$groupId/level/0/itemsPerPage/$itemsPerPage/pageNumber/$pageNum"
                    Log.d(name, "Fetching content for group '$groupTitle' (ID: $groupId, page $page) from: $groupContentUrl")
                    val groupContentResponse = app.get(groupContentUrl).parsedSafe<List<Map<String, Any>>>()
                    val groupContent = groupContentResponse?.mapNotNull { it.toCinemanaItem().toSearchResponse() } ?: emptyList()
                    if (groupContent.isNotEmpty()) {
                        items.add(HomePageList(groupTitle, groupContent))
                        Log.d(name, "Added ${groupContent.size} items for group '$groupTitle' for page $page.")
                    } else {
                        Log.w(name, "No content found for group '$groupTitle' (ID: $groupId) for page $page or failed to parse.")
                    }
                }
            }
            // التعامل مع القوائم المصنفة
            else -> {
                // تحديد نوع المحتوى ومفتاح الفرز بناءً على requestKey مباشرة
                val videoKind: String
                val finalSortParam: String

                when (requestKey) {
                    "MOVIES_SORTED_DESC" -> { videoKind = "1"; finalSortParam = "desc" }
                    "MOVIES_SORTED_ASC" -> { videoKind = "1"; finalSortParam = "asc" }
                    "MOVIES_SORTED_R_DESC" -> { videoKind = "1"; finalSortParam = "r_desc" }
                    "MOVIES_SORTED_R_ASC" -> { videoKind = "1"; finalSortParam = "r_asc" }
                    "MOVIES_SORTED_TITLE_DESC" -> { videoKind = "1"; finalSortParam = "title_desc" }
                    "MOVIES_SORTED_TITLE_ASC" -> { videoKind = "1"; finalSortParam = "title_asc" }
                    "MOVIES_SORTED_VIEWS_DESC" -> { videoKind = "1"; finalSortParam = "views_desc" }
                    "MOVIES_SORTED_VIEWS_ASC" -> { videoKind = "1"; finalSortParam = "views_asc" }
                    "MOVIES_SORTED_STARS_DESC" -> { videoKind = "1"; finalSortParam = "stars_desc" }
                    "MOVIES_SORTED_STARS_ASC" -> { videoKind = "1"; finalSortParam = "stars_asc" }

                    "SERIES_SORTED_DESC" -> { videoKind = "2"; finalSortParam = "desc" }
                    "SERIES_SORTED_ASC" -> { videoKind = "2"; finalSortParam = "asc" }
                    "SERIES_SORTED_R_DESC" -> { videoKind = "2"; finalSortParam = "r_desc" }
                    "SERIES_SORTED_R_ASC" -> { videoKind = "2"; finalSortParam = "r_asc" }
                    "SERIES_SORTED_TITLE_DESC" -> { videoKind = "2"; finalSortParam = "title_desc" }
                    "SERIES_SORTED_TITLE_ASC" -> { videoKind = "2"; finalSortParam = "title_asc" }
                    "SERIES_SORTED_VIEWS_DESC" -> { videoKind = "2"; finalSortParam = "views_desc" }
                    "SERIES_SORTED_VIEWS_ASC" -> { videoKind = "2"; finalSortParam = "views_asc" }
                    "SERIES_SORTED_STARS_DESC" -> { videoKind = "2"; finalSortParam = "stars_desc" }
                    "SERIES_SORTED_STARS_ASC" -> { videoKind = "2"; finalSortParam = "stars_asc" }
                    else -> {
                        Log.e(name, "Unrecognized requestKey for sorting (dynamic section): $requestKey")
                        return HomePageResponse(emptyList(), false)
                    }
                }

                val sortedUrl = "$mainUrl/api/android/video/V/2/itemsPerPage/$itemsPerPage/level/0/videoKind/$videoKind/sortParam/$finalSortParam/pageNumber/$pageNum"
                Log.d(name, "Fetching sorted list '$requestName' (page $page) from: $sortedUrl")
                val sortedResponse = app.get(sortedUrl).parsedSafe<List<Map<String, Any>>>()
                val sortedVideos = sortedResponse?.mapNotNull { it.toCinemanaItem().toSearchResponse() } ?: emptyList()
                if (sortedVideos.isNotEmpty()) {
                    items.add(HomePageList(requestName, sortedVideos)) // استخدم requestName للعرض
                    Log.d(name, "Added ${sortedVideos.size} items for '$requestName' for page $page.")
                } else {
                    Log.w(name, "No content found for '$requestName' for page $page or failed to parse from: $sortedUrl")
                }
            }
        }

        if (items.isEmpty()) {
            Log.w(name, "getMainPage returned no content for request: ${request.name} (Key: ${request.data}). All lists were empty.")
        }

        return newHomePageResponse(items, hasNext = true)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val allResults = mutableListOf<SearchResponse>()
        val itemsPerPageSearch = 30
        val yearRange = "1900,2025"

        val maxPagesToFetch = 3

        for (pageNumberSearch in 0 until maxPagesToFetch) {
            val commonParams = "level=0&videoTitle=$query&staffTitle=$query&year=$yearRange&page=$pageNumberSearch"

            val moviesSearchUrl = "$mainUrl/api/android/AdvancedSearch?$commonParams&type=movies&itemsPerPage=$itemsPerPageSearch"
            Log.d(name, "Searching movies for '$query' at: $moviesSearchUrl (Page: $pageNumberSearch)")
            val moviesResponse = app.get(moviesSearchUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
            val movies = moviesResponse.mapNotNull { it.toCinemanaItem().toSearchResponse() }
            allResults.addAll(movies)

            val seriesSearchUrl = "$mainUrl/api/android/AdvancedSearch?$commonParams&type=series&itemsPerPage=$itemsPerPageSearch"
            Log.d(name, "Searching series for '$query' at: $seriesSearchUrl (Page: $pageNumberSearch)")
            val seriesResponse = app.get(seriesSearchUrl).parsedSafe<List<Map<String, Any>>>() ?: emptyList()
            val series = seriesResponse.mapNotNull { it.toCinemanaItem().toSearchResponse() }
            allResults.addAll(series)

            if (movies.isEmpty() && series.isEmpty()) {
                Log.d(name, "No more results found after page $pageNumberSearch for query '$query'. Stopping.")
                break
            }
        }

        return allResults
    }

    override suspend fun load(url: String): LoadResponse? {
        val extractedId = url.substringAfterLast("/")

        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$extractedId"
        Log.d(name, "Loading details for URL: $detailsUrl (Using extracted ID: $extractedId from input URL: $url)")
        val detailsMap = app.get(detailsUrl).parsedSafe<Map<String, Any>>()
        if (detailsMap == null) {
            Log.e(name, "Failed to parse details from: $detailsUrl. Response might be empty or malformed.")
            return null
        }
        val details = detailsMap.toCinemanaItem()

        val title = details.enTitle
        if (title == null) {
            Log.e(name, "Title is null for item from URL: $detailsUrl")
            return null
        }
        val posterUrl = details.imgObjUrl
        val plot = details.enContent
        val year = details.year?.toIntOrNull()

        val ratingFloat = details.stars?.toFloatOrNull()
        val scoreObject = ratingFloat?.let { Score.from10(it) }

        return if (details.kind == 2) { // kind = 2 للمسلسلات
            Log.d(name, "Found a TvSeries with ID: $extractedId, Title: $title")

            val seasonsAndEpisodesUrl = "$mainUrl/api/android/videoSeason/id/$extractedId"
            Log.d(name, "Fetching seasons and episodes from: $seasonsAndEpisodesUrl")

            val episodesResponse = app.get(seasonsAndEpisodesUrl).parsedSafe<List<Map<String, Any>>>()
            val episodes = mutableListOf<Episode>()

            val seasonsMap = mutableMapOf<Int, MutableList<Episode>>()

            episodesResponse?.forEach { episodeMap ->
                val episodeDetails = episodeMap.toCinemanaItem()
                if (episodeDetails.nb != null && episodeDetails.enTitle != null) {
                    val episodeNum = (episodeDetails.episodeNummer as? String)?.toIntOrNull() ?: 1
                    val seasonNum = (episodeDetails.season as? String)?.toIntOrNull() ?: 1

                    val episodeTitle = "الموسم $seasonNum - الحلقة $episodeNum"

                    val newEpisode = newEpisode(episodeDetails.nb) {
                        this.name = episodeTitle
                        this.season = seasonNum
                        this.episode = episodeNum
                        this.posterUrl = episodeDetails.imgObjUrl ?: posterUrl
                        this.description = episodeDetails.enContent
                    }
                    seasonsMap.getOrPut(seasonNum) { mutableListOf() }.add(newEpisode)
                } else {
                    Log.w(name, "Skipping malformed episode item from response: $episodeMap for series ID: $extractedId")
                }
            }

            if (episodesResponse.isNullOrEmpty()) {
                Log.e(name, "Episodes API ($seasonsAndEpisodesUrl) response was null or empty for series ID: $extractedId")
            } else if (seasonsMap.isEmpty()) {
                Log.w(name, "Parsed episodes API response, but no valid episodes found for series ID: $extractedId. Raw response might be: $episodesResponse")
            }

            val sortedSeasonNumbers = seasonsMap.keys.sorted()

            sortedSeasonNumbers.forEach { sNum ->
                val seasonEpisodes = seasonsMap[sNum]
                if (seasonEpisodes != null) {
                    seasonEpisodes.sortBy { it.episode }
                    episodes.addAll(seasonEpisodes)
                }
            }

            newTvSeriesLoadResponse(title, extractedId, TvType.TvSeries, episodes) {
                this.posterUrl = posterUrl
                this.plot = plot
                this.year = year
            }
        } else { // kind = 1 للأفلام (أو أي قيمة أخرى غير 2)
            Log.d(name, "Returning MovieLoadResponse for: $title (ID: $extractedId)")
            newMovieLoadResponse(title, extractedId, TvType.Movie, extractedId) {
                this.posterUrl = posterUrl
                this.plot = plot
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
        val extractedId = data.substringAfterLast("/")

        val videosUrl = "$mainUrl/api/android/transcoddedFiles/id/$extractedId"
        Log.d(name, "Attempting to fetch video links from: $videosUrl (Using extracted ID: $extractedId from input data: $data)")
        val videoResponse = app.get(videosUrl).parsedSafe<List<Map<String, Any>>>()

        if (videoResponse == null || videoResponse.isEmpty()) {
            Log.e(name, "Failed to get video links from $videosUrl or response was empty for ID: $extractedId")
            return false
        }

        Log.d(name, "Received video response: ${videoResponse.size} links found for ID: $extractedId.")

        videoResponse.forEach { videoMap ->
            val videoUrl = videoMap["videoUrl"] as? String
            val resolution = videoMap["resolution"] as? String
            val linkName = resolution ?: "Default"

            if (videoUrl != null) {
                val headers = mapOf("Referer" to mainUrl)
                Log.d(name, "Creating ExtractorLink: Name='$linkName', URL='$videoUrl', Headers=$headers, Resolution String='$resolution'")
                callback(
                    newExtractorLink(
                        source = name,
                        name = linkName,
                        url = videoUrl
                    ) {
                        this.headers = headers
                        this.quality = getQualityFromName(resolution)
                    }
                )
            } else {
                Log.w(name, "videoUrl is null for a video map in ID: $extractedId, Map: $videoMap")
            }
        }

        val detailsUrl = "$mainUrl/api/android/allVideoInfo/id/$extractedId"
        Log.d(name, "Attempting to fetch subtitle links from: $detailsUrl (Using extracted ID: $extractedId from input data: $data)")
        val detailsMap = app.get(detailsUrl).parsedSafe<Map<String, Any>>()

        if (detailsMap != null) {
            val translations = detailsMap["translations"] as? List<Map<String, Any>>
            if (translations != null) {
                Log.d(name, "Found ${translations.size} subtitle tracks for ID: $extractedId.")
                translations.forEach { sub ->
                    val file = sub["file"] as? String
                    val lang = sub["name"] as? String
                    if (file != null && lang != null) {
                        Log.d(name, "Adding subtitle: Language='$lang', URL='$file'")
                        subtitleCallback(SubtitleFile(lang, file))
                    } else {
                        Log.w(name, "Subtitle file or language is null for sub: $sub")
                    }
                }
            } else {
                Log.d(name, "No 'translations' key found or it's not a list in allVideoInfo for ID: $extractedId")
            }
        } else {
            Log.e(name, "Failed to get allVideoInfo for subtitle fetching for ID: $extractedId")
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
        val kind: Int? = null,
        val fileFile: String? = null,
        @SerialName("episodeNummer") val episodeNummer: String? = null,
        val season: String? = null
    )

    @Serializable
    data class SeasonNumberItem(
        val season: String? = null
    )

    // *** تعريف data class VideoGroup الذي كان مفقوداً ***
    @Serializable
    data class VideoGroup(
        val id: String? = null,
        val title: String? = null,
    )

    private fun Map<String, Any>.toCinemanaItem(): CinemanaItem {
        return CinemanaItem(
            nb = this["nb"] as? String,
            enTitle = this["en_title"] as? String,
            imgObjUrl = this["imgObjUrl"] as? String ?: this["img"] as? String,
            year = this["year"] as? String,
            enContent = this["en_content"] as? String,
            stars = this["stars"] as? String,
            kind = (this["kind"] as? String)?.toIntOrNull() ?: (this["kind"] as? Int),
            fileFile = this["fileFile"] as? String,
            episodeNummer = this["episodeNummer"] as? String,
            season = this["season"] as? String
        )
    }

    private fun CinemanaItem.toSearchResponse(): SearchResponse {
        val validNb = nb ?: return newMovieSearchResponse("Error", "error", TvType.Movie)

        return if (kind == 2) {
            newTvSeriesSearchResponse(enTitle ?: "No Title", validNb, TvType.TvSeries) {
                this.posterUrl = imgObjUrl
            }
        } else {
            newMovieSearchResponse(enTitle ?: "No Title", validNb, TvType.Movie) {
                this.posterUrl = imgObjUrl
            }
        }
    }
}
