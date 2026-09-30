import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

extra.set("compileSdkVersion", 36)
extra.set("targetSdkVersion", 36)
extra.set("minSdkVersion", 21)

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep all build output in the root build folder
val newBuildDir: Directory =
    rootProject.layout.projectDirectory
        .dir("../build")

rootProject.layout.buildDirectory.value(newBuildDir)

// Separate build folder for every subproject
subprojects {
    val newSubprojectBuildDir: Directory =
        newBuildDir.dir(project.name)

    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Force all Android modules to use SDK 36 and Java 17
// afterEvaluate ke andar taaki ye Android plugin ke apne defaults ko OVERRIDE kar sake
subprojects {
    afterEvaluate {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension> {
                compileSdk = 36

                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }

        plugins.withId("com.android.application") {
            extensions.configure<ApplicationExtension> {
                compileSdk = 36

                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }

        // Force ALL Java compilation tasks to Java 17 (last-word override)
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }

        // Force ALL Kotlin compilation tasks to JVM 17 (last-word override)
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(JvmTarget.JVM_17)
            }
        }
    }
}

// Make sure app is evaluated before other subprojects
subprojects {
    if (name != "app") {
        evaluationDependsOn(":app")
    }
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}