import Foundation
import Network
import Observation

enum ClientState {
    case disconnected, connecting, connected
}

/// One outgoing TCP connection with its activity log.
@MainActor
@Observable
final class ClientSession: Identifiable {
    private static let connectTimeout: TimeInterval = 10
    private static let partialFlushDelay: Duration = .milliseconds(250)

    let id = UUID()
    var name: String { didSet { persist?() } }
    var host: String { didSet { persist?() } }
    var port: UInt16 { didSet { persist?() } }
    private(set) var state: ClientState = .disconnected
    let log = ActivityLog()

    @ObservationIgnored var persist: (() -> Void)?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var buffer = Data()
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    init(name: String, host: String, port: UInt16) {
        self.name = name
        self.host = host
        self.port = port
    }

    convenience init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let host = dictionary["host"] as? String,
              let port = dictionary["port"] as? Int,
              let value = UInt16(exactly: port) else { return nil }
        self.init(name: name, host: host, port: value)
    }

    var dictionary: [String: Any] {
        ["name": name, "host": host, "port": Int(port)]
    }

    private var peer: String { "\(host):\(port)" }

    // MARK: Lifecycle

    func connect() {
        guard state == .disconnected, let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        self.connection = connection
        buffer = Data()
        state = .connecting
        log.append("Connecting to \(peer)…", .info)

        connection.stateUpdateHandler = { [weak self, weak connection] newState in
            MainActor.assumeIsolated {
                guard let self, let connection, self.connection === connection else { return }
                self.handle(newState)
            }
        }
        connection.start(queue: .main)

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.connectTimeout))
            guard !Task.isCancelled, let self, self.state == .connecting else { return }
            self.fail("Connection failed: timed out")
        }
    }

    func disconnect() {
        guard state != .disconnected else { return }
        let wasConnected = state == .connected
        teardown()
        flushPending()
        log.append(wasConnected ? "Disconnected" : "Connection attempt cancelled", .info)
    }

    private func handle(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            timeoutTask?.cancel()
            state = .connected
            log.append("Connected to \(peer)", .info)
            receive()
        case .waiting(let error):
            fail("Connection failed: \(error.message)")
        case .failed(let error):
            if state == .connected {
                teardown()
                flushPending()
                log.append("Connection lost: \(error.message)", .error)
            } else {
                fail("Connection failed: \(error.message)")
            }
        default:
            break
        }
    }

    private func fail(_ message: String) {
        guard state != .disconnected else { return }
        teardown()
        log.append(message, .error)
    }

    private func teardown() {
        timeoutTask?.cancel()
        flushTask?.cancel()
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        state = .disconnected
    }

    // MARK: Receiving

    private func receive() {
        guard let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self, weak connection] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self, let connection, self.connection === connection else { return }
                if let data, !data.isEmpty { self.consume(data) }
                if isComplete {
                    self.teardown()
                    self.flushPending()
                    self.log.append("Disconnected by server", .info)
                } else if let error {
                    self.teardown()
                    self.flushPending()
                    self.log.append("Connection lost: \(error.message)", .error)
                } else {
                    self.receive()
                }
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            log.append(TextDecoding.line(from: Data(line)), .received, source: peer)
        }

        // Text without a trailing newline is shown after a short pause.
        flushTask?.cancel()
        guard !buffer.isEmpty else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: Self.partialFlushDelay)
            guard !Task.isCancelled else { return }
            self?.flushPending()
        }
    }

    private func flushPending() {
        flushTask?.cancel()
        guard !buffer.isEmpty else { return }
        let text = TextDecoding.line(from: buffer)
        buffer = Data()
        if !text.isEmpty { log.append(text, .received, source: peer) }
    }

    // MARK: Sending

    func send(_ line: String) {
        guard state == .connected, let connection else {
            log.append("Not connected, message not sent", .error)
            return
        }
        connection.send(content: Data((line + "\r\n").utf8), completion: .contentProcessed { _ in })
        log.append(line, .sent, source: "To \(peer)")
    }
}
