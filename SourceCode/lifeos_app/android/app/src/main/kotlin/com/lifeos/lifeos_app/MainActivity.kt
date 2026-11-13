package com.lifeos.lifeos_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Telephony
import android.util.Log
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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

        // SMS reading for PBI-040.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lifeos.app/sms")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> {
                        val granted = ContextCompat.checkSelfPermission(
                            this, Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                    "requestPermission" -> {
                        if (ContextCompat.checkSelfPermission(
                                this, Manifest.permission.READ_SMS
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            pendingSmsPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_SMS),
                                SMS_PERMISSION_REQUEST_CODE
                            )
                        }
                    }
                    "readSms" -> {
                        val since = call.argument<Long>("since")
                        val limit = call.argument<Int>("limit") ?: 100
                        val messages = readSmsMessages(since, limit, null)
                        result.success(messages)
                    }
                    "readBankSms" -> {
                        val since = call.argument<Long>("since")
                        val limit = call.argument<Int>("limit") ?: 100
                        val messages = readSmsMessages(since, limit, BANK_SENDERS)
                        result.success(messages)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private var pendingSmsPermissionResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingSmsPermissionResult?.success(granted)
            pendingSmsPermissionResult = null
        }
    }

    /**
     * Read SMS messages from inbox.
     * @param since Only read messages after this timestamp (epoch ms).
     * @param limit Maximum number of messages to read.
     * @param senderFilter Optional list of sender patterns to filter by.
     */
    private fun readSmsMessages(
        since: Long?,
        limit: Int,
        senderFilter: List<String>?
    ): List<Map<String, Any>> {
        if (ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_SMS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return emptyList()
        }

        val messages = mutableListOf<Map<String, Any>>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )

        var selection: String? = null
        var selectionArgs: Array<String>? = null

        if (since != null) {
            selection = "${Telephony.Sms.DATE} > ?"
            selectionArgs = arrayOf(since.toString())
        }

        val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT $limit"

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            if (cursor != null && cursor.moveToFirst()) {
                val addressIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val bodyIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val dateIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)

                do {
                    val sender = cursor.getString(addressIdx) ?: continue
                    val body = cursor.getString(bodyIdx) ?: continue
                    val timestamp = cursor.getLong(dateIdx)

                    // Filter by sender if specified
                    if (senderFilter != null) {
                        val senderUpper = sender.uppercase()
                        val matches = senderFilter.any { pattern ->
                            senderUpper.contains(pattern.uppercase())
                        }
                        if (!matches) continue
                    }

                    messages.add(
                        mapOf(
                            "sender" to sender,
                            "body" to body,
                            "timestamp" to timestamp
                        )
                    )
                } while (cursor.moveToNext() && messages.size < limit)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading SMS: ${e.message}")
        } finally {
            cursor?.close()
        }

        return messages
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
        const val SMS_PERMISSION_REQUEST_CODE = 1040

        // Known bank sender IDs in Pakistan (PBI-040)
        val BANK_SENDERS = listOf(
            "HBL", "HBL-Alert", "HBLKonnect", "HBLPK",
            "UBL", "UBL-Alert", "UBLPK",
            "MCB", "MCB-Alert", "MCBPK",
            "Meezan", "MBL", "MeezanBnk",
            "ABL", "ABL-Alert",
            "AKBL", "Askari",
            "Alfalah", "BAF", "BankAlfalah",
            "FBL", "Faysal",
            "SCB", "StanChart",
            "HMB", "HabibMetro",
            "JazzCash", "Jazz", "JAZZCASH",
            "Easypaisa", "EP", "EASYPAISA",
            "SadaPay", "SADAPAY",
            "NayaPay", "NAYAPAY"
        )
    }
}
