import WidgetKit
import SwiftUI

struct AlarmWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmWidgetEntry {
        AlarmWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AlarmWidgetEntry) -> ()) {
        completion(AlarmWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmWidgetEntry>) -> ()) {
        let entry = AlarmWidgetEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct AlarmWidgetEntry: TimelineEntry {
    let date: Date
}

struct AlarmWidgetEntryView: View {
    var entry: AlarmWidgetProvider.Entry

    var body: some View {
        VStack {
            Image(systemName: "alarm.fill")
                .font(.largeTitle)
                .foregroundColor(.pink)
            Text("puddeuk")
                .font(.caption)
        }
    }
}

struct AlarmWidget: Widget {
    let kind: String = "AlarmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                AlarmWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                AlarmWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("puddeuk")
        .description("알람 위젯")
        .supportedFamilies([.systemSmall])
    }
}
