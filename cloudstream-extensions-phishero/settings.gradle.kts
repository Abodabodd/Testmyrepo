// In settings.gradle.kts (the main one in the root folder)

rootProject.name = "CloudstreamPlugins"

// الخطوة 1: قم بتضمين التطبيق الرئيسي. هذا هو السطر الأهم المفقود.
include(":app")

// الخطوة 2: قم بتضمين الإضافة الخاصة بك بشكل صريح
include(":Arabseed")
// وأخبر المشروع بمكان العثور عليها بالضبط
project(":Arabseed").projectDir = file("Arabseed") // <-- تأكد من أن "Arabseed" هو اسم المجلد الصحيح للإضافة