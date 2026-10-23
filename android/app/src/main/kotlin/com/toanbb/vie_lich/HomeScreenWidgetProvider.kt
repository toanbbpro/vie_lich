package com.toanbb.vie_lich

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

class HomeScreenWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            // Lấy đường dẫn tới file ảnh do Flutter render ra
            val imageFile = File(context.filesDir, "widget_image.png")
            
            // Nếu file chưa tồn tại thì bỏ qua
            if (!imageFile.exists()) continue

            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Sử dụng hàm giảm tần số lấy mẫu (Downsampling) để tiết kiệm RAM
                val bitmap = decodeSampledBitmapFromFile(imageFile.absolutePath, 500, 375)
                
                if (bitmap != null) {
                    setImageViewBitmap(R.id.widget_image, bitmap)
                }
                
                // (Nếu sau này bạn muốn bấm vào widget để mở app, hãy mở comment đoạn dưới)
                // val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                // setOnClickPendingIntent(R.id.widget_image, pendingIntent)
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    // ============================================================
    // CÁC HÀM HỖ TRỢ GIẢM KÍCH THƯỚC ẢNH (BITMAP DOWNSAMPLING)
    // ============================================================
    
    private fun decodeSampledBitmapFromFile(
        filePath: String,
        reqWidth: Int,
        reqHeight: Int
    ): Bitmap? {
        // Bước 1: Chỉ đọc kích thước của ảnh (không load vào RAM)
        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(filePath, options)

        // Bước 2: Tính toán tỷ lệ giảm (inSampleSize)
        options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)

        // Bước 3: Load ảnh thật với tỷ lệ giảm đã tính
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

            // Tính toán inSampleSize là lũy thừa của 2 (1, 2, 4, 8...)
            while ((halfHeight / inSampleSize) >= reqHeight && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }
}