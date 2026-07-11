# Flutter ProGuard/R8 Rules

# Keep Flutter framework
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# Cloud Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firestore.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Hive
-keep class com.hive.** { *; }

# Gson/Serialization
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Keep custom model classes used by Hive and Firestore
-keep class com.speakeasy.english.learn.models.** { *; }
-keep class com.speakeasy.english.learn.models.game.** { *; }

# Flutter Wrapper
-keep class * implements io.flutter.embedding.engine.FlutterEngine { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep R8 from stripping generic signatures
-keepattributes Signature, InnerClasses, EnclosingMethod

# Keep annotations
-keepattributes *Annotation*

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# OneSignal - Keep all native SDK classes for background notification delivery
-keep class com.onesignal.** { *; }
-keep class com.onesignal.common.** { *; }
-keep class com.onesignal.notifications.** { *; }
-keep class com.onesignal.user.** { *; }
-keep class com.onesignal.session.** { *; }
-keep class com.onesignal.osinternal.** { *; }
-keep class com.onesignal.language.** { *; }
-keep class com.onesignal.location.** { *; }
-keep class com.onesignal.inAppMessages.** { *; }
-keep class com.onesignal.outcomes.** { *; }
-keep class com.onesignal.debug.** { *; }
-keep class com.huawei.hms.** { *; }
-keep class com.huawei.agconnect.** { *; }

# Keep Play Core / Feature Delivery (needed by Flutter engine's PlayStoreDeferredComponentManager)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
