import SwiftUI

#if canImport(AppKit)
import AppKit

public extension View {
    func hidesVisibleWindowTitle() -> some View {
        background(WindowTitleVisibilityAccessor())
    }
}

private struct WindowTitleVisibilityAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        scheduleTitleHide(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleTitleHide(for: nsView)
    }

    private func scheduleTitleHide(for view: NSView) {
        for delay in [0.0, 0.1, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                hideTitle(for: view)
            }
        }
    }

    private func hideTitle(for view: NSView) {
        guard let window = view.window else { return }
        window.title = ""
        window.titleVisibility = .hidden
    }
}
#else
public extension View {
    func hidesVisibleWindowTitle() -> some View {
        self
    }
}
#endif
