package com.workersafety.worker_safety_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.workersafety.worker_safety_app/sms"
    private val SMS_PERMISSION_REQ_CODE = 991

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendDistressSms" -> {
                    val phone = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")

                    if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Phone number and message cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED

                    if (hasPermission) {
                        try {
                            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }

                            val parts = smsManager.divideMessage(message)
                            if (parts.size > 1) {
                                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            } else {
                                smsManager.sendTextMessage(phone, null, message, null, null)
                            }

                            result.success(
                                mapOf(
                                    "success" to true,
                                    "mode" to "DIRECT_SMS",
                                    "recipient" to phone
                                )
                            )
                        } catch (e: Exception) {
                            // Fallback to launching standard SMS intent if hardware radio fails
                            val fallbackSuccess = openSmsApp(phone, message)
                            result.success(
                                mapOf(
                                    "success" to fallbackSuccess,
                                    "mode" to "INTENT_FALLBACK",
                                    "error" to (e.localizedMessage ?: "Unknown hardware radio error")
                                )
                            )
                        }
                    } else {
                        // Request permission and launch SMS app intent so emergency message is never blocked
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.SEND_SMS),
                            SMS_PERMISSION_REQ_CODE
                        )
                        val fallbackSuccess = openSmsApp(phone, message)
                        result.success(
                            mapOf(
                                "success" to fallbackSuccess,
                                "mode" to "INTENT_LAUNCHED",
                                "note" to "SEND_SMS permission requested"
                            )
                        )
                    }
                }
                "checkSmsPermission" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPermission)
                }
                "requestSmsPermission" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (!hasPermission) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.SEND_SMS),
                            SMS_PERMISSION_REQ_CODE
                        )
                    }
                    result.success(hasPermission)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openSmsApp(phone: String, message: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("smsto:$phone")
                putExtra("sms_body", message)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
