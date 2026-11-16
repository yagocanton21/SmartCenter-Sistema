import Foundation
import UIKit
import SwiftUI

struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum OrderPDFGenerator {
    static func generate(order: [String: OrderJSON], storeName: String = "SmartCenter") throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 em 72 dpi
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = margin

            // Cores
            let primaryColor = UIColor(red: 0.07, green: 0.35, blue: 0.85, alpha: 1.0)
            let darkColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            let grayTextColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            let lightBg = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
            let borderColor = UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0)

            // 1. Cabeçalho
            let storeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let storeSubAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: grayTextColor
            ]
            (storeName as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: storeAttr)
            let subText = "ASSISTÊNCIA TÉCNICA ESPECIALIZADA"
            (subText as NSString).draw(at: CGPoint(x: margin, y: currentY + 22), withAttributes: storeSubAttr)

            // Lado direito: Número da OS
            let numInt = Int(order["numero"]?.number ?? 0)
            let numText = numInt > 0 ? String(format: "#%04d", numInt) : "ORDEM DE SERVIÇO"
            let osTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                .foregroundColor: darkColor
            ]
            let numSize = (numText as NSString).size(withAttributes: osTitleAttr)
            (numText as NSString).draw(at: CGPoint(x: pageRect.width - margin - numSize.width, y: currentY), withAttributes: osTitleAttr)

            let dateRaw = order["dataEntrada"]?.text ?? ""
            let dateText = "Entrada: " + String(dateRaw.prefix(10))
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: grayTextColor
            ]
            let dateSize = (dateText as NSString).size(withAttributes: dateAttr)
            (dateText as NSString).draw(at: CGPoint(x: pageRect.width - margin - dateSize.width, y: currentY + 18), withAttributes: dateAttr)

            currentY += 40

            // Linha divisória
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: margin, y: currentY))
            linePath.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
            primaryColor.setStroke()
            linePath.lineWidth = 1.5
            linePath.stroke()

            currentY += 10

            // Helper para desenhar caixas de seção
            func drawSection(title: String, lines: [(label: String, val: String)], height: CGFloat) {
                let boxRect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
                let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 4)
                lightBg.setFill()
                boxPath.fill()
                borderColor.setStroke()
                boxPath.lineWidth = 0.8
                boxPath.stroke()

                // Título da seção
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                    .foregroundColor: primaryColor
                ]
                (title.uppercased() as NSString).draw(at: CGPoint(x: margin + 8, y: currentY + 5), withAttributes: titleAttr)

                let textY = currentY + 18
                let colW = (contentWidth - 16) / 2
                for (idx, line) in lines.enumerated() {
                    let col = CGFloat(idx % 2)
                    let row = CGFloat(idx / 2)
                    let lineX = margin + 8 + (col * colW)
                    let lineY = textY + (row * 13)

                    let str = NSMutableAttributedString()
                    str.append(NSAttributedString(string: line.label + ": ", attributes: [
                        .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                        .foregroundColor: grayTextColor
                    ]))
                    str.append(NSAttributedString(string: line.val.isEmpty ? "—" : line.val, attributes: [
                        .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                        .foregroundColor: darkColor
                    ]))
                    str.draw(at: CGPoint(x: lineX, y: lineY))
                }

                currentY += height + 8
            }

            // 2. Dados do Cliente
            let clientSnap = order["cliSnap"]?.object ?? [:]
            let clientName = clientSnap["nome"]?.text ?? "Cliente não informado"
            let clientPhone = clientSnap["telefone"]?.text ?? ""
            let clientDoc = clientSnap["doc"]?.text ?? ""
            let clientAddress = clientSnap["endereco"]?.text ?? ""

            drawSection(title: "Dados do Cliente", lines: [
                ("Nome", clientName),
                ("Telefone / WhatsApp", clientPhone),
                ("CPF / CNPJ", clientDoc),
                ("Endereço", clientAddress)
            ], height: 48)

            // 3. Dados do Aparelho
            let dev = order["aparelho"]?.object ?? [:]
            let devType = dev["tipo"]?.text ?? "Celular"
            let devBrand = dev["marca"]?.text ?? ""
            let devModel = dev["modelo"]?.text ?? ""
            let devSerial = dev["imei"]?.text ?? ""
            let devColor = dev["cor"]?.text ?? ""
            let devAcc = dev["acessorios"]?.text ?? ""
            let devCond = dev["estado"]?.text ?? ""
            let devDefect = dev["defeito"]?.text ?? ""

            var lockText = "Sem senha"
            let senhaTipo = dev["senhaTipo"]?.text ?? ""
            if senhaTipo == "alfa" {
                lockText = "PIN / Senha: " + (dev["senha"]?.text ?? "")
            } else if senhaTipo == "padrao" {
                lockText = "Padrão (desenho): " + (dev["senhaPadrao"]?.text.split(separator: "-").joined(separator: " → ") ?? "")
            }

            drawSection(title: "Dados do Aparelho & Acesso", lines: [
                ("Aparelho", "\(devType) \(devBrand) \(devModel)"),
                ("IMEI / Série", devSerial),
                ("Cor / Acessórios", "\(devColor.isEmpty ? "" : devColor + " · ")\(devAcc)"),
                ("Estado físico", devCond),
                ("Defeito relatado", devDefect),
                ("Senha / Desbloqueio", lockText)
            ], height: 60)

            // 4. Checklist Técnico (se celular/tablet)
            if let ckObj = order["checklist"]?.object, !ckObj.isEmpty {
                let ckRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 68)
                let ckPath = UIBezierPath(roundedRect: ckRect, cornerRadius: 4)
                lightBg.setFill()
                ckPath.fill()
                borderColor.setStroke()
                ckPath.lineWidth = 0.8
                ckPath.stroke()

                let ckTitleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                    .foregroundColor: primaryColor
                ]
                ("CHECKLIST TÉCNICO DE ENTRADA" as NSString).draw(at: CGPoint(x: margin + 8, y: currentY + 5), withAttributes: ckTitleAttr)

                let colW = (contentWidth - 16) / 3
                var idx = 0
                for item in allChecklistItems {
                    let st = ckObj[item.id]?.text ?? "nt"
                    let badge = st == "ok" ? "✓ OK" : (st == "def" ? "✗ DEF" : "- N/T")
                    let col = CGFloat(idx % 3)
                    let row = CGFloat(idx / 3)
                    let itemX = margin + 8 + (col * colW)
                    let itemY = currentY + 17 + (row * 8)

                    let str = NSMutableAttributedString()
                    str.append(NSAttributedString(string: item.label + ": ", attributes: [
                        .font: UIFont.systemFont(ofSize: 6.5, weight: .regular),
                        .foregroundColor: grayTextColor
                    ]))
                    let badgeColor = st == "ok" ? UIColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 1.0) : (st == "def" ? UIColor.red : grayTextColor)
                    str.append(NSAttributedString(string: badge, attributes: [
                        .font: UIFont.systemFont(ofSize: 6.5, weight: .bold),
                        .foregroundColor: badgeColor
                    ]))
                    str.draw(at: CGPoint(x: itemX, y: itemY))
                    idx += 1
                }

                currentY += 76
            }

            // 5. Diagnóstico & Serviço
            let diag = order["diagnostico"]?.text ?? ""
            let serv = order["servico"]?.text ?? ""
            let status = order["status"]?.text ?? "Recebido"
            let prazo = order["prazo"]?.text ?? ""
            let obs = order["observacoes"]?.text ?? ""

            drawSection(title: "Atendimento & Laudo", lines: [
                ("Status da OS", status),
                ("Prazo de entrega", prazo.isEmpty ? "Não informado" : prazo),
                ("Diagnóstico técnico", diag),
                ("Serviço realizado", serv),
                ("Observações adicionais", obs),
                ("Status do reparo", status)
            ], height: 56)

            // 6. Peças e Valores
            let parts = (order["pecas"]?.array ?? []).map { $0.object }
            let labor = order["maoDeObra"]?.number ?? 0
            let warrantyDays = Int(order["garantiaDias"]?.number ?? 90)

            let tableHeight: CGFloat = max(40, CGFloat(parts.count + 2) * 14 + 20)
            let tblRect = CGRect(x: margin, y: currentY, width: contentWidth, height: tableHeight)
            let tblPath = UIBezierPath(roundedRect: tblRect, cornerRadius: 4)
            lightBg.setFill()
            tblPath.fill()
            borderColor.setStroke()
            tblPath.lineWidth = 0.8
            tblPath.stroke()

            let valTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: primaryColor
            ]
            ("PEÇAS, SERVIÇOS & VALORES" as NSString).draw(at: CGPoint(x: margin + 8, y: currentY + 5), withAttributes: valTitleAttr)

            var tblY = currentY + 18
            let colDescW = contentWidth - 140
            ("Descrição" as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            ("Qtd" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            ("Valor" as NSString).draw(at: CGPoint(x: margin + colDescW + 50, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            tblY += 12

            var partsTotal: Double = 0
            for p in parts {
                let desc = p["descricao"]?.text ?? ""
                let qtd = p["qtd"]?.number ?? 1
                let val = p["valor"]?.number ?? (p["preco"]?.number ?? 0)
                let sub = qtd * val
                partsTotal += sub

                (desc as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                ("\(Int(qtd))" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                (String(format: "R$ %.2f", sub).replacingOccurrences(of: ".", with: ",") as NSString).draw(at: CGPoint(x: margin + colDescW + 50, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                tblY += 11
            }

            // Mão de obra
            ("Mão de obra técnica" as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
            ("-" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
            (String(format: "R$ %.2f", labor).replacingOccurrences(of: ".", with: ",") as NSString).draw(at: CGPoint(x: margin + colDescW + 50, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
            tblY += 13

            // Total
            let total = labor + partsTotal
            let totalStr = String(format: "TOTAL: R$ %.2f", total).replacingOccurrences(of: ".", with: ",")
            let totAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let totSize = (totalStr as NSString).size(withAttributes: totAttr)
            (totalStr as NSString).draw(at: CGPoint(x: pageRect.width - margin - totSize.width - 8, y: tblY), withAttributes: totAttr)

            currentY += tableHeight + 12

            // 7. Termos de Garantia & Assinatura
            let termoText = """
            TERMO DE RECEBIMENTO E GARANTIA: O cliente autoriza a realização dos testes e reparos necessários. A garantia para as peças e serviços executados é de \(warrantyDays) dias a partir da data de entrega, excluindo danos causados por quedas, contato com líquidos, quebra ou intervenções de terceiros. Aparelhos não retirados em até 90 dias após a conclusão poderão ser descartados para custeio do serviço.
            """
            let termoAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 6.5, weight: .regular),
                .foregroundColor: grayTextColor
            ]
            let termoRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 35)
            (termoText as NSString).draw(in: termoRect, withAttributes: termoAttr)
            currentY += 40

            // Linhas de assinatura
            let sigW = (contentWidth - 40) / 2
            let sigY = currentY + 30

            // Assinatura Cliente
            let line1 = UIBezierPath()
            line1.move(to: CGPoint(x: margin, y: sigY))
            line1.addLine(to: CGPoint(x: margin + sigW, y: sigY))
            borderColor.setStroke()
            line1.lineWidth = 1
            line1.stroke()
            ("Assinatura do Cliente" as NSString).draw(at: CGPoint(x: margin + (sigW / 2) - 35, y: sigY + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .medium), .foregroundColor: grayTextColor])

            // Assinatura Técnico
            let line2 = UIBezierPath()
            line2.move(to: CGPoint(x: margin + sigW + 40, y: sigY))
            line2.addLine(to: CGPoint(x: pageRect.width - margin, y: sigY))
            line2.stroke()
            ("Assinatura do Responsável" as NSString).draw(at: CGPoint(x: margin + sigW + 40 + (sigW / 2) - 45, y: sigY + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .medium), .foregroundColor: grayTextColor])

            // Rodapé
            let footY = pageRect.height - margin + 10
            let footStr = "SmartCenter · Documento emitido eletronicamente via SmartCenter Mobile"
            (footStr as NSString).draw(at: CGPoint(x: margin, y: footY), withAttributes: [.font: UIFont.systemFont(ofSize: 7, weight: .regular), .foregroundColor: grayTextColor])
        }

        let fileName = "OS_\(order["numero"]?.number != nil ? String(format: "%04d", Int(order["numero"]!.number)) : String(UUID().uuidString.prefix(6))).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pdfData.write(to: outputURL)
        return outputURL
    }

    static func generateLabel(order: [String: OrderJSON], storeName: String = "SmartCenter") throws -> URL {
        let labelRect = CGRect(x: 0, y: 0, width: 200, height: 130)
        let renderer = UIGraphicsPDFRenderer(bounds: labelRect)
        let margin: CGFloat = 8

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            let darkColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            let primaryColor = UIColor(red: 0.07, green: 0.35, blue: 0.85, alpha: 1.0)

            let numInt = Int(order["numero"]?.number ?? 0)
            let numText = numInt > 0 ? String(format: "OS #%04d", numInt) : "OS"
            let numAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: primaryColor
            ]
            (numText as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: numAttr)

            let dateRaw = String((order["dataEntrada"]?.text ?? "").prefix(10))
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateSize = (dateRaw as NSString).size(withAttributes: dateAttr)
            (dateRaw as NSString).draw(at: CGPoint(x: labelRect.width - margin - dateSize.width, y: margin + 3), withAttributes: dateAttr)

            let line = UIBezierPath()
            line.move(to: CGPoint(x: margin, y: margin + 17))
            line.addLine(to: CGPoint(x: labelRect.width - margin, y: margin + 17))
            primaryColor.setStroke()
            line.lineWidth = 1
            line.stroke()

            var currentY: CGFloat = margin + 21

            func drawRow(label: String, value: String, isBold: Bool = false) {
                let str = NSMutableAttributedString()
                str.append(NSAttributedString(string: label + ": ", attributes: [
                    .font: UIFont.systemFont(ofSize: 7.5, weight: .semibold),
                    .foregroundColor: UIColor.secondaryLabel
                ]))
                str.append(NSAttributedString(string: value.isEmpty ? "—" : value, attributes: [
                    .font: UIFont.systemFont(ofSize: 7.5, weight: isBold ? .bold : .regular),
                    .foregroundColor: darkColor
                ]))
                str.draw(at: CGPoint(x: margin, y: currentY))
                currentY += 12
            }

            let clientSnap = order["cliSnap"]?.object ?? [:]
            let clientName = clientSnap["nome"]?.text ?? "Cliente"
            let clientPhone = clientSnap["telefone"]?.text ?? ""
            drawRow(label: "Cliente", value: "\(clientName)\(clientPhone.isEmpty ? "" : " · " + clientPhone)", isBold: true)

            let dev = order["aparelho"]?.object ?? [:]
            let devText = [dev["tipo"]?.text, dev["marca"]?.text, dev["modelo"]?.text, dev["cor"]?.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            drawRow(label: "Aparelho", value: devText.isEmpty ? "Aparelho" : devText, isBold: true)

            let defect = dev["defeito"]?.text ?? ""
            drawRow(label: "Defeito", value: defect)

            var lockText = "Sem senha"
            let senhaTipo = dev["senhaTipo"]?.text ?? ""
            if senhaTipo == "alfa" {
                lockText = "PIN: " + (dev["senha"]?.text ?? "")
            } else if senhaTipo == "padrao" {
                lockText = "Padrão: " + (dev["senhaPadrao"]?.text.split(separator: "-").joined(separator: " → ") ?? "")
            }
            drawRow(label: "Senha", value: lockText)

            let total = order["total"]?.number ?? ((order["maoDeObra"]?.number ?? 0) + (order["valorPecas"]?.number ?? 0))
            let totalStr = total > 0 ? String(format: "R$ %.2f", total).replacingOccurrences(of: ".", with: ",") : "Orçamento"
            drawRow(label: "Valor", value: totalStr, isBold: true)
        }

        let fileName = "Etiqueta_OS_\(order["numero"]?.number != nil ? String(format: "%04d", Int(order["numero"]!.number)) : String(UUID().uuidString.prefix(6))).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pdfData.write(to: outputURL)
        return outputURL
    }

    static func generateQuote(quote: [String: OrderJSON], storeName: String = "SmartCenter") throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = margin

            let primaryColor = UIColor(red: 0.07, green: 0.35, blue: 0.85, alpha: 1.0)
            let darkColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            let grayTextColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            let lightBg = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
            let borderColor = UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0)

            let storeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let storeSubAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: grayTextColor
            ]

            (storeName as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: storeAttr)
            ("Assistência Técnica Especializada · Orçamento de Serviços" as NSString).draw(at: CGPoint(x: margin, y: currentY + 22), withAttributes: storeSubAttr)

            let numInt = Int(quote["numero"]?.number ?? 0)
            let numStr = numInt > 0 ? String(format: "#%04d", numInt) : "PROPOSTA"
            let numTitle = "ORÇAMENTO: \(numStr)"
            let numAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let numSize = (numTitle as NSString).size(withAttributes: numAttr)
            (numTitle as NSString).draw(at: CGPoint(x: pageRect.width - margin - numSize.width, y: currentY), withAttributes: numAttr)

            let dateRaw = String((quote["data"]?.text ?? "").prefix(10))
            let valRaw = String((quote["validade"]?.text ?? "").prefix(10))
            let dateStr = "Emissão: \(dateRaw) · Validade: \(valRaw)"
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: grayTextColor
            ]
            let dateSize = (dateStr as NSString).size(withAttributes: dateAttr)
            (dateStr as NSString).draw(at: CGPoint(x: pageRect.width - margin - dateSize.width, y: currentY + 22), withAttributes: dateAttr)

            currentY += 40

            let divLine = UIBezierPath()
            divLine.move(to: CGPoint(x: margin, y: currentY))
            divLine.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
            primaryColor.setStroke()
            divLine.lineWidth = 1.5
            divLine.stroke()
            currentY += 12

            func drawSection(title: String, lines: [(String, String)], height: CGFloat) {
                let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
                lightBg.setFill()
                path.fill()
                borderColor.setStroke()
                path.lineWidth = 0.8
                path.stroke()

                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                    .foregroundColor: primaryColor
                ]
                (title as NSString).draw(at: CGPoint(x: margin + 8, y: currentY + 5), withAttributes: titleAttr)

                var rowY = currentY + 18
                let colW = contentWidth / 2
                for (idx, line) in lines.enumerated() {
                    let colX = margin + 8 + (idx % 2 == 1 ? colW : 0)
                    let str = NSMutableAttributedString()
                    str.append(NSAttributedString(string: "\(line.0): ", attributes: [
                        .font: UIFont.systemFont(ofSize: 7.5, weight: .semibold),
                        .foregroundColor: grayTextColor
                    ]))
                    str.append(NSAttributedString(string: line.1.isEmpty ? "—" : line.1, attributes: [
                        .font: UIFont.systemFont(ofSize: 7.5, weight: .regular),
                        .foregroundColor: darkColor
                    ]))
                    str.draw(at: CGPoint(x: colX, y: rowY))
                    if idx % 2 == 1 { rowY += 11 }
                }
                currentY += height + 8
            }

            let client = quote["cliSnap"]?.object ?? [:]
            let clientName = client["nome"]?.text ?? "Cliente"
            let clientPhone = client["whatsapp"]?.text ?? (client["telefone"]?.text ?? "")
            let clientDoc = client["doc"]?.text ?? ""
            drawSection(title: "DADOS DO CLIENTE", lines: [
                ("Cliente", clientName),
                ("Telefone", clientPhone),
                ("CPF / CNPJ", clientDoc),
                ("Status da Proposta", quote["status"]?.text ?? "Pendente")
            ], height: 44)

            let dev = quote["aparelho"]?.object ?? [:]
            let devMarca = dev["marca"]?.text ?? ""
            let devModelo = dev["modelo"]?.text ?? ""
            let devTipo = dev["tipo"]?.text ?? "Celular"
            let devDefeito = dev["defeito"]?.text ?? ""
            let diag = quote["diagnostico"]?.text ?? ""

            drawSection(title: "APARELHO E DIAGNÓSTICO", lines: [
                ("Aparelho", "\(devMarca) \(devModelo)"),
                ("Tipo", devTipo),
                ("Defeito relatado", devDefeito),
                ("Diagnóstico técnico", diag)
            ], height: 44)

            let parts = (quote["pecas"]?.array ?? []).map { $0.object }
            let labor = quote["maoDeObra"]?.number ?? 0

            let tableHeight: CGFloat = max(40, CGFloat(parts.count + 2) * 14 + 20)
            let tblRect = CGRect(x: margin, y: currentY, width: contentWidth, height: tableHeight)
            let tblPath = UIBezierPath(roundedRect: tblRect, cornerRadius: 4)
            lightBg.setFill()
            tblPath.fill()
            borderColor.setStroke()
            tblPath.lineWidth = 0.8
            tblPath.stroke()

            let valTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: primaryColor
            ]
            ("PEÇAS, SERVIÇOS E VALORES DA PROPOSTA" as NSString).draw(at: CGPoint(x: margin + 8, y: currentY + 5), withAttributes: valTitleAttr)

            var tblY = currentY + 18
            let colDescW = contentWidth - 140
            ("Descrição" as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            ("Qtd" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            ("Valor" as NSString).draw(at: CGPoint(x: margin + colDescW + 50, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            tblY += 12

            var partsTotal: Double = 0
            for p in parts {
                let desc = p["descricao"]?.text ?? ""
                let qtd = p["qtd"]?.number ?? 1
                let val = p["valor"]?.number ?? (p["preco"]?.number ?? 0)
                let sub = qtd * val
                partsTotal += sub

                (desc as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                ("\(Int(qtd))" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                (String(format: "R$ %.2f", sub).replacingOccurrences(of: ".", with: ",") as NSString).draw(at: CGPoint(x: margin + colDescW + 50, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                tblY += 11
            }

            ("Mão de obra técnica" as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
            ("-" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
            (String(format: "R$ %.2f", labor).replacingOccurrences(of: ".", with: ",") as NSString).draw(at: CGPoint(x: margin + colDescW + 50, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
            tblY += 13

            let total = labor + partsTotal
            let totalStr = String(format: "TOTAL: R$ %.2f", total).replacingOccurrences(of: ".", with: ",")
            let totAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let totSize = (totalStr as NSString).size(withAttributes: totAttr)
            (totalStr as NSString).draw(at: CGPoint(x: pageRect.width - margin - totSize.width - 8, y: tblY), withAttributes: totAttr)

            currentY += tableHeight + 12

            let obs = quote["observacoes"]?.text ?? ""
            let obsText = "OBSERVAÇÕES DA PROPOSTA: \(obs.isEmpty ? "Orçamento válido por 7 dias. O início do reparo ocorre após a confirmação e aprovação do cliente." : obs)"
            let obsAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 6.5, weight: .regular),
                .foregroundColor: grayTextColor
            ]
            let obsRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 30)
            (obsText as NSString).draw(in: obsRect, withAttributes: obsAttr)
            currentY += 40

            let sigW = (contentWidth - 40) / 2
            let sigY = currentY + 30
            let line1 = UIBezierPath()
            line1.move(to: CGPoint(x: margin, y: sigY))
            line1.addLine(to: CGPoint(x: margin + sigW, y: sigY))
            borderColor.setStroke()
            line1.lineWidth = 1
            line1.stroke()
            ("Aprovação do Cliente" as NSString).draw(at: CGPoint(x: margin + (sigW / 2) - 35, y: sigY + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .medium), .foregroundColor: grayTextColor])

            let line2 = UIBezierPath()
            line2.move(to: CGPoint(x: margin + sigW + 40, y: sigY))
            line2.addLine(to: CGPoint(x: pageRect.width - margin, y: sigY))
            line2.stroke()
            ("Responsável Técnico" as NSString).draw(at: CGPoint(x: margin + sigW + 40 + (sigW / 2) - 45, y: sigY + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .medium), .foregroundColor: grayTextColor])

            let footY = pageRect.height - margin + 10
            let footStr = "SmartCenter · Documento emitido eletronicamente via SmartCenter Mobile"
            (footStr as NSString).draw(at: CGPoint(x: margin, y: footY), withAttributes: [.font: UIFont.systemFont(ofSize: 7, weight: .regular), .foregroundColor: grayTextColor])
        }

        let fileName = "Orcamento_\(quote["numero"]?.number != nil ? String(format: "%04d", Int(quote["numero"]!.number)) : String(UUID().uuidString.prefix(6))).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pdfData.write(to: outputURL)
        return outputURL
    }

    // MARK: - Sale Receipt PDF Generator
    static func generateSaleReceipt(sale: [String: OrderJSON], storeName: String = "SmartCenter") throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            var currentY: CGFloat = margin

            let primaryColor = UIColor(red: 0.07, green: 0.35, blue: 0.85, alpha: 1.0)
            let darkColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            let grayTextColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            let lightBg = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
            let borderColor = UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1.0)
            let cancelColor = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0)
            let cancelBg = UIColor(red: 0.99, green: 0.91, blue: 0.91, alpha: 1.0)

            let storeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let storeSubAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: grayTextColor
            ]

            (storeName as NSString).draw(at: CGPoint(x: margin, y: currentY), withAttributes: storeAttr)
            ("Assistência Técnica Especializada · Comprovante de Venda" as NSString).draw(at: CGPoint(x: margin, y: currentY + 22), withAttributes: storeSubAttr)

            let numInt = Int(sale["numero"]?.number ?? 0)
            let numStr = numInt > 0 ? String(format: "#%04d", numInt) : "AVULSA"
            let numTitle = "VENDA: \(numStr)"
            let numAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let numSize = (numTitle as NSString).size(withAttributes: numAttr)
            (numTitle as NSString).draw(at: CGPoint(x: pageRect.width - margin - numSize.width, y: currentY), withAttributes: numAttr)

            let rawDate = sale["data"]?.text ?? ""
            let dateStr = "Emissão: \(rawDate.prefix(10))"
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: grayTextColor
            ]
            let dateSize = (dateStr as NSString).size(withAttributes: dateAttr)
            (dateStr as NSString).draw(at: CGPoint(x: pageRect.width - margin - dateSize.width, y: currentY + 22), withAttributes: dateAttr)

            currentY += 40

            let isCancelled = (sale["status"]?.text ?? "") == "Cancelada"
            if isCancelled {
                let cancelRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 26)
                let cPath = UIBezierPath(roundedRect: cancelRect, cornerRadius: 4)
                cancelBg.setFill()
                cPath.fill()
                cancelColor.setStroke()
                cPath.lineWidth = 1
                cPath.stroke()

                let cText = "⚠️ VENDA CANCELADA — PRODUTOS ESTORNADOS AO ESTOQUE"
                let cAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: cancelColor
                ]
                let cSize = (cText as NSString).size(withAttributes: cAttr)
                (cText as NSString).draw(at: CGPoint(x: margin + (contentWidth - cSize.width) / 2, y: currentY + 7), withAttributes: cAttr)

                currentY += 34
            } else {
                let divLine = UIBezierPath()
                divLine.move(to: CGPoint(x: margin, y: currentY))
                divLine.addLine(to: CGPoint(x: pageRect.width - margin, y: currentY))
                primaryColor.setStroke()
                divLine.lineWidth = 1.5
                divLine.stroke()
                currentY += 12
            }

            func drawSection(title: String, lines: [(String, String)], height: CGFloat) {
                let rect = CGRect(x: margin, y: currentY, width: contentWidth, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
                lightBg.setFill()
                path.fill()
                borderColor.setStroke()
                path.lineWidth = 0.8
                path.stroke()

                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8.5, weight: .bold),
                    .foregroundColor: primaryColor
                ]
                (title.uppercased() as NSString).draw(at: CGPoint(x: margin + 8, y: currentY + 6), withAttributes: titleAttr)

                let textY = currentY + 20
                let colW = (contentWidth - 16) / CGFloat(lines.count)
                for (idx, line) in lines.enumerated() {
                    let colX = margin + 8 + (CGFloat(idx) * colW)
                    let lblAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 7, weight: .regular),
                        .foregroundColor: grayTextColor
                    ]
                    (line.0.uppercased() as NSString).draw(at: CGPoint(x: colX, y: textY), withAttributes: lblAttr)

                    let valAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                        .foregroundColor: darkColor
                    ]
                    (line.1 as NSString).draw(at: CGPoint(x: colX, y: textY + 9), withAttributes: valAttr)
                }
                currentY += height + 8
            }

            // Cliente Section
            let clientSnap = sale["cliSnap"]?.object ?? [:]
            let clientName = clientSnap["nome"]?.text ?? "Consumidor final"
            let clientPhone = clientSnap["whatsapp"]?.text ?? (clientSnap["telefone"]?.text ?? "Não informado")
            let clientDoc = clientSnap["doc"]?.text ?? "Não informado"
            drawSection(title: "Dados do Cliente", lines: [
                ("Nome", clientName),
                ("Telefone / WhatsApp", clientPhone),
                ("CPF / CNPJ", clientDoc)
            ], height: 42)

            // Pagamento Section
            let pay = sale["formaPagamento"]?.text ?? "À vista"
            let parcelas = Int(sale["parcelas"]?.number ?? 1)
            let payDesc = parcelas > 1 ? "\(pay) em \(parcelas)x" : pay
            let vendedor = sale["usuario"]?.text ?? "SmartCenter"
            drawSection(title: "Forma de Pagamento", lines: [
                ("Pagamento", payDesc),
                ("Atendente / Vendedor", vendedor),
                ("Situação", sale["status"]?.text ?? "Concluída")
            ], height: 42)

            // Items Table
            let rawItems = (sale["itens"]?.array ?? []).map { $0.object }
            let tableHeight: CGFloat = 24 + CGFloat(max(rawItems.count, 1)) * 14 + 18
            let tblRect = CGRect(x: margin, y: currentY, width: contentWidth, height: tableHeight)
            let tblPath = UIBezierPath(roundedRect: tblRect, cornerRadius: 4)
            lightBg.setFill()
            tblPath.fill()
            borderColor.setStroke()
            tblPath.lineWidth = 0.8
            tblPath.stroke()

            ("ITENS VENDIDOS" as NSString).draw(at: CGPoint(x: margin + 8, y: currentY + 6), withAttributes: [
                .font: UIFont.systemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: primaryColor
            ])

            var tblY = currentY + 20
            let colDescW = contentWidth - 180
            ("Descrição" as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            ("Qtd" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            ("Unitário" as NSString).draw(at: CGPoint(x: margin + colDescW + 40, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            ("Subtotal" as NSString).draw(at: CGPoint(x: margin + colDescW + 110, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .bold), .foregroundColor: grayTextColor])
            tblY += 12

            for it in rawItems {
                let desc = it["descricao"]?.text ?? ""
                let qtd = it["qtd"]?.number ?? 1
                let preco = it["preco"]?.number ?? 0
                let sub = qtd * preco

                (desc as NSString).draw(at: CGPoint(x: margin + 8, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                ("\(Int(qtd))" as NSString).draw(at: CGPoint(x: margin + colDescW, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                (String(format: "R$ %.2f", preco).replacingOccurrences(of: ".", with: ",") as NSString).draw(at: CGPoint(x: margin + colDescW + 40, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                (String(format: "R$ %.2f", sub).replacingOccurrences(of: ".", with: ",") as NSString).draw(at: CGPoint(x: margin + colDescW + 110, y: tblY), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: darkColor])
                tblY += 13
            }

            currentY += tableHeight + 8

            // Totals Box
            let subtotal = sale["subtotal"]?.number ?? 0
            let desconto = sale["desconto"]?.number ?? 0
            let total = sale["total"]?.number ?? (subtotal - desconto)

            let totBoxRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 38)
            let totBoxPath = UIBezierPath(roundedRect: totBoxRect, cornerRadius: 4)
            lightBg.setFill()
            totBoxPath.fill()
            borderColor.setStroke()
            totBoxPath.lineWidth = 0.8
            totBoxPath.stroke()

            let subStr = String(format: "Subtotal: R$ %.2f", subtotal).replacingOccurrences(of: ".", with: ",")
            (subStr as NSString).draw(at: CGPoint(x: margin + 12, y: currentY + 12), withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: grayTextColor
            ])

            if desconto > 0 {
                let descStr = String(format: "Desconto: - R$ %.2f", desconto).replacingOccurrences(of: ".", with: ",")
                (descStr as NSString).draw(at: CGPoint(x: margin + 160, y: currentY + 12), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                    .foregroundColor: UIColor.systemRed
                ])
            }

            let totStr = String(format: "TOTAL: R$ %.2f", total).replacingOccurrences(of: ".", with: ",")
            let totAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: primaryColor
            ]
            let totSize = (totStr as NSString).size(withAttributes: totAttr)
            (totStr as NSString).draw(at: CGPoint(x: pageRect.width - margin - totSize.width - 12, y: currentY + 11), withAttributes: totAttr)

            currentY += 46

            // Observações
            let obs = sale["obs"]?.text ?? ""
            if !obs.isEmpty {
                let obsText = "OBSERVAÇÕES: \(obs)"
                let obsAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7, weight: .regular),
                    .foregroundColor: grayTextColor
                ]
                let obsRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 24)
                (obsText as NSString).draw(in: obsRect, withAttributes: obsAttr)
                currentY += 28
            }

            // Signatures
            let sigW = (contentWidth - 40) / 2
            let sigY = currentY + 40
            let line1 = UIBezierPath()
            line1.move(to: CGPoint(x: margin, y: sigY))
            line1.addLine(to: CGPoint(x: margin + sigW, y: sigY))
            borderColor.setStroke()
            line1.lineWidth = 1
            line1.stroke()
            ("Assinatura do Cliente" as NSString).draw(at: CGPoint(x: margin + (sigW / 2) - 35, y: sigY + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .medium), .foregroundColor: grayTextColor])

            let line2 = UIBezierPath()
            line2.move(to: CGPoint(x: margin + sigW + 40, y: sigY))
            line2.addLine(to: CGPoint(x: pageRect.width - margin, y: sigY))
            line2.stroke()
            ("Vendedor / SmartCenter" as NSString).draw(at: CGPoint(x: margin + sigW + 40 + (sigW / 2) - 45, y: sigY + 4), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5, weight: .medium), .foregroundColor: grayTextColor])

            let legalStr = "Este comprovante não possui valor fiscal. Troca ou garantia mediante apresentação deste documento."
            (legalStr as NSString).draw(at: CGPoint(x: margin, y: sigY + 36), withAttributes: [.font: UIFont.systemFont(ofSize: 6.5, weight: .regular), .foregroundColor: grayTextColor])

            let footY = pageRect.height - margin + 10
            let footStr = "SmartCenter · Documento emitido eletronicamente via SmartCenter Mobile"
            (footStr as NSString).draw(at: CGPoint(x: margin, y: footY), withAttributes: [.font: UIFont.systemFont(ofSize: 7, weight: .regular), .foregroundColor: grayTextColor])
        }

        let fileName = "Venda_\(sale["numero"]?.number != nil ? String(format: "%04d", Int(sale["numero"]!.number)) : String(UUID().uuidString.prefix(6))).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pdfData.write(to: outputURL)
        return outputURL
    }
}
