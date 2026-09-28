import Cocoa
import FlutterMacOS
import WidgetKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // --- LẮNG NGHE DỮ LIỆU TỪ FLUTTER VÀ CẬP NHẬT WIDGET ---
    let widgetChannel = FlutterMethodChannel(
        name: "vie_lich_mac_widget",
        binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    widgetChannel.setMethodCallHandler { (call, result) in
        if call.method == "updateWidget" {
            if let args = call.arguments as? [String: Any],
               let jsonStr = args["data"] as? String,
               let groupId = args["groupId"] as? String {

                // Ghi JSON vào file trong App Group container
                if let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: groupId
                ) {
                    let fileURL = containerURL.appendingPathComponent("widget_data.json")
                    do {
                        try jsonStr.write(to: fileURL, atomically: true, encoding: .utf8)
                        print("🍏 [SWIFT MAC] Đã ghi JSON (\(jsonStr.count) ký tự) vào App Group")
                    } catch {
                        print("❌ [SWIFT MAC] Lỗi ghi file: \(error)")
                    }
                } else {
                    print("❌ [SWIFT MAC] Không tìm thấy thư mục Group: \(groupId)")
                }

                if #available(macOS 11.0, *) {
                    WidgetCenter.shared.reloadAllTimelines()
                    print("🔄 [SWIFT MAC] Đã ra lệnh reload Widget!")
                }
                result("Success")
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Thiếu tham số", details: nil))
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    // ================= KẾT THÚC =================

    super.awakeFromNib()
  }
}
