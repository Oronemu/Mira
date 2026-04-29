import SwiftUI
import CoreKit
import FeatureEntryEditor

/// Bridges a `UUID`-based route into `EntryEditorView` which needs the
/// full snapshot. Loads via the repository, then renders the editor.
struct EditorRouteView: View {
    @Environment(\.entryRepository) private var repository
    let entryID: UUID

    @State private var snapshot: EntrySnapshot?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let snapshot {
                EntryEditorView(mode: .edit(snapshot))
            } else if loadFailed {
                Text("Couldn't load this entry.")
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                snapshot = try await repository.fetch(id: entryID)
                if snapshot == nil { loadFailed = true }
            } catch {
                loadFailed = true
            }
        }
    }
}
