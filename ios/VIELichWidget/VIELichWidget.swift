import WidgetKit
import SwiftUI

// 1. Cấu trúc dữ liệu
struct DayData: Codable {
    let ngayDuong: Int
    let ngayAm: Int
    let thangAm: Int
    let laChuNhat: Bool
    let coSuKien: Bool
    let laHomNay: Bool
    let laTrongThang: Bool
}

struct WidgetData: Codable {
    let ngayDuong: Int
    let thangDuong: Int
    let namDuong: Int
    let thu: String
    let ngayAm: Int
    let thangAm: Int
    let canChiNam: String
    let tenSuKien: String
    let thoiGianSuKien: String
    let dsO: [DayData]?
}

// 2. Provider (Xử lý Timeline 365 ngày)
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // Tìm dữ liệu của đúng ngày hôm nay để hiển thị lên Preview
        let allData = loadAllWidgetData()
        let calendar = Calendar.current
        let now = Date()
        var currentData: WidgetData? = allData.first
        
        for data in allData {
            var components = DateComponents()
            components.year = data.namDuong
            components.month = data.thangDuong
            components.day = data.ngayDuong
            
            if let date = calendar.date(from: components), calendar.isDate(date, inSameDayAs: now) {
                currentData = data
                break
            }
        }
        
        let entry = SimpleEntry(date: now, data: currentData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let allData = loadAllWidgetData()
        let calendar = Calendar.current
        
        if allData.isEmpty {
            let entry = SimpleEntry(date: Date(), data: nil)
            completion(Timeline(entries: [entry], policy: .after(calendar.date(byAdding: .hour, value: 1, to: Date())!)))
            return
        }
        
        var entries: [SimpleEntry] = []
        
        // Tạo một Timeline gồm 365 entry cho 365 ngày
        for data in allData {
            var components = DateComponents()
            components.year = data.namDuong
            components.month = data.thangDuong
            components.day = data.ngayDuong
            components.hour = 0 // Kích hoạt vào lúc 00:00
            components.minute = 0
            
            if let date = calendar.date(from: components) {
                entries.append(SimpleEntry(date: date, data: data))
            }
        }
        
        // Sắp xếp lại theo thời gian tăng dần
        entries.sort { $0.date < $1.date }
        
        // Lên lịch: Khi kết thúc 365 ngày, iOS sẽ gọi lại getTimeline
        let lastDate = entries.last?.date ?? Date()
        let nextUpdate = calendar.date(byAdding: .day, value: 1, to: lastDate) ?? Date().addingTimeInterval(86400)
        
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    func loadAllWidgetData() -> [WidgetData] {
        let userDefaults = UserDefaults(suiteName: "group.com.toanbb.vie_Lich")
        guard let jsonString = userDefaults?.string(forKey: "widget_data"),
              let data = jsonString.data(using: .utf8) else { return [] }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([WidgetData].self, from: data)
        } catch {
            return []
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

// 3. Giao diện Widget
struct VIELichWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let data = entry.data {
            if family == .systemSmall {
                smallView(data: data)
            } else {
                mediumView(data: data)
            }
        } else {
            Text("Đang tải...").padding()
        }
    }
    
    // --- SIZE SMALL (2x2) ---
    func smallView(data: WidgetData) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text("ÂM LỊCH")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
            
            Spacer(minLength: 0)
            
            Text("\(data.ngayAm)")
                .font(.system(size: 95, weight: .bold))
                .foregroundColor(.red)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            
            Text("tháng \(data.thangAm), năm \(data.canChiNam)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer(minLength: 0)
            
            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, -10)
            
            Text(data.tenSuKien)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 12)
        .modifier(WidgetBackgroundModifier())
    }
    
    // --- SIZE MEDIUM (4x2) ---
    func mediumView(data: WidgetData) -> some View {
        let dayString = String(format: "%02d", data.ngayDuong)
        let monthString = String(format: "%02d", data.thangDuong)
        let solarDateFull = "Dương: \(dayString)/\(monthString)/\(data.namDuong)"
        
        return HStack(spacing: 8) {
            // CỘT TRÁI: VẠN NIÊN
            VStack(alignment: .center, spacing: 0) {
                Spacer(minLength: 0)
                
                Text("ÂM LỊCH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.bottom, 2)
                
                Text("\(data.ngayAm)")
                    .font(.system(size: 62, weight: .bold))
                    .foregroundColor(.red)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                Text("tháng \(data.thangAm), năm \(data.canChiNam)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)
                
                Text(solarDateFull)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)
                
                Spacer(minLength: 0)
                
                Divider() 
                
                // Khối sự kiện
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.tenSuKien)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    if !data.thoiGianSuKien.isEmpty {
                        Text(data.thoiGianSuKien)
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .frame(width: 115) 
            
            Divider()
            
            // CỘT PHẢI: LỊCH THÁNG
            if let dsO = data.dsO {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(["T2", "T3", "T4", "T5", "T6", "T7", "CN"], id: \.self) { thu in
                            Text(thu)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(thu == "CN" ? .red : .gray)
                                .frame(maxWidth: .infinity)
                        }
                    }.padding(.bottom, 2)
                    
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(0..<dsO.count, id: \.self) { index in
                            let day = dsO[index]
                            let opacity = day.laTrongThang ? 1.0 : 0.3
                            
                            VStack(spacing: 0) {
                                Text("\(day.ngayDuong)")
                                    .font(.system(size: 11, weight: day.laHomNay ? .bold : .regular))
                                    .foregroundColor(day.laHomNay ? .red : (day.laChuNhat ? .red : .black))
                                Text("\(day.ngayAm)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(opacity)
                            .background(day.laHomNay ? Color.red.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .modifier(WidgetBackgroundModifier())
    }
}

// Modifier nền cho Widget
struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                Color(UIColor.systemBackground)
            }
        } else {
            content.background(Color(UIColor.systemBackground))
        }
    }
}

// 4. Cấu hình (ĐÂY LÀ PHẦN BỊ THIẾU KHIẾN BẠN GẶP LỖI)
struct VIELichWidget: Widget {
    let kind: String = "VIELichWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VIELichWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("VIE Lịch")
        .description("Lịch âm dương và sự kiện sắp tới.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}