import SwiftUI

struct BoardWidgetView: View {
    let widget: BoardWidgetItem

    var body: some View {
        switch widget.kind {
        case .metric:
            MetricWidgetView(widget: widget)
        case .notice:
            NoticeWidgetView(widget: widget)
        case .progress:
            ProgressWidgetView(widget: widget)
        case .countdown:
            CountdownWidgetView(widget: widget)
        }
    }
}
