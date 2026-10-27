# ==========================================
# 1. GIỮ LẠI CODE CỦA APP VÀ WIDGET PROVIDER
# ==========================================
-keep class com.toanbb.vie_lich.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep interface es.antonborri.home_widget.** { *; }
-keep class android.appwidget.** { *; }

# ==========================================
# 2. FIX LỖI SHARED PREFERENCES VÀ PIGEON
# ==========================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep interface io.flutter.plugins.sharedpreferences.** { *; }
-keep class androidx.preferences.** { *; }

# Giữ lại toàn bộ class sinh ra bởi Pigeon (Code Generator)
-keep class **.Pigeon* { *; }
-keep class * extends io.flutter.plugin.common.StandardMessageCodec { *; }
-keep class * implements io.flutter.plugin.common.MessageCodec { *; }

# ==========================================
# 3. FIX LỖI KOTLIN (QUAN TRỌNG NHẤT LÚC NÀY)
# ==========================================
# Giữ lại toàn bộ Kotlin Standard Library và Coroutines
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ==========================================
# 4. CÁC PLUGIN KHÁC
# ==========================================
# Android Alarm Manager Plus
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# ==========================================
# 5. GIỮ LẠI ENTRY POINT EDGE-TO-EDGE CỦA ANDROIDX
# ==========================================
-keep class androidx.activity.EdgeToEdge { public static *** enable*(...); }
-keepnames class androidx.activity.ComponentActivity
-keepnames class androidx.activity.SystemBarStyle