package com.nbekdev.isell

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import android.provider.Settings
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
import java.io.File
import java.io.ByteArrayOutputStream

class MyIdPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, MyIdResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var result: Result? = null
    // Activity result launcher not needed for plugin implementation
    private val myIdClient = MyIdClient()
    // Store call parameters for retry after permission is granted
    private var pendingCall: MethodCall? = null
    // Track if BackendResponded event was received
    private var backendRespondedReceived = false
    // Store session ID to fetch code from API if needed
    private var currentSessionId: String? = null

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
        activityBinding = binding
        Log.d(TAG, "MyIdPlugin attached to activity: ${activity?.javaClass?.simpleName}")
        
        // Add permission result listener to handle camera permission
        binding.addRequestPermissionsResultListener { requestCode, permissions, grantResults ->
            if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
                handlePermissionResult(requestCode, permissions, grantResults)
                true // We handled this request
            } else {
                false // We didn't handle this request
            }
        }
        
        // Add activity result listener to handle MyID SDK result
        binding.addActivityResultListener { requestCode, resultCode, data ->
            Log.d(TAG, "🔵 onActivityResult called: requestCode=$requestCode, resultCode=$resultCode")
            if (requestCode == 1001) {
                Log.d(TAG, "  - MyID SDK activity result received")
                Log.d(TAG, "  - resultCode: $resultCode (RESULT_OK=${Activity.RESULT_OK})")
                Log.d(TAG, "  - data: $data")
                
                // Log all Intent extras to see what data is available
                if (data != null && data.extras != null) {
                    Log.d(TAG, "  - Intent extras:")
                    for (key in data.extras!!.keySet()) {
                        Log.d(TAG, "    - $key: ${data.extras!!.get(key)}")
                    }
                }
                
                // IMPORTANT: According to MyID SDK documentation, we MUST call handleActivityResult
                // to trigger the MyIdResultListener callbacks (onSuccess, onError, onUserExited)
                // The method signature is: handleActivityResult(resultCode, listener)
                Log.d(TAG, "  - Calling myIdClient.handleActivityResult(resultCode=$resultCode, listener=this)")
                try {
                    myIdClient.handleActivityResult(resultCode, this)
                    Log.d(TAG, "  - ✅ handleActivityResult called successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "  - ❌ Error calling handleActivityResult", e)
                    Log.e(TAG, "  - Exception details: ${e.javaClass.simpleName}: ${e.message}")
                    e.printStackTrace()
                }
                
                // Fallback: If callbacks don't fire within 2 seconds, use fallback mechanism
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    // Check if result still hasn't been handled (SDK callbacks didn't fire)
                    if (result != null) {
                        Log.w(TAG, "  - ⚠️ SDK callbacks didn't fire after 2 seconds, using fallback")
                        Log.w(TAG, "  - resultCode=$resultCode (100 = MyID success code)")
                        
                        // Try to extract code from Intent using various possible keys
                        var code: String? = null
                        if (data != null && data.extras != null) {
                            // Try common MyID SDK result keys
                            val extras = data.extras!!
                            code = extras.getString("code")
                                ?: extras.getString("myid_code")
                                ?: extras.getString("result_code")
                                ?: extras.getString("session_code")
                            
                            // Log all extras for debugging
                            Log.d(TAG, "  - Searching for code in Intent extras...")
                            for (key in extras.keySet()) {
                                val value = extras.get(key)
                                if (value is String && value.length > 10) {
                                    Log.d(TAG, "    - $key: ${value.substring(0, 20)}...")
                                } else {
                                    Log.d(TAG, "    - $key: $value")
                                }
                            }
                        }
                        
                        if (code != null && code.isNotEmpty()) {
                            Log.d(TAG, "  - ✅ Found code in Intent: $code")
                            val resultMap = mutableMapOf<String, Any?>()
                            resultMap["success"] = true
                            resultMap["code"] = code
                            resultMap["image"] = null
                            resultMap["comparisonValue"] = null
                            result?.success(resultMap)
                            result = null
                        } else {
                            // No code found in Intent
                            // If BackendResponded was received and resultCode=100, try to get code from API
                            if (resultCode == 100 && backendRespondedReceived && currentSessionId != null) {
                                Log.w(TAG, "  - resultCode=100, BackendResponded received, but no code in Intent")
                                Log.w(TAG, "  - Attempting to fetch code from API using sessionId: ${currentSessionId}")
                                
                                // Try to get code from MyID API using sessionId
                                // This is a fallback - normally SDK should provide code via callback
                                fetchCodeFromApi(currentSessionId!!)
                            } else if (resultCode == 100) {
                                // resultCode 100 usually means success, but no code = might be user exit
                                Log.w(TAG, "  - resultCode=100 but no code found and BackendResponded not received")
                                val resultMap = mapOf(
                                    "success" to false,
                                    "code" to "USER_EXITED",
                                    "message" to "User exited the SDK"
                                )
                                result?.success(resultMap)
                                result = null
                            } else {
                                // Other resultCode - might be error
                                Log.w(TAG, "  - resultCode=$resultCode, no code found, treating as error")
                                val resultMap = mapOf(
                                    "success" to false,
                                    "code" to "UNKNOWN_ERROR",
                                    "message" to "No result code found in Intent"
                                )
                                result?.success(resultMap)
                                result = null
                            }
                        }
                    } else {
                        Log.d(TAG, "  - ✅ Result already handled by SDK callbacks")
                    }
                }, 2000) // Wait 2 seconds for SDK callbacks to fire
                
                // Return false to let SDK also process it
                false
            } else {
                false // We didn't handle this request
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "MyIdPlugin detached from activity for config changes")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        Log.d(TAG, "MyIdPlugin reattached to activity for config changes")
        
        // Re-add permission result listener
        binding.addRequestPermissionsResultListener { requestCode, permissions, grantResults ->
            if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
                handlePermissionResult(requestCode, permissions, grantResults)
                true // We handled this request
            } else {
                false // We didn't handle this request
            }
        }
        
        // Re-add activity result listener
        binding.addActivityResultListener { requestCode, resultCode, data ->
            Log.d(TAG, "🔵 onActivityResult called: requestCode=$requestCode, resultCode=$resultCode")
            if (requestCode == 1001) {
                Log.d(TAG, "  - MyID SDK activity result received")
                Log.d(TAG, "  - resultCode: $resultCode (RESULT_OK=${Activity.RESULT_OK})")
                Log.d(TAG, "  - data: $data")
                
                // Log all Intent extras
                if (data != null && data.extras != null) {
                    Log.d(TAG, "  - Intent extras:")
                    for (key in data.extras!!.keySet()) {
                        Log.d(TAG, "    - $key: ${data.extras!!.get(key)}")
                    }
                }
                
                // IMPORTANT: Call handleActivityResult to trigger SDK callbacks
                // The method signature is: handleActivityResult(resultCode, listener)
                Log.d(TAG, "  - Calling myIdClient.handleActivityResult(resultCode=$resultCode, listener=this)")
                try {
                    myIdClient.handleActivityResult(resultCode, this)
                    Log.d(TAG, "  - ✅ handleActivityResult called successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "  - ❌ Error calling handleActivityResult", e)
                    Log.e(TAG, "  - Exception details: ${e.javaClass.simpleName}: ${e.message}")
                    e.printStackTrace()
                }
                
                // Fallback: If callbacks don't fire within 2 seconds, use fallback mechanism
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    if (result != null) {
                        Log.w(TAG, "  - ⚠️ SDK callbacks didn't fire after 2 seconds, using fallback")
                        Log.w(TAG, "  - resultCode=$resultCode")
                        
                        var code: String? = null
                        if (data != null && data.extras != null) {
                            val extras = data.extras!!
                            code = extras.getString("code")
                                ?: extras.getString("myid_code")
                                ?: extras.getString("result_code")
                                ?: extras.getString("session_code")
                            
                            Log.d(TAG, "  - Searching for code in Intent extras...")
                            for (key in extras.keySet()) {
                                val value = extras.get(key)
                                if (value is String && value.length > 10) {
                                    Log.d(TAG, "    - $key: ${value.substring(0, 20)}...")
                                } else {
                                    Log.d(TAG, "    - $key: $value")
                                }
                            }
                        }
                        
                        if (code != null && code.isNotEmpty()) {
                            Log.d(TAG, "  - ✅ Found code: $code")
                            val resultMap = mutableMapOf<String, Any?>()
                            resultMap["success"] = true
                            resultMap["code"] = code
                            resultMap["image"] = null
                            resultMap["comparisonValue"] = null
                            result?.success(resultMap)
                            result = null
                        } else {
                            if (resultCode == 100) {
                                Log.w(TAG, "  - resultCode=100 but no code, treating as user exit")
                                val resultMap = mapOf(
                                    "success" to false,
                                    "code" to "USER_EXITED",
                                    "message" to "User exited the SDK"
                                )
                                result?.success(resultMap)
                                result = null
                            } else {
                                Log.w(TAG, "  - resultCode=$resultCode, no code, treating as error")
                                val resultMap = mapOf(
                                    "success" to false,
                                    "code" to "UNKNOWN_ERROR",
                                    "message" to "No result code found in Intent"
                                )
                                result?.success(resultMap)
                                result = null
                            }
                        }
                    } else {
                        Log.d(TAG, "  - ✅ Result already handled by SDK callbacks")
                    }
                }, 2000)
                
                false
            } else {
                false
            }
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
        activityBinding = null
        pendingCall = null
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
            // Store the call for retry after permission is granted
            pendingCall = call
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(android.Manifest.permission.CAMERA),
                CAMERA_PERMISSION_REQUEST_CODE
            )
            // Don't return error immediately - wait for permission result
            // The result will be handled in handlePermissionResult
            return
        }

        // Start MyID SDK (internal method that assumes permission is granted)
        startMyIdInternal(call)
    }

    private fun startMyIdInternal(call: MethodCall) {
        val activity = this.activity
        if (activity == null) {
            Log.e(TAG, "Activity is null")
            result?.error("NO_ACTIVITY", "Activity is not available", null)
            result = null
            return
        }
        
        // Check if activity is finishing or destroyed
        if (activity.isFinishing || activity.isDestroyed) {
            Log.e(TAG, "Activity is finishing or destroyed")
            result?.error("ACTIVITY_INVALID", "Activity is finishing or destroyed", null)
            result = null
            return
        }

        // ⚠️ IMPORTANT: According to MyID SDK documentation, root and emulator checks
        // must be implemented in the parent app (not in SDK itself)
        // Note: Emulator check disabled due to false positives on real devices
        // Check for root access
        if (isDeviceRooted()) {
            Log.e(TAG, "❌ Device is rooted - MyID SDK cannot run on rooted devices")
            result?.error(
                "ROOT_DETECTED",
                "MyID SDK cannot run on rooted devices for security reasons",
                null
            )
            result = null
            return
        }

        // Emulator check disabled - was causing false positives on real devices
        // if (isEmulator()) {
        //     Log.e(TAG, "❌ Device is an emulator - MyID SDK cannot run on emulators")
        //     result?.error(
        //         "EMULATOR_DETECTED",
        //         "MyID SDK cannot run on emulators for security reasons",
        //         null
        //     )
        //     result = null
        //     return
        // }

        try {
            // Extract parameters from Flutter
            val sessionId = call.argument<String>("sessionId")
            currentSessionId = sessionId // Store for fallback
            backendRespondedReceived = false // Reset flag
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
                result = null
                return
            }

            if (clientHash.isNullOrEmpty() || clientHashId.isNullOrEmpty()) {
                result?.error("INVALID_ARGUMENT", "clientHash and clientHashId are required", null)
                result = null
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
            result = null
        }
    }

    // Handle permission result
    private fun handlePermissionResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "Camera permission granted, retrying MyID SDK start...")
                // Permission granted, wait a bit for activity to fully resume, then retry starting MyID SDK
                // This prevents navigation issues when activity resumes
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    pendingCall?.let { call ->
                        // Double-check activity is still available
                        if (activity != null) {
                            startMyIdInternal(call)
                        } else {
                            Log.e(TAG, "Activity is null when trying to start MyID after permission grant")
                            result?.error("NO_ACTIVITY", "Activity is not available", null)
                            result = null
                        }
                    }
                    pendingCall = null
                }, 300) // 300ms delay to ensure activity is fully resumed
            } else {
                Log.d(TAG, "Camera permission denied")
                // Permission denied, return error
                result?.error(
                    "CAMERA_PERMISSION_DENIED",
                    "Camera permission is required for MyID SDK",
                    null
                )
                result = null
                pendingCall = null
            }
        }
    }

    // Activity result handling is done through MyIdResultListener callbacks

    // MyIdResultListener implementations
    override fun onSuccess(myIdResult: MyIdResult) {
        Log.d(TAG, "✅ MyID SDK - onSuccess CALLED")
        Log.d(TAG, "  - code: ${myIdResult.code}")
        Log.d(TAG, "  - result object is null: ${result == null}")
        
        try {
            val resultMap = mutableMapOf<String, Any?>()
            resultMap["success"] = true
            resultMap["code"] = myIdResult.code
            Log.d(TAG, "  - resultMap created with success=true and code=${myIdResult.code}")
            
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
            
            Log.d(TAG, "  - Calling result?.success() with map: $resultMap")
            result?.success(resultMap)
            Log.d(TAG, "  - result?.success() called, setting result to null")
            result = null
            Log.d(TAG, "✅ MyID SDK - onSuccess COMPLETED")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing success result", e)
            Log.e(TAG, "  - Exception type: ${e.javaClass.simpleName}")
            Log.e(TAG, "  - Exception message: ${e.message}")
            Log.e(TAG, "  - Exception stack trace: ${e.stackTraceToString()}")
            result?.error("RESULT_ERROR", "Failed to process result: ${e.message}", null)
            result = null
        }
    }

    override fun onUserExited() {
        Log.d(TAG, "⚠️ MyID SDK - onUserExited CALLED")
        Log.d(TAG, "  - result object is null: ${result == null}")
        val resultMap = mapOf(
            "success" to false,
            "code" to "USER_EXITED",
            "message" to "User exited the SDK"
        )
        Log.d(TAG, "  - Calling result?.success() with map: $resultMap")
        result?.success(resultMap)
        result = null
        Log.d(TAG, "⚠️ MyID SDK - onUserExited COMPLETED")
    }

    override fun onError(exception: MyIdException) {
        Log.e(TAG, "❌ MyID SDK - onError CALLED")
        Log.e(TAG, "  - Error code: ${exception.code}")
        Log.e(TAG, "  - Error message: ${exception.message}")
        Log.e(TAG, "  - result object is null: ${result == null}")
        val resultMap = mapOf(
            "success" to false,
            "code" to exception.code,
            "message" to exception.message
        )
        Log.e(TAG, "  - Calling result?.success() with map: $resultMap")
        result?.success(resultMap)
        result = null
        Log.e(TAG, "❌ MyID SDK - onError COMPLETED")
    }

    override fun onEvent(event: MyIdEvent) {
        Log.d(TAG, "MyID SDK - Event: ${event.name}")
        
        // Track BackendResponded event - this means SDK got response from backend
        if (event.name == "BackendResponded") {
            Log.d(TAG, "  - ✅ BackendResponded event received")
            backendRespondedReceived = true
            
            // If onSuccess doesn't fire within 3 seconds, we'll use fallback
            // The code should be available via API using sessionId
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (result != null && backendRespondedReceived) {
                    Log.w(TAG, "  - ⚠️ BackendResponded but onSuccess didn't fire, will use fallback")
                }
            }, 3000)
        }
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

    // Fallback: Fetch code from MyID API using sessionId
    private fun fetchCodeFromApi(sessionId: String) {
        Log.d(TAG, "  - 🔄 Fetching code from MyID API for sessionId: $sessionId")
        
        // This should be done in a background thread
        Thread {
            try {
                // Use Java's HttpURLConnection or OkHttp to call MyID API
                // GET https://api.devmyid.uz/api/v1/sdk/data?code={code}
                // But we need access token first, then we need to find the code
                // Actually, we can't get code from sessionId directly - we need the code from SDK
                
                // Alternative: Since BackendResponded was received, the SDK should have the code
                // The issue is that onSuccess callback is not being called
                // Let's try to manually trigger onSuccess with a mock result
                
                Log.w(TAG, "  - ⚠️ Cannot fetch code from API without code itself")
                Log.w(TAG, "  - SDK should have called onSuccess callback but didn't")
                Log.w(TAG, "  - This is likely a bug in MyID SDK or deprecated startActivityForResult")
                
                // Since we can't get the actual code, we'll return an error
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    if (result != null) {
                        val resultMap = mapOf(
                            "success" to false,
                            "code" to "SDK_CALLBACK_ERROR",
                            "message" to "SDK callback (onSuccess) was not called. Please try again."
                        )
                        result?.success(resultMap)
                        result = null
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "  - ❌ Error fetching code from API", e)
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    if (result != null) {
                        val resultMap = mapOf(
                            "success" to false,
                            "code" to "API_ERROR",
                            "message" to "Failed to fetch code from API: ${e.message}"
                        )
                        result?.success(resultMap)
                        result = null
                    }
                }
            }
        }.start()
    }

    /**
     * Check if device is rooted
     * According to MyID SDK documentation, root detection must be implemented in parent app
     */
    private fun isDeviceRooted(): Boolean {
        // Check for common root binaries
        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        
        for (path in rootPaths) {
            if (File(path).exists()) {
                Log.w(TAG, "Root detected: $path exists")
                return true
            }
        }
        
        // Check for test-keys in build tags (indicates custom/rooted ROM)
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            Log.w(TAG, "Root detected: test-keys found in build tags")
            return true
        }
        
        // Check for dangerous properties
        try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val inputStream = process.inputStream
            val reader = inputStream.bufferedReader()
            val result = reader.readLine()
            reader.close()
            if (result != null && result.isNotEmpty()) {
                Log.w(TAG, "Root detected: su command found at $result")
                return true
            }
        } catch (e: Exception) {
            // Ignore - this is expected on non-rooted devices
        }
        
        return false
    }

    /**
     * Check if device is running on emulator
     * According to MyID SDK documentation, emulator detection must be implemented in parent app
     * This function uses only reliable emulator indicators to avoid false positives on real devices
     */
    private fun isEmulator(): Boolean {
        // Most reliable check: ro.kernel.qemu system property
        try {
            val process = Runtime.getRuntime().exec(arrayOf("getprop", "ro.kernel.qemu"))
            val inputStream = process.inputStream
            val reader = inputStream.bufferedReader()
            val result = reader.readLine()
            reader.close()
            if (result != null && result == "1") {
                Log.w(TAG, "Emulator detected: ro.kernel.qemu = 1")
                return true
            }
        } catch (e: Exception) {
            // Ignore - this is expected on real devices
        }
        
        // Check for emulator-specific hardware (most reliable indicator)
        val hardware = Build.HARDWARE.lowercase()
        if (hardware.contains("goldfish") || 
            hardware.contains("ranchu") || 
            hardware.contains("vbox86") ||
            hardware.contains("vbox")) {
            Log.w(TAG, "Emulator detected: hardware = $hardware")
            return true
        }
        
        // Check for emulator-specific files
        val emulatorFiles = arrayOf(
            "/system/lib/libc_malloc_debug_qemu.so",
            "/sys/qemu_trace",
            "/system/bin/qemu-props"
        )
        
        for (file in emulatorFiles) {
            if (File(file).exists()) {
                Log.w(TAG, "Emulator detected: $file exists")
                return true
            }
        }
        
        // Check FINGERPRINT for generic/unknown (Android emulator indicator)
        val fingerprint = Build.FINGERPRINT.lowercase()
        if (fingerprint.startsWith("generic") || 
            (fingerprint.startsWith("unknown") && Build.MODEL.contains("sdk"))) {
            Log.w(TAG, "Emulator detected: FINGERPRINT = ${Build.FINGERPRINT}")
            return true
        }
        
        // Check MODEL for explicit emulator names
        val model = Build.MODEL.lowercase()
        if (model.contains("google_sdk") ||
            model.contains("emulator") ||
            model.contains("android sdk built for x86") ||
            model.contains("genymotion")) {
            Log.w(TAG, "Emulator detected: MODEL = ${Build.MODEL}")
            return true
        }
        
        // Check MANUFACTURER for Genymotion
        if (Build.MANUFACTURER.lowercase().contains("genymotion")) {
            Log.w(TAG, "Emulator detected: MANUFACTURER = ${Build.MANUFACTURER}")
            return true
        }
        
        // Check PRODUCT for explicit emulator products (but be careful - real devices may have "sdk" in product name)
        val product = Build.PRODUCT.lowercase()
        if (product == "google_sdk" || 
            product.contains("emulator") ||
            product.contains("simulator")) {
            Log.w(TAG, "Emulator detected: PRODUCT = ${Build.PRODUCT}")
            return true
        }
        
        // Check if BRAND and DEVICE are both generic (Android emulator indicator)
        if (Build.BRAND.lowercase().startsWith("generic") && 
            Build.DEVICE.lowercase().startsWith("generic")) {
            Log.w(TAG, "Emulator detected: BRAND=${Build.BRAND}, DEVICE=${Build.DEVICE}")
            return true
        }
        
        return false
    }
}
