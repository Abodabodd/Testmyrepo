// In build.gradle.kts (the main one for your extension)

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// هذا القسم يضيف المستودعات اللازمة لتحميل المكتبة
repositories {
    mavenCentral()
    maven { url = uri("https://jitpack.io") }
}

android {
    namespace = "com.arabseed"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    // هذا هو السطر الذي يقوم بتحميل مكتبة CloudStream من الإنترنت
    // ويحل مشكلة "Unresolved reference"
    compileOnly("com.github.recloudstream:cloudstream:pre-release")
}