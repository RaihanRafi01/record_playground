package com.example.record_playground

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "audio.device.control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            when (call.method) {
                "getInputDevices" -> {
                    val devices = mutableListOf<String>()
                    devices.add("Built-in Microphone") // Add default mic

                    // Check for paired Bluetooth devices
                    val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                    if (bluetoothAdapter != null && ActivityCompat.checkSelfPermission(
                            this,
                            Manifest.permission.BLUETOOTH_CONNECT
                        ) == PackageManager.PERMISSION_GRANTED
                    ) {
                        val pairedDevices: Set<BluetoothDevice> = bluetoothAdapter.bondedDevices
                        for (device in pairedDevices) {
                            devices.add(device.name) // Add Bluetooth devices
                        }
                    }

                    // Check for other input devices (e.g., wired headsets)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
                        for (device in audioDevices) {
                            val name = device.productName?.toString()
                            if (name != null && !devices.contains(name)) {
                                devices.add(name) // Add wired or other input devices
                            }
                        }
                    }

                    result.success(devices)
                }
                "setInputDevice" -> {
                    val deviceName = call.argument<String>("device")
                    if (deviceName == "Built-in Microphone") {
                        audioManager.stopBluetoothSco()
                        audioManager.isBluetoothScoOn = false
                    } else {
                        audioManager.startBluetoothSco()
                        audioManager.isBluetoothScoOn = true
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
