import SwiftUI

struct QuoteEditor: View {
    @ObservedObject var auth: AuthStore
    let quoteID: String?
    let onSaved: () -> Void
    @State private var original: [String: OrderJSON]?
    @State private var clientID = ""
    @State private var clientName = ""
    @State private var defect = ""
    @State private var diagnosis = ""
    @State private var labor = "0"
    @State private var status = "Pendente"
    @State private var notes = ""
    @State private var parts: [OrderPart] = []
    @State private var validUntil = Date()
    @State private var chooseClient = false
    @State private var loading = false
    @State private var saving = false
    @State private var ready = false
    @State private var error: String?
    @State private var lastPayload: Data?
    @State private var key = UUID().uuidString
    @State private var generatingOS = false
    private let newID = UUID().uuidString
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack { Form {
            if loading { ProgressView("Carregando orçamento…") }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            if ready {
                Section("Cliente") { Button(clientName.isEmpty ? "Selecionar cliente" : clientName) { chooseClient = true } }
                Section("Aparelho e serviço") {
                    TextField("Defeito relatado *", text: $defect, axis: .vertical)
                    TextField("Diagnóstico", text: $diagnosis, axis: .vertical)
                    DatePicker("Válido até", selection: $validUntil, displayedComponents: .date)
                    Picker("Status", selection: $status) { ForEach(["Pendente","Aprovado","Recusado"], id: \.self) { Text($0) } }
                }
                Section("Itens") {
                    ForEach($parts) { $part in
                        VStack { HStack { TextField("Descrição", text: $part.description); Button(role: .destructive) { parts.removeAll { $0.id == part.id } } label: { Image(systemName: "minus.circle") } }; HStack { TextField("Qtd", text: $part.quantity).keyboardType(.decimalPad); TextField("Valor", text: $part.price).keyboardType(.decimalPad) } }
                    }
                    Button("Adicionar item", systemImage: "plus") { parts.append(OrderPart()) }
                    LabeledContent("Mão de obra") { TextField("0,00", text: $labor).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section("Observações") { TextField("Observações", text: $notes, axis: .vertical) }
                if original != nil {
                    Section {
                        Button {
                            generatingOS = true
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
            }
        }.disabled(loading || saving).navigationTitle(quoteID == nil ? "Novo orçamento" : "Editar orçamento").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button { Task { if await save() { onSaved(); dismiss() } } } label: { saving ? AnyView(ProgressView()) : AnyView(Text("Salvar").bold()) }.disabled(!ready || saving) }
        }
        .sheet(isPresented: $chooseClient) {
            ClientPickerSheet(auth: auth) { client in
                clientID = client.id
                clientName = client.nome
            }
        }
        .sheet(isPresented: $generatingOS) {
            if let original {
                OrderEditor(auth: auth, orderID: nil, prefillQuote: original) {
                    onSaved()
                    dismiss()
                }
            }
        }
        .task { await load() } }
    }
    private func decimal(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
    private func load() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        guard let quoteID else { ready = true; return }
        do { let data = try await auth.orderRequest("api/orcamentos/" + quoteID, permission: "orcamentos"); let quote = try JSONDecoder().decode(OrderJSON.self, from: data).object["orcamento"]!.object
            original = quote; clientID = quote["clienteId"]?.text ?? ""; clientName = quote["cliSnap"]?.object["nome"]?.text ?? ""; defect = quote["aparelho"]?.object["defeito"]?.text ?? ""; diagnosis = quote["diagnostico"]?.text ?? ""; labor = String(quote["maoDeObra"]?.number ?? 0); status = quote["status"]?.text ?? "Pendente"; notes = quote["observacoes"]?.text ?? ""; parts = (quote["pecas"]?.array ?? []).map { v in let p = v.object; return OrderPart(raw: p, description: p["descricao"]?.text ?? "", quantity: String(p["qtd"]?.number ?? 1), price: String(p["valor"]?.number ?? 0), productID: p["produtoId"]?.text) }; ready = true
        } catch { self.error = error.localizedDescription }
    }
    private func save() async -> Bool {
        guard !saving, !clientID.isEmpty, !defect.trimmingCharacters(in: .whitespaces).isEmpty, let labor = decimal(labor), labor >= 0 else { error = "Selecione o cliente, informe o defeito e confira a mão de obra."; return false }
        for part in parts { guard !part.description.isEmpty, let q = decimal(part.quantity), q > 0, let price = decimal(part.price), price >= 0 else { error = "Confira os itens do orçamento."; return false } }
        saving = true; defer { saving = false }; do { var quote = original ?? ["id": .string(newID)]; quote["clienteId"] = .string(clientID); quote["cliSnap"] = .object(["id": .string(clientID), "nome": .string(clientName)]); quote["aparelho"] = .object(["defeito": .string(defect)]); quote["diagnostico"] = .string(diagnosis); quote["maoDeObra"] = .number(labor); quote["pecas"] = .array(parts.map(\.json)); quote["status"] = .string(status); quote["observacoes"] = .string(notes); quote["validade"] = .string(DashboardData.dateKey(validUntil)); quote["data"] = quote["data"] ?? .string(ISO8601DateFormatter().string(from: Date())); let id = quote["id"]!.text; let change: OrderJSON = .object(["entity": .string("orcamentos"), "id": .string(id), "before": original.map(OrderJSON.object) ?? .null, "after": .object(quote)]); let data = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])])) ; if data != lastPayload { lastPayload = data; key = UUID().uuidString }; _ = try await auth.orderRequest("api/changes", body: data, idempotencyKey: key, permission: "orcamentos"); return true } catch { self.error = error.localizedDescription; return false }
    }
}
