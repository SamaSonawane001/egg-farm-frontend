package com.example.egg_farm

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "egg_farm/invoice_share"
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareInvoiceToWhatsApp") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val filePath = call.argument<String>("filePath")
                    ?: throw IllegalArgumentException("Invoice file path is missing")
                val phone = call.argument<String>("phone")
                    ?: throw IllegalArgumentException("Customer phone number is missing")
                val text = call.argument<String>("text")
                    ?: throw IllegalArgumentException("Invoice summary is missing")
                val file = File(filePath)
                if (!file.isFile) {
                    throw IllegalArgumentException("Invoice PDF file does not exist")
                }

                val uri: Uri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.invoiceprovider",
                    file
                )
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "application/pdf"
                    setPackage("com.whatsapp")
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    putExtra("jid", "$phone@s.whatsapp.net")
                    clipData = ClipData.newUri(contentResolver, "Invoice PDF", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(intent)
                result.success(true)
            } catch (error: Exception) {
                result.error(
                    "WHATSAPP_SHARE_FAILED",
                    error.message ?: "Could not share invoice to WhatsApp",
                    null
                )
            }
        }
    }
}
