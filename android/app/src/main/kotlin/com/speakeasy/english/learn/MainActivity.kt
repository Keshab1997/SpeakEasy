package com.speakeasy.english.learn

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceChannel = "com.speakeasy.english.learn/device"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FlutterActivity is not always a ComponentActivity on the compile
        // classpath, so avoid enableEdgeToEdge() (CI failed with receiver mismatch).
        // This is the same inset contract Play Console asks for on Android 15+.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER ?: "")
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(requestIgnoreBatteryOptimizations())
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "openBatteryOptimizationSettings" -> {
                        result.success(openBatteryOptimizationSettings())
                    }
                    "openAutoStartSettings" -> {
                        result.success(openAutoStartSettings())
                    }
                    "openAppDetailsSettings" -> {
                        result.success(openAppDetailsSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (pm.isIgnoringBatteryOptimizations(packageName)) {
                    true
                } else {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    true
                }
            } else {
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                pm.isIgnoringBatteryOptimizations(packageName)
            } else {
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openAppDetailsSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Best-effort attempt to open the manufacturer's "auto-start / background
     * launch" permission screen. These component names differ per OEM and per
     * OS version, so this tries the common ones and returns false (caller then
     * falls back to the generic app-details screen) if none resolve.
     */
    private fun openAutoStartSettings(): Boolean {
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        val candidates = mutableListOf<Intent>()

        when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") ||
                manufacturer.contains("poco") -> {
                candidates.add(component("com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"))
            }
            manufacturer.contains("oppo") || manufacturer.contains("realme") ||
                manufacturer.contains("oneplus") -> {
                candidates.add(component("com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"))
                candidates.add(component("com.oplus.safecenter",
                    "com.oplus.safecenter.permission.startup.StartupAppListActivity"))
                candidates.add(component("com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity"))
                candidates.add(component("com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"))
            }
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                candidates.add(component("com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"))
                candidates.add(component("com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"))
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                candidates.add(component("com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"))
                candidates.add(component("com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity"))
            }
        }

        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // try the next candidate
            }
        }
        return false
    }

    private fun component(pkg: String, cls: String): Intent {
        return Intent().setComponent(ComponentName(pkg, cls))
    }
}
