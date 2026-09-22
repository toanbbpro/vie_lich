package com.toanbb.vie_lich

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class HomeScreenWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        // Lặp qua tất cả các widget Vie Lịch đang có trên màn hình chính
        appWidgetIds.forEach { widgetId ->
            // Mở khung layout rỗng (widget_layout.xml) mà ta đã tạo
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                // Tìm đường dẫn bức ảnh mà Flutter vừa chụp (lưu dưới tên 'widget_image')
                val imagePath = widgetData.getString("widget_image", null)
                
                if (imagePath != null) {
                    val imageFile = File(imagePath)
                    if (imageFile.exists()) {
                        // Biến file ảnh thành Bitmap và dán thẳng vào thẻ ImageView
                        val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                        setImageViewBitmap(R.id.widget_image, bitmap)
                    }
                }
            }
            // Ra lệnh cho hệ điều hành cập nhật hiển thị
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}