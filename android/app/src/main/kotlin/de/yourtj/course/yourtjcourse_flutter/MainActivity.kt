package de.yourtj.course.yourtjcourse_flutter

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingGallerySave: PendingGallerySave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "de.yourtj.course.flutter/updater",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "installApk" -> installApk(call.argument<String>("path"), result)
                "saveImageToGallery" -> saveImageToGallery(
                    call.argument<ByteArray>("bytes"),
                    call.argument<String>("name"),
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_EXTERNAL_STORAGE) return

        val pending = pendingGallerySave ?: return
        pendingGallerySave = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            saveImageToGallery(pending.bytes, pending.name, pending.result, skipPermissionCheck = true)
        } else {
            pending.result.error("permission_denied", "没有相册写入权限", null)
        }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("invalid_path", "安装包路径为空", null)
            return
        }

        val apkFile = File(path)
        if (!apkFile.exists()) {
            result.error("missing_apk", "安装包文件不存在", null)
            return
        }

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        result.success(null)
    }

    private fun saveImageToGallery(
        bytes: ByteArray?,
        name: String?,
        result: MethodChannel.Result,
        skipPermissionCheck: Boolean = false,
    ) {
        if (bytes == null || bytes.isEmpty()) {
            result.error("invalid_image", "图片数据为空", null)
            return
        }

        if (!skipPermissionCheck && Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val permission = Manifest.permission.WRITE_EXTERNAL_STORAGE
            val hasPermission = ContextCompat.checkSelfPermission(this, permission) ==
                PackageManager.PERMISSION_GRANTED
            if (!hasPermission) {
                if (pendingGallerySave != null) {
                    result.error("permission_busy", "正在等待相册权限授权", null)
                    return
                }
                pendingGallerySave = PendingGallerySave(bytes, name, result)
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(permission),
                    REQUEST_WRITE_EXTERNAL_STORAGE,
                )
                return
            }
        }

        val displayName = (name?.takeIf { it.isNotBlank() } ?: "yourtj-review-share")
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .let { if (it.endsWith(".png", ignoreCase = true)) it else "$it.png" }

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/YourTJ Course",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("insert_failed", "无法写入系统相册", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IllegalStateException("openOutputStream returned null")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            result.error("save_failed", error.localizedMessage ?: "保存图片失败", null)
        }
    }

    private data class PendingGallerySave(
        val bytes: ByteArray,
        val name: String?,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val REQUEST_WRITE_EXTERNAL_STORAGE = 7101
    }
}
