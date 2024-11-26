import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private let CHANNEL = "audio.device.control"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let audioChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)

        audioChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            let audioSession = AVAudioSession.sharedInstance()

            switch call.method {
            case "getInputDevices":
                var devices = ["Built-in Microphone"] // Add default mic

                // Fetch available audio input devices
                let availableInputs = audioSession.availableInputs ?? []
                for input in availableInputs {
                    let portName = input.portName
                    if !devices.contains(portName) {
                        devices.append(portName) // Add other input devices (e.g., wired or Bluetooth)
                    }
                }

                result(devices)

            case "setInputDevice":
                guard let args = call.arguments as? [String: Any],
                      let deviceName = args["device"] as? String else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Device name not provided", details: nil))
                    return
                }

                // Set input device
                try? audioSession.setPreferredInput(audioSession.availableInputs?.first { $0.portName == deviceName })

                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Required for Flutter setup
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
