O Assignment type mismatch: actual type is 'Int?', but 'Score?' was expected. :61
O No parameter with name 'dataUrl' found.:72
O Assignment type mismatch: actual type is 'Int?', but 'Score?' was expected. :76
A Class "ShabakatyCinemanaProvider" is never used :6
A Package directive does not match the file location :1                this.posterUrl = posterUrl
                this.year = year
            }
        } else {
            newTvSeriesSearchResponse(title, href, type = TvType.TvSeries) {
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
        val score = doc.selectFirst("span.rating")?.text()?.toScore()

        return if (url.contains("/movie/")) {
            newMovieLoadResponse(title, url, dataUrl = url, type = TvType.Movie) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.score = score
            }
        } else {
            val episodes = doc.select("ul.episodes li").mapNotNull {
                val epTitle = it.text()
                val epUrl = it.selectFirst("a")?.attr("href") ?: return@mapNotNull null
                newEpisode(epUrl) {
                    this.name = epTitle
                }
            }

            newTvSeriesLoadResponse(title, url, dataUrl = url, type = TvType.TvSeries, episodes = episodes) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.score = score
            }
        }
    }
}                this.year = year
            }
        } else {
            newTvSeriesSearchResponse(title, href, type = TvType.TvSeries) {
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
        val score = doc.selectFirst("span.rating")?.text()?.toRatingInt()

        return if (url.contains("/movie/")) {
            newMovieLoadResponse(title, url, dataUrl = url, type = TvType.Movie) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.score = score
            }
        } else {
            val episodes = doc.select("ul.episodes li").mapNotNull {
                val epTitle = it.text()
                val epUrl = it.selectFirst("a")?.attr("href") ?: return@mapNotNull null
                newEpisode(epUrl) {
                    this.name = epTitle
                }
            }

            newTvSeriesLoadResponse(title, url, dataUrl = url, type = TvType.TvSeries, episodes = episodes) {
                this.posterUrl = posterUrl
                this.year = year
                this.plot = plot
                this.score = score
            }
        }
    }
}
