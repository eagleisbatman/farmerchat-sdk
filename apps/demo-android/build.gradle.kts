plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "org.digitalgreen.farmerchat.demo"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.digitalgreen.farmerchat.demo"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"

        // API key from gradle.properties or environment; falls back to placeholder
        buildConfigField(
            "String",
            "FC_API_KEY",
            "\"${project.findProperty("FC_API_KEY") ?: "demo-key"}\""
        )
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

dependencies {
    // SDK modules
    implementation(project(":android-compose"))
    implementation(project(":android-views"))

    // Compose
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    // AndroidX
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime.compose)

    // Views SDK support
    implementation(libs.material)
    implementation(libs.appcompat)
    implementation(libs.constraintlayout)
}
