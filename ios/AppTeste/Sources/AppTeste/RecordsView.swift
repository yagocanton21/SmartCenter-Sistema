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
    @Published private(set) var currentPage = 1
    private var revision = 0
    private(set) var requestedPage = 1
    var pageCount: Int { max(1, (total + 9) / 10) }

    func fetch(auth: AuthStore, entity: String, query: String, status: String, target: Int, reset: Bool = false) async {
        if !reset && loading { return }
        revision += 1
        let version = revision
        if reset { items = []; total = 0; currentPage = 1; hasMore = false }
        requestedPage = max(1, target)
        loading = true; error = nil
        defer { if version == revision { loading = false } }
        do {
            let result = try await auth.recordPage(entity: entity, page: requestedPage, query: query, status: status)
            try Task.checkCancellation()
            guard version == revision else { return }
            items = result.items
            total = result.total; hasMore = result.hasMore; currentPage = result.page
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
    @State private var creating = false
    @State private var refreshID = 0
    @State private var recordToDelete: MobileRecord?
    @State private var confirmDeleteSwipe = false
    @State private var swipeError: String?
    private var key: String { page.rawValue + "|" + search + "|" + status + "|\(refreshID)" }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(store.total) registros").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        if store.loading { ProgressView().controlSize(.small) }
                    }
                    if page == .os {
                        Picker("Status", selection: $status) {
                            Text("Todos").tag("Todos")
                            ForEach(DashboardData.statuses, id: \.self) { Text($0).tag($0) }
                        }.font(.system(size: 13))
                    }
                }.id("top").listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                ForEach(store.items) { row in
                    NavigationLink {
                        RecordDetailView(row: row, icon: page.icon, auth: auth, page: page) { refreshID += 1; Task { await auth.loadDashboard() } }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: page.icon).font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.blue).frame(width: 28, height: 28)
                                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                if !row.subtitle.isEmpty {
                                    Text(row.subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            if !row.badge.isEmpty {
                                Text(row.badge).font(.system(size: 10, weight: .medium)).foregroundStyle(.blue)
                                    .lineLimit(2).multilineTextAlignment(.trailing).frame(maxWidth: 95, alignment: .trailing)
                            }
                        }.padding(.vertical, 3)
                    }
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 12))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if page == .clientes || page == .os {
                            Button(role: .destructive) {
                                recordToDelete = row
                                confirmDeleteSwipe = true
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                }
                if let error = store.error {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.footnote)
                        Button("Tentar novamente") { Task { await fetch(store.requestedPage) } }.disabled(store.loading)
                    }.listRowSeparator(.hidden)
                } else if store.items.isEmpty && !store.loading {
                    ContentUnavailableView("Nenhum resultado", systemImage: page.icon, description: Text("Nenhum registro disponível para esta busca."))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 44)
            .navigationTitle(page.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if page == .os || page == .clientes || page == .produtos || page == .orcamentos {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel(page == .os ? "Nova ordem de serviço" : page == .clientes ? "Novo cliente" : page == .produtos ? "Novo produto" : "Novo orçamento")
                    }
                }
            }
            .sheet(isPresented: $creating) {
                if page == .clientes {
                    ClientEditor(auth: auth, clientID: nil) { _ in refreshID += 1; Task { await auth.loadDashboard() } }
                } else if page == .os {
                    OrderEditor(auth: auth, orderID: nil) { refreshID += 1; Task { await auth.loadDashboard() } }
                } else if page == .produtos {
                    ProductEditor(auth: auth, productID: nil) { refreshID += 1 }
                } else {
                    QuoteEditor(auth: auth, quoteID: nil) { refreshID += 1 }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar")
            .safeAreaInset(edge: .bottom, spacing: 0) { pagination }
            .confirmationDialog(page == .os ? "Excluir ordem de serviço?" : "Excluir cliente?", isPresented: $confirmDeleteSwipe, titleVisibility: .visible) {
                if let rec = recordToDelete {
                    Button(page == .os ? "Excluir OS" : "Excluir \(rec.title)", role: .destructive) {
                        Task { await deleteRecordSwipe(rec) }
                    }
                }
            } message: {
                Text(page == .os ? "Esta OS será excluída definitivamente e eventuais peças serão estornadas ao estoque." : "Clientes com ordens de serviço, vendas ou orçamentos não podem ser excluídos.")
            }
            .alert("Não foi possível excluir", isPresented: Binding<Bool>(
                get: { swipeError != nil },
                set: { if !$0 { swipeError = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(swipeError ?? "")
            }
            .onChange(of: store.currentPage) { _, _ in proxy.scrollTo("top", anchor: .top) }
            .refreshable { await fetch(1, reset: true) }
            .task(id: key) {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    try Task.checkCancellation()
                    await fetch(1, reset: true)
                } catch { }
            }
        }
    }

    private var pagination: some View {
        HStack(spacing: 12) {
            Button { Task { await fetch(store.currentPage - 1) } } label: {
                Label("Anterior", systemImage: "chevron.left")
            }.disabled(store.loading || store.currentPage <= 1)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text("\(store.currentPage) / \(store.pageCount)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text("10 por página").font(.system(size: 10)).foregroundStyle(.secondary)
            }.accessibilityLabel("Página \(store.currentPage) de \(store.pageCount)")
            Spacer(minLength: 0)
            Button { Task { await fetch(store.currentPage + 1) } } label: {
                HStack(spacing: 4) { Text("Próxima"); Image(systemName: "chevron.right") }
            }.disabled(store.loading || !store.hasMore)
        }.font(.system(size: 13, weight: .medium)).buttonStyle(.bordered)
            .controlSize(.regular).padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar).overlay(alignment: .top) { Divider() }
    }

    private func fetch(_ target: Int, reset: Bool = false) async {
        await store.fetch(auth: auth, entity: page.rawValue, query: search, status: status, target: target, reset: reset)
    }

    private func deleteRecordSwipe(_ row: MobileRecord) async {
        do {
            let entity = page.rawValue
            let data = try await auth.orderRequest("api/\(entity)/" + row.id, permission: entity)
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let key = entity == "os" ? "os" : "cliente"
            if let obj = envelope[key]?.object {
                let change: OrderJSON = .object([
                    "entity": .string(entity),
                    "id": .string(row.id),
                    "before": .object(obj),
                    "after": .null
                ])
                let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
                _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: entity)
                refreshID += 1
                Task { await auth.loadDashboard() }
            }
        } catch {
            if error.localizedDescription.contains("depende de um") {
                swipeError = "Este registro possui dependências vinculadas e não pode ser excluído diretamente."
            } else {
                swipeError = error.localizedDescription
            }
        }
    }
}

private struct RecordDetailView: View {
    let row: MobileRecord
    let icon: String
    @ObservedObject var auth: AuthStore
    let page: MobilePage
    let onSaved: () -> Void
    @State private var editing = false
    @State private var saved = false
    @State private var showingWhatsApp = false
    @State private var generatingOS = false
    @State private var quoteData: [String: OrderJSON]?
    @State private var pdfShareItem: PDFShareItem?
    @State private var generatingPDF = false
    @State private var generatingLabel = false
    @State private var orderDetails: [String: OrderJSON]?
    @State private var confirmDeleteClient = false
    @State private var deletingClient = false
    @State private var deleteError: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundStyle(.blue)
                    Text(row.title).font(.system(size: 16, weight: .semibold))
                }.padding(.vertical, 4)
                ForEach(Array(row.fields.enumerated()), id: \.offset) { _, field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        Text(field.value.isEmpty ? "Não informado" : field.value).font(.system(size: 14)).textSelection(.enabled)
                    }.padding(.vertical, 2)
                }
            }
            if page == .os {
                Section {
                    Button {
                        showingWhatsApp = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Notificar via WhatsApp", systemImage: "message.fill")
                                .bold()
                                .foregroundStyle(.green)
                            Spacer()
                        }
                    }
                    Button {
                        Task {
                            generatingPDF = true
                            defer { generatingPDF = false }
                            do {
                                let data = try await auth.orderRequest("api/os/" + row.id)
                                let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
                                if let os = envelope["os"]?.object {
                                    let url = try OrderPDFGenerator.generate(order: os)
                                    pdfShareItem = PDFShareItem(url: url)
                                }
                            } catch { }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if generatingPDF {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Imprimir / Salvar PDF", systemImage: "printer.fill")
                                    .bold()
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                        }
                    }
                    .disabled(generatingPDF)

                    Button {
                        Task {
                            generatingLabel = true
                            defer { generatingLabel = false }
                            do {
                                let data = try await auth.orderRequest("api/os/" + row.id)
                                let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
                                if let os = envelope["os"]?.object {
                                    let url = try OrderPDFGenerator.generateLabel(order: os)
                                    pdfShareItem = PDFShareItem(url: url)
                                }
                            } catch { }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if generatingLabel {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Imprimir Etiqueta da Bancada", systemImage: "tag.fill")
                                    .bold()
                                    .foregroundStyle(.indigo)
                            }
                            Spacer()
                        }
                    }
                    .disabled(generatingLabel)
                }

                if let history = orderDetails?["historico"]?.array, !history.isEmpty {
                    Section("Histórico e Linha do Tempo") {
                        OrderTimelineView(history: history)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmDeleteClient = true
                    } label: {
                        HStack {
                            Spacer()
                            if deletingClient {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Excluir ordem de serviço", systemImage: "trash.fill")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(deletingClient)
                }
            } else if page == .clientes {
                let phoneField = row.fields.first(where: { $0.label.contains("WhatsApp") || $0.label.contains("Telefone") })?.value ?? ""
                if !phoneField.isEmpty {
                    Section {
                        Button {
                            WhatsAppHelper.openWhatsApp(phone: phoneField, message: "Olá, \(row.title)!")
                        } label: {
                            HStack {
                                Spacer()
                                Label("Conversar no WhatsApp", systemImage: "message.fill")
                                    .bold()
                                    .foregroundStyle(.green)
                                Spacer()
                            }
                        }
                    }
                }

                ClientHistorySection(auth: auth, clientID: row.id)

                Section {
                    Button(role: .destructive) {
                        confirmDeleteClient = true
                    } label: {
                        HStack {
                            Spacer()
                            if deletingClient {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Excluir cliente", systemImage: "trash.fill")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(deletingClient)
                }
            } else if page == .orcamentos {
                Section {
                    Button {
                        Task {
                            do {
                                let data = try await auth.orderRequest("api/orcamentos/" + row.id, permission: "orcamentos")
                                let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
                                if let quote = envelope["orcamento"]?.object {
                                    quoteData = quote
                                    generatingOS = true
                                }
                            } catch { }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Gerar Ordem de Serviço", systemImage: "wrench.and.screwdriver.fill")
                                .bold()
                                .foregroundStyle(.blue)
                            Spacer()
                        }
                    }
                }
            }
        }.listStyle(.insetGrouped).environment(\.defaultMinListRowHeight, 40)
            .navigationTitle("Detalhes").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if [.os, .clientes, .produtos, .orcamentos].contains(page) { ToolbarItem(placement: .topBarTrailing) { Button("Editar") { editing = true } } }
            }
            .task {
                if page == .os {
                    do {
                        let data = try await auth.orderRequest("api/os/" + row.id)
                        let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
                        if let os = envelope["os"]?.object {
                            orderDetails = os
                        }
                    } catch { }
                }
            }
            .sheet(isPresented: $editing, onDismiss: { if saved { onSaved(); dismiss() } }) {
                if page == .clientes {
                    ClientEditor(auth: auth, clientID: row.id) { _ in saved = true }
                } else if page == .os {
                    OrderEditor(auth: auth, orderID: row.id) { saved = true }
                } else if page == .produtos {
                    ProductEditor(auth: auth, productID: row.id) { saved = true }
                } else {
                    QuoteEditor(auth: auth, quoteID: row.id) { saved = true }
                }
            }
            .sheet(isPresented: $showingWhatsApp) {
                WhatsAppSheet(
                    auth: auth,
                    orderID: row.id,
                    initialPhone: row.fields.first(where: { $0.label.contains("Telefone") })?.value ?? "",
                    initialClientName: row.title,
                    orderTitle: row.title
                )
            }
            .sheet(isPresented: $generatingOS) {
                if let quoteData {
                    OrderEditor(auth: auth, orderID: nil, prefillQuote: quoteData) {
                        onSaved()
                        dismiss()
                    }
                }
            }
            .sheet(item: $pdfShareItem) { item in
                ShareSheetView(activityItems: [item.url])
            }
            .confirmationDialog(page == .os ? "Excluir ordem de serviço?" : "Excluir cliente?", isPresented: $confirmDeleteClient, titleVisibility: .visible) {
                Button(page == .os ? "Excluir OS" : "Excluir definitivamente", role: .destructive) {
                    Task { await deleteClient() }
                }
            } message: {
                Text(page == .os ? "Esta OS será excluída definitivamente e eventuais peças utilizadas serão estornadas ao estoque." : "Clientes com ordens de serviço, vendas ou orçamentos não podem ser excluídos.")
            }
            .alert("Não foi possível excluir", isPresented: Binding<Bool>(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(deleteError ?? "")
            }
    }

    private func deleteClient() async {
        deletingClient = true
        deleteError = nil
        defer { deletingClient = false }
        do {
            let entity = page.rawValue
            let data = try await auth.orderRequest("api/\(entity)/" + row.id, permission: entity)
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let key = entity == "os" ? "os" : "cliente"
            if let clientObj = envelope[key]?.object {
                let change: OrderJSON = .object([
                    "entity": .string(entity),
                    "id": .string(row.id),
                    "before": .object(clientObj),
                    "after": .null
                ])
                let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
                _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: entity)
                onSaved()
                dismiss()
            }
        } catch {
            if error.localizedDescription.contains("depende de um") {
                deleteError = "Este registro possui dependências vinculadas e não pode ser excluído."
            } else {
                deleteError = error.localizedDescription
            }
        }
    }
}
