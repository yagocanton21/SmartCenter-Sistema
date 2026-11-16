package com.smartcenter.app.data

import android.content.Context
import android.content.Intent
import android.net.Uri
import java.net.URLEncoder

object WhatsAppHelper {
    fun cleanPhone(raw: String): String {
        val digits = raw.filter { it.isDigit() }
        if (digits.isEmpty()) return ""
        if (digits.startsWith("55") && digits.length >= 12) return digits
        if (digits.length == 10 || digits.length == 11) return "55$digits"
        return digits
    }

    fun openWhatsApp(context: Context, phone: String, message: String) {
        val cleaned = cleanPhone(phone)
        if (cleaned.isEmpty()) return
        try {
            val encoded = URLEncoder.encode(message, "UTF-8")
            val uri = Uri.parse("https://wa.me/$cleaned?text=$encoded")
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (_: Exception) {
            // Fallback or ignore
        }
    }

    fun sendOSWhatsApp(context: Context, order: Order, storeName: String = "SmartCenter") {
        val phone = order.clientPhone
        if (phone.isEmpty()) return
        val client = order.clientName
        val orderNum = order.shortNumber
        val dev = order.aparelho.title
        val defect = order.aparelho.defeito
        val status = order.status
        val total = String.format("R$ %.2f", order.total).replace(".", ",")

        val msg = """
            Olá, *$client*! Tudo bem? 👋
            
            Informações sobre sua Ordem de Serviço na *$storeName*:
            
            📋 *OS:* $orderNum
            📱 *Aparelho:* $dev
            ⚠️ *Defeito:* $defect
            📊 *Situação Atual:* *$status*
            💰 *Total:* $total
            
            Ficamos à disposição para qualquer dúvida! 🤝
        """.trimIndent()

        openWhatsApp(context, phone, msg)
    }

    fun sendQuoteWhatsApp(context: Context, quote: Quote, storeName: String = "SmartCenter") {
        val phone = quote.clientPhone
        if (phone.isEmpty()) return
        val client = quote.clientName
        val num = quote.shortNumber
        val dev = quote.aparelho.title
        val defect = quote.aparelho.defeito
        val total = String.format("R$ %.2f", quote.total).replace(".", ",")

        val msg = """
            Olá, *$client*! Tudo bem? 👋
            
            Segue o orçamento solicitado na *$storeName*:
            
            📄 *Orçamento:* $num
            📱 *Aparelho:* $dev
            ⚠️ *Defeito reclamado:* $defect
            💰 *Valor Total:* *$total*
            
            Para aprovar o reparo, basta responder a esta mensagem. Ficamos no aguardo! 🤝
        """.trimIndent()

        openWhatsApp(context, phone, msg)
    }

    fun sendSaleWhatsApp(context: Context, sale: Sale, storeName: String = "SmartCenter") {
        val phone = sale.clientPhone
        if (phone.isEmpty()) return
        val client = sale.clientName
        val saleNum = sale.shortNumber
        val total = String.format("R$ %.2f", sale.total).replace(".", ",")
        val pay = if (sale.parcelas > 1) "${sale.formaPagamento} (${sale.parcelas}x)" else sale.formaPagamento

        val items = sale.itens.joinToString("\n") {
            "• ${it.qtd.toInt()}x ${it.descricao} (R$ ${String.format("%.2f", it.preco).replace(".", ",")})"
        }.ifEmpty { "• Itens diversos" }

        val msg = """
            Olá, *$client*! 👋
            
            Aqui está o comprovante da sua compra na *$storeName*:
            
            🧾 *Venda $saleNum*
            🛒 *Itens:*
            $items
            
            💳 *Pagamento:* $pay
            💰 *Total:* *$total*
            
            Agradecemos muito pela preferência! Se precisar de algo, estamos sempre à disposição. 🤝
        """.trimIndent()

        openWhatsApp(context, phone, msg)
    }
}

