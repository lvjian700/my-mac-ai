import SwiftUI

#if DEBUG
#Preview {
    WeekCalendarView()
        .environmentObject(AppModel.preview())
        .frame(width: 1180, height: 720)
}
#endif

struct WeekCalendarView: View {
    @EnvironmentObject private var model: AppModel

    private let headerBottomPadding: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            WeekHeaderView()
                .padding(.horizontal)
                .padding(.bottom, headerBottomPadding)

            if model.accessStatus == .denied {
                CalendarUnavailableView(
                    title: "Calendar Access Needed",
                    systemImage: "calendar.badge.exclamationmark",
                    detail: model.statusText
                )
            } else {
                WeekGridView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
