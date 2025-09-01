package com.hexated

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.LoadResponse.Companion.addEpisodes
import com.lagradost.cloudstream3.mvvm.safeApiCall
import org.jsoup.nodes.Element

class ShabakatyCinemanaProvider : MainAPI() {
    override var name = "Shabakaty Cinemana"
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var lang = "ar"
    override val hasMainPage = true
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val doc = app.get(mainUrl).document
        val movies = doc.select("div.movie-item").mapNotNull {
            toSearchResponse(it)
        }
        return newHomePageResponse(HomePageList("أحدث الأفلام", movies), hasNext = false)
    }

    override suspend fun search(query: String): List<SearchResponse> {
        val url = "$mainUrl/search?query=$query"
        val doc = app.get(url).document
        return doc.select("div.movie-item").mapNotNull {
            toSearchResponse(it)
        }
    }

    private fun toSearchResponse(it: Element): SearchResponse? {
        val title = it.selectFirst("h3.title")?.text() ?: return null
        val href = it.selectFirst("a")?.attr("href") ?: return null
        val posterUrl = it.selectFirst("img")?.attr("src")
        val year = it.selectFirst("span.year")?.text()?.toIntOrNull()

        return if (href.contains("/movie/")) {
            newMovieSearchResponse(title, href) {
                this.posterUrl = posterUrl
                this.year = year
            }
        } else {
            newTvSeriesSearchResponse(title, href) {
                this.posterUrl = posterUrl
                this.year = year
            }
        }
    }

    override suspend fun load(url: String): LoadResponse {
        val doc = app.get(url).document
        val title = doc.selectFirst("h1")?.text() ?: "No Title"
        val posterUrl = doc.selectFirst("div.poster img")?.attr("src")
        val year = doc.selectFirst("span.year")?.text()?.toIntOrNull()
        val plot = doc.selectFirst("div.plot")?.text()
        val rating = doc.selectFirst("span.rating")?.text()?.toRatingInt()

        return if (url.contains("/movie/")) {
            newMovieLoadResponse(title, url) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = rating
            }
        } else {
            val episodes = doc.select("ul.episodes li").map {
                val epTitle = it.text()
                val epUrl = it.selectFirst("a")?.attr("href") ?: return@map null
                newEpisode(epUrl) {
                    this.name = epTitle
                }
            }.filterNotNull()

            newTvSeriesLoadResponse(title, url) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.rating = rating
                addEpisodes(DubStatus.Subbed, episodes)
            }
        }
    }
}
