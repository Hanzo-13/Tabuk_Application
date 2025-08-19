allprojects {
	repositories {
		google()
		mavenCentral()
	}
}

// Place all Android build outputs under the Flutter project's root build/ directory
rootProject.layout.buildDirectory.set(file("../build"))

subprojects {
	// Keep each module's build under the unified root build/ directory
	layout.buildDirectory.set(file("${rootProject.layout.buildDirectory.get().asFile}/${project.name}"))
	project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
	delete(rootProject.layout.buildDirectory)
}
