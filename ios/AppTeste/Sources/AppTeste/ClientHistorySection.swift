import SwiftUI

struct ClientHistoryOSItem: Identifiable, Sendable {
    let id: String
    let numero: Int
    let status: String
    let data: String
    let deviceText: String
    let total: Double
}

struct ClientHistoryQuoteItem: Identifiable, Sendable {
    let id: String
    let numero: Int
    let status: String
    let data: String
    let total: Double
}

struct ClientHistorySection: View {
    @ObservedObject var auth: AuthStore
    let clientID: String

    @State private var loading = false
    @State private var orders: [ClientHistoryOSItem] = []
    @State private var quotes: [ClientHistoryQuoteItem] = []
    @State private var selectedOrderID: String?
    @State private var selectedQuoteID: String?

    var body: some View {
        Group {
            Section("Ordens de serviço do cliente") {
                if loading {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Spacer()
                    }
                } else if orders.isEmpty {
                    Text("Nenhuma ordem de serviço vinculada a este cliente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orders) { os in
                        Button {
                            selectedOrderID = os.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("OS #\(String(format: "%04d", os.numero))")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.primary)
                                        Text("· \(os.data)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    if !os.deviceText.isEmpty {
                                        Text(os.deviceText)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(os.status)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(os.status == "Concluído" || os.status == "Entregue" ? Color.green : Color.blue)
                                    Text(os.total.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR"))))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Orçamentos do cliente") {
                if quotes.isEmpty && !loading {
                    Text("Nenhum orçamento em aberto para este cliente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(quotes) { q in
                        Button {
                            selectedQuoteID = q.id
                        } label: {
                            HStack {
                                Text("Orçamento #\(String(format: "%04d", q.numero))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(q.status)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(q.total.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR"))))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await fetchHistory()
        }
        .sheet(item: Binding<IdentifiableString?>(
            get: { selectedOrderID.map { IdentifiableString(value: $0) } },
            set: { selectedOrderID = $0?.value }
        )) { item in
            OrderEditor(auth: auth, orderID: item.value) {
                Task { await fetchHistory() }
            }
        }
        .sheet(item: Binding<IdentifiableString?>(
            get: { selectedQuoteID.map { IdentifiableString(value: $0) } },
            set: { selectedQuoteID = $0?.value }
        )) { item in
            QuoteEditor(auth: auth, quoteID: item.value) {
                Task { await fetchHistory() }
            }
        }
    }

    private func fetchHistory() async {
        guard !clientID.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/os?limit=100")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let list = envelope["items"]?.array ?? []
            orders = list.compactMap { item -> ClientHistoryOSItem? in
                let obj = item.object
                guard obj["clienteId"]?.text == clientID else { return nil }
                let id = obj["id"]?.text ?? ""
                let num = Int(obj["numero"]?.number ?? 0)
                let st = obj["status"]?.text ?? ""
                let dt = String((obj["dataEntrada"]?.text ?? "").prefix(10))
                let dev = obj["aparelho"]?.object ?? [:]
                let devText = [dev["tipo"]?.text, dev["marca"]?.text, dev["modelo"]?.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                let tot = obj["total"]?.number ?? ((obj["maoDeObra"]?.number ?? 0) + (obj["valorPecas"]?.number ?? 0))
                return ClientHistoryOSItem(id: id, numero: num, status: st, data: dt, deviceText: devText, total: tot)
            }

            let qData = try await auth.orderRequest("api/orcamentos?limit=100", permission: "orcamentos")
            let qEnvelope = try JSONDecoder().decode(OrderJSON.self, from: qData).object
            let qList = qEnvelope["items"]?.array ?? []
            quotes = qList.compactMap { item -> ClientHistoryQuoteItem? in
                let obj = item.object
                guard obj["clienteId"]?.text == clientID else { return nil }
                let id = obj["id"]?.text ?? ""
                let num = Int(obj["numero"]?.number ?? 0)
                let st = obj["status"]?.text ?? ""
                let dt = String((obj["data"]?.text ?? "").prefix(10))
                let tot = obj["total"]?.number ?? 0
                return ClientHistoryQuoteItem(id: id, numero: num, status: st, data: dt, total: tot)
            }
        } catch { }
    }
}

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

