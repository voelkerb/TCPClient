import Foundation
import Observation

/// The list of configured clients, persisted in UserDefaults.
@MainActor
@Observable
final class ClientStore {
    private static let defaultsKey = "Clients"

    private(set) var sessions: [ClientSession] = []
    var selection: ClientSession.ID?

    init() {
        let saved = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [[String: Any]] ?? []
        sessions = saved.compactMap(ClientSession.init(dictionary:))
        if sessions.isEmpty {
            sessions = [makeDefault()]
        }
        sessions.forEach(attach)
        #if os(macOS)
        selection = sessions.first?.id
        #endif
    }

    var anyActive: Bool {
        sessions.contains { $0.state != .disconnected }
    }

    func addClient() {
        let session = makeDefault()
        attach(session)
        sessions.append(session)
        selection = session.id
        save()
    }

    func remove(_ session: ClientSession) {
        session.disconnect()
        sessions.removeAll { $0 === session }
        if selection == session.id {
            selection = sessions.first?.id
        }
        save()
    }

    func session(withID id: ClientSession.ID?) -> ClientSession? {
        sessions.first { $0.id == id }
    }

    private func attach(_ session: ClientSession) {
        session.persist = { [weak self] in self?.save() }
    }

    private func save() {
        UserDefaults.standard.set(sessions.map(\.dictionary), forKey: Self.defaultsKey)
    }

    private func makeDefault() -> ClientSession {
        var number = 1
        while sessions.contains(where: { $0.name == "Client \(number)" }) { number += 1 }
        return ClientSession(name: "Client \(number)", host: "127.0.0.1", port: 54321)
    }
}
