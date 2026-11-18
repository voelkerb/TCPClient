import SwiftUI

struct ClientDetailView: View {
    @Bindable var session: ClientSession
    @State private var portText: String
    @State private var message = ""
    @State private var follow = true
    @AppStorage("showRawLog") private var showRaw = false
    @State private var alert: AlertInfo?
    @FocusState private var messageFocused: Bool

    init(session: ClientSession) {
        self.session = session
        _portText = State(initialValue: String(session.port))
    }

    private var statusText: String {
        switch session.state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        }
    }

    private var idle: Bool { session.state == .disconnected }
    private var statusTint: Color {
        switch session.state {
        case .disconnected: Color(white: 0.5).opacity(0.6)
        case .connecting: .orange
        case .connected: .green
        }
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var receiveCard: some View {
        LogCard(title: "Receive", log: session.log, follow: $follow, raw: $showRaw,
                filename: "\(session.name) log")
            .frame(minHeight: 260, maxHeight: .infinity)
            .layoutPriority(-1)
    }

    @ViewBuilder private var content: some View {
        #if os(iOS)
        if sizeClass == .compact {
            TabView {
                Tab("Connection", systemImage: "network") {
                    VStack(spacing: Layout.cardSpacing) {
                        connectionCard
                        Spacer(minLength: 0)
                    }
                    .padding(Layout.phoneMargin)
                }
                Tab("Activity", systemImage: "list.bullet.rectangle") {
                    VStack(spacing: Layout.cardSpacing) {
                        sendCard.fixedSize(horizontal: false, vertical: true)
                        receiveCard
                    }
                    .padding(Layout.phoneMargin)
                }
            }
        } else {
            stacked
        }
        #else
        stacked
        #endif
    }

    private var stacked: some View {
        VStack(spacing: Layout.cardSpacing) {
            connectionCard.fixedSize(horizontal: false, vertical: true)
            sendCard.fixedSize(horizontal: false, vertical: true)
            receiveCard
        }
        .padding(Layout.outerMargin)
    }

    var body: some View {
        content
        .dismissKeyboardOnTap()
        #if os(macOS)
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(session.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert($alert)
    }

    private var connectionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                HStack {
                    CardTitle("Connection")
                    Spacer(minLength: 8)
                    StatusBadge(text: statusText, tint: statusTint)
                }
                .frame(minHeight: 34)
                TextField("Client name", text: $session.name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Layout.itemSpacing) { hostFields; toggleButton }
                    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                        HStack(spacing: Layout.itemSpacing) { hostFields }
                        HStack { Spacer(minLength: 0); toggleButton }
                    }
                }
            }
        }
    }

    @ViewBuilder private var hostFields: some View {
        Text("Host").foregroundStyle(.secondary)
        TextField("127.0.0.1", text: $session.host)
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .frame(minWidth: 120, maxWidth: 220)
            .disabled(!idle)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            #endif
        Text("Port").foregroundStyle(.secondary)
        TextField("54321", text: $portText)
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .multilineTextAlignment(.center)
            .frame(width: 88)
            .disabled(!idle)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onChange(of: portText) { _, text in
                if let value = UInt16(text), value > 0 { session.port = value }
            }
    }

    private var toggleButton: some View {
        Button(action: toggle) {
            Label(idle ? "Connect" : "Disconnect", systemImage: idle ? "bolt.fill" : "bolt.slash.fill")
                .frame(minWidth: 100)
        }
        .buttonStyle(.glassProminent)
        .tint(idle ? Color.accentColor : .red)
        .controlSize(.large)
        .fixedSize()
    }

    private var sendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                CardTitle("Send")
                HStack(spacing: Layout.itemSpacing) {
                    TextField("Message to send", text: $message)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .focused($messageFocused)
                        .onSubmit(send)
                    Button(action: send) {
                        Label("Send", systemImage: "paperplane.fill").frame(minWidth: 60)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .fixedSize()
                    .disabled(message.isEmpty || session.state != .connected)
                }
            }
        }
    }

    private func toggle() {
        if session.state != .disconnected {
            session.disconnect()
            return
        }
        let host = session.host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else {
            alert = AlertInfo(title: "Invalid Host", text: "Enter a host name or IP address.")
            return
        }
        guard let value = UInt16(portText), value > 0 else {
            alert = AlertInfo(title: "Invalid Port", text: "Enter a port number between 1 and 65535.")
            return
        }
        session.host = host
        session.port = value
        session.connect()
    }

    private func send() {
        guard !message.isEmpty, session.state == .connected else { return }
        session.send(message)
        message = ""
        messageFocused = true
    }
}
