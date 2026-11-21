package fr.cie6.mufasa

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var verrou: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mufasa/multicast")
            .setMethodCallHandler { appel, resultat ->
                when (appel.method) {
                    "acquerir" -> {
                        if (verrou == null) {
                            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            verrou = wifi.createMulticastLock("mufasa").apply {
                                setReferenceCounted(false)
                                acquire()
                            }
                        }
                        resultat.success(null)
                    }
                    "liberer" -> {
                        verrou?.release()
                        verrou = null
                        resultat.success(null)
                    }
                    else -> resultat.notImplemented()
                }
            }
    }
}
