plugins {
    id("com.android.library")
    kotlin("android")
}

android {
    namespace = "com.cinemana"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
    }
}

dependencies {
    // لازم يربط بالمكتبة الرئيسية
    implementation(project(":app"))

    // مكتبات أساسية
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jsoup:jsoup:1.15.4")
}
