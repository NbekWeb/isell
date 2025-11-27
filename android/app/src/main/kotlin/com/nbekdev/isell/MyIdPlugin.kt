package com.nbekdev.isell

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
// Activity Result API not needed for plugin implementation
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import uz.myid.android.sdk.capture.MyIdClient
import uz.myid.android.sdk.capture.MyIdConfig
import uz.myid.android.sdk.capture.MyIdResult
import uz.myid.android.sdk.capture.MyIdResultListener
import uz.myid.android.sdk.capture.MyIdException
import uz.myid.android.sdk.capture.model.MyIdEnvironment
import uz.myid.android.sdk.capture.model.MyIdEntryType
import uz.myid.android.sdk.capture.model.MyIdLocale
import uz.myid.android.sdk.capture.model.MyIdCameraShape
import uz.myid.android.sdk.capture.model.MyIdResidency
import uz.myid.android.sdk.capture.model.MyIdEvent
import uz.myid.android.sdk.capture.model.MyIdGraphicFieldType
import java.io.ByteArrayOutputStream

class MyIdPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, MyIdResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var result: Result? = null
    // Activity result launcher not needed for plugin implementation
    private val myIdClient = MyIdClient()

    companion object {
        private const val TAG = "MyIdPlugin"
        private const val CHANNEL_NAME = "com.isell.myid"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        Log.d(TAG, "MyIdPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.d(TAG, "MyIdPlugin detached from engine")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        Log.d(TAG, "MyIdPlugin attached to activity: ${activity?.javaClass?.simpleName}")
        
        // Note: registerForActivityResult is not available in plugin context
        // We'll use the deprecated startActivityForResult method instead
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "MyIdPlugin detached from activity for config changes")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        Log.d(TAG, "MyIdPlugin reattached to activity for config changes")
    }

    override fun onDetachedFromActivity() {
        activity = null
        Log.d(TAG, "MyIdPlugin detached from activity")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Method call received: ${call.method}")
        
        when (call.method) {
            "startMyId" -> {
                this.result = result
                startMyId(call)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startMyId(call: MethodCall) {
        val activity = this.activity
        if (activity == null) {
            Log.e(TAG, "Activity is null")
            result?.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        // Check camera permission first
        if (ContextCompat.checkSelfPermission(activity, android.Manifest.permission.CAMERA) 
            != PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "Camera permission not granted, requesting...")
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(android.Manifest.permission.CAMERA),
                CAMERA_PERMISSION_REQUEST_CODE
            )
            result?.error("CAMERA_PERMISSION_DENIED", "Camera permission is required for MyID SDK", null)
            return
        }

        try {
            // Extract parameters from Flutter
            val sessionId = call.argument<String>("sessionId")
            val clientHash = call.argument<String>("clientHash")
            val clientHashId = call.argument<String>("clientHashId")
            val environment = call.argument<String>("environment") ?: "debug"
            val entryType = call.argument<String>("entryType") ?: "identification"
            val minAge = call.argument<Int>("minAge") ?: 16
            val residency = call.argument<String>("residency") ?: "resident"
            val locale = call.argument<String>("locale") ?: "uzbek"
            val cameraShape = call.argument<String>("cameraShape") ?: "circle"
            val showErrorScreen = call.argument<Boolean>("showErrorScreen") ?: true

            Log.d(TAG, "Starting MyID with parameters:")
            Log.d(TAG, "  - sessionId: $sessionId")
            Log.d(TAG, "  - clientHashId: $clientHashId")
            Log.d(TAG, "  - clientHash: ${clientHash?.substring(0, 50)}...")
            Log.d(TAG, "  - environment: $environment")
            Log.d(TAG, "  - entryType: $entryType")
            Log.d(TAG, "  - locale: $locale")

            if (sessionId.isNullOrEmpty()) {
                result?.error("INVALID_ARGUMENT", "sessionId is required", null)
                return
            }

            if (clientHash.isNullOrEmpty() || clientHashId.isNullOrEmpty()) {
                result?.error("INVALID_ARGUMENT", "clientHash and clientHashId are required", null)
                return
            }

            // Build MyID config
            val configBuilder = MyIdConfig.Builder(sessionId)
                .withClientHash(clientHash, clientHashId)
                .withEnvironment(parseEnvironment(environment))
                .withEntryType(parseEntryType(entryType))
                .withMinAge(minAge)
                .withResidency(parseResidency(residency))
                .withLocale(parseLocale(locale))
                .withCameraShape(parseCameraShape(cameraShape))
                .withErrorScreen(showErrorScreen)

            val config = configBuilder.build()

            // Start MyID SDK using deprecated method (only available option in plugin)
            myIdClient.startActivityForResult(activity, 1001, config, this)
            Log.d(TAG, "MyID SDK started using startActivityForResult")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting MyID SDK", e)
            result?.error("SDK_ERROR", "Failed to start MyID SDK: ${e.message}", null)
        }
    }

    // Activity result handling is done through MyIdResultListener callbacks

    // MyIdResultListener implementations
    override fun onSuccess(myIdResult: MyIdResult) {
        Log.d(TAG, "MyID SDK - Success")
        Log.d(TAG, "  - code: ${myIdResult.code}")
        
        try {
            val resultMap = mutableMapOf<String, Any?>()
            resultMap["success"] = true
            resultMap["code"] = myIdResult.code
            
            // Get face portrait image if available
            val bitmap = myIdResult.getGraphicFieldImageByType(MyIdGraphicFieldType.FacePortrait)
            if (bitmap != null) {
                val base64Image = bitmapToBase64(bitmap)
                resultMap["image"] = base64Image
                Log.d(TAG, "  - image: present (${base64Image.length} chars)")
            } else {
                resultMap["image"] = null
                Log.d(TAG, "  - image: null")
            }
            
            // Note: comparisonValue not available in this SDK version
            resultMap["comparisonValue"] = null
            Log.d(TAG, "  - comparisonValue: not available")
            
            result?.success(resultMap)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error processing success result", e)
            result?.error("RESULT_ERROR", "Failed to process result: ${e.message}", null)
        }
    }

    override fun onUserExited() {
        Log.d(TAG, "MyID SDK - User exited")
        val resultMap = mapOf(
            "success" to false,
            "code" to "USER_EXITED",
            "message" to "User exited the SDK"
        )
        result?.success(resultMap)
    }

    override fun onError(exception: MyIdException) {
        Log.e(TAG, "MyID SDK - Error: ${exception.code} - ${exception.message}")
        val resultMap = mapOf(
            "success" to false,
            "code" to exception.code,
            "message" to exception.message
        )
        result?.success(resultMap)
    }

    override fun onEvent(event: MyIdEvent) {
        Log.d(TAG, "MyID SDK - Event: ${event.name}")
        // Events can be handled here if needed
    }

    // Helper methods to parse parameters
    private fun parseEnvironment(environment: String): MyIdEnvironment {
        return when (environment.lowercase()) {
            "production" -> MyIdEnvironment.Production
            "debug" -> MyIdEnvironment.Debug
            else -> MyIdEnvironment.Debug
        }
    }

    private fun parseEntryType(entryType: String): MyIdEntryType {
        return when (entryType.lowercase()) {
            "identification" -> MyIdEntryType.Identification
            "videoidentification" -> MyIdEntryType.VideoIdentification
            "facedetection" -> MyIdEntryType.FaceDetection
            else -> MyIdEntryType.Identification
        }
    }

    private fun parseResidency(residency: String): MyIdResidency {
        return when (residency.lowercase()) {
            "resident" -> MyIdResidency.Resident
            "nonresident" -> MyIdResidency.NonResident
            "userdefined" -> MyIdResidency.UserDefined
            else -> MyIdResidency.Resident
        }
    }

    private fun parseLocale(locale: String): MyIdLocale {
        return when (locale.lowercase()) {
            "uzbek" -> MyIdLocale.Uzbek
            "karakalpak" -> MyIdLocale.Karakalpak
            "tajik" -> MyIdLocale.Tajik
            "english" -> MyIdLocale.English
            "russian" -> MyIdLocale.Russian
            else -> MyIdLocale.Uzbek
        }
    }

    private fun parseCameraShape(cameraShape: String): MyIdCameraShape {
        return when (cameraShape.lowercase()) {
            "circle" -> MyIdCameraShape.Circle
            "ellipse" -> MyIdCameraShape.Ellipse
            else -> MyIdCameraShape.Circle
        }
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
        val byteArray = outputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.DEFAULT)
    }
}
