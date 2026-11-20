import SwiftUI
import UIKit

/// The system share sheet (AirDrop, Messages, Save to Files, Google Drive, ...) for a file that already exists.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onFinish(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Lets `.sheet(item:)` open the share sheet only once the file exists, and always with the right file.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
