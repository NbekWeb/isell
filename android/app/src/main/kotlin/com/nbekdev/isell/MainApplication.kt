package com.nbekdev.isell

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize Yandex MapKit
        MapKitFactory.setLocale("ru_RU") // Your preferred language
        MapKitFactory.setApiKey("491a85a5-7445-4d5d-a419-84bda4ad6328") // Your API key
    }
}

