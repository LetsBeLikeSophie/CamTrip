# ML Kit text recognition references the Devanagari model, which CamTrip does not ship.
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Keep ML Kit and its Flutter plugins whole: the release shrinker otherwise
# strips classes they look up at runtime, and the translation plugin fails
# to register (nothing happens after taking a photo).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google_mlkit_** { *; }
