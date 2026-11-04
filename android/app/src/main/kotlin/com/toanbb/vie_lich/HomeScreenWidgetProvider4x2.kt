package com.toanbb.vie_lich

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import java.io.File

class HomeScreenWidgetProvider4x2 : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val imageFile = File(context.filesDir, "home_widget/widget_image_4x2.png")

        if (!imageFile.exists() || imageFile.length() == 0L) {
            Log.e("WidgetDebug4x2", "File ảnh 4x2 không tồn tại")
            val views = RemoteViews(context.packageName, R.layout.widget_layout_4x2)
            for (appWidgetId in appWidgetIds) {
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
            return
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout_4x2).apply {
                val bitmap = decodeSampledBitmapFromFile(imageFile.absolutePath, 800, 360)
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_image_4x2, bitmap)
                }

                // 1. Link mở Lịch Ngày (Vùng bên trái)
                val dayIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("vielich://open?tab=day")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val dayPendingIntent = PendingIntent.getActivity(
                    context,
                    1,
                    dayIntent,
                    // Dùng FLAG_CANCEL_CURRENT để xóa cache cũ
                    PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.left_click_area, dayPendingIntent)

                // 2. Link mở Lịch Tháng (Vùng bên phải + khoảng trống)
                val monthIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("vielich://open?tab=month")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val monthPendingIntent = PendingIntent.getActivity(
                    context,
                    2,
                    monthIntent,
                    PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.right_click_area, monthPendingIntent)
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context.packageName, javaClass.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    private fun decodeSampledBitmapFromFile(
        filePath: String,
        reqWidth: Int,
        reqHeight: Int
    ): Bitmap? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(filePath, options)
        options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)
        options.inJustDecodeBounds = false
        return BitmapFactory.decodeFile(filePath, options)
    }

    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1

        if (height > reqHeight || width > reqWidth) {
            val halfHeight: Int = height / 2
            val halfWidth: Int = width / 2
            while ((halfHeight / inSampleSize) >= reqHeight && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }
}