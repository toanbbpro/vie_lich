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
// PROVIDER
// ============================================================
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date(), data: loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date(), data: loadData())
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadData() -> WidgetData? {
        let groupId = "group.com.toanbb.vie_Lich"
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupId
        ) else { return nil }

        let fileURL = containerURL.appendingPathComponent("widget_data.json")
        guard let jsonStr = try? String(contentsOf: fileURL, encoding: .utf8),
              let jsonData = jsonStr.data(using: .utf8) else { return nil }

        return try? JSONDecoder().decode(WidgetData.self, from: jsonData)
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
                Text("Đang tải...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// ============================================================
// SMALL (170×170)
// - Giữ "THÁNG 9" trên cùng
// - Số ngày to hơn
// - Gộp "18/8 Bính Ngọ" 1 dòng
// - Đường kẻ ngang 40%
// - Next event dưới
// ============================================================
struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Phần lịch
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

                // Đường kẻ 40% chiều ngang
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geo.size.width * 0.4, height: 1)
                    .padding(.vertical, 6)

                // Next event 1 dòng
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
// - Sửa tiêu đề tháng
// - Bỏ "THÁNG 9" cột trái
// - Số ngày to hơn
// - Gộp "18/8 Bính Ngọ"
// - Next event 1 dòng
// ============================================================
struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                // Cột trái compact
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
// - Chỉ sửa tiêu đề tháng
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
// - Bỏ "THÁNG 9" cột trái
// - Số ngày to hơn
// - Gộp "18/8 Bính Ngọ"
// - Next event 1 dòng
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
// CỘT TRÁI (EL) — BỎ tiêu đề tháng, số ngày to
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
// CỘT PHẢI (Large + EL) — âm trên trái, dương dưới phải
// ============================================================
struct CotPhai: View {
    let data: WidgetData

    private let thuTuan = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    var body: some View {
        VStack(spacing: 6) {
            // Tiêu đề "Tháng 09/2026" + padding bottom
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
// Ô NGÀY — âm trên trái, dương dưới phải (theo yêu cầu)
// ============================================================
struct ONgay: View {
    let o: WidgetO
    let fontDuong: CGFloat
    let fontAm: CGFloat

    var body: some View {
        ZStack {
            // Dương - góc TRÊN TRÁI
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

            // Âm - góc DƯỚI PHẢI
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
            // Dot sự kiện ở góc dưới trái
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
// NEXT EVENT — 1 DÒNG DUY NHẤT
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