import WidgetKit
import SwiftUI

@main
struct AlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmWidget()
        AlarmWidgetLiveActivity()
    }
}
