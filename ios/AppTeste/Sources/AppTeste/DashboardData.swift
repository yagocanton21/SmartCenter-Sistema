import Foundation

struct DashboardSnapshot: Decodable { let db: DashboardData }

struct DashboardData: Decodable {
    let os: [DashboardOrder]
    let vendas: [DashboardSale]
    let orcamentos: [DashboardQuote]
    let produtos: [DashboardProduct]
    let clientes: [MobileClient]?

    static let statuses = ["Recebido", "Em análise", "Aguardando aprovação", "Aguardando peças", "Em reparo", "Concluído", "Entregue"]
    func count(_ statuses: [String]) -> Int { os.filter { statuses.contains($0.status) }.count }
    var validSales: [DashboardSale] { vendas.filter { $0.status != "Cancelada" } }
    var pendingQuotes: [DashboardQuote] { orcamentos.filter { $0.status == "Pendente" } }
    var lowStock: Int { produtos.filter { $0.controla == true && ($0.estoque ?? 0) <= ($0.estoqueMin ?? 0) }.count }

    static func dateKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var overdue: Int {
        os.filter {
            guard let prazo = $0.prazo, !prazo.isEmpty else { return false }
            return prazo < Self.dateKey() && !["Concluído", "Entregue"].contains($0.status)
        }.count
    }

    func revenue(prefix: String) -> Double {
        let orders = os.filter {
            $0.status == "Entregue" && ($0.dataEntrega.flatMap { $0.isEmpty ? nil : $0 } ?? $0.dataEntrada ?? "").hasPrefix(prefix)
        }.reduce(0) { $0 + ($1.total ?? 0) }
        return orders + validSales.filter { ($0.data ?? "").hasPrefix(prefix) }.reduce(0) { $0 + ($1.total ?? 0) }
    }
}

struct DashboardOrder: Decodable {
    let id: String?
    let numero: Int?
    let clienteId: String?
    let cliSnap: MobileClient?
    let aparelho: MobileDevice?
    let diagnostico: String?
    let servico: String?
    let observacoes: String?
    let status: String
    let dataEntrada: String?
    let dataEntrega: String?
    let prazo: String?
    let total: Double?
}
struct DashboardSale: Decodable {
    let id: String?
    let numero: Int?
    let clienteId: String?
    let cliSnap: MobileClient?
    let status: String?
    let data: String?
    let total: Double?
}
struct DashboardQuote: Decodable {
    let id: String?
    let numero: Int?
    let clienteId: String?
    let cliSnap: MobileClient?
    let data: String?
    let aparelho: MobileDevice?
    let status: String?
    let total: Double?
}
struct DashboardProduct: Decodable {
    let id: String?
    let nome: String?
    let codigo: String?
    let preco: Double?
    let controla: Bool?
    let estoque: Double?
    let estoqueMin: Double?
}

struct MobileClient: Decodable {
    let id: String?
    let nome: String?
    let telefone: String?
    let email: String?
}

struct MobileDevice: Decodable {
    let marca: String?
    let modelo: String?
    let defeito: String?
    var name: String { [marca, modelo].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ") }
}
