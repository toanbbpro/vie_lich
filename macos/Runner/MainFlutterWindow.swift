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
            guard let args = call.arguments as? [String: Any],
                  let groupId = args["groupId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Thiếu groupId",
                                    details: nil))
                return
            }

            // Nhận data: String (single) hoặc [String] (multi-day)
            var multiDayArray: [String] = []
            var singleStr: String? = nil

            if let dataArray = args["data"] as? [String] {
                // Multi-day (format mới)
                multiDayArray = dataArray
            } else if let dataStr = args["data"] as? String {
                // Single-day (backward compat)
                singleStr = dataStr
                multiDayArray = [dataStr]
            } else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "data phải là String hoặc [String]",
                                    details: nil))
                return
            }

            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: groupId
            ) else {
                print("❌ [SWIFT MAC] Không tìm thấy thư mục Group: \(groupId)")
                result(FlutterError(code: "NO_GROUP",
                                    message: "Không tìm thấy App Group",
                                    details: nil))
                return
            }

            // === 1. Ghi file multi-day (array JSON) ===
            let multiDayURL = containerURL.appendingPathComponent("widget_multi_day.json")
            let combinedJson = "[" + multiDayArray.joined(separator: ",") + "]"
            do {
                try combinedJson.write(to: multiDayURL, atomically: true, encoding: .utf8)
                print("🍏 [SWIFT MAC] Đã ghi \(multiDayArray.count) ngày (\(combinedJson.count) ký tự)")
            } catch {
                print("❌ [SWIFT MAC] Lỗi ghi multi-day: \(error)")
                result(FlutterError(code: "WRITE_FAIL",
                                    message: "Lỗi ghi file: \(error)",
                                    details: nil))
                return
            }

            // === 2. Ghi file single (backward compat cho widget cũ) ===
            if let single = singleStr ?? multiDayArray.first {
                let singleURL = containerURL.appendingPathComponent("widget_data.json")
                try? single.write(to: singleURL, atomically: true, encoding: .utf8)
            }

            // === 3. Reload widget ===
            if #available(macOS 11.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 [SWIFT MAC] Đã ra lệnh reload Widget!")
            }
            result("Success")
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    // ================= KẾT THÚC =================

    super.awakeFromNib()
  }
}