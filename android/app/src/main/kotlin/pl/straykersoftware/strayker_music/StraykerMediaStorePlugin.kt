package pl.straykersoftware.strayker_music

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.concurrent.Executors

class StraykerMediaStorePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val pendingPermissionResults = mutableListOf<MethodChannel.Result>()
    private var permissionRequestInProgress = false
    private var permissionWasPreviouslyRequested = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            "pl.straykersoftware.strayker_music/media_store",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() = detachFromActivity()

    private fun detachFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasRequiredAudioPermission" -> result.success(hasPermission())
            "requestRequiredAudioPermission" -> requestPermission(result)
            "listAudio" -> listAudio(call, result)
            "listAudioFolders" -> listAudioFolders(result)
            else -> result.notImplemented()
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success("granted")
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success("denied")
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Audio permission requires an attached activity.", null)
            return
        }

        pendingPermissionResults.add(result)
        if (permissionRequestInProgress) return

        permissionRequestInProgress = true
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        permissionWasPreviouslyRequested = preferences.getBoolean(PERMISSION_REQUESTED, false)
        preferences.edit().putBoolean(PERMISSION_REQUESTED, true).apply()
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(requiredPermission()),
            PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        val currentActivity = activity
        val permission = requiredPermission()
        val response = when {
            granted -> "granted"
            permissionWasPreviouslyRequested && currentActivity != null &&
                !ActivityCompat.shouldShowRequestPermissionRationale(currentActivity, permission) ->
                "permanentlyDenied"
            else -> "denied"
        }
        val results = pendingPermissionResults.toList()
        pendingPermissionResults.clear()
        permissionRequestInProgress = false
        results.forEach { it.success(response) }
        return true
    }

    private fun listAudio(call: MethodCall, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("PERMISSION_DENIED", "Audio permission has not been granted.", null)
            return
        }
        val rawSourceIds = call.argument<List<Any?>>("sourceIds")
        if (rawSourceIds == null || rawSourceIds.any { it !is String }) {
            result.error("INVALID_SOURCE", "sourceIds must be a list of strings.", null)
            return
        }
        val parsedSources = try {
            rawSourceIds.map { parseSource(it as String) }.distinct()
        } catch (error: IllegalArgumentException) {
            result.error("INVALID_SOURCE", error.message, null)
            return
        }

        executor.execute {
            try {
                val documents = mutableListOf<Map<String, Any?>>()
                val skipped = mutableListOf<String>()
                parsedSources.forEach { source ->
                    try {
                        val sourceDocuments = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            queryModernSource(source)
                        } else {
                            queryLegacySource(source)
                        }
                        if (sourceDocuments == null) skipped.add(source.sourceId)
                        else documents.addAll(sourceDocuments)
                    } catch (_: Exception) {
                        skipped.add(source.sourceId)
                    }
                }
                val uniqueDocuments = documents.distinctBy { it["contentUri"] }
                successOnMain(
                    result,
                    mapOf(
                        "documents" to uniqueDocuments,
                        "skippedSourceIds" to skipped.distinct(),
                    ),
                )
            } catch (error: Exception) {
                errorOnMain(result, "QUERY_FAILED", "Unable to query MediaStore.", error.message)
            }
        }
    }

    private fun listAudioFolders(result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("PERMISSION_DENIED", "Audio permission has not been granted.", null)
            return
        }
        executor.execute {
            try {
                val folders = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    queryModernFolders()
                } else {
                    queryLegacyFolders()
                }
                successOnMain(result, folders.sortedBy { it["displayPath"] as String })
            } catch (error: Exception) {
                errorOnMain(result, "QUERY_FAILED", "Unable to query MediaStore folders.", error.message)
            }
        }
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return ContextCompat.checkSelfPermission(context, requiredPermission()) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requiredPermission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.Q)
    private fun externalVolumes(): Set<String> = MediaStore.getExternalVolumeNames(context)

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.Q)
    private fun queryModernSource(source: ParsedSource): List<Map<String, Any?>>? {
        if (!externalVolumes().contains(source.volumeName)) return null
        val collection = MediaStore.Audio.Media.getContentUri(source.volumeName)
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.RELATIVE_PATH,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.SIZE,
        )
        val documents = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(
            collection,
            projection,
            "${MediaStore.Audio.Media.RELATIVE_PATH} = ?",
            arrayOf(source.relativePath),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                cursorToDocument(cursor, collection, source.volumeName)?.let(documents::add)
            }
        } ?: throw IllegalStateException("MediaStore returned a null cursor")
        return documents
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.Q)
    private fun queryModernFolders(): List<Map<String, Any?>> {
        val folders = linkedMapOf<String, Map<String, Any?>>()
        externalVolumes().forEach { volume ->
            val collection = MediaStore.Audio.Media.getContentUri(volume)
            val projection = arrayOf(
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.RELATIVE_PATH,
                MediaStore.Audio.Media.MIME_TYPE,
            )
            try {
                context.contentResolver.query(collection, projection, null, null, null)?.use { cursor ->
                    val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                    val pathIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.RELATIVE_PATH)
                    val mimeIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
                    while (cursor.moveToNext()) {
                        val name = cursor.getString(nameIndex) ?: continue
                        val mime = if (cursor.isNull(mimeIndex)) null else cursor.getString(mimeIndex)
                        if (!isSupportedMp3(name, mime)) continue
                        val relativePath = normalizeRelativePath(cursor.getString(pathIndex) ?: continue)
                        val sourceId = buildSourceId(volume, relativePath)
                        folders[sourceId] = folderMap(volume, relativePath, sourceId)
                    }
                }
            } catch (_: Exception) {
                // One unavailable volume must not hide folders from other volumes.
            }
        }
        return folders.values.toList()
    }

    @Suppress("DEPRECATION")
    private fun queryLegacySource(source: ParsedSource): List<Map<String, Any?>>? {
        if (source.volumeName != MediaStore.VOLUME_EXTERNAL_PRIMARY) return null
        val root = Environment.getExternalStorageDirectory().canonicalFile
        val expectedParent = File(root, source.relativePath).canonicalFile
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.SIZE,
        )
        val documents = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(collection, projection, null, null, null)?.use { cursor ->
            val dataIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            while (cursor.moveToNext()) {
                val data = cursor.getString(dataIndex) ?: continue
                if (File(data).canonicalFile.parentFile != expectedParent) continue
                cursorToDocument(cursor, collection, source.volumeName, source.relativePath)
                    ?.let(documents::add)
            }
        } ?: throw IllegalStateException("MediaStore returned a null cursor")
        return documents
    }

    @Suppress("DEPRECATION")
    private fun queryLegacyFolders(): List<Map<String, Any?>> {
        val root = Environment.getExternalStorageDirectory().canonicalFile
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.MIME_TYPE,
        )
        val folders = linkedMapOf<String, Map<String, Any?>>()
        context.contentResolver.query(collection, projection, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val dataIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val mimeIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameIndex) ?: continue
                val mime = if (cursor.isNull(mimeIndex)) null else cursor.getString(mimeIndex)
                if (!isSupportedMp3(name, mime)) continue
                val parent = File(cursor.getString(dataIndex) ?: continue).canonicalFile.parentFile ?: continue
                val relative = relativePathUnderRoot(root, parent) ?: continue
                val sourceId = buildSourceId(MediaStore.VOLUME_EXTERNAL_PRIMARY, relative)
                folders[sourceId] = folderMap(MediaStore.VOLUME_EXTERNAL_PRIMARY, relative, sourceId)
            }
        } ?: throw IllegalStateException("MediaStore returned a null cursor")
        return folders.values.toList()
    }

    private fun cursorToDocument(
        cursor: Cursor,
        collection: Uri,
        volumeName: String,
        legacyRelativePath: String? = null,
    ): Map<String, Any?>? {
        val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
        val name = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME))
            ?: return null
        val mimeIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
        val mime = if (cursor.isNull(mimeIndex)) null else cursor.getString(mimeIndex)
        if (!isSupportedMp3(name, mime)) return null
        val sizeIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
        val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val index = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.RELATIVE_PATH)
            if (cursor.isNull(index)) null else normalizeRelativePath(cursor.getString(index))
        } else {
            legacyRelativePath
        }
        return mapOf(
            "contentUri" to ContentUris.withAppendedId(collection, id).toString(),
            "displayName" to name,
            "relativePath" to relativePath,
            "volumeName" to volumeName,
            "mimeType" to mime,
            "size" to if (cursor.isNull(sizeIndex)) null else cursor.getLong(sizeIndex),
        )
    }

    private fun isSupportedMp3(displayName: String, mimeType: String?): Boolean {
        val mime = mimeType?.lowercase()
        if (mime == "audio/mpeg" || mime == "audio/mp3" || mime == "audio/x-mp3") return true
        val genericMime = mime == null || mime == "application/octet-stream" ||
            mime == "binary/octet-stream" || mime == "audio/*"
        return genericMime && displayName.endsWith(".mp3", ignoreCase = true)
    }

    private fun folderMap(
        volumeName: String,
        relativePath: String,
        sourceId: String,
    ): Map<String, Any?> = mapOf(
        "sourceId" to sourceId,
        "displayPath" to displayPath(volumeName, relativePath),
        "volumeName" to volumeName,
        "relativePath" to relativePath,
    )

    private fun displayPath(volumeName: String, relativePath: String): String {
        val root = if (volumeName == MediaStore.VOLUME_EXTERNAL_PRIMARY) {
            "/storage/emulated/0"
        } else {
            "/storage/$volumeName"
        }
        return "$root/${relativePath.removeSuffix("/")}" 
    }

    private fun parseSource(sourceId: String): ParsedSource {
        val uri = Uri.parse(sourceId)
        require(uri.scheme == "mediastore" && uri.authority?.isNotEmpty() == true) {
            "Invalid MediaStore source identifier."
        }
        require(uri.query == null && uri.fragment == null && sourceId.endsWith("/")) {
            "MediaStore source identifier is not canonical."
        }
        val volume = uri.authority!!
        val segments = uri.pathSegments
        require(segments.isNotEmpty() && segments.none { it.isEmpty() || it == "." || it == ".." || it.contains('/') }) {
            "MediaStore source path is invalid."
        }
        val relativePath = normalizeRelativePath(segments.joinToString("/"))
        val canonical = buildSourceId(volume, relativePath)
        require(sourceId == canonical) { "MediaStore source identifier is not canonical." }
        return ParsedSource(volume, relativePath, canonical)
    }

    private fun normalizeRelativePath(path: String): String {
        val segments = path.trim('/').split('/').filter { it.isNotEmpty() }
        require(segments.isNotEmpty() && segments.none { it == "." || it == ".." }) {
            "MediaStore relative path is invalid."
        }
        return segments.joinToString("/", postfix = "/")
    }

    private fun buildSourceId(volumeName: String, relativePath: String): String {
        val builder = Uri.Builder().scheme("mediastore").authority(volumeName)
        relativePath.removeSuffix("/").split('/').forEach(builder::appendPath)
        return builder.build().toString() + "/"
    }

    private fun relativePathUnderRoot(root: File, folder: File): String? {
        val rootPath = root.path.trimEnd('/') + "/"
        val folderPath = folder.path
        if (!folderPath.startsWith(rootPath)) return null
        return normalizeRelativePath(folderPath.removePrefix(rootPath))
    }

    private fun successOnMain(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun errorOnMain(
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: Any?,
    ) {
        mainHandler.post { result.error(code, message, details) }
    }

    private data class ParsedSource(
        val volumeName: String,
        val relativePath: String,
        val sourceId: String,
    )

    companion object {
        private const val PERMISSION_REQUEST_CODE = 7402
        private const val PREFERENCES = "strayker_media_store"
        private const val PERMISSION_REQUESTED = "audio_permission_requested"
    }
}
