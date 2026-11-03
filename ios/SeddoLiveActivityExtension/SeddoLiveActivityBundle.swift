import WidgetKit
import SwiftUI

#if canImport(ActivityKit)
@main
struct SeddoLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 16.1, *) {
            SeddoLiveActivityWidget()
        }
    }
}
#endif
