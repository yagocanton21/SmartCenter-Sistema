import SwiftUI
import Combine

enum OrderJSON: Codable, Equatable, Sendable {
    case object([String: OrderJSON]), array([OrderJSON]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(Double.self) { self = .number(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode([String: OrderJSON].self) { self = .object(v) }
        else { self = .array(try value.decode([OrderJSON].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .object(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }
    var object: [String: OrderJSON] { if case .object(let v) = self { return v }; return [:] }
    var array: [OrderJSON] { if case .array(let v) = self { return v }; return [] }
    var text: String { if case .string(let v) = self { return v }; return "" }
    var number: Double { if case .number(let v) = self { return v }; return 0 }
    var boolean: Bool { if case .bool(let v) = self { return v }; return false }
}

struct OrderPart: Identifiable {
    let id = UUID()
    var raw: [String: OrderJSON] = [:]
    var description = ""
    var quantity = "1"
    var price = "0"
    var productID: String?
    var json: OrderJSON {
        var result = raw
        result["descricao"] = .string(description.trimmingCharacters(in: .whitespaces))
        result["qtd"] = .number(OrderDraft.decimal(quantity) ?? 0)
        result["valor"] = .number(OrderDraft.decimal(price) ?? 0)
        if let productID { result["produtoId"] = .string(productID) }
        return .object(result)
    }
}

@MainActor
final class OrderDraft: ObservableObject {
    @Published var loading = false
    @Published var saving = false
    @Published var error: String?
    @Published var conflict = false
    @Published var ready = false
    @Published var clientID = ""
    @Published var clientName = ""
    @Published var deviceType = "Celular"
    @Published var brand = ""
    @Published var model = ""
    @Published var serial = ""
    @Published var color = ""
    @Published var accessories = ""
    @Published var condition = ""
    @Published var defect = ""
    @Published var diagnosis = ""
    @Published var service = ""
    @Published var notes = ""
    @Published var status = "Recebido"
    @Published var labor = "0"
    @Published var parts: [OrderPart] = []
    @Published var entry = Date()
    @Published var hasDeadline = false
    @Published var deadline = Date()
    @Published var warranty = "90"
    @Published var payment = ""
    @Published var lockType = "nenhuma"
    @Published var password = ""
    @Published var patternSequence = ""
    @Published var checklist: [String: String] = [:]
    @Published var checklistObs = ""
    private var original: [String: OrderJSON]?
    private var snapshot: [String: OrderJSON] = [:]
    private let newID = UUID().uuidString
    private var lastPayload: Data?
    private var idempotencyKey = UUID().uuidString
    var isNew: Bool { original == nil }
    var clientPhone: String { snapshot["telefone"]?.text ?? "" }
    var total: Double { (Self.decimal(labor) ?? 0) + parts.reduce(0) { $0 + (Self.decimal($1.quantity) ?? 0) * (Self.decimal($1.price) ?? 0) } }
    nonisolated static func decimal(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }
    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(value.prefix(10)))
    }

    func load(auth: AuthStore, id: String?) async {
        guard !loading else { return }
        loading = true; ready = false; error = nil; conflict = false
        defer { loading = false }
        guard let id else { ready = true; return }
        do {
            let data = try await auth.orderRequest("api/os/" + id)
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            guard let value = envelope["os"], !value.object.isEmpty else { throw URLError(.cannotParseResponse) }
            let order = value.object, device = order["aparelho"]?.object ?? [:]
            original = order; snapshot = order["cliSnap"]?.object ?? [:]
            clientID = order["clienteId"]?.text ?? ""; clientName = snapshot["nome"]?.text ?? "Cliente selecionado"
            brand = device["marca"]?.text ?? ""; model = device["modelo"]?.text ?? ""
            deviceType = device["tipo"]?.text ?? "Celular"; serial = device["imei"]?.text ?? ""
            color = device["cor"]?.text ?? ""; accessories = device["acessorios"]?.text ?? ""
            condition = device["estado"]?.text ?? ""; defect = device["defeito"]?.text ?? ""
            diagnosis = order["diagnostico"]?.text ?? ""; service = order["servico"]?.text ?? ""; notes = order["observacoes"]?.text ?? ""
            status = order["status"]?.text ?? "Recebido"; labor = String(order["maoDeObra"]?.number ?? 0)
            warranty = String(Int(order["garantiaDias"]?.number ?? 0)); payment = order["formaPagamento"]?.text ?? ""
            lockType = device["senhaTipo"]?.text ?? (!device["senha"]!.text.isEmpty ? "alfa" : (!device["senhaPadrao"]!.text.isEmpty ? "padrao" : "nenhuma"))
            password = device["senha"]?.text ?? ""
            patternSequence = device["senhaPadrao"]?.text ?? ""
            if let ck = order["checklist"]?.object {
                var map: [String: String] = [:]
                for (k, v) in ck { map[k] = v.text }
                checklist = map
            } else {
                checklist = [:]
            }
            checklistObs = order["checklistObs"]?.text ?? ""
            entry = Self.parseDate(order["dataEntrada"]?.text ?? "") ?? Date()
            hasDeadline = !(order["prazo"]?.text ?? "").isEmpty
            deadline = Self.parseDate(order["prazo"]?.text ?? "") ?? Date()
            parts = (order["pecas"]?.array ?? []).map { value in
                let p = value.object
                return OrderPart(raw: p, description: p["descricao"]?.text ?? "", quantity: String(p["qtd"]?.number ?? 1), price: String(p["valor"]?.number ?? p["preco"]?.number ?? 0), productID: p["produtoId"]?.text)
            }
            ready = true
        } catch { self.error = error.localizedDescription }
    }

    func selectClient(_ client: MobileRecord) {
        clientID = client.id; clientName = client.title
        snapshot = ["id": .string(client.id), "nome": .string(client.title)]
        if let phone = client.fields.first(where: { $0.label == "Telefone" }) { snapshot["telefone"] = .string(phone.value) }
    }

    func save(auth: AuthStore) async -> Bool {
        guard !saving, ready, !conflict else { return false }
        error = nil
        guard !clientID.isEmpty else { error = "Selecione um cliente."; return false }
        guard !brand.trimmingCharacters(in: .whitespaces).isEmpty, !model.trimmingCharacters(in: .whitespaces).isEmpty, !defect.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Informe marca, modelo e defeito relatado."; return false }
        guard let amount = Self.decimal(labor), amount.isFinite, amount >= 0, let days = Int(warranty), days >= 0 else { error = "Confira a mão de obra e os dias de garantia."; return false }
        for part in parts {
            guard !part.description.trimmingCharacters(in: .whitespaces).isEmpty, let qty = Self.decimal(part.quantity), qty.isFinite, qty > 0, let price = Self.decimal(part.price), price.isFinite, price >= 0 else { error = "Confira descrição, quantidade e valor das peças."; return false }
        }
        saving = true
        defer { saving = false }
        do {
            var result = original ?? ["id": .string(newID), "historico": .array([]), "baixaEstoque": .array([]), "estoqueBaixado": .bool(false)]
            var device = result["aparelho"]?.object ?? [:]
            for (key, value) in ["tipo": deviceType, "marca": brand, "modelo": model, "imei": serial, "cor": color, "acessorios": accessories, "estado": condition, "defeito": defect] { device[key] = .string(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            device["senhaTipo"] = .string(lockType)
            device["senha"] = .string(lockType == "alfa" ? password.trimmingCharacters(in: .whitespacesAndNewlines) : "")
            device["senhaPadrao"] = .string(lockType == "padrao" ? patternSequence : "")
            result["aparelho"] = .object(device); result["clienteId"] = .string(clientID); result["cliSnap"] = .object(snapshot)
            for (key, value) in ["status": status, "diagnostico": diagnosis, "servico": service, "observacoes": notes, "formaPagamento": payment] { result[key] = .string(value) }
            if ["Celular", "Tablet"].contains(deviceType) {
                var ckDict: [String: OrderJSON] = [:]
                for (k, v) in checklist { ckDict[k] = .string(v) }
                result["checklist"] = .object(ckDict)
                result["checklistObs"] = .string(checklistObs.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                result["checklist"] = .null
                result["checklistObs"] = .string("")
            }
            let day = DashboardData.dateKey(entry)
            let previousDate = original?["dataEntrada"]?.text ?? ""
            result["dataEntrada"] = .string(previousDate.hasPrefix(day) ? previousDate : day + "T12:00:00")
            result["prazo"] = .string(hasDeadline ? DashboardData.dateKey(deadline) : "")
            result["garantiaDias"] = .number(Double(days)); result["maoDeObra"] = .number(amount); result["pecas"] = .array(parts.map(\.json))
            if let original { result["before"] = .object(original) }
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(OrderJSON.object(result))
            if lastPayload != data { lastPayload = data; idempotencyKey = UUID().uuidString }
            _ = try await auth.orderRequest("api/os", body: data, idempotencyKey: idempotencyKey)
            return true
        } catch {
            conflict = (error as NSError).domain == "Smartcenter" && (error as NSError).code == 409 && (error.localizedDescription.contains("OS alterada") || error.localizedDescription.contains("OS removida"))
            if error is URLError {
                self.error = "Não foi possível confirmar a gravação. Confira a conexão e tente salvar novamente; a mesma tentativa não duplica a OS."
            } else {
                self.error = conflict ? "Esta OS foi alterada em outro lugar. Recarregue os dados antes de salvar." : error.localizedDescription
            }
            return false
        }
    }

    func prefillFromQuote(_ quote: [String: OrderJSON]) {
        clientID = quote["clienteId"]?.text ?? ""
        let snap = quote["cliSnap"]?.object ?? [:]
        snapshot = snap
        clientName = snap["nome"]?.text ?? "Cliente selecionado"
        let dev = quote["aparelho"]?.object ?? [:]
        deviceType = dev["tipo"]?.text ?? "Celular"
        brand = dev["marca"]?.text ?? ""
        model = dev["modelo"]?.text ?? ""
        defect = dev["defeito"]?.text ?? ""
        diagnosis = quote["diagnostico"]?.text ?? ""
        labor = String(quote["maoDeObra"]?.number ?? 0)
        status = "Em reparo"
        parts = (quote["pecas"]?.array ?? []).map { value in
            let p = value.object
            return OrderPart(raw: p, description: p["descricao"]?.text ?? "", quantity: String(p["qtd"]?.number ?? 1), price: String(p["valor"]?.number ?? p["preco"]?.number ?? 0), productID: p["produtoId"]?.text)
        }
        var initial: [String: OrderJSON] = [
            "id": .string(newID),
            "historico": .array([]),
            "baixaEstoque": .array([]),
            "estoqueBaixado": .bool(false)
        ]
        if let qid = quote["id"]?.text, !qid.isEmpty {
            initial["orcamentoId"] = .string(qid)
        }
        original = initial
        ready = true
    }

    func prefillFromClient(_ client: [String: OrderJSON]) {
        clientID = client["id"]?.text ?? ""
        snapshot = client
        clientName = client["nome"]?.text ?? "Cliente selecionado"
        ready = true
    }
}

struct OrderEditor: View {
    @ObservedObject var auth: AuthStore
    let orderID: String?
    var prefillQuote: [String: OrderJSON]? = nil
    var prefillClient: [String: OrderJSON]? = nil
    let onSaved: () -> Void
    @StateObject private var draft = OrderDraft()
    @State private var choosingClient = false
    @State private var choosingProduct = false
    @State private var confirmFinish = false
    @State private var confirmCancel = false
    @State private var showingWhatsApp = false
    @State private var pdfShareItem: PDFShareItem?
    @State private var generatingPDF = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if draft.loading { ProgressView("Carregando OS…") }
                if let error = draft.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        if draft.conflict || !draft.ready {
                            Button("Recarregar dados") { Task { await draft.load(auth: auth, id: orderID) } }
                        }
                    }
                }
                if draft.ready {
                    Section("Cliente") {
                        Button { choosingClient = true } label: {
                            HStack {
                                Label(draft.clientName.isEmpty ? "Selecionar cliente" : draft.clientName, systemImage: "person.crop.circle")
                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }
                        }.disabled(auth.user?.can("clientes") != true)
                    }
                    Section("Aparelho") {
                        input("Marca *", $draft.brand)
                        input("Modelo *", $draft.model)
                        TextField("Defeito relatado *", text: $draft.defect, axis: .vertical).lineLimit(2...5)
                        DisclosureGroup("Mais informações do aparelho") {
                            input("Tipo", $draft.deviceType)
                            input("IMEI / número de série", $draft.serial)
                            input("Cor", $draft.color)
                            input("Acessórios", $draft.accessories)
                            input("Estado de conservação", $draft.condition)
                        }
                    }
                    DeviceLockPickerView(lockType: $draft.lockType, password: $draft.password, patternSequence: $draft.patternSequence)

                    if ["Celular", "Tablet"].contains(draft.deviceType) {
                        ChecklistSectionView(checklist: $draft.checklist, observations: $draft.checklistObs)
                    }
                    Section("Atendimento") {
                        Picker("Status", selection: $draft.status) { ForEach(DashboardData.statuses, id: \.self) { Text($0).tag($0) } }
                        DatePicker("Entrada", selection: $draft.entry, displayedComponents: .date)
                        Toggle("Definir prazo", isOn: $draft.hasDeadline)
                        if draft.hasDeadline { DatePicker("Prazo", selection: $draft.deadline, displayedComponents: .date) }
                        TextField("Diagnóstico técnico", text: $draft.diagnosis, axis: .vertical).lineLimit(2...5)
                        TextField("Serviço realizado", text: $draft.service, axis: .vertical).lineLimit(2...5)
                    }
                    Section {
                        ForEach($draft.parts) { $part in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    TextField("Descrição", text: $part.description)
                                    Button(role: .destructive) { draft.parts.removeAll { $0.id == part.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                                }
                                HStack {
                                    TextField("Quantidade", text: $part.quantity).keyboardType(.decimalPad)
                                    TextField("Valor unitário", text: $part.price).keyboardType(.decimalPad)
                                }.foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                        Button("Selecionar produto do estoque", systemImage: "shippingbox") { choosingProduct = true }
                            .disabled(auth.user?.can("produtos") != true)
                        Button("Adicionar peça avulsa", systemImage: "plus") { draft.parts.append(OrderPart()) }
                    } header: { Text("Peças") } footer: { Text("Peças do estoque são baixadas ao concluir ou entregar a OS, conforme as regras da web.") }
                    Section("Valores e garantia") {
                        HStack { Text("Mão de obra (R$)"); Spacer(); TextField("0,00", text: $draft.labor).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                        LabeledContent("Total", value: draft.total.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))).fontWeight(.semibold)
                        HStack { Text("Garantia (dias)"); Spacer(); TextField("0", text: $draft.warranty).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                        input("Forma de pagamento", $draft.payment)
                        TextField("Observações", text: $draft.notes, axis: .vertical).lineLimit(2...5)
                    }
                }
            }.font(.system(size: 14)).environment(\.defaultMinListRowHeight, 42)
                .disabled(draft.saving)
                .navigationTitle(orderID == nil ? "Nova ordem de serviço" : "Editar OS").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { confirmCancel = true }.disabled(draft.saving) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { if ["Concluído", "Entregue"].contains(draft.status) { confirmFinish = true } else { save() } } label: {
                            if draft.saving { ProgressView() } else { Text("Salvar").bold() }
                        }.disabled(!draft.ready || draft.loading || draft.saving || draft.conflict)
                    }
                    if orderID != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                Task {
                                    generatingPDF = true
                                    defer { generatingPDF = false }
                                    do {
                                        let data = try await auth.orderRequest("api/os/" + orderID!)
                                        let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
                                        if let os = envelope["os"]?.object {
                                            let url = try OrderPDFGenerator.generate(order: os)
                                            pdfShareItem = PDFShareItem(url: url)
                                        }
                                    } catch { }
                                }
                            } label: {
                                Image(systemName: "printer.fill").foregroundStyle(.blue)
                            }.disabled(generatingPDF).accessibilityLabel("Imprimir / Salvar PDF")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showingWhatsApp = true } label: {
                                Image(systemName: "message.fill").foregroundStyle(.green)
                            }.accessibilityLabel("Enviar WhatsApp")
                        }
                    }
                }
                .interactiveDismissDisabled()
                .task {
                    if let prefillQuote, orderID == nil {
                        draft.prefillFromQuote(prefillQuote)
                    } else if let prefillClient, orderID == nil {
                        draft.prefillFromClient(prefillClient)
                    } else {
                        await draft.load(auth: auth, id: orderID)
                    }
                }
                .sheet(isPresented: $choosingClient) {
                    ClientPickerSheet(auth: auth) { client in
                        draft.prefillFromClient(client.raw)
                    }
                }
                .sheet(isPresented: $choosingProduct) {
                    OrderRecordPicker(auth: auth, entity: "produtos", title: "Selecionar produto") { product in
                        let priceText = product.fields.first { $0.label == "Preço" }?.value ?? "0"
                        let digits = priceText.filter { $0.isNumber || $0 == "," || $0 == "." }.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                        draft.parts.append(OrderPart(description: product.title, price: digits, productID: product.id))
                    }
                }
                .sheet(isPresented: $showingWhatsApp) {
                    if let orderID {
                        WhatsAppSheet(auth: auth, orderID: orderID, initialPhone: draft.clientPhone, initialClientName: draft.clientName, orderTitle: "OS")
                    }
                }
                .sheet(item: $pdfShareItem) { item in
                    ShareSheetView(activityItems: [item.url])
                }
                .confirmationDialog("Descartar alterações?", isPresented: $confirmCancel, titleVisibility: .visible) { Button("Descartar", role: .destructive) { dismiss() } }
                .confirmationDialog("Salvar como \(draft.status)?", isPresented: $confirmFinish, titleVisibility: .visible) {
                    Button("Confirmar e salvar") { save() }
                } message: { Text("O estoque e as datas da OS serão atualizados pela API.") }
        }
    }
    private func input(_ title: String, _ value: Binding<String>) -> some View {
        LabeledContent(title) { TextField("Não informado", text: value).multilineTextAlignment(.trailing) }
    }
    private func save() { Task { if await draft.save(auth: auth) { onSaved(); dismiss() } } }
}

private struct OrderRecordPicker: View {
    @ObservedObject var auth: AuthStore
    let entity: String
    let title: String
    let choose: (MobileRecord) -> Void
    @StateObject private var store = RecordsStore()
    @State private var query = ""
    @State private var creatingClient = false
    @State private var savedClient: MobileRecord?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.items) { row in
                    Button { choose(row); dismiss() } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title).foregroundStyle(.primary)
                            Text(row.subtitle).foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                if store.loading { ProgressView() }
                if let error = store.error { Text(error).foregroundStyle(.red); Button("Tentar novamente") { load(store.requestedPage) } }
                if store.items.isEmpty && !store.loading && store.error == nil { Text("Nenhum registro encontrado.").foregroundStyle(.secondary) }
            }.font(.system(size: 14)).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: "Buscar")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                    if entity == "clientes" {
                        ToolbarItem(placement: .confirmationAction) { Button("Novo", systemImage: "plus") { creatingClient = true } }
                    }
                }
                .sheet(isPresented: $creatingClient, onDismiss: {
                    if let savedClient { choose(savedClient); dismiss() }
                }) {
                    ClientEditor(auth: auth, clientID: nil) { savedClient = $0 }
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button("Anterior") { load(store.currentPage - 1) }.disabled(store.loading || store.currentPage <= 1)
                        Spacer(); Text("\(store.currentPage) / \(store.pageCount)").font(.caption); Spacer()
                        Button("Próxima") { load(store.currentPage + 1) }.disabled(store.loading || !store.hasMore)
                    }.padding().background(.bar)
                }
                .task(id: query) {
                    do { try await Task.sleep(for: .milliseconds(300)); try Task.checkCancellation(); await store.fetch(auth: auth, entity: entity, query: query, status: "Todos", target: 1, reset: true) } catch { }
                }
        }
    }
    private func load(_ page: Int) { Task { await store.fetch(auth: auth, entity: entity, query: query, status: "Todos", target: page) } }
}
