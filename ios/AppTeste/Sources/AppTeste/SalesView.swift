import SwiftUI
import UIKit

// MARK: - Sale Models
struct SaleItemModel: Identifiable, Sendable {
    let id: String
    let produtoId: String?
    let descricao: String
    let qtd: Double
    let preco: Double
    let custo: Double

    var subtotal: Double {
        qtd * preco
    }
}

struct SaleRowItem: Identifiable, Sendable {
    let id: String
    let numero: Int
    let data: String
    let clienteId: String?
    let clienteNome: String
    let clienteTelefone: String
    let clienteDoc: String
    let itens: [SaleItemModel]
    let subtotal: Double
    let desconto: Double
    let total: Double
    let lucro: Double
    let formaPagamento: String
    let parcelas: Int
    let status: String
    let usuario: String
    let obs: String
    let raw: [String: OrderJSON]

    var shortNumber: String {
        String(format: "#%04d", numero)
    }

    var isCancelled: Bool {
        status == "Cancelada"
    }

    var formattedDate: String {
        guard !data.isEmpty else { return "" }
        let raw = String(data.prefix(19))
        let parts = raw.split(separator: "T")
        if parts.count == 2 {
            let dateParts = parts[0].split(separator: "-")
            let timeParts = parts[1].prefix(5)
            if dateParts.count == 3 {
                return "\(dateParts[2])/\(dateParts[1])/\(dateParts[0]) às \(timeParts)"
            }
        }
        return raw
    }

    var itemsSummary: String {
        guard !itens.isEmpty else { return "Sem itens" }
        let firstTwo = itens.prefix(2).map { "\(Int($0.qtd))× \($0.descricao)" }.joined(separator: ", ")
        if itens.count > 2 {
            return "\(firstTwo) +\(itens.count - 2) item(s)"
        }
        return firstTwo
    }
}

// MARK: - Main SalesView
struct SalesView: View {
    @ObservedObject var auth: AuthStore
    @State private var search = ""
    @State private var selectedStatusFilter = "Todas"
    @State private var loading = false
    @State private var fetchError: String?
    @State private var allSales: [SaleRowItem] = []
    @State private var clientsById: [String: [String: OrderJSON]] = [:]

    @State private var selectedSaleForDetail: SaleRowItem?
    @State private var pdfShareItem: PDFShareItem?
    @State private var saleToCancel: SaleRowItem?
    @State private var confirmCancel = false
    @State private var cancelling = false
    @State private var actionError: String?

    @State private var currentPage = 1
    private let pageSize = 10

    // MARK: - Computed Filters & Pagination
    private var filteredSales: [SaleRowItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allSales.filter { sale in
            if selectedStatusFilter != "Todas" && sale.status != selectedStatusFilter {
                return false
            }
            if q.isEmpty { return true }

            let numStr = String(sale.numero)
            let shortNum = sale.shortNumber.lowercased()
            let client = sale.clienteNome.lowercased()
            let phone = sale.clienteTelefone.lowercased()
            let pay = sale.formaPagamento.lowercased()
            let itemsDesc = sale.itens.map(\.descricao).joined(separator: " ").lowercased()

            return numStr.contains(q) || shortNum.contains(q) || client.contains(q) || phone.contains(q) || pay.contains(q) || itemsDesc.contains(q)
        }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(filteredSales.count) / Double(pageSize))))
    }

    private var paginatedSales: [SaleRowItem] {
        let start = (currentPage - 1) * pageSize
        guard start < filteredSales.count else { return [] }
        let end = min(start + pageSize, filteredSales.count)
        return Array(filteredSales[start..<end])
    }

    // MARK: - Financial Highlights
    private var completedSales: [SaleRowItem] {
        allSales.filter { !$0.isCancelled }
    }

    private var totalRevenue: Double {
        completedSales.reduce(0) { $0 + $1.total }
    }

    private var totalProfit: Double {
        completedSales.reduce(0) { $0 + $1.lucro }
    }

    private var averageTicket: Double {
        completedSales.isEmpty ? 0 : totalRevenue / Double(completedSales.count)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            mainScrollView
                .navigationTitle("Vendas")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar por nº, cliente, produto...")
                .refreshable {
                    await loadSales()
                }
                .sheet(item: $selectedSaleForDetail) { sale in
                    SaleDetailView(
                        sale: sale,
                        auth: auth,
                        onSaleCancelled: {
                            Task { await loadSales() }
                        }
                    )
                }
                .sheet(item: $pdfShareItem) { share in
                    ShareSheetView(activityItems: [share.url])
                }
                .confirmationDialog("Cancelar venda?", isPresented: $confirmCancel, titleVisibility: .visible) {
                    if let sale = saleToCancel {
                        Button("Cancelar Venda \(sale.shortNumber) e devolver estoque", role: .destructive) {
                            Task { await cancelSale(sale) }
                        }
                    }
                    Button("Voltar", role: .cancel) { saleToCancel = nil }
                } message: {
                    Text("Tem certeza que deseja cancelar esta venda? Os produtos vinculados serão automaticamente devolvidos ao estoque.")
                }
                .alert("Aviso", isPresented: Binding(
                    get: { actionError != nil },
                    set: { if !$0 { actionError = nil } }
                )) {
                    Button("OK", role: .cancel) { actionError = nil }
                } message: {
                    Text(actionError ?? "")
                }
        }
        .task {
            await loadSales()
        }
        .onChange(of: search) { _, _ in currentPage = 1 }
        .onChange(of: selectedStatusFilter) { _, _ in currentPage = 1 }
    }

    // MARK: - Subviews
    @ViewBuilder
    private var mainScrollView: some View {
        ScrollView {
            VStack(spacing: 14) {
                financialHighlightsView
                statusChipsScrollView

                if let fetchError {
                    errorBanner(fetchError)
                }

                if loading && allSales.isEmpty {
                    loadingIndicator
                } else if filteredSales.isEmpty {
                    emptyStateView
                } else {
                    salesCountBar
                    salesCardsList
                    paginationBar
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Financial Highlights Cards
    @ViewBuilder
    private var financialHighlightsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Card 1: Total Vendido
                highlightCard(
                    title: "Total Vendido",
                    value: String(format: "R$ %.2f", totalRevenue).replacingOccurrences(of: ".", with: ","),
                    icon: "chart.line.uptrend.xyaxis",
                    accent: .green,
                    badge: "\(completedSales.count) vendas"
                )

                // Card 2: Ticket Médio
                highlightCard(
                    title: "Ticket Médio",
                    value: String(format: "R$ %.2f", averageTicket).replacingOccurrences(of: ".", with: ","),
                    icon: "creditcard.fill",
                    accent: .blue,
                    badge: "Por compra"
                )

                // Card 3: Lucro Estimado
                if auth.user?.perfil == "admin" {
                    highlightCard(
                        title: "Lucro Estimado",
                        value: String(format: "R$ %.2f", totalProfit).replacingOccurrences(of: ".", with: ","),
                        icon: "dollarsign.circle.fill",
                        accent: .indigo,
                        badge: "Líquido"
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private func highlightCard(title: String, value: String, icon: String, accent: Color, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.12), in: Circle())
                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 160, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Status Filter Chips
    @ViewBuilder
    private var statusChipsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusChip(title: "Todas", count: allSales.count, isSelected: selectedStatusFilter == "Todas") {
                    selectedStatusFilter = "Todas"
                }

                let completedCount = allSales.filter { $0.status == "Concluída" }.count
                statusChip(title: "Concluídas", count: completedCount, color: .green, isSelected: selectedStatusFilter == "Concluída") {
                    selectedStatusFilter = "Concluída"
                }

                let cancelledCount = allSales.filter { $0.status == "Cancelada" }.count
                statusChip(title: "Canceladas", count: cancelledCount, color: .red, isSelected: selectedStatusFilter == "Cancelada") {
                    selectedStatusFilter = "Cancelada"
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func statusChip(title: String, count: Int, color: Color = .blue, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? color.opacity(0.2) : Color.primary.opacity(0.08), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? color : .primary)
            .background(
                isSelected ? color.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sales Count Bar
    @ViewBuilder
    private var salesCountBar: some View {
        HStack {
            Text("\(filteredSales.count) \(filteredSales.count == 1 ? "venda encontrada" : "vendas encontradas")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if loading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Cards List
    @ViewBuilder
    private var salesCardsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(paginatedSales) { sale in
                saleCard(sale)
            }
        }
    }

    // MARK: - Sale Card
    private func saleCard(_ sale: SaleRowItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Number + Status + Total
            HStack(alignment: .center, spacing: 8) {
                Text(sale.shortNumber)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                // Status Badge
                HStack(spacing: 4) {
                    Image(systemName: sale.isCancelled ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(sale.status)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(sale.isCancelled ? Color.red : Color.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((sale.isCancelled ? Color.red : Color.green).opacity(0.12), in: Capsule())

                Spacer()

                Text(String(format: "R$ %.2f", sale.total).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(sale.isCancelled ? .secondary : .primary)
            }

            Divider()
                .opacity(0.4)

            // Customer Row
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sale.clienteNome)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if !sale.clienteTelefone.isEmpty {
                        Text(sale.clienteTelefone)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Products Row
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                Text(sale.itemsSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(2)

                Spacer()
            }

            // Payment & Date Row
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    let parDesc = sale.parcelas > 1 ? "\(sale.formaPagamento) (\(sale.parcelas)x)" : sale.formaPagamento
                    Text(parDesc)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(sale.formattedDate)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .opacity(0.4)

            // Actions Bar
            HStack(spacing: 10) {
                // WhatsApp Button
                Button {
                    WhatsAppHelper.sendSaleWhatsApp(sale: sale.raw)
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .frame(width: 34, height: 34)
                        .background(Color.green.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                // PDF Comprovante Button
                Button {
                    printReceipt(sale)
                } label: {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                        .frame(width: 34, height: 34)
                        .background(Color.blue.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                // Cancel Sale Button (if still active)
                if !sale.isCancelled && auth.user?.can("vendas") == true {
                    Button {
                        saleToCancel = sale
                        confirmCancel = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 34, height: 34)
                            .background(Color.red.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Details Button
                Button {
                    selectedSaleForDetail = sale
                } label: {
                    HStack(spacing: 4) {
                        Text("Ver detalhes")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSaleForDetail = sale
        }
    }

    // MARK: - Pagination Bar
    @ViewBuilder
    private var paginationBar: some View {
        HStack {
            Button {
                if currentPage > 1 { currentPage -= 1 }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Anterior")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 1)
            .opacity(currentPage <= 1 ? 0.35 : 1.0)

            Spacer()

            VStack(spacing: 2) {
                Text("\(currentPage) / \(totalPages)")
                    .font(.system(size: 13, weight: .bold))
                Text("\(filteredSales.count) vendas · 10 por pág.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if currentPage < totalPages { currentPage += 1 }
            } label: {
                HStack(spacing: 4) {
                    Text("Próxima")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages)
            .opacity(currentPage >= totalPages ? 0.35 : 1.0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - Empty & Error Views
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(search.isEmpty ? "Nenhuma venda registrada" : "Nenhum resultado para \"\(search)\"")
                .font(.system(size: 16, weight: .semibold))
            Text(search.isEmpty ? "Vendas finalizadas no sistema serão exibidas aqui." : "Tente buscar por outro termo ou limpe os filtros.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !search.isEmpty || selectedStatusFilter != "Todas" {
                Button("Limpar filtros") {
                    search = ""
                    selectedStatusFilter = "Todas"
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.blue)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(msg)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
            Spacer()
            Button("Tentar novamente") {
                Task { await loadSales() }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.red)
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Carregando histórico de vendas...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Actions & Data Loading
    private func loadSales() async {
        loading = true
        fetchError = nil
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "vendas")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            let db = envelope["db"]?.object ?? envelope
            let salesList = db["vendas"]?.array ?? []
            let clientsList = db["clientes"]?.array ?? []

            var clientsMap: [String: [String: OrderJSON]] = [:]
            for c in clientsList {
                let obj = c.object
                if let cid = obj["id"]?.text, !cid.isEmpty {
                    clientsMap[cid] = obj
                }
            }
            clientsById = clientsMap

            allSales = salesList.compactMap { item -> SaleRowItem? in
                let v = item.object
                guard let id = v["id"]?.text, !id.isEmpty else { return nil }
                let cid = v["clienteId"]?.text ?? ""
                let snap = v["cliSnap"]?.object ?? clientsMap[cid] ?? [:]

                let items = (v["itens"]?.array ?? []).map { it -> SaleItemModel in
                    let obj = it.object
                    return SaleItemModel(
                        id: obj["id"]?.text ?? UUID().uuidString,
                        produtoId: obj["produtoId"]?.text,
                        descricao: obj["descricao"]?.text ?? "Item avulso",
                        qtd: obj["qtd"]?.number ?? 1,
                        preco: obj["preco"]?.number ?? 0,
                        custo: obj["custo"]?.number ?? 0
                    )
                }

                return SaleRowItem(
                    id: id,
                    numero: Int(v["numero"]?.number ?? 0),
                    data: v["data"]?.text ?? "",
                    clienteId: cid.isEmpty ? nil : cid,
                    clienteNome: snap["nome"]?.text ?? "Consumidor final",
                    clienteTelefone: snap["whatsapp"]?.text ?? (snap["telefone"]?.text ?? ""),
                    clienteDoc: snap["doc"]?.text ?? "",
                    itens: items,
                    subtotal: v["subtotal"]?.number ?? 0,
                    desconto: v["desconto"]?.number ?? 0,
                    total: v["total"]?.number ?? 0,
                    lucro: v["lucro"]?.number ?? 0,
                    formaPagamento: v["formaPagamento"]?.text ?? "À vista",
                    parcelas: Int(v["parcelas"]?.number ?? 1),
                    status: v["status"]?.text ?? "Concluída",
                    usuario: v["usuario"]?.text ?? "SmartCenter",
                    obs: v["obs"]?.text ?? "",
                    raw: v
                )
            }.sorted { $0.numero > $1.numero }

        } catch {
            fetchError = error.localizedDescription
        }
    }

    private func printReceipt(_ sale: SaleRowItem) {
        do {
            let url = try OrderPDFGenerator.generateSaleReceipt(sale: sale.raw)
            pdfShareItem = PDFShareItem(url: url)
        } catch {
            actionError = "Erro ao gerar comprovante: " + error.localizedDescription
        }
    }

    private func cancelSale(_ sale: SaleRowItem) async {
        cancelling = true
        defer {
            cancelling = false
            saleToCancel = nil
        }
        do {
            _ = try await auth.orderRequest("api/vendas/\(sale.id)/cancelar", body: Data("{}".utf8), permission: "vendas")
            await loadSales()
            Task { await auth.loadDashboard() }
        } catch {
            actionError = "Erro ao cancelar venda: " + error.localizedDescription
        }
    }
}

// MARK: - SaleDetailView (Inspector Modal)
struct SaleDetailView: View {
    let sale: SaleRowItem
    @ObservedObject var auth: AuthStore
    var onSaleCancelled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pdfShareItem: PDFShareItem?
    @State private var confirmCancel = false
    @State private var cancelling = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroHeaderView
                    customerCardView
                    itemsTableView
                    totalsCardView
                    paymentDetailsCardView

                    if !sale.obs.isEmpty {
                        obsCardView
                    }

                    actionButtonsView
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Venda \(sale.shortNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $pdfShareItem) { share in
                ShareSheetView(activityItems: [share.url])
            }
            .confirmationDialog("Cancelar venda?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Cancelar venda definitivamente", role: .destructive) {
                    Task { await cancelThisSale() }
                }
                Button("Voltar", role: .cancel) {}
            } message: {
                Text("Esta ação cancelará a venda \(sale.shortNumber) e devolverá todos os produtos ao estoque.")
            }
            .alert("Erro", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Detail Subviews
    @ViewBuilder
    private var heroHeaderView: some View {
        VStack(spacing: 10) {
            HStack {
                Text(sale.shortNumber)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: sale.isCancelled ? "xmark.circle.fill" : "checkmark.circle.fill")
                    Text(sale.status)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(sale.isCancelled ? Color.red : Color.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((sale.isCancelled ? Color.red : Color.green).opacity(0.12), in: Capsule())
            }

            VStack(spacing: 4) {
                Text(String(format: "R$ %.2f", sale.total).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(sale.isCancelled ? .secondary : .primary)

                Text("Realizada em \(sale.formattedDate)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var customerCardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("DADOS DO CLIENTE", systemImage: "person.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sale.clienteNome)
                        .font(.system(size: 15, weight: .semibold))
                    if !sale.clienteTelefone.isEmpty {
                        Text(sale.clienteTelefone)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    if !sale.clienteDoc.isEmpty {
                        Text("Doc: \(sale.clienteDoc)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if !sale.clienteTelefone.isEmpty {
                    HStack(spacing: 10) {
                        Button {
                            WhatsAppHelper.sendSaleWhatsApp(sale: sale.raw)
                        } label: {
                            Image(systemName: "message.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                                .frame(width: 36, height: 36)
                                .background(Color.green.opacity(0.12), in: Circle())
                        }

                        if let phoneURL = URL(string: "tel://\(WhatsAppHelper.cleanPhone(sale.clienteTelefone))") {
                            Link(destination: phoneURL) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                                    .frame(width: 36, height: 36)
                                    .background(Color.blue.opacity(0.12), in: Circle())
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var itemsTableView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ITENS DA VENDA", systemImage: "cart.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(sale.itens) { item in
                    HStack(alignment: .top) {
                        Text("\(Int(item.qtd))×")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.blue)
                            .frame(width: 30, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.descricao)
                                .font(.system(size: 13, weight: .medium))
                            Text(String(format: "Unitário: R$ %.2f", item.preco).replacingOccurrences(of: ".", with: ","))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(String(format: "R$ %.2f", item.subtotal).replacingOccurrences(of: ".", with: ","))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    if item.id != sale.itens.last?.id {
                        Divider()
                            .opacity(0.4)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var totalsCardView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Subtotal")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "R$ %.2f", sale.subtotal).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 13, weight: .medium))
            }

            if sale.desconto > 0 {
                HStack {
                    Text("Desconto")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                    Spacer()
                    Text(String(format: "- R$ %.2f", sale.desconto).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(String(format: "R$ %.2f", sale.total).replacingOccurrences(of: ".", with: ","))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
            }

            if auth.user?.perfil == "admin" && sale.lucro > 0 {
                HStack {
                    Text("Lucro estimado")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "R$ %.2f", sale.lucro).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var paymentDetailsCardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("PAGAMENTO E ATENDIMENTO", systemImage: "creditcard.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Forma de Pagamento:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                let parDesc = sale.parcelas > 1 ? "\(sale.formaPagamento) em \(sale.parcelas)x" : sale.formaPagamento
                Text(parDesc)
                    .font(.system(size: 12, weight: .semibold))
            }

            HStack {
                Text("Atendente / Vendedor:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sale.usuario)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var obsCardView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("OBSERVAÇÕES", systemImage: "text.bubble.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text(sale.obs)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var actionButtonsView: some View {
        VStack(spacing: 10) {
            // Print / Share PDF
            Button {
                do {
                    let url = try OrderPDFGenerator.generateSaleReceipt(sale: sale.raw)
                    pdfShareItem = PDFShareItem(url: url)
                } catch {
                    errorMessage = "Erro ao gerar comprovante: " + error.localizedDescription
                }
            } label: {
                Label("Imprimir Comprovante PDF", systemImage: "printer.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
            }

            // WhatsApp Receipt
            Button {
                WhatsAppHelper.sendSaleWhatsApp(sale: sale.raw)
            } label: {
                Label("Enviar Comprovante via WhatsApp", systemImage: "message.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
            }

            // Cancel Sale
            if !sale.isCancelled && auth.user?.can("vendas") == true {
                Button(role: .destructive) {
                    confirmCancel = true
                } label: {
                    Label("Cancelar Venda (Devolver Estoque)", systemImage: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    private func cancelThisSale() async {
        cancelling = true
        defer { cancelling = false }
        do {
            _ = try await auth.orderRequest("api/vendas/\(sale.id)/cancelar", body: Data("{}".utf8), permission: "vendas")
            onSaleCancelled()
            dismiss()
        } catch {
            errorMessage = "Erro ao cancelar venda: " + error.localizedDescription
        }
    }
}

