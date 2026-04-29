import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    enum Route: Hashable {
        case detail(UUID)
        case editor(EditorMode)
        case dayList(Date)
        case insight(UUID)
    }

    enum EditorMode: Hashable {
        case new
        case edit(UUID)
    }

    var path: [Route] = []

    func openDetail(_ id: UUID) {
        path.append(.detail(id))
    }

    func openEditor(_ mode: EditorMode = .new) {
        path.append(.editor(mode))
    }

    func openDayList(_ day: Date) {
        path.append(.dayList(day))
    }

    func openInsight(_ id: UUID) {
        path.append(.insight(id))
    }

    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
