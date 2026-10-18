allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// AGP 8.13 fails a plugin module whose compileSdk is below the minCompileSdk of
// its AndroidX dependencies (34 for the libraries Flutter's embedding brings in).
// flutter_webrtc 0.12.x (31) and share_plus 7.x (33) still ask for older SDKs, so
// compile such plugins against the app's SDK. Only the android.jar they compile
// against changes, not their code or native libraries. Remove once both plugins
// are on releases that compile against 34+.
// Must stay above evaluationDependsOn(":app"), which evaluates the plugins.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.getByType(com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java)
            .finalizeDsl { android ->
                val requested = android.compileSdk
                if (requested != null && requested < 34) {
                    logger.lifecycle("Compiling ${project.path} against android-36 (it asks for android-$requested)")
                    android.compileSdk = 36
                }
            }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
