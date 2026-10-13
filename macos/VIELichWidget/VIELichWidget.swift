import WidgetKit
import SwiftUI

// ============================================================
// MODEL
// ============================================================
struct WidgetO: Codable {
    let ngayDuong: Int
    let ngayAm: Int
    let thangAm: Int
    let laChuNhat: Bool
    let laHomNay: Bool
    let coSuKien: Bool
    let laDauThangAm: Bool
    let laTrongThang: Bool
}

struct WidgetData: Codable {
    let thangDuong: Int
    let namDuong: Int
    let ngayDuong: Int
    let thu: String
    let ngayAm: Int
    let thangAm: Int
    let namAm: Int
    let canChiNam: String
    let dsO: [WidgetO]
    let tenSuKien: String
    let thoiGianSuKien: String
    let loaiSuKien: String
}

// ============================================================
// ENTRY
// ============================================================
struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

// ============================================================
// PROVIDER — ĐỌC 7 NGÀY, SINH 7 ENTRY
// ============================================================
struct Provider: TimelineProvider {
    private static let groupId = "group.com.toanbb.vie_Lich"
    private static let fileName = "widget_multi_day.json"

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let data = Self.loadMultiDayData()?.first
        completion(SimpleEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        guard let multiDay = Self.loadMultiDayData(), !multiDay.isEmpty,
              Self.isDataFresh() else {
            // Data cũ hoặc không có → 1 entry placeholder, thử lại sau 30 phút
            let entry = SimpleEntry(date: Date(), data: nil)
            completion(Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(30 * 60))
            ))
            return
        }

        var entries: [SimpleEntry] = []
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        for (index, data) in multiDay.enumerated() {
            let entryDate = calendar.date(
                byAdding: .day, value: index, to: startOfToday
            )!
            entries.append(SimpleEntry(date: entryDate, data: data))
        }

        // Khi hết multi-day → OS hỏi lại. Nếu data đã cũ → placeholder
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    // ------------------------------------------------------------
    // Đọc file multi-day từ App Group
    // ------------------------------------------------------------
    private static func loadMultiDayData() -> [WidgetData]? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupId
        ) else { return nil }

        let fileURL = containerURL.appendingPathComponent(fileName)
        guard let rawData = try? Data(contentsOf: fileURL) else { return nil }

        // Thử decode array trước (format mới)
        if let array = try? JSONDecoder().decode([WidgetData].self, from: rawData) {
            return array
        }

        // Fallback: format cũ (single object)
        if let single = try? JSONDecoder().decode(WidgetData.self, from: rawData) {
            return [single]
        }

        return nil
    }

    // ------------------------------------------------------------
    // Check data có "tươi" không (< 7 ngày)
    // ------------------------------------------------------------
    private static func isDataFresh() -> Bool {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupId
        ) else { return false }

        let fileURL = containerURL.appendingPathComponent(fileName)
        guard let attrs = try? FileManager.default.attributesOfItem(
            atPath: fileURL.path
        ), let modDate = attrs[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modDate) < 7 * 24 * 3600
    }
}

// ============================================================
// HELPER
// ============================================================
func tieuDeThang(_ thang: Int, _ nam: Int) -> String {
    return String(format: "Tháng %02d/%d", thang, nam)
}

// ============================================================
// VIEW CHÍNH
// ============================================================
struct VIELichWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        if let data = entry.data {
            switch family {
            case .systemSmall:
                SmallWidgetView(data: data)
            case .systemMedium:
                MediumWidgetView(data: data)
            case .systemExtraLarge:
                ExtraLargeWidgetView(data: data)
            default:
                LargeWidgetView(data: data)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title)
                    .foregroundColor(.secondary)
                Text("Mở app để cập nhật")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// ============================================================
// SMALL (170×170)
// ============================================================
struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("THÁNG \(data.thangDuong)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("\(data.ngayDuong)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(data.thu)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("\(data.ngayAm)/\(data.thangAm) \(data.canChiNam)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxHeight: .infinity)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geo.size.width * 0.4, height: 1)
                    .padding(.vertical, 6)

                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))

                    Text(data.tenSuKien)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !data.thoiGianSuKien.isEmpty {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text(data.thoiGianSuKien)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetURL(URL(string: "vielich://open")!)
    }
}

// ============================================================
// MEDIUM (360×170)
// ============================================================
struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                MediumCotTrai(data: data)
                    .frame(width: 90)
                    .padding(.leading, 10)
                    .padding(.trailing, 8)

                Rectangle()
                    .fill(Color.gray.opacity(0.18))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 8)

                CotPhaiCompact(data: data)
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal, 10)

            NextEventMotDong(data: data, fontSize: 10, iconSize: 11)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .widgetURL(URL(string: "vielich://open")!)
    }
}

struct MediumCotTrai: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("\(data.ngayDuong)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(data.thu)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(data.ngayAm)/\(data.thangAm) \(data.canChiNam)")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// ============================================================
// LARGE (344×344)
// ============================================================
struct LargeWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 0) {
            CotPhai(data: data)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxHeight: .infinity)

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal, 12)

            NextEventMotDong(data: data, fontSize: 12, iconSize: 14)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .widgetURL(URL(string: "vielich://open")!)
    }
}

// ============================================================
// EXTRA LARGE (688×344)
// ============================================================
struct ExtraLargeWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                CotTrai(data: data)
                    .frame(width: 140)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)

                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.gray.opacity(0.18))
                        .frame(width: 1)
                        .frame(height: geo.size.height * 0.75)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(width: 1)

                CotPhai(data: data)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            .padding(.vertical, 10)

            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal, 16)

            NextEventMotDong(data: data, fontSize: 13, iconSize: 15)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .widgetURL(URL(string: "vielich://open")!)
    }
}

// ============================================================
// CỘT TRÁI (EL)
// ============================================================
struct CotTrai: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("\(data.ngayDuong)")
                .font(.system(size: 88, weight: .bold))
                .foregroundColor(.red)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(data.thu)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("\(data.ngayAm)/\(data.thangAm) \(data.canChiNam)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// ============================================================
// CỘT PHẢI (Large + EL)
// ============================================================
struct CotPhai: View {
    let data: WidgetData

    private let thuTuan = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    var body: some View {
        VStack(spacing: 6) {
            Text(tieuDeThang(data.thangDuong, data.namDuong))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)

            HStack(spacing: 0) {
                ForEach(thuTuan, id: \.self) { thu in
                    Text(thu)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(thu == "CN" ? .red : .secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 0) {
                ForEach(0..<(data.dsO.count / 7), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < data.dsO.count {
                                ONgay(o: data.dsO[idx], fontDuong: 14, fontAm: 9)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// ============================================================
// CỘT PHẢI COMPACT (Medium)
// ============================================================
struct CotPhaiCompact: View {
    let data: WidgetData

    private let thuTuan = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    var body: some View {
        VStack(spacing: 3) {
            Text(tieuDeThang(data.thangDuong, data.namDuong))
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)

            HStack(spacing: 0) {
                ForEach(thuTuan, id: \.self) { thu in
                    Text(thu)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(thu == "CN" ? .red : .secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 0) {
                ForEach(0..<(data.dsO.count / 7), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < data.dsO.count {
                                ONgay(o: data.dsO[idx], fontDuong: 9, fontAm: 6)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// ============================================================
// Ô NGÀY
// ============================================================
struct ONgay: View {
    let o: WidgetO
    let fontDuong: CGFloat
    let fontAm: CGFloat

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Text("\(o.ngayDuong)")
                        .font(.system(size: fontDuong,
                                      weight: o.laHomNay ? .bold : .medium))
                        .foregroundColor(duongColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }

            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Text(amText)
                        .font(.system(size: fontAm,
                                      weight: o.laDauThangAm ? .semibold : .regular))
                        .foregroundColor(amColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(o.laHomNay ? Color.red.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(alignment: .bottomLeading) {
            if o.coSuKien {
                Circle()
                    .fill(Color.red)
                    .frame(width: 3, height: 3)
                    .padding(.leading, 3)
                    .padding(.bottom, 2)
            }
        }
        .opacity(o.laTrongThang ? 1.0 : 0.35)
    }

    private var amText: String {
        if o.laDauThangAm {
            return "\(o.ngayAm)/\(o.thangAm)"
        }
        return "\(o.ngayAm)"
    }

    private var amColor: Color {
        if o.laDauThangAm {
            return .red.opacity(o.laTrongThang ? 0.9 : 0.4)
        }
        return .secondary.opacity(o.laTrongThang ? 0.8 : 0.3)
    }

    private var duongColor: Color {
        if o.laHomNay { return .red }
        if !o.laTrongThang { return .secondary }
        if o.laChuNhat { return .red.opacity(0.8) }
        return .primary
    }
}

// ============================================================
// NEXT EVENT
// ============================================================
struct NextEventMotDong: View {
    let data: WidgetData
    let fontSize: CGFloat
    let iconSize: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundColor(.orange)
                .font(.system(size: iconSize))

            Text(data.tenSuKien)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            if !data.thoiGianSuKien.isEmpty {
                Text("•")
                    .font(.system(size: fontSize - 2))
                    .foregroundColor(.secondary)

                Text(data.thoiGianSuKien)
                    .font(.system(size: fontSize - 1))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var iconName: String {
        switch data.loaiSuKien {
        case "cake": return "birthday.cake"
        case "alarm": return "alarm"
        default: return "calendar.badge.clock"
        }
    }
}

// ============================================================
// WIDGET
// ============================================================
struct VIELichWidget: Widget {
    let kind: String = "VIELichWidget_V3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VIELichWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("VIE Lịch - Âm Dương Lịch Widget")
        .description("Lịch âm dương và nhắc lịch sắp tới.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}