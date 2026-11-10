# ML Kit text recognition: the app uses the Latin recognizer only; the
# optional Chinese/Devanagari/Japanese/Korean ones are not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit wires its internals together at runtime (component registrars,
# lazy instance maps). Release shrinking broke that on a test phone: every
# InputImage.fromFilePath threw a NullPointerException inside ML Kit's
# own logger (device log 2026-11-09). Keep ML Kit, its internals, the
# component runtime and the Flutter plugin bridges as they are.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
