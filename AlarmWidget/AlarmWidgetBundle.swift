//
//  AlarmWidgetBundle.swift
//  AlarmWidget
//
//  Created by 성현 on 2/2/26.
//

import WidgetKit
import SwiftUI

@main
struct AlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmWidget()
        AlarmWidgetLiveActivity()
    }
}
