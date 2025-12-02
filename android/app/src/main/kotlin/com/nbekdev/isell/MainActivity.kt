package com.nbekdev.isell

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register all plugins including YandexMap
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Register MyID plugin
        flutterEngine.plugins.add(MyIdPlugin())
    }
}
