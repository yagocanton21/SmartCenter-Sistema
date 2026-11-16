import SwiftUI

// MARK: - Client Avatar View
struct ClientAvatarView: View {
    let name: String
    var size: CGFloat = 42
    var fontSize: CGFloat = 15

    private var initials: String {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .filter { !$0.isEmpty }
        if parts.isEmpty { return "?" }
        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }
        let first = parts[0].prefix(1)
        let second = parts[1].prefix(1)
        return "\(first)\(second)".uppercased()
    }

    private var gradient: LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.15, green: 0.50, blue: 0.95), Color(red: 0.20, green: 0.75, blue: 0.95)], // Blue-Cyan
            [Color(red: 0.55, green: 0.25, blue: 0.85), Color(red: 0.80, green: 0.35, blue: 0.90)], // Purple
            [Color(red: 0.10, green: 0.70, blue: 0.55), Color(red: 0.20, green: 0.85, blue: 0.65)], // Teal-Mint
            [Color(red: 0.95, green: 0.45, blue: 0.20), Color(red: 0.95, green: 0.30, blue: 0.50)], // Orange-Pink
            [Color(red: 0.25, green: 0.35, blue: 0.85), Color(red: 0.45, green: 0.55, blue: 0.95)], // Indigo
            [Color(red: 0.90, green: 0.25, blue: 0.45), Color(red: 0.95, green: 0.45, blue: 0.65)], // Rose
            [Color(red: 0.15, green: 0.65, blue: 0.40), Color(red: 0.35, green: 0.80, blue: 0.55)]  // Green
        ]
        let hash = abs(name.hashValue)
        let pair = palettes[hash % palettes.count]
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Text(initials)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient, in: Circle())
            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
    }
}

// MARK: - Client Model
struct ClientRowItem: Identifiable, Sendable {
    let id: String
    let nome: String
    let telefone: String
    let whatsapp: String
    let email: String
    let doc: String
    let cep: String
    let cidade: String
    let endereco: String
    let obs: String
    let criadoEm: String
    let raw: [String: OrderJSON]

    var phoneFormatted: String {
        let p = !whatsapp.isEmpty ? whatsapp : telefone
        return p.isEmpty ? "" : p
    }
}

// MARK: - Clients View
struct ClientsView: View {
    @ObservedObject var auth: AuthStore
    @State private var search = ""
    @State private var loading = false
    @State private var fetchError: String?
    @State private var allClients: [ClientRowItem] = []
    @State private var creatingClient = false
    @State private var selectedClient: ClientRowItem?
    @State private var clientToDelete: ClientRowItem?
    @State private var confirmDelete = false
    @State private var deleteError: String?
    @State private var currentPage = 1
    private let pageSize = 10

    private var filteredClients: [ClientRowItem] {
        if search.trimmingCharacters(in: .whitespaces).isEmpty {
            return allClients
        }
        let term = search.lowercased().trimmingCharacters(in: .whitespaces)
        let termDigits = term.filter(\.isNumber)
        return allClients.filter { c in
            let matchNome = c.nome.lowercased().contains(term)
            let matchEmail = c.email.lowercased().contains(term)
            let matchCidade = c.cidade.lowercased().contains(term)
            let matchDoc = !termDigits.isEmpty && c.doc.filter(\.isNumber).contains(termDigits)
            let matchPhone = !termDigits.isEmpty && c.phoneFormatted.filter(\.isNumber).contains(termDigits)
            return matchNome || matchEmail || matchCidade || matchDoc || matchPhone
        }
    }

    private var pageCount: Int {
        max(1, (filteredClients.count + pageSize - 1) / pageSize)
    }

    private var paginatedClients: [ClientRowItem] {
        let start = (currentPage - 1) * pageSize
        guard start < filteredClients.count else { return [] }
        let end = min(start + pageSize, filteredClients.count)
        return Array(filteredClients[start..<end])
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Color.clear.frame(height: 1).id("top")

                    // Subtítulo com contagem
                    HStack {
                        Text("\(filteredClients.count) clientes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if loading {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    if let fetchError {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(fetchError, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.footnote)
                            Button("Tentar novamente") { Task { await loadClients() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }

                    if loading && allClients.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Carregando clientes…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if filteredClients.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Nenhum cliente encontrado")
                                .font(.headline)
                            Text(search.isEmpty ? "Toque no botão + no topo para cadastrar o primeiro cliente." : "Nenhum cliente corresponde ao termo pesquisado.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(paginatedClients) { client in
                                NavigationLink {
                                    ClientDetailView(auth: auth, client: client) {
                                        Task { await loadClients() }
                                    }
                                } label: {
                                    clientCard(client)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        let phone = !client.whatsapp.isEmpty ? client.whatsapp : client.telefone
                                        WhatsAppHelper.openWhatsApp(phone: phone, message: "Olá, \(client.nome)!")
                                    } label: {
                                        Label("WhatsApp", systemImage: "message.fill")
                                    }

                                    Button(role: .destructive) {
                                        clientToDelete = client
                                        confirmDelete = true
                                    } label: {
                                        Label("Excluir cliente", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Clientes")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Buscar por nome, telefone, CPF ou cidade")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        creatingClient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Novo cliente")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !filteredClients.isEmpty {
                    paginationBar
                }
            }
            .onChange(of: currentPage) { _, _ in
                withAnimation { proxy.scrollTo("top", anchor: .top) }
            }
            .onChange(of: search) { _, _ in currentPage = 1 }
            .refreshable { await loadClients() }
            .task { await loadClients() }
            .sheet(isPresented: $creatingClient) {
                ClientEditor(auth: auth, clientID: nil) { _ in
                    Task { await loadClients() }
                }
            }
            .confirmationDialog("Excluir cliente?", isPresented: $confirmDelete, titleVisibility: .visible) {
                if let client = clientToDelete {
                    Button("Excluir \(client.nome)", role: .destructive) {
                        Task { await deleteClientAction(client) }
                    }
                }
            } message: {
                Text("Clientes com ordens de serviço, vendas ou orçamentos vinculados não podem ser excluídos.")
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
    }

    // MARK: - Client Card
    private func clientCard(_ client: ClientRowItem) -> some View {
        HStack(spacing: 12) {
            ClientAvatarView(name: client.nome, size: 44, fontSize: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.nome)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !client.phoneFormatted.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(client.phoneFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                if !client.cidade.isEmpty {
                    Text(client.cidade)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Botão rápido de WhatsApp
            if !client.phoneFormatted.isEmpty {
                Button {
                    WhatsAppHelper.openWhatsApp(phone: client.phoneFormatted, message: "Olá, \(client.nome)!")
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Pagination
    private var paginationBar: some View {
        HStack(spacing: 12) {
            Button {
                if currentPage > 1 { currentPage -= 1 }
            } label: {
                Label("Anterior", systemImage: "chevron.left")
            }
            .disabled(currentPage <= 1)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("\(currentPage) / \(pageCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                Text("\(filteredClients.count) clientes · 10 por pág.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                if currentPage < pageCount { currentPage += 1 }
            } label: {
                HStack(spacing: 4) {
                    Text("Próxima")
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(currentPage >= pageCount)
        }
        .font(.system(size: 13, weight: .medium))
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - API Calls
    private func loadClients() async {
        loading = true
        fetchError = nil
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "clientes")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let db = envelope["db"]?.object ?? envelope
            let list = db["clientes"]?.array ?? []
            allClients = list.map { item -> ClientRowItem in
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
            fetchError = error.localizedDescription
        }
    }

    private func deleteClientAction(_ client: ClientRowItem) async {
        do {
            let change: OrderJSON = .object([
                "entity": .string("clientes"),
                "id": .string(client.id),
                "before": .object(client.raw),
                "after": .null
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "clientes")
            await loadClients()
            Task { await auth.loadDashboard() }
        } catch {
            if error.localizedDescription.contains("depende de um") {
                deleteError = "Este cliente possui histórico (OS, orçamentos ou vendas) e não pode ser excluído."
            } else {
                deleteError = error.localizedDescription
            }
        }
    }
}

// MARK: - Client Detail View
struct ClientDetailView: View {
    @ObservedObject var auth: AuthStore
    let client: ClientRowItem
    let onModified: () -> Void

    @State private var editing = false
    @State private var creatingOS = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var copiedField: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Header estilo Ficha do Apple Contacts
            Section {
                VStack(spacing: 12) {
                    ClientAvatarView(name: client.nome, size: 76, fontSize: 26)

                    VStack(spacing: 4) {
                        Text(client.nome)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)

                        if !client.doc.isEmpty {
                            Text("CPF / CNPJ: \(client.doc)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !client.criadoEm.isEmpty {
                            Text("Cliente cadastrado em \(String(client.criadoEm.prefix(10)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Botões redondos de ação rápida
                    HStack(spacing: 16) {
                        actionButton(icon: "message.fill", title: "WhatsApp", color: .green) {
                            let phone = !client.whatsapp.isEmpty ? client.whatsapp : client.telefone
                            WhatsAppHelper.openWhatsApp(phone: phone, message: "Olá, \(client.nome)!")
                        }

                        actionButton(icon: "phone.fill", title: "Ligar", color: .blue) {
                            let phone = client.phoneFormatted.filter { $0.isNumber }
                            if let url = URL(string: "tel://\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }

                        actionButton(icon: "wrench.and.screwdriver.fill", title: "Nova OS", color: .orange) {
                            creatingOS = true
                        }

                        actionButton(icon: "pencil", title: "Editar", color: .gray) {
                            editing = true
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Contato
            Section("Contato") {
                if !client.telefone.isEmpty {
                    infoRow(icon: "phone", label: "Telefone", value: client.telefone)
                }
                if !client.whatsapp.isEmpty {
                    infoRow(icon: "message", label: "WhatsApp", value: client.whatsapp)
                }
                if !client.email.isEmpty {
                    infoRow(icon: "envelope", label: "E-mail", value: client.email)
                }
                if !client.doc.isEmpty {
                    infoRow(icon: "doc.text", label: "CPF / CNPJ", value: client.doc)
                }
            }

            // Endereço
            if !client.endereco.isEmpty || !client.cidade.isEmpty || !client.cep.isEmpty {
                Section("Endereço") {
                    if !client.endereco.isEmpty {
                        infoRow(icon: "mappin.and.ellipse", label: "Endereço", value: client.endereco)
                    }
                    if !client.cidade.isEmpty {
                        infoRow(icon: "building.2", label: "Cidade / UF", value: client.cidade)
                    }
                    if !client.cep.isEmpty {
                        infoRow(icon: "number", label: "CEP", value: client.cep)
                    }

                    let fullAddress = [client.endereco, client.cidade].filter { !$0.isEmpty }.joined(separator: ", ")
                    if !fullAddress.isEmpty {
                        Button {
                            if let encoded = fullAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               let url = URL(string: "maps://?q=\(encoded)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Abrir no Apple Maps", systemImage: "map.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // Observações
            if !client.obs.isEmpty {
                Section("Observações") {
                    Text(client.obs)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            // Histórico Completo de OS e Orçamentos
            ClientHistorySection(auth: auth, clientID: client.id)

            // Exclusão
            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    HStack {
                        Spacer()
                        if deleting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Excluir cliente", systemImage: "trash.fill")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(deleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(client.nome)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            ClientEditor(auth: auth, clientID: client.id) { _ in
                onModified()
                dismiss()
            }
        }
        .sheet(isPresented: $creatingOS) {
            OrderEditor(auth: auth, orderID: nil, prefillClient: client.raw) {
                onModified()
                dismiss()
            }
        }
        .confirmationDialog("Excluir cliente?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Excluir definitivamente", role: .destructive) {
                Task { await deleteClient() }
            }
        } message: {
            Text("Clientes com ordens de serviço, vendas ou orçamentos não podem ser excluídos.")
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

    // MARK: - Action Button
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color, in: Circle())
                    .shadow(color: color.opacity(0.3), radius: 4, y: 2)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Row
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button {
                UIPasteboard.general.string = value
                copiedField = label
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedField == label { copiedField = nil }
                }
            } label: {
                Image(systemName: copiedField == label ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(copiedField == label ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Delete Client
    private func deleteClient() async {
        deleting = true
        deleteError = nil
        defer { deleting = false }
        do {
            let change: OrderJSON = .object([
                "entity": .string("clientes"),
                "id": .string(client.id),
                "before": .object(client.raw),
                "after": .null
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "clientes")
            onModified()
            dismiss()
        } catch {
            if error.localizedDescription.contains("depende de um") {
                deleteError = "Este cliente possui ordens de serviço, vendas ou orçamentos vinculados e não pode ser excluído."
            } else {
                deleteError = error.localizedDescription
            }
        }
    }
}

