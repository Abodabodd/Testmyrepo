package com.cinmana // تأكد أن اسم الحزمة صحيح

import com.lagradost.cloudstream3.extractors.FileMoonIn
import com.lagradost.cloudstream3.plugins.BasePlugin
import com.lagradost.cloudstream3.plugins.CloudstreamPlugin

// مهم: يجب أن تكون هذه الفئة هي نفس الفئة التي تحددها في build.gradle.kts كـ pluginClassName
@CloudstreamPlugin
class CinmanaPlugin : BasePlugin() { // اسم الفئة يجب أن يكون فريداً وواضحاً، وليكن CinmanaPlugin
    override fun load() {
        // تسجيل المصدر الرئيسي لإضافتك
        registerMainAPI(CinmanaProvider()) // << تصحيح: استدعي CinmanaProvider

        // تسجيل المستخرجات (Extractors)
        // إذا كنت تريد استخدام مستخرجات أخرى، يجب عليك أولاً استيرادها أو تعريفها.
        // FileMoonIn متاح لأنه تم استيراده
        registerExtractorAPI(FileMoonIn())

        // مثال: إذا كنت تريد إضافة مستخرج Vidhide
        // registerExtractorAPI(Vidhide())

        // إذا كنت قد قمت بتعريف هذه المستخرجات بنفسك أو استوردتها من Cloudstream، فاستخدمها
        // registerExtractorAPI(Ryderjet())
        // registerExtractorAPI(FilemoonV2())
        // registerExtractorAPI(Dhtpre())
        // registerExtractorAPI(Vidhideplus())
    }
}