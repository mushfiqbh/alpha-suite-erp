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

    // Register namespace & compileSdk fix for ota_update before project evaluation
    if (project.name == "ota_update") {
        project.afterEvaluate {
            project.extensions.findByName("android")?.let { androidExt ->
                val methods = androidExt::class.java.methods
                methods.find { it.name == "setNamespace" }?.invoke(androidExt, "sk.fourq.otaupdate")
                methods.find { it.name == "setCompileSdk" }?.invoke(androidExt, 36)
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
