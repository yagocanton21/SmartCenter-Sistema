import Foundation
import UIKit
import SwiftUI

enum WhatsAppTemplate: String, CaseIterable, Identifiable, Sendable {
    case abertura = "Recebimento (Abertura da OS)"
    case status = "Atualização de status"
    case aprovacao = "Orçamento para aprovação"
    case pronto = "Pronto para retirada"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .abertura: return "tray.and.arrow.down"
        case .status: return "arrow.triangle.2.circlepath"
        case .aprovacao: return "doc.text.magnifyingglass"
        case .pronto: return "checkmark.circle.fill"
        }
    }
}

enum WhatsAppHelper {
    static func cleanPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        if digits.isEmpty { return "" }
        if digits.hasPrefix("55") && digits.count >= 12 {
            return String(digits)
        }
        if digits.count == 10 || digits.count == 11 {
            return "55" + digits
        }
        return String(digits)
    }

    @MainActor
    static func openWhatsApp(phone: String, message: String) {
        let cleaned = cleanPhone(phone)
        guard !cleaned.isEmpty else { return }
        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://wa.me/\(cleaned)?text=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    static func sendOSWhatsApp(order: [String: OrderJSON], storeName: String = "SmartCenter") {
        let snap = order["cliSnap"]?.object ?? [:]
        let phone = snap["whatsapp"]?.text ?? (snap["telefone"]?.text ?? "")
        let client = snap["nome"]?.text ?? "Cliente"
        let numInt = Int(order["numero"]?.number ?? 0)
        let orderNum = numInt > 0 ? String(format: "%04d", numInt) : "OS"
        let dev = order["aparelho"]?.object ?? [:]
        let devParts = [dev["tipo"]?.text, dev["marca"]?.text, dev["modelo"]?.text].compactMap { $0 }.filter { !$0.isEmpty }
        let devText = devParts.isEmpty ? "aparelho" : devParts.joined(separator: " ")
        let defect = dev["defeito"]?.text ?? ""
        let diagnosis = order["diagnostico"]?.text ?? ""
        let st = order["status"]?.text ?? "Recebido"
        let tot = order["total"]?.number ?? ((order["maoDeObra"]?.number ?? 0) + (order["valorPecas"]?.number ?? 0))
        let totStr = String(format: "R$ %.2f", tot).replacingOccurrences(of: ".", with: ",")
        let pay = order["formaPagamento"]?.text ?? ""
        let deadline = order["prazo"]?.text ?? ""
        let partsList = (order["pecas"]?.array ?? []).compactMap { item -> String? in
            let p = item.object
            guard let desc = p["descricao"]?.text, !desc.isEmpty else { return nil }
            let qty = Int(p["qtd"]?.number ?? 1)
            return qty > 1 ? "\(desc) (x\(qty))" : desc
        }

        let template: WhatsAppTemplate
        if st == "Recebido" { template = .abertura }
        else if st == "Aguardando aprovação" { template = .aprovacao }
        else if st == "Concluído" || st == "Entregue" { template = .pronto }
        else { template = .status }

        let msg = buildMessage(
            template: template,
            storeName: storeName,
            clientName: client,
            orderNumber: orderNum,
            deviceText: devText,
            defect: defect,
            diagnosis: diagnosis,
            status: st,
            total: totStr,
            payment: pay,
            deadline: deadline,
            parts: partsList
        )
        openWhatsApp(phone: phone, message: msg)
    }

    @MainActor
    static func sendQuoteWhatsApp(quote: [String: OrderJSON], storeName: String = "SmartCenter") {
        let snap = quote["cliSnap"]?.object ?? [:]
        let phone = snap["whatsapp"]?.text ?? (snap["telefone"]?.text ?? "")
        let client = snap["nome"]?.text ?? "Cliente"
        let numInt = Int(quote["numero"]?.number ?? 0)
        let quoteNum = numInt > 0 ? String(format: "%04d", numInt) : "Orçamento"
        let dev = quote["aparelho"]?.object ?? [:]
        let devParts = [dev["tipo"]?.text, dev["marca"]?.text, dev["modelo"]?.text].compactMap { $0 }.filter { !$0.isEmpty }
        let devText = devParts.isEmpty ? "aparelho" : devParts.joined(separator: " ")
        let defect = dev["defeito"]?.text ?? ""
        let diagnosis = quote["diagnostico"]?.text ?? ""
        let st = quote["status"]?.text ?? "Pendente"
        let tot = quote["total"]?.number ?? ((quote["maoDeObra"]?.number ?? 0) + (quote["valorPecas"]?.number ?? 0))
        let totStr = String(format: "R$ %.2f", tot).replacingOccurrences(of: ".", with: ",")
        let deadline = quote["validade"]?.text ?? ""
        let partsList = (quote["pecas"]?.array ?? []).compactMap { item -> String? in
            let p = item.object
            guard let desc = p["descricao"]?.text, !desc.isEmpty else { return nil }
            let qty = Int(p["qtd"]?.number ?? 1)
            return qty > 1 ? "\(desc) (x\(qty))" : desc
        }

        let msg = buildMessage(
            template: .aprovacao,
            storeName: storeName,
            clientName: client,
            orderNumber: quoteNum,
            deviceText: devText,
            defect: defect,
            diagnosis: diagnosis,
            status: st,
            total: totStr,
            payment: "",
            deadline: deadline,
            parts: partsList
        )
        openWhatsApp(phone: phone, message: msg)
    }

    @MainActor
    static func sendSaleWhatsApp(sale: [String: OrderJSON], storeName: String = "SmartCenter") {
        let snap = sale["cliSnap"]?.object ?? [:]
        let phone = snap["whatsapp"]?.text ?? (snap["telefone"]?.text ?? "")
        let client = snap["nome"]?.text ?? "Cliente"
        let numInt = Int(sale["numero"]?.number ?? 0)
        let saleNum = numInt > 0 ? String(format: "%04d", numInt) : "Venda"
        let tot = sale["total"]?.number ?? 0
        let totStr = String(format: "R$ %.2f", tot).replacingOccurrences(of: ".", with: ",")
        let pay = sale["formaPagamento"]?.text ?? "À vista"
        let parcelas = Int(sale["parcelas"]?.number ?? 1)
        let payDesc = parcelas > 1 ? "\(pay) (\(parcelas)x)" : pay

        let items = (sale["itens"]?.array ?? []).compactMap { item -> String? in
            let obj = item.object
            guard let desc = obj["descricao"]?.text, !desc.isEmpty else { return nil }
            let qtd = Int(obj["qtd"]?.number ?? 1)
            let pr = obj["preco"]?.number ?? 0
            let prStr = String(format: "R$ %.2f", pr).replacingOccurrences(of: ".", with: ",")
            return "• \(qtd)x \(desc) (\(prStr))"
        }
        let itemsText = items.isEmpty ? "• Itens diversos" : items.joined(separator: "\n")

        var msg = "Olá, *\(client)*! 👋\n\n"
        msg += "Aqui está o comprovante da sua compra na *\(storeName)*:\n\n"
        msg += "🧾 *Venda #\(saleNum)*\n"
        msg += "🛒 *Itens:*\n\(itemsText)\n\n"
        msg += "💳 *Pagamento:* \(payDesc)\n"
        msg += "💰 *Total:* *\(totStr)*\n\n"
        msg += "Agradecemos muito pela preferência! Se precisar de algo, estamos sempre à disposição. 🤝"

        openWhatsApp(phone: phone, message: msg)
    }

    static func buildMessage(
        template: WhatsAppTemplate,
        storeName: String,
        clientName: String,
        orderNumber: String,
        deviceText: String,
        defect: String = "",
        diagnosis: String = "",
        status: String = "",
        total: String = "",
        payment: String = "",
        deadline: String = "",
        parts: [String] = []
    ) -> String {
        let firstName = clientName.split(separator: " ").first.map(String.init) ?? "cliente"
        let store = storeName.isEmpty ? "SmartCenter" : storeName
        var msg = ""

        switch template {
        case .abertura:
            let deadlineLine = deadline.isEmpty ? "" : "Prazo previsto: \(deadline)\n"
            msg = "Olá, \(firstName)! Recebemos seu aparelho na *\(store)*.\n\n*Ordem de Serviço nº \(orderNumber)*\nAparelho: \(deviceText)\nDefeito relatado: \(defect.isEmpty ? "—" : defect)\n\(deadlineLine)\nAssim que tivermos o diagnóstico, avisaremos por aqui. Guarde o número da OS para acompanhar seu atendimento."
        case .status:
            let diagLine = diagnosis.isEmpty ? "" : "Diagnóstico: \(diagnosis)\n"
            msg = "Olá, \(firstName)! Atualização do seu atendimento na *\(store)*:\n\n*OS nº \(orderNumber)* – \(deviceText)\nStatus atual: *\(status)*\n\(diagLine)\nQualquer dúvida, é só responder esta mensagem."
        case .aprovacao:
            let partsText = parts.isEmpty ? "" : "\nPeças:\n" + parts.map { "• \($0)" }.joined(separator: "\n") + "\n"
            let deadlineLine = deadline.isEmpty ? "" : "Prazo de entrega: \(deadline)\n"
            msg = "Olá, \(firstName)! Concluímos a análise do seu \(deviceText) (*OS nº \(orderNumber)*).\n\nDiagnóstico: \(diagnosis.isEmpty ? "—" : diagnosis)\(partsText)\n*Total: \(total)*\n\(deadlineLine)\nPodemos aprovar o serviço? Responda *SIM* para autorizar o reparo."
        case .pronto:
            let payLine = payment.isEmpty ? "" : "Forma de pagamento: \(payment)\n"
            msg = "Olá, \(firstName)! Boa notícia: seu \(deviceText) está *pronto para retirada* (OS nº \(orderNumber)).\n\nValor total: *\(total)*\n\(payLine)\nPara retirar, leve um documento com foto."
        }

        return msg + "\n\n*\(store)*"
    }
}

struct WhatsAppSheet: View {
    @ObservedObject var auth: AuthStore
    let orderID: String
    let initialPhone: String
    let initialClientName: String
    let orderTitle: String

    @State private var loading = false
    @State private var selectedTemplate: WhatsAppTemplate = .status
    @State private var phone = ""
    @State private var message = ""
    @State private var orderData: [String: OrderJSON] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if loading {
                    ProgressView("Carregando dados da OS…")
                } else {
                    Section("Modelo da mensagem") {
                        Picker("Modelo", selection: $selectedTemplate) {
                            ForEach(WhatsAppTemplate.allCases) { t in
                                Label(t.rawValue, systemImage: t.icon).tag(t)
                            }
                        }
                        .onChange(of: selectedTemplate) { _, _ in
                            generateMessage()
                        }
                    }

                    Section("WhatsApp do cliente") {
                        TextField("DDD + Telefone", text: $phone)
                            .keyboardType(.phonePad)
                    }

                    Section("Mensagem") {
                        TextEditor(text: $message)
                            .frame(minHeight: 180)
                            .font(.system(size: 14))
                    }
                }
            }
            .navigationTitle("Enviar WhatsApp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        WhatsAppHelper.openWhatsApp(phone: phone, message: message)
                        dismiss()
                    } label: {
                        Label("Abrir WhatsApp", systemImage: "paperplane.fill")
                            .bold()
                    }
                    .disabled(phone.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                phone = initialPhone
                await loadOS()
            }
        }
    }

    private func loadOS() async {
        loading = true
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/os/" + orderID)
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            if let os = envelope["os"]?.object {
                orderData = os
                if phone.isEmpty {
                    let clientSnap = os["cliSnap"]?.object
                    phone = clientSnap?["telefone"]?.text ?? ""
                }
                let st = os["status"]?.text ?? ""
                if st == "Recebido" { selectedTemplate = .abertura }
                else if st == "Aguardando aprovação" { selectedTemplate = .aprovacao }
                else if st == "Concluído" { selectedTemplate = .pronto }
                else { selectedTemplate = .status }
                generateMessage()
            }
        } catch {
            generateMessage()
        }
    }

    private func generateMessage() {
        let os = orderData
        let storeName = "SmartCenter"
        let client = initialClientName.isEmpty ? (os["cliSnap"]?.object["nome"]?.text ?? "cliente") : initialClientName
        let numInt = Int(os["numero"]?.number ?? 0)
        let orderNum = numInt > 0 ? String(format: "%04d", numInt) : orderTitle
        let dev = os["aparelho"]?.object ?? [:]
        let devParts = [dev["tipo"]?.text, dev["marca"]?.text, dev["modelo"]?.text].compactMap { $0 }.filter { !$0.isEmpty }
        let devText = devParts.isEmpty ? "aparelho" : devParts.joined(separator: " ")
        let defect = dev["defeito"]?.text ?? ""
        let diagnosis = os["diagnostico"]?.text ?? ""
        let st = os["status"]?.text ?? "Em andamento"
        let tot = os["total"]?.number ?? ((os["maoDeObra"]?.number ?? 0) + (os["valorPecas"]?.number ?? 0))
        let totStr = String(format: "R$ %.2f", tot).replacingOccurrences(of: ".", with: ",")
        let pay = os["formaPagamento"]?.text ?? ""
        let deadline = os["prazo"]?.text ?? ""
        let partsList = (os["pecas"]?.array ?? []).compactMap { item -> String? in
            let p = item.object
            guard let desc = p["descricao"]?.text, !desc.isEmpty else { return nil }
            let qty = Int(p["qtd"]?.number ?? 1)
            return qty > 1 ? "\(desc) (x\(qty))" : desc
        }

        message = WhatsAppHelper.buildMessage(
            template: selectedTemplate,
            storeName: storeName,
            clientName: client,
            orderNumber: orderNum,
            deviceText: devText,
            defect: defect,
            diagnosis: diagnosis,
            status: st,
            total: totStr,
            payment: pay,
            deadline: deadline,
            parts: partsList
        )
    }
}

