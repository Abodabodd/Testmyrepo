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
}
