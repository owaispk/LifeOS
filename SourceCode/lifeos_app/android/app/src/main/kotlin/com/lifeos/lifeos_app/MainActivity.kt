package com.lifeos.lifeos_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** FlutterFragmentActivity for local_auth (PBI-024). */
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super: the share plugin reads the launch intent on attach.
        dropUnreadableShare(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        dropUnreadableShare(intent)
        super.onNewIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Screenshot blocking inside the Vault (PBI-024 AC5).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lifeos/secure")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * receive_sharing_intent copies shared content:// files with no
     * try/catch, so a file we may not read (the sender didn't grant access)
     * crashes the app. Check each one first: unreadable items are dropped,
     * and a share with nothing readable left just opens the app. A document
     * share never falls back to its caption as text (PBI-034 AC5). Nothing
     * about the share's content is logged.
     */
    private fun dropUnreadableShare(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = streamUri(intent) ?: return
                if (!canRead(uri)) dropShare(intent)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = streamUris(intent) ?: return
                val readable = uris.indices.filter { canRead(uris[it]) }
                if (readable.size == uris.size) return
                if (readable.isEmpty()) {
                    dropShare(intent)
                    return
                }
                Log.w(TAG, "share: dropped ${uris.size - readable.size} unreadable item(s)")
                intent.putParcelableArrayListExtra(
                    Intent.EXTRA_STREAM,
                    ArrayList(readable.map { uris[it] }),
                )
                intent.getStringArrayExtra(Intent.EXTRA_MIME_TYPES)?.let { types ->
                    if (types.size == uris.size) {
                        intent.putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            readable.map { types[it] }.toTypedArray(),
                        )
                    }
                }
            }
        }
    }

    private fun dropShare(intent: Intent) {
        Log.w(TAG, "share: unreadable item, share ignored")
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(Intent.EXTRA_STREAM)
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.type = null
    }

    /** Only content:// is opened by the plugin; other schemes pass through. */
    private fun canRead(uri: Uri): Boolean {
        if (uri.scheme != "content") return true
        return try {
            contentResolver.openInputStream(uri)?.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun streamUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamUris(intent: Intent): ArrayList<Uri>? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }

    private companion object {
        const val TAG = "LifeOS"
    }
}
