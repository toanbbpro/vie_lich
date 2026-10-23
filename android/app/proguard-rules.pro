# Giữ nguyên code của Android Alarm Manager Plus
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }

# Giữ nguyên code của Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Giữ lại code Kotlin của riêng ứng dụng (để không đứt kết nối MediaStore)
-keep class com.toanbb.vie_lich.** { *; }

# Giữ lại entry point edge-to-edge của AndroidX để Play Console quét được
-keep class androidx.activity.EdgeToEdge { public static *** enable*(...); }
-keepnames class androidx.activity.ComponentActivity
-keepnames class androidx.activity.SystemBarStyle