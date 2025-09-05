package com.cinemana

import com.lagradost.cloudstream3.*
import com.lagradost.cloudstream3.utils.*

class ShabakatyCinemanaProvider : MainAPI() {
    override var mainUrl = "https://cinemana.shabakaty.com"
    override var name = "Shabakaty Cinemana"
    override val supportedTypes = setOf(TvType.Movie, TvType.TvSeries)
    override val lang = "ar"

    // تجربة بسيطة: فقط بحث وهمي
    override suspend fun search(query: String): List<SearchResponse> {
        return listOf(
            newMovieSearchResponse("فيلم تجريبي", "$mainUrl/test") {
                this.posterUrl = null
            }
        )
    }

    // صفحة رئيسية فارغة للتجربة
    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        return newHomePageResponse(listOf())
    }
}
