import SwiftUI

struct ProductEditor: View {
    @ObservedObject var auth: AuthStore
    let productID: String?
    let onSaved: () -> Void
    @State private var original: [String: OrderJSON]?
    @State private var name = ""
    @State private var code = ""
    @State private var category = ""
    @State private var cost = "0"
    @State private var price = "0"
    @State private var stock = "0"
    @State private var minimumStock = "0"
    @State private var controlsStock = true
    @State private var active = true
    @State private var loading = false
    @State private var saving = false
    @State private var ready = false
    @State private var error: String?
    @State private var idempotencyKey = UUID().uuidString
    @State private var lastPayload: Data?
    private let newID = UUID().uuidString
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if loading { ProgressView("Carregando produto…") }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
                if ready {
                    Section("Produto") {
                        TextField("Nome *", text: $name)
                        TextField("Código", text: $code)
                        TextField("Categoria", text: $category)
                    }
                    Section("Preços") {
                        moneyField("Custo", value: $cost)
                        moneyField("Preço de venda *", value: $price)
                    }
                    Section("Estoque") {
                        Toggle("Controlar estoque", isOn: $controlsStock)
                        if controlsStock {
                            numberField("Quantidade atual", value: $stock)
                            numberField("Estoque mínimo", value: $minimumStock)
                        }
                        Toggle("Produto ativo", isOn: $active)
                    }
                }
            }
            .disabled(loading || saving)
            .navigationTitle(productID == nil ? "Novo produto" : "Editar produto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { if await save() { onSaved(); dismiss() } } } label: {
                        if saving { ProgressView() } else { Text("Salvar").bold() }
                    }.disabled(!ready || saving)
                }
            }
            .task { await load() }
        }
    }

    private func moneyField(_ title: String, value: Binding<String>) -> some View {
        LabeledContent(title) { TextField("0,00", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
    }

    private func numberField(_ title: String, value: Binding<String>) -> some View {
        LabeledContent(title) { TextField("0", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
    }

    private func decimal(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        guard let productID else { ready = true; return }
        do {
            let data = try await auth.orderRequest("api/produtos/" + productID, permission: "produtos")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            guard let product = envelope["produto"]?.object else { throw URLError(.cannotParseResponse) }
            original = product
            name = product["nome"]?.text ?? ""; code = product["codigo"]?.text ?? ""; category = product["categoria"]?.text ?? ""
            cost = String(product["custo"]?.number ?? 0); price = String(product["preco"]?.number ?? 0)
            stock = String(product["estoque"]?.number ?? 0); minimumStock = String(product["estoqueMin"]?.number ?? 0)
            controlsStock = product["controla"]?.bool ?? true; active = product["ativo"]?.bool ?? true
            ready = true
        } catch { self.error = error.localizedDescription }
    }

    private func save() async -> Bool {
        guard !saving, ready else { return false }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let cost = decimal(cost), cost >= 0,
              let price = decimal(price), price > 0,
              let stock = decimal(stock), stock >= 0,
              let minimumStock = decimal(minimumStock), minimumStock >= 0 else {
            error = "Informe nome, preço de venda e valores numéricos válidos."; return false
        }
        saving = true; error = nil
        defer { saving = false }
        do {
            var product = original ?? ["id": .string(newID)]
            product["nome"] = .string(name.trimmingCharacters(in: .whitespacesAndNewlines))
            product["codigo"] = .string(code.trimmingCharacters(in: .whitespacesAndNewlines))
            product["categoria"] = .string(category.trimmingCharacters(in: .whitespacesAndNewlines))
            product["custo"] = .number(cost); product["preco"] = .number(price)
            product["controla"] = .bool(controlsStock); product["estoque"] = .number(controlsStock ? stock : 0)
            product["estoqueMin"] = .number(controlsStock ? minimumStock : 0); product["ativo"] = .bool(active)
            let id = product["id"]?.text ?? newID
            let change: OrderJSON = .object([
                "entity": .string("produtos"), "id": .string(id),
                "before": original.map(OrderJSON.object) ?? .null, "after": .object(product)
            ])
            let data = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            if data != lastPayload { lastPayload = data; idempotencyKey = UUID().uuidString }
            _ = try await auth.orderRequest("api/changes", body: data, idempotencyKey: idempotencyKey, permission: "produtos")
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
}

private extension OrderJSON {
    var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
}
