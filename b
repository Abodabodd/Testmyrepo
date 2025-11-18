private fun collectFromRenderer(renderer: Map<*, *>?, seenIds: MutableSet<String>): SearchResponse? {
    if (renderer == null) return null

    val videoData = renderer.getMapKey("videoRenderer")
        ?: renderer.getMapKey("compactVideoRenderer")
        ?: renderer.getMapKey("gridVideoRenderer")
    if (videoData != null) {
        val videoId = videoData.getString("videoId")
        if (videoId != null && seenIds.add(videoId)) {
            val title = extractTitle(videoData.getMapKey("title")) ?: "YouTube Video"
            val poster = videoData.getMapKey("thumbnail")?.getListKey("thumbnails")?.lastOrNull()?.getString("url")
            return newMovieSearchResponse(title, "$mainUrl/watch?v=$videoId", TvType.Movie) {
                // ***  استخدام الدالة المساعدة هنا  ***
                this.posterUrl = fixPosterUrl(poster)
            }
        }
    }

    val reelData = renderer.getMapKey("reelItemRenderer")
    if (reelData != null) {
        val videoId = reelData.getString("videoId")
        if (videoId != null && seenIds.add(videoId)) {
            val title = extractTitle(reelData.getMapKey("headline")) ?: "YouTube Short"
            val poster = reelData.getMapKey("thumbnail")?.getListKey("thumbnails")?.lastOrNull()?.getString("url")
            return newMovieSearchResponse("[Shorts] $title", "$mainUrl/shorts/$videoId", TvType.Movie) {
                // ***  واستخدامها هنا أيضاً  ***
                this.posterUrl = fixPosterUrl(poster)
            }
        }
    }
    // لا حاجة لتعديل بقية أجزاء هذه الدالة لأنها كانت مجرد أمثلة،
    // والمنطق الأساسي هنا يغطي معظم الحالات.
    return null
}
