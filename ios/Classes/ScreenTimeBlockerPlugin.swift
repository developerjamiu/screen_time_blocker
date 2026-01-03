import Flutter
import UIKit

public class ScreenTimeBlockerPlugin: NSObject, FlutterPlugin {
    
    private var screenTimeFeature: Any?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ScreenTimeBlockerPlugin()
        
        if #available(iOS 16.0, *) {
            instance.screenTimeFeature = ScreenTimeFeature(messenger: registrar.messenger())
            
            let channel = FlutterMethodChannel(
                name: "com.developerjamiu.screen_time_blocker",
                binaryMessenger: registrar.messenger()
            )
            registrar.addMethodCallDelegate(instance, channel: channel)
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else {
            result(FlutterError(
                code: "UNSUPPORTED_OS",
                message: "Screen Time features require iOS 16.0 or later",
                details: nil
            ))
            return
        }
        
        guard let feature = screenTimeFeature as? ScreenTimeFeature else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "ScreenTimeFeature not initialized",
                details: nil
            ))
            return
        }
        
        feature.handle(call, result: result)
    }
}
