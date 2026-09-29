# Release minify is off in this skeleton. If you enable it, keep kotlinx
# serialization and Hotwire bridge models.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class **$$serializer { *; }
-keep,includedescriptorclasses class dev.hotwire.nativeshell.**$$serializer { *; }
-keepclassmembers class dev.hotwire.nativeshell.** {
    *** Companion;
}
-keepclasseswithmembers class dev.hotwire.nativeshell.** {
    kotlinx.serialization.KSerializer serializer(...);
}
