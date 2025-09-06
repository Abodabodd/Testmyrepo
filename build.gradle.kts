plugins {
    id("com.android.library")
    kotlin("android")
}

android {
    namespace = "com.cinemana"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
        targetSdk = 34
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

dependencies {
    implementation("com.lagradost:cloudstream3-core:1.0.0") // ضع نسخة Core الصحيحة
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
}
