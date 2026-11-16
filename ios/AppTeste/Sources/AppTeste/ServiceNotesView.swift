import SwiftUI

struct ServiceNoteItem: Identifiable, Sendable {
    let id: String
    let numero: Int
    let dataConclusao: String
    let clienteNome: String
    let clienteTelefone: String
    let aparelhoText: String
    let status: String
    let garantiaDias: Int
    let total: Double
    let raw: [String: OrderJSON]

    var formattedDate: String {
        let raw = String(dataConclusao.prefix(10))
        if raw.contains("-") {
            let parts = raw.split(separator: "-")
            if parts.count == 3 {
                return "\(parts[2])/\(parts[1])/\(parts[0])"
            }
        }
        return raw
    }

    var isGarantiaVigente: Bool {
        guard garantiaDias > 0, !dataConclusao.isEmpty else { return false }
        let raw = String(dataConclusao.prefix(10))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        if let dt = f.date(from: raw),
           let venc = Calendar.current.date(byAdding: .day, value: garantiaDias, to: dt) {
            return venc >= Calendar.current.startOfDay(for: Date())
        }
        return false
    }

    var garantiaExpiryDate: String {
        guard garantiaDias > 0, !dataConclusao.isEmpty else { return "" }
        let raw = String(dataConclusao.prefix(10))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        if let dt = f.date(from: raw),
           let venc = Calendar.current.date(byAdding: .day, value: garantiaDias, to: dt) {
            let out = DateFormatter()
            out.dateFormat = "dd/MM/yyyy"
            return out.string(from: venc)
        }
        return ""
    }
}

struct ServiceNotesView: View {
    @ObservedObject var auth: AuthStore
    @State private var search = ""
    @State private var statusFilter = "Todos"
    @State private var warrantyFilter = "Todas"
    @State private var loading = false
    @State private var fetchError: String?
    @State private var allNotes: [ServiceNoteItem] = []
    @State private var pdfShareItem: PDFShareItem?
    @State private var editingOrderID: String?
    @State private var currentPage = 1
    private let pageSize = 10

    var pageCount: Int { max(1, (filteredNotes.count + pageSize - 1) / pageSize) }

    var paginatedNotes: [ServiceNoteItem] {
        let start = (currentPage - 1) * pageSize
        guard start < filteredNotes.count else { return [] }
        let end = min(start + pageSize, filteredNotes.count)
        return Array(filteredNotes[start..<end])
    }

    private var filteredNotes: [ServiceNoteItem] {
        allNotes.filter { item in
            if statusFilter != "Todos" && item.status != statusFilter { return false }
            if warrantyFilter == "Vigente" && !item.isGarantiaVigente { return false }
            if warrantyFilter == "Vencida" && (item.garantiaDias == 0 || item.isGarantiaVigente) { return false }
            if warrantyFilter == "Sem garantia" && item.garantiaDias > 0 { return false }
            if !search.isEmpty {
                let term = search.lowercased()
                let matchNum = String(item.numero).contains(term)
                let matchClient = item.clienteNome.lowercased().contains(term)
                let matchPhone = item.clienteTelefone.contains(term)
                let matchDev = item.aparelhoText.lowercased().contains(term)
                return matchNum || matchClient || matchPhone || matchDev
            }
            return true
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: 1).id("top")
                    // Filter chips horizontais elegantes
                    filterBar

                    if let fetchError {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(fetchError, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.footnote)
                            Button("Tentar novamente") { Task { await fetchNotes() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }

                    if loading && allNotes.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Carregando notas de serviço…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if filteredNotes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Nenhuma nota encontrada")
                                .font(.headline)
                            Text("As notas aparecem assim que uma OS é marcada como Concluída ou Entregue.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(paginatedNotes) { note in
                                noteCard(note)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 10)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Notas de serviço")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Buscar por nº, cliente ou aparelho")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !filteredNotes.isEmpty {
                    pagination
                }
            }
            .onChange(of: currentPage) { _, _ in
                withAnimation { proxy.scrollTo("top", anchor: .top) }
            }
            .onChange(of: search) { _, _ in currentPage = 1 }
            .onChange(of: statusFilter) { _, _ in currentPage = 1 }
            .onChange(of: warrantyFilter) { _, _ in currentPage = 1 }
            .refreshable { await fetchNotes() }
            .task { await fetchNotes() }
            .sheet(item: Binding<IdentifiableString?>(
                get: { editingOrderID.map { IdentifiableString(value: $0) } },
                set: { editingOrderID = $0?.value }
            )) { item in
                OrderEditor(auth: auth, orderID: item.value) {
                    Task { await fetchNotes() }
                }
            }
            .sheet(item: $pdfShareItem) { item in
                ShareSheetView(activityItems: [item.url])
            }
        }
    }

    private var pagination: some View {
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
                Text("\(filteredNotes.count) notas · 10 por pág.")
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

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Todas", isSelected: statusFilter == "Todos" && warrantyFilter == "Todas") {
                    statusFilter = "Todos"
                    warrantyFilter = "Todas"
                }

                chip(title: "Entregues", isSelected: statusFilter == "Entregue") {
                    statusFilter = (statusFilter == "Entregue") ? "Todos" : "Entregue"
                }

                chip(title: "Aguardando Retirada", isSelected: statusFilter == "Concluído") {
                    statusFilter = (statusFilter == "Concluído") ? "Todos" : "Concluído"
                }

                chip(title: "Garantia Vigente", isSelected: warrantyFilter == "Vigente") {
                    warrantyFilter = (warrantyFilter == "Vigente") ? "Todas" : "Vigente"
                }

                chip(title: "Garantia Vencida", isSelected: warrantyFilter == "Vencida") {
                    warrantyFilter = (warrantyFilter == "Vencida") ? "Todas" : "Vencida"
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : Color.primary.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Card
    private func noteCard(_ note: ServiceNoteItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cabeçalho: Número, Data e Status Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Nota #\(String(format: "%04d", note.numero))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        if !note.formattedDate.isEmpty {
                            Text("· Concluído em \(note.formattedDate)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(note.clienteNome)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if !note.clienteTelefone.isEmpty {
                        Text(note.clienteTelefone)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status Badge
                Text(note.status)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (note.status == "Entregue" ? Color.green : Color.blue).opacity(0.14),
                        in: Capsule()
                    )
                    .foregroundStyle(note.status == "Entregue" ? Color.green : Color.blue)
            }

            // Aparelho e Garantia
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(note.aparelhoText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if note.garantiaDias > 0 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(note.isGarantiaVigente ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(note.isGarantiaVigente ? "Garantia até \(note.garantiaExpiryDate) (\(note.garantiaDias) dias)" : "Garantia vencida (\(note.garantiaDias) dias)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(note.isGarantiaVigente ? Color.green : Color.secondary)
                    }
                } else {
                    Text("Sem garantia")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.5)

            // Rodapé: Valor e Botões de Ação
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TOTAL")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Text(note.total.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR"))))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                HStack(spacing: 8) {
                    // Botão Entregue (apenas para Concluído)
                    if note.status == "Concluído" {
                        Button {
                            Task { await markAsDelivered(note) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Entregar")
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                    }

                    // Botão WhatsApp
                    Button {
                        sendWhatsApp(note)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                            Text("Whats")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .controlSize(.small)

                    // Botão PDF / Termo
                    Button {
                        printNote(note)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "printer.fill")
                            Text("PDF")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)

                    // Acessar OS
                    Button {
                        editingOrderID = note.id
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 2)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            editingOrderID = note.id
        }
    }

    // MARK: - Actions & Fetching
    private func fetchNotes() async {
        loading = true
        fetchError = nil
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "os")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let db = envelope["db"]?.object ?? envelope
            let clientsList = (db["clientes"]?.array ?? []).map { $0.object }
            var clientsMap: [String: [String: OrderJSON]] = [:]
            for c in clientsList {
                if let cid = c["id"]?.text, !cid.isEmpty {
                    clientsMap[cid] = c
                }
            }
            let list = db["os"]?.array ?? []
            allNotes = list.compactMap { item -> ServiceNoteItem? in
                let obj = item.object
                let st = (obj["status"]?.text ?? "").trimmingCharacters(in: .whitespaces)
                let norm = st.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                guard norm == "concluido" || norm == "entregue" else { return nil }

                let id = obj["id"]?.text ?? ""
                let num = Int(obj["numero"]?.number ?? 0)
                let dtEntr = obj["dataEntrega"]?.text ?? ""
                let dtConc = obj["dataConclusao"]?.text ?? ""
                let dtEntrada = obj["dataEntrada"]?.text ?? ""
                let baseDate = !dtEntr.isEmpty ? dtEntr : (!dtConc.isEmpty ? dtConc : dtEntrada)

                let clientSnap = obj["cliSnap"]?.object ?? [:]
                let clientID = obj["clienteId"]?.text ?? ""
                let fallbackClient = clientsMap[clientID] ?? [:]
                let clientName: String = {
                    let s = clientSnap["nome"]?.text ?? ""
                    if !s.isEmpty { return s }
                    let f = fallbackClient["nome"]?.text ?? ""
                    if !f.isEmpty { return f }
                    let d = obj["clienteNome"]?.text ?? ""
                    if !d.isEmpty { return d }
                    return "Consumidor final"
                }()
                let clientPhone: String = {
                    let s = clientSnap["telefone"]?.text ?? ""
                    if !s.isEmpty { return s }
                    return fallbackClient["telefone"]?.text ?? ""
                }()

                let dev = obj["aparelho"]?.object ?? [:]
                let devText = [dev["tipo"]?.text, dev["marca"]?.text, dev["modelo"]?.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                let garDias = Int(obj["garantiaDias"]?.number ?? 90)
                let tot = obj["total"]?.number ?? ((obj["maoDeObra"]?.number ?? 0) + (obj["valorPecas"]?.number ?? 0))

                return ServiceNoteItem(
                    id: id,
                    numero: num,
                    dataConclusao: baseDate,
                    clienteNome: clientName,
                    clienteTelefone: clientPhone,
                    aparelhoText: devText.isEmpty ? "Aparelho" : devText,
                    status: norm == "entregue" ? "Entregue" : "Concluído",
                    garantiaDias: garDias,
                    total: tot,
                    raw: obj
                )
            }.sorted { $0.numero > $1.numero }
        } catch {
            fetchError = error.localizedDescription
        }
    }

    private func printNote(_ note: ServiceNoteItem) {
        do {
            let url = try OrderPDFGenerator.generate(order: note.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch { }
    }

    private func sendWhatsApp(_ note: ServiceNoteItem) {
        let msg = """
        Olá, \(note.clienteNome.split(separator: " ").first ?? "cliente")! Segue o resumo da sua *Nota de Serviço nº \(String(format: "%04d", note.numero))* (ref. OS #\(String(format: "%04d", note.numero))) – *SmartCenter*.
        
        Aparelho: \(note.aparelhoText)
        *Total: R$ \(String(format: "%.2f", note.total).replacingOccurrences(of: ".", with: ","))*
        *Garantia:* \(note.garantiaDias > 0 ? "\(note.garantiaDias) dias (válida até \(note.garantiaExpiryDate))" : "Sem garantia")
        
        O Termo de Garantia acompanha este documento. Guarde-o para acionar a garantia se necessário.
        Obrigado pela preferência!
        
        *SmartCenter*
        """
        WhatsAppHelper.openWhatsApp(phone: note.clienteTelefone, message: msg)
    }

    private func markAsDelivered(_ note: ServiceNoteItem) async {
        do {
            var updated = note.raw
            updated["status"] = .string("Entregue")
            updated["dataEntrega"] = .string(ISO8601DateFormatter().string(from: Date()))
            if var dev = updated["aparelho"]?.object {
                dev["senha"] = .string("")
                dev["senhaPadrao"] = .string("")
                updated["aparelho"] = .object(dev)
            }
            updated["before"] = .object(note.raw)
            let data = try JSONEncoder().encode(OrderJSON.object(updated))
            _ = try await auth.orderRequest("api/os", body: data, idempotencyKey: UUID().uuidString)
            await fetchNotes()
        } catch { }
    }
}
