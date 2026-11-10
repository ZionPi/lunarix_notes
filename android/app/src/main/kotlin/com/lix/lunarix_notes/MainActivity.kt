package com.lix.lunarix_notes

import android.content.ClipData
import android.content.Intent
import android.os.Bundle
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.io.File

class MainActivity: FlutterActivity() {
    private var shareChannel: MethodChannel? = null
    private val pendingShares = java.util.ArrayDeque<Map<String, String>>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val stored = getSharedPreferences("incoming_shares", MODE_PRIVATE)
            .getString("pending", "[]") ?: "[]"
        val shares = JSONArray(stored)
        for (i in 0 until shares.length()) {
            val item = shares.getJSONObject(i)
            pendingShares.addLast(mapOf(
                "id" to item.getString("id"),
                "text" to item.getString("text"),
                "subject" to item.getString("subject")
            ))
        }
        receiveShare(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.lix.lunarix_notes/share_image").setMethodCallHandler { call, result ->
            if (call.method != "share") {
                result.notImplemented()
            } else {
                val name = call.arguments as? String
                if (name == null || !Regex("""note-\d+\.png""").matches(name)) {
                    result.error("invalid_file", "Invalid export filename", null)
                } else {
                    try {
                        val file = File(cacheDir, "note_exports/$name")
                        require(file.isFile)
                        val uri = FileProvider.getUriForFile(this, "$packageName.note_exports", file)
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newUri(contentResolver, "笔记", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(share, null))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("share_failed", "Could not share the exported note", null)
                    }
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.lix.lunarix_notes/app_info").setMethodCallHandler { call, result ->
            if (call.method == "getVersion") {
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(packageName, 0)
                @Suppress("DEPRECATION")
                val build = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                    else info.versionCode.toLong()
                result.success(mapOf("name" to info.versionName, "build" to build))
            } else {
                result.notImplemented()
            }
        }
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.lix.lunarix_notes/shared_text"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "peek" -> result.success(pendingShares.peekFirst())
                    "acknowledge" -> {
                        pendingShares.pollFirst()
                        persistShares()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveShare(intent)
    }

    private fun receiveShare(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return
        if (text.isBlank()) return
        pendingShares.addLast(mapOf(
            "id" to UUID.randomUUID().toString(),
            "text" to text,
            "subject" to (intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: "")
        ))
        persistShares()
        // Clear the consumed Intent so activity recreation cannot import it again.
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.removeExtra(Intent.EXTRA_SUBJECT)
        shareChannel?.invokeMethod("available", null)
    }

    private fun persistShares() {
        val items = JSONArray()
        pendingShares.forEach { items.put(JSONObject(it)) }
        getSharedPreferences("incoming_shares", MODE_PRIVATE).edit()
            .putString("pending", items.toString()).commit()
    }
}

class NoteExportProvider : FileProvider()
