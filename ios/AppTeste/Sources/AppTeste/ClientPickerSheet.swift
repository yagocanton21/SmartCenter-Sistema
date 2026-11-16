import SwiftUI

struct ClientPickerSheet: View {
    @ObservedObject var auth: AuthStore
    let onSelect: (ClientRowItem) -> Void
    @State private var search = ""
    @State private var clients: [ClientRowItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var creatingClient = false
    @Environment(\.dismiss) private var dismiss

    private var filteredClients: [ClientRowItem] {
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        if term.isEmpty { return clients }
        let termDigits = term.filter(\.isNumber)
        return clients.filter { c in
            let matchNome = c.nome.lowercased().contains(term)
            let matchDoc = !termDigits.isEmpty && c.doc.filter(\.isNumber).contains(termDigits)
            let matchPhone = !termDigits.isEmpty && c.phoneFormatted.filter(\.isNumber).contains(termDigits)
            let matchCidade = c.cidade.lowercased().contains(term)
            return matchNome || matchDoc || matchPhone || matchCidade
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if loading && clients.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Carregando clientes…")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if filteredClients.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text(search.isEmpty ? "Nenhum cliente cadastrado." : "Nenhum cliente encontrado para \"\(search)\".")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(filteredClients) { client in
                            Button {
                                onSelect(client)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ClientAvatarView(name: client.nome, size: 38, fontSize: 14)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(client.nome)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        if !client.phoneFormatted.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "phone.fill")
                                                    .font(.system(size: 9))
                                                Text(client.phoneFormatted)
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundStyle(.secondary)
                                        }

                                        if !client.doc.isEmpty {
                                            Text("CPF/CNPJ: \(client.doc)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("\(filteredClients.count) clientes")
                    }
                }
            }
            .navigationTitle("Selecionar cliente")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Buscar por nome, telefone ou CPF…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        creatingClient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Novo cliente")
                }
            }
            .sheet(isPresented: $creatingClient) {
                ClientEditor(auth: auth, clientID: nil) { newRecord in
                    Task {
                        await loadClients()
                        if let found = clients.first(where: { $0.id == newRecord.id }) {
                            onSelect(found)
                            dismiss()
                        }
                    }
                }
            }
            .refreshable { await loadClients() }
            .task { await loadClients() }
        }
    }

    private func loadClients() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "clientes")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let db = envelope["db"]?.object ?? envelope
            let list = db["clientes"]?.array ?? []
            clients = list.map { item -> ClientRowItem in
                let obj = item.object
                return ClientRowItem(
                    id: obj["id"]?.text ?? "",
                    nome: obj["nome"]?.text ?? "Cliente",
                    telefone: obj["telefone"]?.text ?? "",
                    whatsapp: obj["whatsapp"]?.text ?? "",
                    email: obj["email"]?.text ?? "",
                    doc: obj["doc"]?.text ?? "",
                    cep: obj["cep"]?.text ?? "",
                    cidade: obj["cidade"]?.text ?? "",
                    endereco: obj["endereco"]?.text ?? "",
                    obs: obj["obs"]?.text ?? "",
                    criadoEm: obj["criadoEm"]?.text ?? "",
                    raw: obj
                )
            }.sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

