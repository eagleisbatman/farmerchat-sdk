pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "demo-android"

include(":android-compose")
include(":android-views")

project(":android-compose").projectDir = file("../../packages/android-compose")
project(":android-views").projectDir = file("../../packages/android-views")
