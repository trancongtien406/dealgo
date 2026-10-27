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
// flutter_ringtone_player still compiles against android-33, while
// current AndroidX deps need 34+. Raise only its compile SDK;
// its minSdk / targetSdk stay as they are.
subprojects {
    if (name != "flutter_ringtone_player") return@subprojects
    plugins.withId("com.android.library") {
        extensions.getByType(
            com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java,
        ).finalizeDsl { lib ->
            if ((lib.compileSdk ?: 0) < 36) lib.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
