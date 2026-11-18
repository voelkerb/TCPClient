import SwiftUI

struct ContentView: View {
    @Environment(ClientStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pendingRemoval: ClientSession?

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            List(selection: $store.selection) {
                ForEach(store.sessions) { session in
                    ClientRow(session: session)
                        .tag(session.id)
                        .contextMenu {
                            Button("Remove Client", systemImage: "trash", role: .destructive) {
                                pendingRemoval = session
                            }
                        }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                pendingRemoval = session
                            }
                        }
                }
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem {
                    Button("Add Client", systemImage: "plus") { store.addClient() }
                }
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
            #endif
        } detail: {
            if let session = store.session(withID: store.selection) {
                ClientDetailView(session: session)
                    .id(session.id)
            } else {
                ContentUnavailableView("No Client Selected", systemImage: "network",
                                       description: Text("Add one with the + button."))
            }
        }
        .alert("Remove Client?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        ), presenting: pendingRemoval) { session in
            Button("Remove", role: .destructive) { store.remove(session) }
            Button("Cancel", role: .cancel) {}
        } message: { session in
            Text("“\(session.name)” will be disconnected and removed.")
        }
        .onAppear {
            if store.selection == nil, sizeClass == .regular {
                store.selection = store.sessions.first?.id
            }
        }
        #if os(macOS)
        .frame(minHeight: 480)
        #endif
    }
}

private struct ClientRow: View {
    let session: ClientSession

    private var color: Color {
        switch session.state {
        case .disconnected: return .secondary.opacity(0.5)
        case .connecting: return .orange
        case .connected: return .green
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name.isEmpty ? "Untitled" : session.name)
                    .lineLimit(1)
                Text("\(session.host):\(String(session.port))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
