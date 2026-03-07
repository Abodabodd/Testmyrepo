val serverButtons = doc.select("#AllServerWatch button")
    .mapNotNull { btn ->
        Regex("""SwitchServer\(this,\s*(\d+)""")
            .find(btn.attr("onclick"))?.groupValues?.get(1)
    }
