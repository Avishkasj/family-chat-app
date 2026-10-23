import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("prod") {
            dimension = "flavor-type"
            applicationId = "app.famnest.chat"
            resValue(type = "string", name = "app_name", value = "FamNest")
        }
        create("dev") {
            dimension = "flavor-type"
            applicationId = "app.famnest.chat.dev"
            resValue(type = "string", name = "app_name", value = "FamNest Dev")
        }
    }
}