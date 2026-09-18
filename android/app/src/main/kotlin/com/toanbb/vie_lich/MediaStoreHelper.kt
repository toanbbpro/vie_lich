package com.toanbb.vie_lich

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream

object MediaStoreHelper {
    const val ALBUM_NAME = "VieLich"
    const val FILE_NAME = "vie_lich_custom_sound.mp3"

    fun saveToMediaStore(context: Context, sourcePath: String): String? {
        return try {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists()) return null

            deleteFromMediaStore(context)

            val resolver = context.contentResolver
            // Dùng EXTERNAL_CONTENT_URI thay vì VOLUME_EXTERNAL_PRIMARY
            // để có URI dạng content://media/external/audio/media/ID
            val collection: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, FILE_NAME)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
                put(MediaStore.MediaColumns.TITLE, "VieLich Custom Sound")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        Environment.DIRECTORY_RINGTONES + "/" + ALBUM_NAME
                    )
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }

            val uri: Uri = resolver.insert(collection, values) ?: return null

            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(sourceFile).use { input ->
                    input.copyTo(output)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }

            uri.toString()
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun deleteFromMediaStore(context: Context): Boolean {
        return try {
            val resolver = context.contentResolver
            val collection: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(FILE_NAME)
            val deleted = resolver.delete(collection, selection, selectionArgs)
            deleted > 0
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun existsInMediaStore(context: Context): Boolean {
        return try {
            val resolver = context.contentResolver
            val collection: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
            val selectionArgs = arrayOf(FILE_NAME)

            resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                cursor.count > 0
            } ?: false
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}