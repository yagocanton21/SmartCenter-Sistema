package com.smartcenter.app.data

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

data class User(
    val id: String = "",
    val nome: String = "",
    val login: String = "",
    val perfil: String = "",
    val perms: List<String>? = null
) {
    fun can(permission: String): Boolean {
        return perfil == "admin" || (perms?.contains(permission) == true)
    }
}

data class Client(
    val id: String = "",
    val nome: String = "",
    val telefone: String = "",
    val whatsapp: String = "",
    val doc: String = "",
    val email: String = "",
    val endereco: String = "",
    val bairro: String = "",
    val cidade: String = "",
    val estado: String = "",
    val cep: String = "",
    val obs: String = ""
) {
    val effectivePhone: String
        get() = whatsapp.ifEmpty { telefone }

    val initials: String
        get() {
            val parts = nome.trim().split("\\s+".toRegex()).filter { it.isNotEmpty() }
            return when {
                parts.isEmpty() -> "C"
                parts.size == 1 -> parts[0].take(2).uppercase()
                else -> (parts[0].take(1) + parts[parts.size - 1].take(1)).uppercase()
            }
        }
}

data class OrderPart(
    val descricao: String = "",
    val qtd: Double = 1.0,
    val valor: Double = 0.0,
    val preco: Double = 0.0
) {
    val subtotal: Double
        get() = qtd * (if (valor > 0.0) valor else preco)
}

data class DeviceInfo(
    val tipo: String = "Celular",
    val marca: String = "",
    val modelo: String = "",
    val cor: String = "",
    val serial: String = "",
    val defeito: String = "",
    val acessorios: String = "",
    val condicoes: String = "",
    val senha: String = "",
    val senhaPadrao: String = ""
) {
    val title: String
        get() {
            val parts = listOf(marca, modelo).filter { it.isNotBlank() }
            return if (parts.isEmpty()) tipo.ifEmpty { "Aparelho" } else parts.joinToString(" ")
        }
}

data class Order(
    val id: String = "",
    val numero: Int = 0,
    val data: String = "",
    val dataEntrada: String = "",
    val dataEntrega: String = "",
    val status: String = "Recebido",
    val clienteId: String = "",
    val cliSnap: Map<String, Any?> = emptyMap(),
    val aparelho: DeviceInfo = DeviceInfo(),
    val pecas: List<OrderPart> = emptyList(),
    val maoDeObra: Double = 0.0,
    val valorPecas: Double = 0.0,
    val desconto: Double = 0.0,
    val total: Double = 0.0,
    val formaPagamento: String = "",
    val prazo: String = "",
    val garantia: String = "",
    val obs: String = "",
    val diagnostico: String = "",
    val raw: Map<String, Any?> = emptyMap()
) {
    val shortNumber: String
        get() = String.format("#%04d", numero)

    val clientName: String
        get() = (cliSnap["nome"] as? String)?.ifEmpty { "Cliente" } ?: "Cliente"

    val clientPhone: String
        get() = (cliSnap["whatsapp"] as? String)
            ?: (cliSnap["telefone"] as? String)
            ?: ""

    val effectiveDate: String
        get() = dataEntrada.ifEmpty { data }

    val formattedDate: String
        get() {
            val d = effectiveDate
            if (d.length < 10) return d
            val norm = DashboardCalculator.normalizeDate(d)
            val parts = norm.split("-")
            return if (parts.size == 3) "${parts[2]}/${parts[1]}/${parts[0]}" else d
        }
}

data class Quote(
    val id: String = "",
    val numero: Int = 0,
    val data: String = "",
    val validade: String = "",
    val status: String = "Pendente",
    val clienteId: String = "",
    val cliSnap: Map<String, Any?> = emptyMap(),
    val aparelho: DeviceInfo = DeviceInfo(),
    val pecas: List<OrderPart> = emptyList(),
    val maoDeObra: Double = 0.0,
    val valorPecas: Double = 0.0,
    val total: Double = 0.0,
    val diagnostico: String = "",
    val observacoes: String = "",
    val raw: Map<String, Any?> = emptyMap()
) {
    val shortNumber: String
        get() = String.format("#%04d", numero)

    val clientName: String
        get() = (cliSnap["nome"] as? String)?.ifEmpty { "Cliente" } ?: "Cliente"

    val clientPhone: String
        get() = (cliSnap["whatsapp"] as? String)
            ?: (cliSnap["telefone"] as? String)
            ?: ""

    val formattedDate: String
        get() {
            if (data.length < 10) return data
            val norm = DashboardCalculator.normalizeDate(data)
            val parts = norm.split("-")
            return if (parts.size == 3) "${parts[2]}/${parts[1]}/${parts[0]}" else data
        }
}

data class SaleItem(
    val id: String = "",
    val produtoId: String? = null,
    val descricao: String = "",
    val qtd: Double = 1.0,
    val preco: Double = 0.0,
    val custo: Double = 0.0
) {
    val subtotal: Double
        get() = qtd * preco
}

data class Sale(
    val id: String = "",
    val numero: Int = 0,
    val data: String = "",
    val clienteId: String? = null,
    val cliSnap: Map<String, Any?> = emptyMap(),
    val itens: List<SaleItem> = emptyList(),
    val subtotal: Double = 0.0,
    val desconto: Double = 0.0,
    val total: Double = 0.0,
    val lucro: Double = 0.0,
    val formaPagamento: String = "À vista",
    val parcelas: Int = 1,
    val status: String = "Concluída",
    val usuario: String = "SmartCenter",
    val obs: String = "",
    val raw: Map<String, Any?> = emptyMap()
) {
    val shortNumber: String
        get() = String.format("#%04d", numero)

    val isCancelled: Boolean
        get() = status.equals("Cancelada", ignoreCase = true)

    val clientName: String
        get() = (cliSnap["nome"] as? String)?.ifEmpty { "Consumidor final" } ?: "Consumidor final"

    val clientPhone: String
        get() = (cliSnap["whatsapp"] as? String)
            ?: (cliSnap["telefone"] as? String)
            ?: ""

    val itemsSummary: String
        get() {
            if (itens.isEmpty()) return "Sem itens"
            val firstTwo = itens.take(2).joinToString(", ") { "${it.qtd.toInt()}× ${it.descricao}" }
            return if (itens.size > 2) "$firstTwo +${itens.size - 2} item(s)" else firstTwo
        }

    val formattedDate: String
        get() {
            if (data.length < 10) return data
            val norm = DashboardCalculator.normalizeDate(data)
            val parts = norm.split("-")
            return if (parts.size == 3) "${parts[2]}/${parts[1]}/${parts[0]}" else data
        }
}

data class Product(
    val id: String = "",
    val codigo: String = "",
    val nome: String = "",
    val categoria: String = "Geral",
    val preco: Double = 0.0,
    val custo: Double = 0.0,
    val controla: Boolean = true,
    val estoque: Double = 0.0,
    val estoqueMin: Double = 0.0,
    val ativo: Boolean = true
) {
    val isLowStock: Boolean
        get() = controla && estoque <= estoqueMin
}

data class DayRevenue(
    val id: String,
    val dayLabel: String,
    val amount: Double,
    val isToday: Boolean
)

data class DashboardMetrics(
    val totalOrders: Int = 0,
    val ordersThisMonth: Int = 0,
    val waitingApproval: Int = 0,
    val inMaintenance: Int = 0,
    val completedOrders: Int = 0,
    val waitingPickup: Int = 0,
    val totalSalesCount: Int = 0,
    val totalSalesAmount: Double = 0.0,
    val revenueToday: Double = 0.0,
    val revenueMonth: Double = 0.0,
    val pendingQuotesCount: Int = 0,
    val pendingQuotesAmount: Double = 0.0,
    val overdueOrdersCount: Int = 0,
    val lowStockCount: Int = 0,
    val last14Days: List<DayRevenue> = emptyList(),
    val statusDistribution: Map<String, Int> = emptyMap()
)

object DashboardCalculator {
    val statuses = listOf(
        "Recebido",
        "Em análise",
        "Aguardando aprovação",
        "Aguardando peças",
        "Em reparo",
        "Concluído",
        "Entregue"
    )

    fun normalizeDate(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        val trimmed = raw.trim()
        if (trimmed.length >= 10 && trimmed[4] == '-' && trimmed[7] == '-') {
            return trimmed.substring(0, 10)
        }
        if (trimmed.length >= 10 && trimmed[2] == '/' && trimmed[5] == '/') {
            val p = trimmed.substring(0, 10).split("/")
            return "${p[2]}-${p[1]}-${p[0]}"
        }
        if (trimmed.length >= 10 && trimmed[4] == '/' && trimmed[7] == '/') {
            return trimmed.substring(0, 10).replace('/', '-')
        }
        return if (trimmed.length >= 10) trimmed.substring(0, 10) else trimmed
    }

    fun calculate(
        orders: List<Order>,
        sales: List<Sale>,
        quotes: List<Quote>,
        products: List<Product>
    ): DashboardMetrics {
        val sdfDate = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val todayStr = sdfDate.format(Date())
        val monthPrefix = if (todayStr.length >= 7) todayStr.substring(0, 7) else todayStr

        val validSales = sales.filter { !it.isCancelled }
        val pendingQuotes = quotes.filter { it.status.equals("Pendente", ignoreCase = true) }

        val ordersThisMonth = orders.count {
            val d = normalizeDate(it.dataEntrada.ifEmpty { it.data })
            d.startsWith(monthPrefix)
        }

        val waitingApproval = orders.count { it.status.equals("Aguardando aprovação", ignoreCase = true) }
        val inMaintenance = orders.count {
            it.status.equals("Em análise", ignoreCase = true) ||
            it.status.equals("Aguardando peças", ignoreCase = true) ||
            it.status.equals("Em reparo", ignoreCase = true)
        }
        val completed = orders.count {
            it.status.equals("Concluído", ignoreCase = true) || it.status.equals("Entregue", ignoreCase = true)
        }
        val waitingPickup = orders.count { it.status.equals("Concluído", ignoreCase = true) }

        fun revenue(prefix: String): Double {
            val osTotal = orders.filter {
                it.status.equals("Entregue", ignoreCase = true) &&
                normalizeDate(it.dataEntrega.ifEmpty { it.dataEntrada.ifEmpty { it.data } }).startsWith(prefix)
            }.sumOf { it.total }

            val salesTotal = validSales.filter {
                normalizeDate(it.data).startsWith(prefix)
            }.sumOf { it.total }

            return osTotal + salesTotal
        }

        val revenueToday = revenue(todayStr)
        val revenueMonth = revenue(monthPrefix)

        val daysList = mutableListOf<DayRevenue>()
        for (i in 13 downTo 0) {
            val c = Calendar.getInstance()
            c.add(Calendar.DAY_OF_YEAR, -i)
            val dayKey = sdfDate.format(c.time)
            val dayLabel = dayKey.takeLast(2)
            val amt = revenue(dayKey)
            daysList.add(DayRevenue(dayKey, dayLabel, amt, dayKey == todayStr))
        }

        val overdue = orders.count {
            val prazoNorm = normalizeDate(it.prazo)
            prazoNorm.isNotEmpty() && prazoNorm < todayStr && !listOf("Concluído", "Entregue").any { st -> st.equals(it.status, ignoreCase = true) }
        }

        val lowStock = products.count { it.isLowStock }

        val distribution = statuses.associateWith { st ->
            orders.count { it.status.equals(st, ignoreCase = true) }
        }

        return DashboardMetrics(
            totalOrders = orders.size,
            ordersThisMonth = ordersThisMonth,
            waitingApproval = waitingApproval,
            inMaintenance = inMaintenance,
            completedOrders = completed,
            waitingPickup = waitingPickup,
            totalSalesCount = validSales.size,
            totalSalesAmount = validSales.sumOf { it.total },
            revenueToday = revenueToday,
            revenueMonth = revenueMonth,
            pendingQuotesCount = pendingQuotes.size,
            pendingQuotesAmount = pendingQuotes.sumOf { it.total },
            overdueOrdersCount = overdue,
            lowStockCount = lowStock,
            last14Days = daysList,
            statusDistribution = distribution
        )
    }
}
