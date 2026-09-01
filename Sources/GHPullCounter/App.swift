import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct GHPullCounterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = PRCounterModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(model)
        } label: {
            if let counts = model.counts {
                Text("\(counts.opened)·\(counts.drafts)·\(counts.merged)")
                    .monospacedDigit()
            } else if model.error != nil {
                Image(systemName: "exclamationmark.triangle")
            } else {
                Text("…")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
