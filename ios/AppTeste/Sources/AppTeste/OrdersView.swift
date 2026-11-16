import SwiftUI
import UIKit

// MARK: - Status Helpers & Constants
enum OSStatusConfig {
    static let allStatuses = [
        "Recebido",
        "Em análise",
        "Aguardando aprovação",
        "Aguardando peças",
        "Em reparo",
        "Concluído",
        "Entregue"
    ]

    static func icon(for status: String) -> String {
        switch status {
        case "Recebido": return "tray.and.arrow.down.fill"
        case "Em análise": return "magnifyingglass.circle.fill"
        case "Aguardando aprovação": return "hourglass.circle.fill"
        case "Aguardando peças": return "shippingbox.circle.fill"
        case "Em reparo": return "wrench.and.screwdriver.fill"
        case "Concluído": return "checkmark.seal.fill"
        case "Entregue": return "hand.thumbsup.fill"
        default: return "circle.fill"
        }
    }

    static func color(for status: String) -> Color {
        switch status {
        case "Recebido": return Color.blue
        case "Em análise": return Color.orange
        case "Aguardando aprovação": return Color.purple
        case "Aguardando peças": return Color(red: 0.85, green: 0.65, blue: 0.15) // Amber
        case "Em reparo": return Color(red: 0.15, green: 0.45, blue: 0.95) // Royal blue
        case "Concluído": return Color(red: 0.10, green: 0.70, blue: 0.55) // Mint
        case "Entregue": return Color.green
        default: return Color.secondary
        }
    }
}

// MARK: - Order Part Model
struct OrderPartItem: Identifiable, Sendable {
    let id = UUID()
    let descricao: String
    let qtd: Double
    let valor: Double
    let subtotal: Double
}

// MARK: - Order Row Item Model
struct OrderRowItem: Identifiable, Sendable {
    let id: String
    let numero: Int
    let dataEntrada: String
    let prazo: String
    let dataConclusao: String
    let dataEntrega: String
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
    let aparelhoCor: String
    let aparelhoSerial: String
    let aparelhoCondicoes: String
    let aparelhoAcessorios: String
    let aparelhoDefeito: String
    let diagnostico: String
    let servico: String
    let observacoes: String
    let lockType: String
    let password: String
    let patternSequence: String
    let checklist: [String: String]
    let checklistObs: String
    let pecas: [OrderPartItem]
    let historico: [OrderJSON]
    let garantiaDias: Int
    let formaPagamento: String
    let raw: [String: OrderJSON]

    var formattedNumber: String {
        String(format: "#%06d", numero)
    }

    var shortNumber: String {
        String(format: "#%04d", numero)
    }

    var deviceTitle: String {
        let parts = [aparelhoMarca, aparelhoModelo].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if parts.isEmpty {
            return aparelhoTipo.isEmpty ? "Aparelho" : aparelhoTipo
        }
        return parts.joined(separator: " ")
    }

    var deviceSubtitle: String {
        var items: [String] = []
        if !aparelhoTipo.isEmpty { items.append(aparelhoTipo) }
        if !aparelhoCor.isEmpty { items.append(aparelhoCor) }
        if !aparelhoSerial.isEmpty { items.append("IMEI: \(aparelhoSerial)") }
        return items.joined(separator: " · ")
    }

    var deviceIcon: String {
        switch aparelhoTipo.lowercased() {
        case "celular": return "iphone"
        case "tablet": return "ipad"
        case "notebook": return "laptopcomputer"
        case "computador": return "desktopcomputer"
        case "console / videogame", "console": return "gamecontroller"
        case "smartwatch": return "applewatch"
        default: return "wrench.and.screwdriver"
        }
    }

    var isLate: Bool {
        guard !prazo.isEmpty, status != "Concluído", status != "Entregue" else { return false }
        let rawDate = String(prazo.prefix(10))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        if let dt = f.date(from: rawDate) {
            return dt < Calendar.current.startOfDay(for: Date())
        }
        return false
    }

    var formattedEntryDate: String {
        formatDate(dataEntrada)
    }

    var formattedDeadlineDate: String {
        formatDate(prazo)
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

// MARK: - Main Orders View
struct OrdersView: View {
    @ObservedObject var auth: AuthStore
    @State private var search = ""
    @State private var selectedStatusFilter = "Todas"
    @State private var loading = false
    @State private var fetchError: String?
    @State private var allOrders: [OrderRowItem] = []
    @State private var clientsById: [String: [String: OrderJSON]] = [:]

    @State private var creatingOrder = false
    @State private var editingOrderID: String?
    @State private var orderToDelete: OrderRowItem?
    @State private var confirmDelete = false
    @State private var deleteError: String?
    @State private var pdfShareItem: PDFShareItem?
    @State private var generatingPDF = false

    @State private var currentPage = 1
    private let pageSize = 10

    // MARK: - Filters & Computeds
    private var lateOrdersCount: Int {
        allOrders.filter(\.isLate).count
    }

    private var filteredOrders: [OrderRowItem] {
        var list = allOrders

        if selectedStatusFilter == "atrasadas" {
            list = list.filter(\.isLate)
        } else if selectedStatusFilter != "Todas" {
            list = list.filter { $0.status == selectedStatusFilter }
        }

        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !term.isEmpty {
            let termDigits = term.filter(\.isNumber)
            list = list.filter { o in
                let matchNum = String(o.numero).contains(term) || o.formattedNumber.lowercased().contains(term)
                let matchCli = o.clienteNome.lowercased().contains(term)
                let matchDev = o.deviceTitle.lowercased().contains(term) || o.aparelhoSerial.lowercased().contains(term)
                let matchPhone = !termDigits.isEmpty && o.clienteTelefone.filter(\.isNumber).contains(termDigits)
                let matchDoc = !termDigits.isEmpty && o.clienteDoc.filter(\.isNumber).contains(termDigits)
                let matchDefect = o.aparelhoDefeito.lowercased().contains(term)
                return matchNum || matchCli || matchDev || matchPhone || matchDoc || matchDefect
            }
        }

        return list
    }

    private var pageCount: Int {
        max(1, (filteredOrders.count + pageSize - 1) / pageSize)
    }

    private var paginatedOrders: [OrderRowItem] {
        let start = (currentPage - 1) * pageSize
        guard start < filteredOrders.count else { return [] }
        let end = min(start + pageSize, filteredOrders.count)
        return Array(filteredOrders[start..<end])
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
                .navigationTitle("Ordens de serviço")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "Buscar por nº, cliente, modelo, IMEI…")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            creatingOrder = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Nova OS")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !filteredOrders.isEmpty {
                        paginationBar
                    }
                }
                .onChange(of: currentPage) { _, _ in
                    withAnimation { proxy.scrollTo("top", anchor: .top) }
                }
                .onChange(of: search) { _, _ in currentPage = 1 }
                .onChange(of: selectedStatusFilter) { _, _ in currentPage = 1 }
                .refreshable { await loadOrders() }
                .task { await loadOrders() }
                .sheet(isPresented: $creatingOrder) {
                    OrderEditor(auth: auth, orderID: nil) {
                        Task { await loadOrders() }
                    }
                }
                .sheet(item: Binding<IdentifiableString?>(
                    get: { editingOrderID.map { IdentifiableString(value: $0) } },
                    set: { editingOrderID = $0?.value }
                )) { item in
                    OrderEditor(auth: auth, orderID: item.value) {
                        Task { await loadOrders() }
                    }
                }
                .sheet(item: $pdfShareItem) { share in
                    ShareSheetView(activityItems: [share.url])
                }
                .confirmationDialog("Excluir Ordem de Serviço?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    if let order = orderToDelete {
                        Button("Excluir OS \(order.formattedNumber)", role: .destructive) {
                            Task { await deleteOrderAction(order) }
                        }
                    }
                } message: {
                    Text("Esta ação não pode ser desfeita. Peças baixadas retornarão ao estoque.")
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
                ordersHeaderCountBar

                if let fetchError {
                    errorBanner(fetchError)
                }

                if loading && allOrders.isEmpty {
                    loadingIndicator
                } else if filteredOrders.isEmpty {
                    emptyStateView
                } else {
                    ordersCardsList
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var ordersHeaderCountBar: some View {
        HStack {
            Text("\(filteredOrders.count) ordens de serviço")
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
            Button("Tentar novamente") { Task { await loadOrders() } }
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
            Text("Carregando ordens de serviço…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nenhuma OS encontrada")
                .font(.headline)
            Text(search.isEmpty && selectedStatusFilter == "Todas"
                 ? "Toque no botão + no topo para abrir sua primeira ordem de serviço."
                 : "Nenhuma OS corresponde aos filtros selecionados.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    private var ordersCardsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(paginatedOrders) { order in
                NavigationLink {
                    OrderDetailView(
                        auth: auth,
                        order: order,
                        onModified: { Task { await loadOrders() } }
                    )
                } label: {
                    orderCard(order)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        sendWhatsApp(order)
                    } label: {
                        Label("WhatsApp", systemImage: "message.fill")
                    }

                    Button {
                        printOS(order)
                    } label: {
                        Label("Imprimir OS (Termo)", systemImage: "printer.fill")
                    }

                    Button {
                        printLabel(order)
                    } label: {
                        Label("Etiqueta de Bancada", systemImage: "tag.fill")
                    }

                    Button {
                        editingOrderID = order.id
                    } label: {
                        Label("Editar OS", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        orderToDelete = order
                        confirmDelete = true
                    } label: {
                        Label("Excluir OS", systemImage: "trash")
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
                // Todas
                chipButton(
                    title: "Todas",
                    count: allOrders.count,
                    isSelected: selectedStatusFilter == "Todas",
                    color: .blue
                ) {
                    selectedStatusFilter = "Todas"
                }

                // Apenas Atrasadas (se houver)
                if lateOrdersCount > 0 {
                    chipButton(
                        title: "⚠️ Atrasadas",
                        count: lateOrdersCount,
                        isSelected: selectedStatusFilter == "atrasadas",
                        color: .red
                    ) {
                        selectedStatusFilter = "atrasadas"
                    }
                }

                // Status individuais
                ForEach(OSStatusConfig.allStatuses, id: \.self) { status in
                    let count = allOrders.filter { $0.status == status }.count
                    chipButton(
                        title: status,
                        count: count,
                        isSelected: selectedStatusFilter == status,
                        color: OSStatusConfig.color(for: status)
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

    // MARK: - Order Card Component
    private func orderCard(_ order: OrderRowItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Número, Status interativo, Alerta de atraso, Total
            HStack(alignment: .center, spacing: 8) {
                // Número em destaque estilo pill
                Text(order.shortNumber)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))

                // Badge de Status (Interativo via Menu com chevron)
                Menu {
                    ForEach(OSStatusConfig.allStatuses, id: \.self) { s in
                        Button {
                            Task { await changeOrderStatus(order, to: s) }
                        } label: {
                            if order.status == s {
                                Label(s, systemImage: "checkmark")
                            } else {
                                Text(s)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: OSStatusConfig.icon(for: order.status))
                            .font(.system(size: 10))
                        Text(order.status)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(OSStatusConfig.color(for: order.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OSStatusConfig.color(for: order.status).opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)

                // Alerta Atrasada
                if order.isLate {
                    Text("Atrasada")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.12), in: Capsule())
                }

                Spacer()

                // Total
                Text(String(format: "R$ %.2f", order.total).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Divider()

            // Aparelho & Cliente
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: order.deviceIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
                    .frame(width: 38, height: 38)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(order.deviceTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !order.deviceSubtitle.isEmpty {
                        Text(order.deviceSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(order.clienteNome)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if !order.clienteTelefone.isEmpty {
                            Text("· " + order.clienteTelefone)
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
            if !order.aparelhoDefeito.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "wrench.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                    Text(order.aparelhoDefeito)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }

            // Rodapé do Card: Datas & Ações Rápidas circulares limpas
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Entrada:").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(order.formattedEntryDate).font(.system(size: 11, weight: .medium)).foregroundStyle(.primary)
                    }
                    if !order.prazo.isEmpty {
                        HStack(spacing: 4) {
                            Text("Prazo:").font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(order.formattedDeadlineDate)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(order.isLate ? Color.red : Color.primary)
                        }
                    }
                }

                Spacer()

                // Botões de Ação Rápida Circulares (sem quebra de linha)
                HStack(spacing: 10) {
                    // WhatsApp
                    Button {
                        sendWhatsApp(order)
                    } label: {
                        Image(systemName: "message.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                            .frame(width: 34, height: 34)
                            .background(Color.green.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Enviar WhatsApp")

                    // Menu Imprimir PDF
                    Menu {
                        Button {
                            printOS(order)
                        } label: {
                            Label("Termo de Entrada (OS)", systemImage: "doc.text.fill")
                        }

                        Button {
                            printLabel(order)
                        } label: {
                            Label("Etiqueta de Bancada", systemImage: "tag.fill")
                        }

                        if order.status == "Concluído" || order.status == "Entregue" {
                            Button {
                                printOS(order)
                            } label: {
                                Label("Termo de Garantia", systemImage: "checkmark.seal.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 34, height: 34)
                            .background(Color.blue.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Imprimir ou Salvar PDF")

                    // Alterar Status Rápido
                    Menu {
                        ForEach(OSStatusConfig.allStatuses, id: \.self) { s in
                            Button {
                                Task { await changeOrderStatus(order, to: s) }
                            } label: {
                                if order.status == s {
                                    Label(s, systemImage: "checkmark")
                                } else {
                                    Text(s)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.purple)
                            .frame(width: 34, height: 34)
                            .background(Color.purple.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Alterar status")
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(order.isLate ? Color.red.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: order.isLate ? 1.5 : 1)
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
                Text("\(filteredOrders.count) OSs · 10 por pág.")
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
    private func loadOrders() async {
        loading = true
        fetchError = nil
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "os")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let db = envelope["db"]?.object ?? envelope
            let osList = db["os"]?.array ?? []
            let clientesList = db["clientes"]?.array ?? []

            var clientsMap: [String: [String: OrderJSON]] = [:]
            for c in clientesList {
                let obj = c.object
                if let cid = obj["id"]?.text, !cid.isEmpty {
                    clientsMap[cid] = obj
                }
            }
            clientsById = clientsMap

            allOrders = osList.compactMap { item -> OrderRowItem? in
                let o = item.object
                guard let id = o["id"]?.text, !id.isEmpty else { return nil }
                let dev = o["aparelho"]?.object ?? [:]
                let cid = o["clienteId"]?.text ?? ""
                let snap = o["cliSnap"]?.object ?? clientsMap[cid] ?? [:]

                let parts = (o["pecas"]?.array ?? []).map { p -> OrderPartItem in
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

                var checkMap: [String: String] = [:]
                if let ck = dev["checklist"]?.object {
                    for (k, v) in ck { checkMap[k] = v.text }
                }

                return OrderRowItem(
                    id: id,
                    numero: Int(o["numero"]?.number ?? 0),
                    dataEntrada: o["dataEntrada"]?.text ?? "",
                    prazo: o["prazo"]?.text ?? "",
                    dataConclusao: o["dataConclusao"]?.text ?? "",
                    dataEntrega: o["dataEntrega"]?.text ?? "",
                    status: o["status"]?.text ?? "Recebido",
                    total: o["total"]?.number ?? 0,
                    maoDeObra: o["maoDeObra"]?.number ?? 0,
                    valorPecas: o["valorPecas"]?.number ?? 0,
                    clienteId: cid,
                    clienteNome: snap["nome"]?.text ?? "Cliente",
                    clienteTelefone: snap["whatsapp"]?.text ?? (snap["telefone"]?.text ?? ""),
                    clienteDoc: snap["doc"]?.text ?? "",
                    aparelhoTipo: dev["tipo"]?.text ?? "Celular",
                    aparelhoMarca: dev["marca"]?.text ?? "",
                    aparelhoModelo: dev["modelo"]?.text ?? "",
                    aparelhoCor: dev["cor"]?.text ?? "",
                    aparelhoSerial: dev["imei"]?.text ?? (dev["serial"]?.text ?? ""),
                    aparelhoCondicoes: dev["condicoes"]?.text ?? "",
                    aparelhoAcessorios: dev["acessorios"]?.text ?? "",
                    aparelhoDefeito: dev["defeito"]?.text ?? "",
                    diagnostico: o["diagnostico"]?.text ?? "",
                    servico: o["servico"]?.text ?? "",
                    observacoes: o["observacoes"]?.text ?? "",
                    lockType: dev["senhaTipo"]?.text ?? "nenhuma",
                    password: dev["senha"]?.text ?? "",
                    patternSequence: dev["senhaPadrao"]?.text ?? "",
                    checklist: checkMap,
                    checklistObs: dev["checklistObs"]?.text ?? "",
                    pecas: parts,
                    historico: o["historico"]?.array ?? [],
                    garantiaDias: Int(o["garantiaDias"]?.number ?? 90),
                    formaPagamento: o["formaPagamento"]?.text ?? "",
                    raw: o
                )
            }.sorted { $0.numero > $1.numero }
        } catch {
            fetchError = error.localizedDescription
        }
    }

    private func changeOrderStatus(_ order: OrderRowItem, to newStatus: String) async {
        guard order.status != newStatus else { return }
        do {
            var updated = order.raw
            updated["status"] = .string(newStatus)

            var hist = updated["historico"]?.array ?? []
            let newHistEntry: [String: OrderJSON] = [
                "status": .string(newStatus),
                "data": .string(ISO8601DateFormatter().string(from: Date())),
                "usuario": .string(auth.user?.nome ?? "Mobile")
            ]
            hist.append(.object(newHistEntry))
            updated["historico"] = .array(hist)

            let isFim = newStatus == "Concluído" || newStatus == "Entregue"
            if isFim {
                if updated["dataConclusao"] == nil || updated["dataConclusao"]?.text.isEmpty == true {
                    updated["dataConclusao"] = .string(ISO8601DateFormatter().string(from: Date()))
                }
            } else {
                updated["dataConclusao"] = .null
            }

            if newStatus == "Entregue" {
                if updated["dataEntrega"] == nil || updated["dataEntrega"]?.text.isEmpty == true {
                    updated["dataEntrega"] = .string(ISO8601DateFormatter().string(from: Date()))
                }
            } else {
                updated["dataEntrega"] = .null
            }

            let change: OrderJSON = .object([
                "entity": .string("os"),
                "id": .string(order.id),
                "before": .object(order.raw),
                "after": .object(updated)
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "os")
            await loadOrders()
            Task { await auth.loadDashboard() }
        } catch {
            deleteError = "Erro ao alterar status: " + error.localizedDescription
        }
    }

    private func sendWhatsApp(_ order: OrderRowItem) {
        WhatsAppHelper.sendOSWhatsApp(order: order.raw)
    }

    private func printOS(_ order: OrderRowItem) {
        do {
            let url = try OrderPDFGenerator.generate(order: order.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch {
            deleteError = "Erro ao gerar PDF: " + error.localizedDescription
        }
    }

    private func printLabel(_ order: OrderRowItem) {
        do {
            let url = try OrderPDFGenerator.generateLabel(order: order.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch {
            deleteError = "Erro ao gerar etiqueta: " + error.localizedDescription
        }
    }

    private func deleteOrderAction(_ order: OrderRowItem) async {
        do {
            let change: OrderJSON = .object([
                "entity": .string("os"),
                "id": .string(order.id),
                "before": .object(order.raw),
                "after": .null
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "os")
            await loadOrders()
            Task { await auth.loadDashboard() }
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Order Detail View
struct OrderDetailView: View {
    @ObservedObject var auth: AuthStore
    let order: OrderRowItem
    let onModified: () -> Void

    @State private var editing = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?
    @State private var pdfShareItem: PDFShareItem?
    @State private var currentStatus: String
    @State private var updatingStatus = false
    @State private var copiedLabel: String?
    @State private var patternState = ""
    @Environment(\.dismiss) private var dismiss

    init(auth: AuthStore, order: OrderRowItem, onModified: @escaping () -> Void) {
        self.auth = auth
        self.order = order
        self.onModified = onModified
        _currentStatus = State(initialValue: order.status)
        _patternState = State(initialValue: order.patternSequence)
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
                        Text(order.formattedNumber)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(String(format: "R$ %.2f", order.total).replacingOccurrences(of: ".", with: ","))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                    }

                    // Seletor interativo de status
                    HStack {
                        Menu {
                            ForEach(OSStatusConfig.allStatuses, id: \.self) { s in
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
                                Image(systemName: OSStatusConfig.icon(for: currentStatus))
                                Text(currentStatus)
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(OSStatusConfig.color(for: currentStatus), in: Capsule())
                        }

                        if order.isLate {
                            Text("⚠️ Atrasada")
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
                            WhatsAppHelper.sendOSWhatsApp(order: order.raw)
                        }

                        actionRoundButton(icon: "doc.text.fill", title: "Termo / OS", color: .blue) {
                            printOS()
                        }

                        actionRoundButton(icon: "tag.fill", title: "Etiqueta", color: .purple) {
                            printLabel()
                        }

                        if currentStatus == "Concluído" || currentStatus == "Entregue" {
                            actionRoundButton(icon: "checkmark.seal.fill", title: "Garantia", color: .teal) {
                                printOS()
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
                infoRow(icon: "person", label: "Nome", value: order.clienteNome)
                if !order.clienteTelefone.isEmpty {
                    HStack {
                        infoRow(icon: "phone", label: "Telefone / WhatsApp", value: order.clienteTelefone)
                        Spacer()
                        Button {
                            let clean = order.clienteTelefone.filter { $0.isNumber }
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
                            WhatsAppHelper.openWhatsApp(phone: order.clienteTelefone, message: "Olá, \(order.clienteNome)!")
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
                if !order.clienteDoc.isEmpty {
                    infoRow(icon: "doc.text", label: "CPF / CNPJ", value: order.clienteDoc)
                }
            }

            // Aparelho & Segurança
            Section("Aparelho & Segurança") {
                infoRow(icon: order.deviceIcon, label: "Modelo", value: order.deviceTitle)
                if !order.aparelhoTipo.isEmpty {
                    infoRow(icon: "tag", label: "Tipo", value: order.aparelhoTipo)
                }
                if !order.aparelhoCor.isEmpty {
                    infoRow(icon: "paintpalette", label: "Cor", value: order.aparelhoCor)
                }
                if !order.aparelhoSerial.isEmpty {
                    infoRow(icon: "barcode", label: "IMEI / Nº de Série", value: order.aparelhoSerial)
                }
                if !order.aparelhoCondicoes.isEmpty {
                    infoRow(icon: "hand.raised", label: "Condições físicas", value: order.aparelhoCondicoes)
                }
                if !order.aparelhoAcessorios.isEmpty {
                    infoRow(icon: "cable.connector", label: "Acessórios deixados", value: order.aparelhoAcessorios)
                }

                // Senha / Bloqueio
                if order.lockType == "alfa" && !order.password.isEmpty {
                    infoRow(icon: "key.fill", label: "PIN / Senha de desbloqueio", value: order.password)
                } else if order.lockType == "padrao" && !patternState.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.pattern.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("Padrão de desbloqueio")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        PatternLockView(sequence: $patternState)
                            .frame(height: 220)
                            .allowsHitTesting(false)
                    }
                    .padding(.vertical, 4)
                } else {
                    infoRow(icon: "lock.open", label: "Bloqueio", value: "Sem senha informada")
                }
            }

            // Checklist de Entrada
            if !order.checklist.isEmpty {
                Section("Checklist de entrada") {
                    ForEach(allChecklistItems) { item in
                        if let status = order.checklist[item.id], status != "nt" {
                            HStack {
                                Text(item.label)
                                    .font(.system(size: 13))
                                Spacer()
                                if status == "ok" {
                                    Text("OK")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.12), in: Capsule())
                                } else if status == "def" {
                                    Text("Defeito")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                    if !order.checklistObs.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Observações do checklist")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(order.checklistObs)
                                .font(.system(size: 13))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Laudo & Serviços
            Section("Laudo & Serviços") {
                if !order.aparelhoDefeito.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Defeito relatado")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(order.aparelhoDefeito)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 2)
                }
                if !order.diagnostico.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diagnóstico técnico")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(order.diagnostico)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 2)
                }
                if !order.servico.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Serviço realizado")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(order.servico)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 2)
                }
                if !order.observacoes.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Observações gerais")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(order.observacoes)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 2)
                }
                infoRow(icon: "calendar", label: "Data de entrada", value: order.formattedEntryDate)
                if !order.prazo.isEmpty {
                    infoRow(icon: "clock", label: "Prazo previsto", value: order.formattedDeadlineDate)
                }
                infoRow(icon: "shield", label: "Garantia", value: "\(order.garantiaDias) dias")
            }

            // Peças & Valores
            Section("Peças, Serviços e Valores") {
                if !order.pecas.isEmpty {
                    ForEach(order.pecas) { p in
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

                if order.maoDeObra > 0 {
                    HStack {
                        Text("Mão de obra técnica")
                            .font(.system(size: 13))
                        Spacer()
                        Text("R$ " + String(format: "%.2f", order.maoDeObra).replacingOccurrences(of: ".", with: ","))
                            .font(.system(size: 13))
                    }
                }

                HStack {
                    Text("Total")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("R$ " + String(format: "%.2f", order.total).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.blue)
                }

                if !order.formaPagamento.isEmpty {
                    infoRow(icon: "creditcard", label: "Forma de pagamento", value: order.formaPagamento)
                }
            }

            // Linha do tempo / Histórico
            OrderTimelineView(history: order.historico)

            // Excluir OS
            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    HStack {
                        Spacer()
                        if deleting {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Excluir ordem de serviço", systemImage: "trash.fill")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(deleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(order.formattedNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            OrderEditor(auth: auth, orderID: order.id) {
                onModified()
                dismiss()
            }
        }
        .sheet(item: $pdfShareItem) { share in
            ShareSheetView(activityItems: [share.url])
        }
        .confirmationDialog("Excluir Ordem de Serviço?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Excluir definitivamente", role: .destructive) {
                Task { await deleteOrder() }
            }
        } message: {
            Text("Esta ação não pode ser desfeita. Peças baixadas retornarão ao estoque.")
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

    private func printOS() {
        do {
            let url = try OrderPDFGenerator.generate(order: order.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch {
            deleteError = "Erro ao gerar PDF: " + error.localizedDescription
        }
    }

    private func printLabel() {
        do {
            let url = try OrderPDFGenerator.generateLabel(order: order.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch {
            deleteError = "Erro ao gerar etiqueta: " + error.localizedDescription
        }
    }

    private func changeStatus(to newStatus: String) async {
        guard currentStatus != newStatus else { return }
        updatingStatus = true
        defer { updatingStatus = false }
        do {
            var updated = order.raw
            updated["status"] = .string(newStatus)

            var hist = updated["historico"]?.array ?? []
            let newHistEntry: [String: OrderJSON] = [
                "status": .string(newStatus),
                "data": .string(ISO8601DateFormatter().string(from: Date())),
                "usuario": .string(auth.user?.nome ?? "Mobile")
            ]
            hist.append(.object(newHistEntry))
            updated["historico"] = .array(hist)

            let isFim = newStatus == "Concluído" || newStatus == "Entregue"
            if isFim {
                if updated["dataConclusao"] == nil || updated["dataConclusao"]?.text.isEmpty == true {
                    updated["dataConclusao"] = .string(ISO8601DateFormatter().string(from: Date()))
                }
            } else {
                updated["dataConclusao"] = .null
            }

            if newStatus == "Entregue" {
                if updated["dataEntrega"] == nil || updated["dataEntrega"]?.text.isEmpty == true {
                    updated["dataEntrega"] = .string(ISO8601DateFormatter().string(from: Date()))
                }
            } else {
                updated["dataEntrega"] = .null
            }

            let change: OrderJSON = .object([
                "entity": .string("os"),
                "id": .string(order.id),
                "before": .object(order.raw),
                "after": .object(updated)
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "os")
            currentStatus = newStatus
            onModified()
            Task { await auth.loadDashboard() }
        } catch {
            deleteError = "Erro ao alterar status: " + error.localizedDescription
        }
    }

    private func deleteOrder() async {
        deleting = true
        deleteError = nil
        defer { deleting = false }
        do {
            let change: OrderJSON = .object([
                "entity": .string("os"),
                "id": .string(order.id),
                "before": .object(order.raw),
                "after": .null
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "os")
            onModified()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
