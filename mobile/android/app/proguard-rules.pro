# DealGo release (R8) keep rules.
# Flutter's own rules are added by the Flutter Gradle plugin; these cover the
# plugins that reflect / are reached from native callbacks.

# CallKit-style incoming calls (flutter_callkit_incoming): activities, the
# broadcast receiver and the Gson/Jackson-mapped call data.
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-dontwarn com.hiennv.flutter_callkit_incoming.**

# LiveKit voice + WebRTC (JNI looks these up by name).
-keep class io.livekit.** { *; }
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**
-dontwarn io.livekit.**

# Firebase Messaging / Core.
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn com.google.firebase.**

# DealGo's own native side (MainActivity, NewJobChannels notification channels).
-keep class dealgo.nguyengoctien.com.** { *; }

# Keep annotations / signatures that Gson-style mappers need.
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod

# ML Kit text recognition: only the Latin model is bundled (KYC OCR); the
# plugin references optional script recognizers that are not on the classpath.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
