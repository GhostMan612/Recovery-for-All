// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

allprojects {
    repositories {
        google()
        mavenCentral()
        // The Atlas SDK is published by Metro-IntelliTrip to an append-only
        // branch, not to Maven Central. Override -PatlasMavenUrl with a file
        // URI when testing a staged publication; the default is the same
        // immutable repository CI resolves. The content filter keeps Gradle
        // from asking this repository for unrelated dependencies.
        val atlasMavenUrl = providers.gradleProperty("atlasMavenUrl").orNull
            ?: "https://raw.githubusercontent.com/GhostMan612/Metro-IntelliTrip/atlas-maven"
        maven {
            name = "atlas"
            url = uri(atlasMavenUrl)
            content { includeGroup("com.intellitrip.atlas") }
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
    
    project.afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                // Force compileSdk 36 across the board
                try {
                    androidExt.javaClass.getMethod("setCompileSdk", Int::class.java).invoke(androidExt, 36)
                } catch (e: Throwable) {
                    androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java).invoke(androidExt, 36)
                }
                
                val compileOptions = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
                compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java).invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (e: Throwable) {
            }
        }
        
        project.tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
        
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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