import ICalMacCore
import SwiftUI

extension View {
    func eventDetailInteraction(
        event: CalendarEvent,
        selectedEvent: Binding<CalendarEvent?>,
        showDetails: @escaping () -> Void
    ) -> some View {
        modifier(
            EventDetailInteractionModifier(
                event: event,
                selectedEvent: selectedEvent,
                showDetails: showDetails
            )
        )
    }
}

struct EventDetailInteractionModifier: ViewModifier {
    let event: CalendarEvent
    @Binding var selectedEvent: CalendarEvent?
    let showDetails: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded(showDetails)
            )
            .contextMenu {
                Button(action: showDetails) {
                    Label("Show Details", systemImage: "info.circle")
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                showDetails()
            }
            .accessibilityAction(named: Text("Show Details"), showDetails)
            .popover(item: $selectedEvent, arrowEdge: .trailing) { event in
                CalendarEventDetailView(event: event)
            }
    }
}
