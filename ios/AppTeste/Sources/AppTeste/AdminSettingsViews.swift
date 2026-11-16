import SwiftUI

// MARK: - Users Manager View
struct UsersManagerView: View {
    @ObservedObject var auth: AuthStore
    @State private var loading = false
    @State private var users: [[String: OrderJSON]] = []
    @State private var showingAddUser = false
    @State private var editingUser: [String: OrderJSON]?

    var body: some View {
        List {
                if loading && users.isEmpty {
                    ProgressView("Carregando operadores…")
                } else {
                    ForEach(users, id: \.description) { u in
                        let nome = u["nome"]?.text ?? "Sem nome"
                        let login = u["login"]?.text ?? ""
                        let perfil = (u["perfil"]?.text ?? "atendente").capitalized
                        let ativo = u["ativo"]?.boolean ?? true

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(nome).font(.system(size: 14, weight: .semibold))
                                    if !ativo {
                                        Text("Inativo")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.red)
                                    }
                                }
                                Text("Usuário: \(login) · Perfil: \(perfil)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingUser = u
                        }
                    }
                }
            }
            .navigationTitle("Usuários e acessos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddUser = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await loadUsers() }
            .sheet(isPresented: $showingAddUser) {
                UserEditorModal(auth: auth, existingUser: nil) {
                    Task { await loadUsers() }
                }
            }
            .sheet(item: Binding<IdentifiableString?>(
                get: { editingUser.flatMap { $0["id"]?.text }.map { IdentifiableString(value: $0) } },
                set: { if $0 == nil { editingUser = nil } }
            )) { _ in
                if let u = editingUser {
                    UserEditorModal(auth: auth, existingUser: u) {
                        editingUser = nil
                        Task { await loadUsers() }
                    }
                }
            }
    }

    private func loadUsers() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "usuarios")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            if let db = envelope["db"]?.object, let list = db["users"]?.array {
                users = list.map { $0.object }
            }
        } catch { }
    }
}

private struct UserEditorModal: View {
    @ObservedObject var auth: AuthStore
    let existingUser: [String: OrderJSON]?
    let onSaved: () -> Void

    @State private var nome = ""
    @State private var login = ""
    @State private var senha = ""
    @State private var perfil = "atendente"
    @State private var ativo = true
    @State private var saving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
                Section("Dados do operador") {
                    TextField("Nome completo", text: $nome)
                    TextField("Nome de usuário (login)", text: $login)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(existingUser != nil)
                    SecureField(existingUser == nil ? "Senha inicial" : "Nova senha (deixe vazio para manter)", text: $senha)
                }

                Section("Perfil de acesso") {
                    Picker("Perfil", selection: $perfil) {
                        Text("Atendente").tag("atendente")
                        Text("Técnico").tag("tecnico")
                        Text("Administrador").tag("admin")
                    }
                    .pickerStyle(.segmented)

                    Toggle("Usuário ativo", isOn: $ativo)
                }
            }
            .navigationTitle(existingUser == nil ? "Novo usuário" : "Editar usuário")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { Task { await save() } }
                        .disabled(nome.isEmpty || login.isEmpty || (existingUser == nil && senha.isEmpty) || saving)
                }
            }
            .onAppear {
                if let u = existingUser {
                    nome = u["nome"]?.text ?? ""
                    login = u["login"]?.text ?? ""
                    perfil = u["perfil"]?.text ?? "atendente"
                    ativo = u["ativo"]?.boolean ?? true
                }
            }
        }
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            let id = existingUser?["id"]?.text ?? UUID().uuidString
            var updated = existingUser ?? [:]
            updated["id"] = .string(id)
            updated["nome"] = .string(nome.trimmingCharacters(in: .whitespaces))
            updated["login"] = .string(login.trimmingCharacters(in: .whitespaces).lowercased())
            updated["perfil"] = .string(perfil)
            updated["ativo"] = .bool(ativo)
            if !senha.isEmpty {
                updated["senha"] = .string(senha)
            }

            let change: OrderJSON = .object([
                "entity": .string("users"),
                "id": .string(id),
                "before": existingUser.map(OrderJSON.object) ?? .null,
                "after": .object(updated)
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "usuarios")
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Backup View
struct BackupView: View {
    @ObservedObject var auth: AuthStore
    @State private var loading = false
    @State private var shareURL: URL?
    @State private var error: String?

    var body: some View {
        List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Backup do SmartCenter")
                                    .font(.headline)
                                Text("Cópia de segurança completa do banco de dados.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        Text("O backup exporta com segurança todos os clientes, aparelhos, orçamentos, vendas e ordens de serviço. Você pode salvar nos Arquivos do seu iPhone, iCloud Drive ou enviar pelo WhatsApp.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task { await exportBackup() }
                    } label: {
                        HStack {
                            Spacer()
                            if loading {
                                ProgressView("Exportando dados…")
                            } else {
                                Label("Exportar Backup Completo", systemImage: "square.and.arrow.up.fill")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(loading)
                }
            }
            .navigationTitle("Backup e restauração")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: Binding<PDFShareItem?>(
                get: { shareURL.map { PDFShareItem(url: $0) } },
                set: { shareURL = $0?.url }
            )) { item in
                ShareSheetView(activityItems: [item.url])
            }
    }

    private func exportBackup() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/backup", permission: "backup")
            let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
            let fileName = "SmartCenter_Backup_\(dateStr).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            shareURL = tempURL
        } catch {
            self.error = error.localizedDescription
        }
    }
}

