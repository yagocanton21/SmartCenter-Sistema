import SwiftUI
import UIKit

// MARK: - Quote Status Config
enum QuoteStatusConfig {
    static let allStatuses = ["Pendente", "Aprovado", "Recusado"]

    static func icon(for status: String) -> String {
        switch status {
        case "Pendente": return "clock.fill"
        case "Aprovado": return "checkmark.circle.fill"
        case "Recusado": return "xmark.circle.fill"
        default: return "circle.fill"
        }
    }

    static func color(for status: String) -> Color {
        switch status {
        case "Pendente": return Color.orange
        case "Aprovado": return Color.green
        case "Recusado": return Color.red
        default: return Color.secondary
        }
    }
}

// MARK: - Quote Row Item
struct QuoteRowItem: Identifiable, Sendable {
    let id: String
    let numero: Int
    let data: String
    let validade: String
    let status: String
    let total: Double
    let maoDeObra: Double
    let valorPecas: Double
    let clienteId: String
    let clienteNome: String
    let clienteTelefone: String
    let clienteDoc: String
    let aparelhoTipo: String
    let aparelhoMarca: String
    let aparelhoModelo: String
    let aparelhoDefeito: String
    let diagnostico: String
    let observacoes: String
    let pecas: [OrderPartItem]
    let osId: String?
    let raw: [String: OrderJSON]

    var shortNumber: String {
        String(format: "#%04d", numero)
    }

    var formattedNumber: String {
        String(format: "#%06d", numero)
    }

    var deviceTitle: String {
        let parts = [aparelhoMarca, aparelhoModelo].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if parts.isEmpty {
            return aparelhoTipo.isEmpty ? "Aparelho" : aparelhoTipo
        }
        return parts.joined(separator: " ")
    }

    var deviceIcon: String {
        switch aparelhoTipo.lowercased() {
        case "celular": return "iphone"
        case "tablet": return "ipad"
        case "notebook": return "laptopcomputer"
        case "computador": return "desktopcomputer"
        case "console / videogame", "console": return "gamecontroller"
        case "smartwatch": return "applewatch"
        default: return "doc.text"
        }
    }

    var isExpired: Bool {
        guard status == "Pendente", !validade.isEmpty else { return false }
        let rawDate = String(validade.prefix(10))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        if let dt = f.date(from: rawDate) {
            return dt < Calendar.current.startOfDay(for: Date())
        }
        return false
    }

    var formattedDate: String {
        formatDate(data)
    }

    var formattedValidityDate: String {
        formatDate(validade)
    }

    private func formatDate(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let raw = String(iso.prefix(10))
        let parts = raw.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[2])/\(parts[1])/\(parts[0])"
        }
        return raw
    }
}

// MARK: - Quotes View
struct QuotesView: View {
    @ObservedObject var auth: AuthStore
    @State private var search = ""
    @State private var selectedStatusFilter = "Todos"
    @State private var loading = false
    @State private var fetchError: String?
    @State private var allQuotes: [QuoteRowItem] = []
    @State private var clientsById: [String: [String: OrderJSON]] = [:]

    @State private var creatingQuote = false
    @State private var editingQuoteID: String?
    @State private var convertingQuote: QuoteRowItem?
    @State private var quoteToDelete: QuoteRowItem?
    @State private var confirmDelete = false
    @State private var deleteError: String?
    @State private var pdfShareItem: PDFShareItem?

    @State private var currentPage = 1
    private let pageSize = 10

    // MARK: - Filters
    private var expiredCount: Int {
        allQuotes.filter(\.isExpired).count
    }

    private var filteredQuotes: [QuoteRowItem] {
        var list = allQuotes

        if selectedStatusFilter == "vencidos" {
            list = list.filter(\.isExpired)
        } else if selectedStatusFilter != "Todos" {
            list = list.filter { $0.status == selectedStatusFilter }
        }

        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !term.isEmpty {
            let termDigits = term.filter(\.isNumber)
            list = list.filter { q in
                let matchNum = String(q.numero).contains(term) || q.formattedNumber.contains(term)
                let matchCli = q.clienteNome.lowercased().contains(term)
                let matchDev = q.deviceTitle.lowercased().contains(term)
                let matchDefect = q.aparelhoDefeito.lowercased().contains(term)
                let matchPhone = !termDigits.isEmpty && q.clienteTelefone.filter(\.isNumber).contains(termDigits)
                return matchNum || matchCli || matchDev || matchDefect || matchPhone
            }
        }

        return list
    }

    private var pageCount: Int {
        max(1, (filteredQuotes.count + pageSize - 1) / pageSize)
    }

    private var paginatedQuotes: [QuoteRowItem] {
        let start = (currentPage - 1) * pageSize
        guard start < filteredQuotes.count else { return [] }
        let end = min(start + pageSize, filteredQuotes.count)
        return Array(filteredQuotes[start..<end])
    }

    private var isAlertShowing: Binding<Bool> {
        Binding<Bool>(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )
    }

    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            mainScrollView(proxy: proxy)
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
                .navigationTitle("Orçamentos")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "Buscar por nº, cliente, aparelho…")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            creatingQuote = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Novo orçamento")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !filteredQuotes.isEmpty {
                        paginationBar
                    }
                }
                .onChange(of: currentPage) { _, _ in
                    withAnimation { proxy.scrollTo("top", anchor: .top) }
                }
                .onChange(of: search) { _, _ in currentPage = 1 }
                .onChange(of: selectedStatusFilter) { _, _ in currentPage = 1 }
                .refreshable { await loadQuotes() }
                .task { await loadQuotes() }
                .sheet(isPresented: $creatingQuote) {
                    QuoteEditor(auth: auth, quoteID: nil) {
                        Task { await loadQuotes() }
                    }
                }
                .sheet(item: Binding<IdentifiableString?>(
                    get: { editingQuoteID.map { IdentifiableString(value: $0) } },
                    set: { editingQuoteID = $0?.value }
                )) { item in
                    QuoteEditor(auth: auth, quoteID: item.value) {
                        Task { await loadQuotes() }
                    }
                }
                .sheet(item: Binding<IdentifiableString?>(
                    get: { convertingQuote.map { IdentifiableString(value: $0.id) } },
                    set: { if $0 == nil { convertingQuote = nil } }
                )) { item in
                    if let quote = allQuotes.first(where: { $0.id == item.value }) {
                        OrderEditor(auth: auth, orderID: nil, prefillQuote: quote.raw) {
                            Task { await loadQuotes() }
                        }
                    }
                }
                .sheet(item: $pdfShareItem) { share in
                    ShareSheetView(activityItems: [share.url])
                }
                .confirmationDialog("Excluir orçamento?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    if let quote = quoteToDelete {
                        Button("Excluir Orçamento \(quote.formattedNumber)", role: .destructive) {
                            Task { await deleteQuoteAction(quote) }
                        }
                    }
                } message: {
                    Text("Esta ação não pode ser desfeita.")
                }
                .alert("Aviso", isPresented: isAlertShowing) {
                    Button("OK") { }
                } message: {
                    Text(deleteError ?? "")
                }
        }
    }

    // MARK: - Main Scroll & Subviews
    @ViewBuilder
    private func mainScrollView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Color.clear.frame(height: 1).id("top")
                statusChipsBar
                quotesHeaderCountBar

                if let fetchError {
                    errorBanner(fetchError)
                }

                if loading && allQuotes.isEmpty {
                    loadingIndicator
                } else if filteredQuotes.isEmpty {
                    emptyStateView
                } else {
                    quotesCardsList
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var quotesHeaderCountBar: some View {
        HStack {
            Text("\(filteredQuotes.count) orçamentos")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if loading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.footnote)
            Button("Tentar novamente") { Task { await loadQuotes() } }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Carregando orçamentos…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nenhum orçamento encontrado")
                .font(.headline)
            Text(search.isEmpty && selectedStatusFilter == "Todos"
                 ? "Toque no botão + no topo para criar uma nova proposta de orçamento."
                 : "Nenhum orçamento corresponde aos filtros selecionados.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    private var quotesCardsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(paginatedQuotes) { quote in
                NavigationLink {
                    QuoteDetailView(
                        auth: auth,
                        quote: quote,
                        onModified: { Task { await loadQuotes() } }
                    )
                } label: {
                    quoteCard(quote)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        sendWhatsApp(quote)
                    } label: {
                        Label("WhatsApp", systemImage: "message.fill")
                    }

                    Button {
                        printQuote(quote)
                    } label: {
                        Label("Imprimir Proposta (PDF)", systemImage: "printer.fill")
                    }

                    if quote.status == "Aprovado" && (quote.osId == nil || quote.osId?.isEmpty == true) {
                        Button {
                            convertingQuote = quote
                        } label: {
                            Label("Gerar Ordem de Serviço", systemImage: "wrench.and.screwdriver.fill")
                        }
                    }

                    Button {
                        editingQuoteID = quote.id
                    } label: {
                        Label("Editar Orçamento", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        quoteToDelete = quote
                        confirmDelete = true
                    } label: {
                        Label("Excluir Orçamento", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Status Filter Chips Bar
    private var statusChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(
                    title: "Todos",
                    count: allQuotes.count,
                    isSelected: selectedStatusFilter == "Todos",
                    color: .blue
                ) {
                    selectedStatusFilter = "Todos"
                }

                if expiredCount > 0 {
                    chipButton(
                        title: "⚠️ Vencidos",
                        count: expiredCount,
                        isSelected: selectedStatusFilter == "vencidos",
                        color: .red
                    ) {
                        selectedStatusFilter = "vencidos"
                    }
                }

                ForEach(QuoteStatusConfig.allStatuses, id: \.self) { status in
                    let count = allQuotes.filter { $0.status == status }.count
                    chipButton(
                        title: status,
                        count: count,
                        isSelected: selectedStatusFilter == status,
                        color: QuoteStatusConfig.color(for: status)
                    ) {
                        selectedStatusFilter = status
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func chipButton(title: String, count: Int, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : color.opacity(0.15), in: Capsule())
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                isSelected ? color : Color(uiColor: .secondarySystemGroupedBackground),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quote Card Component
    private func quoteCard(_ quote: QuoteRowItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Número, Status interativo, Vencido, Total
            HStack(alignment: .center, spacing: 8) {
                Text(quote.shortNumber)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))

                // Status interativo via Menu
                Menu {
                    ForEach(QuoteStatusConfig.allStatuses, id: \.self) { s in
                        Button {
                            Task { await changeQuoteStatus(quote, to: s) }
                        } label: {
                            if quote.status == s {
                                Label(s, systemImage: "checkmark")
                            } else {
                                Text(s)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: QuoteStatusConfig.icon(for: quote.status))
                            .font(.system(size: 10))
                        Text(quote.status)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(QuoteStatusConfig.color(for: quote.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(QuoteStatusConfig.color(for: quote.status).opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)

                if quote.isExpired {
                    Text("Vencido")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.12), in: Capsule())
                }

                Spacer()

                Text(String(format: "R$ %.2f", quote.total).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Divider()

            // Aparelho & Cliente
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: quote.deviceIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                    .frame(width: 38, height: 38)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(quote.deviceTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(quote.clienteNome)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if !quote.clienteTelefone.isEmpty {
                            Text("· " + quote.clienteTelefone)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }

            // Defeito (se houver)
            if !quote.aparelhoDefeito.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                    Text(quote.aparelhoDefeito)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            // Rodapé do Card
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Emissão:").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(quote.formattedDate).font(.system(size: 11, weight: .medium)).foregroundStyle(.primary)
                    }
                    if !quote.validade.isEmpty {
                        HStack(spacing: 4) {
                            Text("Validade:").font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(quote.formattedValidityDate)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(quote.isExpired ? Color.red : Color.primary)
                        }
                    }
                }

                Spacer()

                // Botões de Ação Rápida Circulares
                HStack(spacing: 10) {
                    // WhatsApp
                    Button {
                        sendWhatsApp(quote)
                    } label: {
                        Image(systemName: "message.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                            .frame(width: 34, height: 34)
                            .background(Color.green.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Enviar Proposta no WhatsApp")

                    // PDF / Imprimir
                    Button {
                        printQuote(quote)
                    } label: {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 34, height: 34)
                            .background(Color.blue.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Gerar PDF do Orçamento")

                    // Gerar OS (se aprovado)
                    if quote.status == "Aprovado" && (quote.osId == nil || quote.osId?.isEmpty == true) {
                        Button {
                            convertingQuote = quote
                        } label: {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.blue, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Gerar Ordem de Serviço")
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(quote.isExpired ? Color.red.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: quote.isExpired ? 1.5 : 1)
        )
    }

    // MARK: - Pagination Bar
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
                Text("\(filteredQuotes.count) orçamentos · 10 por pág.")
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

    // MARK: - API & Actions
    private func loadQuotes() async {
        loading = true
        fetchError = nil
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "orcamentos")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let db = envelope["db"]?.object ?? envelope
            let quotesList = db["orcamentos"]?.array ?? []
            let clientesList = db["clientes"]?.array ?? []

            var clientsMap: [String: [String: OrderJSON]] = [:]
            for c in clientesList {
                let obj = c.object
                if let cid = obj["id"]?.text, !cid.isEmpty {
                    clientsMap[cid] = obj
                }
            }
            clientsById = clientsMap

            allQuotes = quotesList.compactMap { item -> QuoteRowItem? in
                let q = item.object
                guard let id = q["id"]?.text, !id.isEmpty else { return nil }
                let dev = q["aparelho"]?.object ?? [:]
                let cid = q["clienteId"]?.text ?? ""
                let snap = q["cliSnap"]?.object ?? clientsMap[cid] ?? [:]

                let parts = (q["pecas"]?.array ?? []).map { p -> OrderPartItem in
                    let pobj = p.object
                    let qtd = pobj["qtd"]?.number ?? 1
                    let val = pobj["valor"]?.number ?? (pobj["preco"]?.number ?? 0)
                    return OrderPartItem(
                        descricao: pobj["descricao"]?.text ?? "Item",
                        qtd: qtd,
                        valor: val,
                        subtotal: qtd * val
                    )
                }

                return QuoteRowItem(
                    id: id,
                    numero: Int(q["numero"]?.number ?? 0),
                    data: q["data"]?.text ?? "",
                    validade: q["validade"]?.text ?? "",
                    status: q["status"]?.text ?? "Pendente",
                    total: q["total"]?.number ?? 0,
                    maoDeObra: q["maoDeObra"]?.number ?? 0,
                    valorPecas: q["valorPecas"]?.number ?? 0,
                    clienteId: cid,
                    clienteNome: snap["nome"]?.text ?? "Cliente",
                    clienteTelefone: snap["whatsapp"]?.text ?? (snap["telefone"]?.text ?? ""),
                    clienteDoc: snap["doc"]?.text ?? "",
                    aparelhoTipo: dev["tipo"]?.text ?? "Celular",
                    aparelhoMarca: dev["marca"]?.text ?? "",
                    aparelhoModelo: dev["modelo"]?.text ?? "",
                    aparelhoDefeito: dev["defeito"]?.text ?? "",
                    diagnostico: q["diagnostico"]?.text ?? "",
                    observacoes: q["observacoes"]?.text ?? "",
                    pecas: parts,
                    osId: q["osId"]?.text,
                    raw: q
                )
            }.sorted { $0.numero > $1.numero }
        } catch {
            fetchError = error.localizedDescription
        }
    }

    private func changeQuoteStatus(_ quote: QuoteRowItem, to newStatus: String) async {
        guard quote.status != newStatus else { return }
        do {
            var updated = quote.raw
            updated["status"] = .string(newStatus)

            let change: OrderJSON = .object([
                "entity": .string("orcamentos"),
                "id": .string(quote.id),
                "before": .object(quote.raw),
                "after": .object(updated)
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "orcamentos")
            await loadQuotes()
            Task { await auth.loadDashboard() }
        } catch {
            deleteError = "Erro ao alterar status: " + error.localizedDescription
        }
    }

    private func sendWhatsApp(_ quote: QuoteRowItem) {
        WhatsAppHelper.sendQuoteWhatsApp(quote: quote.raw)
    }

    private func printQuote(_ quote: QuoteRowItem) {
        do {
            let url = try OrderPDFGenerator.generateQuote(quote: quote.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch {
            deleteError = "Erro ao gerar PDF: " + error.localizedDescription
        }
    }

    private func deleteQuoteAction(_ quote: QuoteRowItem) async {
        do {
            let change: OrderJSON = .object([
                "entity": .string("orcamentos"),
                "id": .string(quote.id),
                "before": .object(quote.raw),
                "after": .null
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "orcamentos")
            await loadQuotes()
            Task { await auth.loadDashboard() }
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Quote Detail View
struct QuoteDetailView: View {
    @ObservedObject var auth: AuthStore
    let quote: QuoteRowItem
    let onModified: () -> Void

    @State private var editing = false
    @State private var convertingToOS = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var pdfShareItem: PDFShareItem?
    @State private var currentStatus: String
    @State private var updatingStatus = false
    @State private var copiedLabel: String?
    @Environment(\.dismiss) private var dismiss

    init(auth: AuthStore, quote: QuoteRowItem, onModified: @escaping () -> Void) {
        self.auth = auth
        self.quote = quote
        self.onModified = onModified
        _currentStatus = State(initialValue: quote.status)
    }

    private var isAlertShowing: Binding<Bool> {
        Binding<Bool>(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )
    }

    var body: some View {
        List {
            // Header Hero
            Section {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text(quote.formattedNumber)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(String(format: "R$ %.2f", quote.total).replacingOccurrences(of: ".", with: ","))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                    }

                    // Seletor interativo de status
                    HStack {
                        Menu {
                            ForEach(QuoteStatusConfig.allStatuses, id: \.self) { s in
                                Button {
                                    Task { await changeStatus(to: s) }
                                } label: {
                                    if currentStatus == s {
                                        Label(s, systemImage: "checkmark")
                                    } else {
                                        Text(s)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: QuoteStatusConfig.icon(for: currentStatus))
                                Text(currentStatus)
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(QuoteStatusConfig.color(for: currentStatus), in: Capsule())
                        }

                        if quote.isExpired {
                            Text("⚠️ Vencido")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.12), in: Capsule())
                        }

                        Spacer()

                        if updatingStatus {
                            ProgressView().controlSize(.small)
                        }
                    }

                    // Botões de ação redondos
                    HStack(spacing: 16) {
                        actionRoundButton(icon: "message.fill", title: "WhatsApp", color: .green) {
                            WhatsAppHelper.sendQuoteWhatsApp(quote: quote.raw)
                        }

                        actionRoundButton(icon: "doc.text.fill", title: "PDF / Termo", color: .blue) {
                            printQuote()
                        }

                        if currentStatus == "Aprovado" && (quote.osId == nil || quote.osId?.isEmpty == true) {
                            actionRoundButton(icon: "wrench.and.screwdriver.fill", title: "Gerar OS", color: .indigo) {
                                convertingToOS = true
                            }
                        }

                        actionRoundButton(icon: "pencil", title: "Editar", color: .gray) {
                            editing = true
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Cliente
            Section("Cliente") {
                infoRow(icon: "person", label: "Nome", value: quote.clienteNome)
                if !quote.clienteTelefone.isEmpty {
                    HStack {
                        infoRow(icon: "phone", label: "Telefone / WhatsApp", value: quote.clienteTelefone)
                        Spacer()
                        Button {
                            let clean = quote.clienteTelefone.filter { $0.isNumber }
                            if let url = URL(string: "tel://\(clean)") { UIApplication.shared.open(url) }
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            WhatsAppHelper.openWhatsApp(phone: quote.clienteTelefone, message: "Olá, \(quote.clienteNome)!")
                        } label: {
                            Image(systemName: "message.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                                .padding(6)
                                .background(Color.green.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !quote.clienteDoc.isEmpty {
                    infoRow(icon: "doc.text", label: "CPF / CNPJ", value: quote.clienteDoc)
                }
            }

            // Aparelho & Defeito
            Section("Aparelho e Defeito") {
                infoRow(icon: quote.deviceIcon, label: "Aparelho", value: quote.deviceTitle)
                if !quote.aparelhoTipo.isEmpty {
                    infoRow(icon: "tag", label: "Tipo", value: quote.aparelhoTipo)
                }
                if !quote.aparelhoDefeito.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Defeito relatado")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(quote.aparelhoDefeito)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 2)
                }
                if !quote.diagnostico.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diagnóstico técnico")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(quote.diagnostico)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 2)
                }
            }

            // Peças, Mão de Obra e Valores
            Section("Peças e Valores da Proposta") {
                if !quote.pecas.isEmpty {
                    ForEach(quote.pecas) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.descricao)
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(Int(p.qtd)) × R$ " + String(format: "%.2f", p.valor).replacingOccurrences(of: ".", with: ","))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("R$ " + String(format: "%.2f", p.subtotal).replacingOccurrences(of: ".", with: ","))
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }

                if quote.maoDeObra > 0 {
                    HStack {
                        Text("Mão de obra técnica")
                            .font(.system(size: 13))
                        Spacer()
                        Text("R$ " + String(format: "%.2f", quote.maoDeObra).replacingOccurrences(of: ".", with: ","))
                            .font(.system(size: 13))
                    }
                }

                HStack {
                    Text("Total do Orçamento")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("R$ " + String(format: "%.2f", quote.total).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }

            // Validade & Datas
            Section("Datas e Observações") {
                infoRow(icon: "calendar", label: "Data de emissão", value: quote.formattedDate)
                if !quote.validade.isEmpty {
                    infoRow(icon: "clock", label: "Validade da proposta", value: quote.formattedValidityDate)
                }
                if !quote.observacoes.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Observações adicionais")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(quote.observacoes)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 2)
                }
            }

            // Excluir
            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    HStack {
                        Spacer()
                        if deleting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Excluir orçamento", systemImage: "trash.fill")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(deleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(quote.formattedNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            QuoteEditor(auth: auth, quoteID: quote.id) {
                onModified()
                dismiss()
            }
        }
        .sheet(isPresented: $convertingToOS) {
            OrderEditor(auth: auth, orderID: nil, prefillQuote: quote.raw) {
                onModified()
                dismiss()
            }
        }
        .sheet(item: $pdfShareItem) { share in
            ShareSheetView(activityItems: [share.url])
        }
        .confirmationDialog("Excluir Orçamento?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Excluir definitivamente", role: .destructive) {
                Task { await deleteQuote() }
            }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
        .alert("Aviso", isPresented: isAlertShowing) {
            Button("OK") { }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Action Buttons
    private func actionRoundButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
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
                copiedLabel = label
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedLabel == label { copiedLabel = nil }
                }
            } label: {
                Image(systemName: copiedLabel == label ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(copiedLabel == label ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func printQuote() {
        do {
            let url = try OrderPDFGenerator.generateQuote(quote: quote.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch {
            deleteError = "Erro ao gerar PDF: " + error.localizedDescription
        }
    }

    private func changeStatus(to newStatus: String) async {
        guard currentStatus != newStatus else { return }
        updatingStatus = true
        defer { updatingStatus = false }
        do {
            var updated = quote.raw
            updated["status"] = .string(newStatus)

            let change: OrderJSON = .object([
                "entity": .string("orcamentos"),
                "id": .string(quote.id),
                "before": .object(quote.raw),
                "after": .object(updated)
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "orcamentos")
            currentStatus = newStatus
            onModified()
            Task { await auth.loadDashboard() }
        } catch {
            deleteError = "Erro ao alterar status: " + error.localizedDescription
        }
    }

    private func deleteQuote() async {
        deleting = true
        deleteError = nil
        defer { deleting = false }
        do {
            let change: OrderJSON = .object([
                "entity": .string("orcamentos"),
                "id": .string(quote.id),
                "before": .object(quote.raw),
                "after": .null
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "orcamentos")
            onModified()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

