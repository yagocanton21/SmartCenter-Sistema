import SwiftUI
import Combine

struct MobileRecordField: Decodable { let label: String; let value: String }
struct MobileRecord: Decodable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    let fields: [MobileRecordField]
}
struct MobileRecordPage: Decodable {
    let items: [MobileRecord]
    let page: Int
    let total: Int
    let hasMore: Bool
}

@MainActor
final class RecordsStore: ObservableObject {
    @Published private(set) var items: [MobileRecord] = []
    @Published private(set) var total = 0
    @Published private(set) var loading = false
    @Published private(set) var hasMore = false
    @Published private(set) var error: String?
    private var nextPage = 1
    private var revision = 0

    func reload(auth: AuthStore, entity: String, query: String, status: String) async {
        revision += 1
        items = []; total = 0; nextPage = 1; hasMore = true; loading = false; error = nil
        await load(auth: auth, entity: entity, query: query, status: status)
    }

    func load(auth: AuthStore, entity: String, query: String, status: String) async {
        guard !loading, hasMore else { return }
        let version = revision
        loading = true; error = nil
        defer { if version == revision { loading = false } }
        do {
            let result = try await auth.recordPage(entity: entity, page: nextPage, query: query, status: status)
            try Task.checkCancellation()
            guard version == revision else { return }
            let existing = Set(items.map(\.id))
            items.append(contentsOf: result.items.filter { !existing.contains($0.id) })
            total = result.total; hasMore = result.hasMore; nextPage = result.page + 1
        } catch is CancellationError { }
        catch {
            guard version == revision else { return }
            if let urlError = error as? URLError, urlError.code == .cancelled { return }
            self.error = error.localizedDescription
        }
    }
}

struct RecordsView: View {
    @ObservedObject var auth: AuthStore
    let page: MobilePage
    @StateObject private var store = RecordsStore()
    @State private var search = ""
    @State private var status = "Todos"
    private var key: String { page.rawValue + "|" + search + "|" + status }

    var body: some View {
        List {
            if page == .os {
                Section {
                    Picker("Status", selection: $status) {
                        Text("Todos").tag("Todos")
                        ForEach(DashboardData.statuses, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            Section {
                ForEach(store.items) { row in
                    NavigationLink {
                        List {
                            ForEach(Array(row.fields.enumerated()), id: \.offset) { _, field in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(field.label).font(.caption).foregroundStyle(.secondary)
                                    Text(field.value.isEmpty ? "Não informado" : field.value).textSelection(.enabled)
                                }.padding(.vertical, 4)
                            }
                        }.navigationTitle(row.title).navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: page.icon).foregroundStyle(.blue).frame(width: 38, height: 38)
                                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 7) {
                                Text(row.title).font(.headline)
                                if !row.subtitle.isEmpty { Text(row.subtitle).font(.subheadline).foregroundStyle(.secondary) }
                                if !row.badge.isEmpty {
                                    Text(row.badge).font(.caption.weight(.medium)).foregroundStyle(.blue)
                                        .padding(.horizontal, 8).padding(.vertical, 4).background(.blue.opacity(0.1), in: Capsule())
                                }
                            }
                        }.padding(.vertical, 8)
                    }
                }
            } header: { Text("\(store.items.count) de \(store.total) registro(s)") }
            if let error = store.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    Button("Tentar novamente") { Task { await loadMore() } }.disabled(store.loading)
                }
            } else if store.hasMore {
                HStack {
                    Spacer()
                    ProgressView("Carregando…")
                    Spacer()
                }.task(id: store.items.count) { await loadMore() }
            } else if store.items.isEmpty && !store.loading {
                ContentUnavailableView("Nenhum resultado", systemImage: page.icon, description: Text("Nenhum registro disponível para esta busca."))
            }
        }
        .navigationTitle(page.title).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Buscar em \(page.title.lowercased())")
        .refreshable { await reload() }
        .task(id: key) {
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                await reload()
            } catch { }
        }
    }

    private func reload() async { await store.reload(auth: auth, entity: page.rawValue, query: search, status: status) }
    private func loadMore() async { await store.load(auth: auth, entity: page.rawValue, query: search, status: status) }
}
