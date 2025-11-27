allprojects {
    repositories {
        google()
        mavenCentral()
        // Yandex MapKit repository
        maven {
            url = uri("https://maven.yandex.ru/repository/yandex-maps-public")
        }
        // MyID SDK repository
        maven {
            url = uri("https://artifactory.aigroup.uz:443/artifactory/myid")
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
