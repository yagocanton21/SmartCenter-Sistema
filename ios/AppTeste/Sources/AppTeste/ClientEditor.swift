import SwiftUI

struct ClientEditor: View {
    @ObservedObject var auth: AuthStore
    let clientID: String?
    let onSaved: (MobileRecord) -> Void
    @State private var values: [String: String] = [:]
    @State private var original: [String: OrderJSON]?
    @State private var loading = false
    @State private var ready = false
    @State private var saving = false
    @State private var error: String?
    @State private var conflict = false
    @State private var confirmCancel = false
    @State private var newID = UUID().uuidString
    @State private var created = ISO8601DateFormatter().string(from: Date())
    @State private var payload: Data?
    @State private var requestKey = UUID().uuidString
    @Environment(\.dismiss) private var dismiss
    private let keys = ["nome", "telefone", "whatsapp", "doc", "email", "cep", "cidade", "endereco", "obs"]

    var body: some View {
        NavigationStack {
            Form {
                if loading { ProgressView("Carregando cliente…") }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                        if conflict || !ready { Button("Recarregar dados") { Task { await load() } } }
                    }
                }
                if ready {
                    Section {
                        field("Nome / razão social *", key: "nome")
                        field("Telefone", key: "telefone", keyboard: .phonePad)
                        field("WhatsApp", key: "whatsapp", keyboard: .phonePad)
                        field("E-mail", key: "email", keyboard: .emailAddress)
                    } header: { Text("Contato") } footer: { Text("Somente o nome é obrigatório. Sem WhatsApp informado, será usado o telefone.") }
                    Section("Documento e endereço") {
                        field("CPF / CNPJ", key: "doc", keyboard: .numberPad)
                        field("CEP", key: "cep", keyboard: .numberPad)
                        field("Cidade", key: "cidade")
                        TextField("Rua, número e bairro", text: binding("endereco"), axis: .vertical).lineLimit(1...3)
                    }
                    Section("Observações") {
                        TextField("Informações adicionais", text: binding("obs"), axis: .vertical).lineLimit(2...5)
                    }
                }
            }.font(.system(size: 14)).environment(\.defaultMinListRowHeight, 42)
                .disabled(saving)
                .navigationTitle(clientID == nil ? "Novo cliente" : "Editar cliente").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { confirmCancel = true }.disabled(saving) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { Task { await save() } } label: { if saving { ProgressView() } else { Text("Salvar").bold() } }
                            .disabled(!ready || loading || saving || conflict)
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Concluir") { hideKeyboard() }
                    }
                }
                .interactiveDismissDisabled()
                .confirmationDialog("Descartar alterações?", isPresented: $confirmCancel, titleVisibility: .visible) {
                    Button("Descartar", role: .destructive) { dismiss() }
                }
                .task { await load() }
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }
    private func field(_ title: String, key: String, keyboard: UIKeyboardType = .default) -> some View {
        LabeledContent(title) {
            TextField(key == "nome" ? "Obrigatório" : "Opcional", text: binding(key))
                .keyboardType(keyboard).multilineTextAlignment(.trailing)
                .textInputAutocapitalization(key == "email" ? .never : .words)
                .autocorrectionDisabled(key == "email")
        }
    }
    private func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

    @MainActor private func load() async {
        guard !loading else { return }
        loading = true; ready = false; error = nil; conflict = false
        defer { loading = false }
        guard let clientID else { ready = true; return }
        do {
            let data = try await auth.orderRequest("api/clientes/" + clientID, permission: "clientes")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            guard let record = envelope["cliente"], !record.object.isEmpty else { throw URLError(.cannotParseResponse) }
            original = record.object
            for key in keys { values[key] = record.object[key]?.text ?? "" }
            ready = true
        } catch { self.error = error.localizedDescription }
    }

    @MainActor private func save() async {
        guard ready, !saving, !conflict else { return }
        error = nil; hideKeyboard()
        let cleaned = values.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !(cleaned["nome"] ?? "").isEmpty else { error = "Informe o nome do cliente."; return }
        let digits = (cleaned["doc"] ?? "").filter { $0.isASCII && $0.isNumber }
        guard Self.validDocument(digits) else { error = "CPF/CNPJ inválido. Confira os números ou deixe em branco."; return }
        let email = cleaned["email"] ?? ""
        guard email.isEmpty || (email.contains("@") && !email.contains(" ") && email.split(separator: "@").count == 2) else { error = "Confira o endereço de e-mail."; return }
        saving = true
        defer { saving = false }
        do {
            var after = original ?? ["id": .string(newID), "criadoEm": .string(created)]
            for key in keys { after[key] = .string(cleaned[key] ?? "") }
            after["doc"] = .string(digits)
            if (cleaned["whatsapp"] ?? "").isEmpty { after["whatsapp"] = .string(cleaned["telefone"] ?? "") }
            let id = clientID ?? newID
            let change: OrderJSON = .object(["entity": .string("clientes"), "id": .string(id), "before": original.map { .object($0) } ?? .null, "after": .object(after)])
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(OrderJSON.object(["changes": .array([change])]))
            if payload != data { payload = data; requestKey = UUID().uuidString }
            _ = try await auth.orderRequest("api/changes", body: data, idempotencyKey: requestKey, permission: "clientes")
            let fieldKeys = [("Nome", "nome"), ("Telefone", "telefone"), ("E-mail", "email"), ("WhatsApp", "whatsapp"), ("CPF / CNPJ", "doc"), ("CEP", "cep"), ("Cidade", "cidade"), ("Endereço", "endereco"), ("Observações", "obs")]
            let row = MobileRecord(id: id, title: after["nome"]?.text ?? "", subtitle: after["telefone"]?.text ?? "", badge: "", fields: fieldKeys.map { MobileRecordField(label: $0.0, value: after[$0.1]?.text ?? "") })
            onSaved(row); dismiss()
        } catch {
            conflict = (error as NSError).domain == "Smartcenter" && (error as NSError).code == 409 && error.localizedDescription.contains("alterado por outra pessoa")
            if conflict { self.error = "Este cliente foi alterado ou removido na web. Recarregue antes de salvar." }
            else if error is URLError { self.error = "Não foi possível confirmar a gravação. Confira a conexão e tente novamente; a mesma tentativa não duplica o cliente." }
            else { self.error = error.localizedDescription }
        }
    }

    static func validDocument(_ text: String) -> Bool {
        if text.isEmpty { return true }
        let d = text.compactMap { $0.wholeNumberValue }
        guard [11, 14].contains(d.count), Set(d).count > 1 else { return false }
        if d.count == 11 {
            for n in [9, 10] {
                let sum = (0..<n).reduce(0) { $0 + d[$1] * (n + 1 - $1) }
                if ((sum * 10) % 11) % 10 != d[n] { return false }
            }
        } else {
            for n in [12, 13] {
                var weight = n - 7, sum = 0
                for i in 0..<n { sum += d[i] * weight; weight -= 1; if weight < 2 { weight = 9 } }
                let remainder = sum % 11
                if (remainder < 2 ? 0 : 11 - remainder) != d[n] { return false }
            }
        }
        return true
    }
}
