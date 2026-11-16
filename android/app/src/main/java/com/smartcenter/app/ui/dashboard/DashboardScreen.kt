package com.smartcenter.app.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.smartcenter.app.data.*
import com.smartcenter.app.ui.components.*
import com.smartcenter.app.ui.theme.*
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    authStore: AuthStore,
    onMenuClick: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val currentUser by authStore.currentUser.collectAsState()

    var metrics by remember { mutableStateOf<DashboardMetrics?>(null) }
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var lastUpdated by remember { mutableStateOf<String?>(null) }

    fun loadDashboard() {
        scope.launch {
            loading = true
            errorMessage = null
            val res = authStore.fetchDB()
            loading = false
            res.onSuccess { db ->
                val osList = ((db["os"] as? List<*>) ?: emptyList<Any>()).mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    val dEntrada = (m["dataEntrada"] as? String) ?: (m["data"] as? String) ?: ""
                    val dEntrega = (m["dataEntrega"] as? String) ?: ""
                    val prazoStr = (m["prazo"] as? String) ?: ""
                    Order(
                        id = (m["id"] as? String) ?: "",
                        numero = (m["numero"] as? Number)?.toInt() ?: 0,
                        data = dEntrada,
                        dataEntrada = dEntrada,
                        dataEntrega = dEntrega,
                        status = (m["status"] as? String) ?: "Recebido",
                        prazo = prazoStr,
                        total = (m["total"] as? Number)?.toDouble() ?: 0.0
                    )
                }

                val salesList = ((db["vendas"] as? List<*>) ?: emptyList<Any>()).mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    val dVenda = (m["data"] as? String) ?: (m["dataVenda"] as? String) ?: ""
                    Sale(
                        id = (m["id"] as? String) ?: "",
                        numero = (m["numero"] as? Number)?.toInt() ?: 0,
                        data = dVenda,
                        status = (m["status"] as? String) ?: "Concluída",
                        total = (m["total"] as? Number)?.toDouble() ?: 0.0
                    )
                }

                val quotesList = ((db["orcamentos"] as? List<*>) ?: emptyList<Any>()).mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    val dQuote = (m["data"] as? String) ?: (m["dataEntrada"] as? String) ?: ""
                    Quote(
                        id = (m["id"] as? String) ?: "",
                        numero = (m["numero"] as? Number)?.toInt() ?: 0,
                        data = dQuote,
                        status = (m["status"] as? String) ?: "Pendente",
                        total = (m["total"] as? Number)?.toDouble() ?: 0.0
                    )
                }

                val productsList = ((db["produtos"] as? List<*>) ?: emptyList<Any>()).mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    val controlaVal = when (val c = m["controla"]) {
                        is Boolean -> c
                        is Number -> c.toInt() != 0
                        else -> true
                    }
                    Product(
                        id = (m["id"] as? String) ?: "",
                        codigo = (m["codigo"] as? String) ?: "",
                        nome = (m["nome"] as? String) ?: "",
                        categoria = (m["categoria"] as? String) ?: "Geral",
                        preco = (m["preco"] as? Number)?.toDouble() ?: 0.0,
                        custo = (m["custo"] as? Number)?.toDouble() ?: 0.0,
                        controla = controlaVal,
                        estoque = (m["estoque"] as? Number)?.toDouble() ?: 0.0,
                        estoqueMin = (m["estoqueMin"] as? Number)?.toDouble() ?: 0.0,
                        ativo = (m["ativo"] as? Boolean) ?: true
                    )
                }

                metrics = DashboardCalculator.calculate(osList, salesList, quotesList, productsList)
                val sdfTime = SimpleDateFormat("HH:mm", Locale("pt", "BR"))
                lastUpdated = sdfTime.format(Date())
            }.onFailure { err ->
                errorMessage = err.localizedMessage ?: "Falha ao carregar métricas do painel"
            }
        }
    }

    LaunchedEffect(Unit) {
        loadDashboard()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Painel", fontWeight = FontWeight.Bold, color = TextPrimary) },
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, contentDescription = "Menu", tint = TextPrimary)
                    }
                },
                actions = {
                    IconButton(onClick = { loadDashboard() }, enabled = !loading) {
                        Icon(Icons.Default.Refresh, contentDescription = "Atualizar", tint = AppleBlue)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkBackground)
            )
        },
        containerColor = DarkBackground
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(vertical = 12.dp)
        ) {
            // Header Card com Gradiente
            item {
                DashboardHeader(userName = currentUser?.nome ?: "Usuário")
            }

            if (errorMessage != null) {
                item {
                    AppleCard {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(Icons.Default.Warning, contentDescription = null, tint = AppleRed)
                            Text(errorMessage ?: "", color = AppleRed, fontSize = 13.sp)
                        }
                        Spacer(Modifier.height(8.dp))
                        Button(
                            onClick = { loadDashboard() },
                            colors = ButtonDefaults.buttonColors(containerColor = AppleBlue),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text("Tentar novamente", fontSize = 12.sp)
                        }
                    }
                }
            }

            if (loading && metrics == null) {
                item {
                    Box(modifier = Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = AppleBlue)
                    }
                }
            }

            metrics?.let { m ->
                // Título Visão Geral
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Visão geral", color = TextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Text("Hoje", color = TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    }
                }

                // Grid de Métricas (2 colunas)
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Ordens de serviço",
                                value = m.totalOrders.toString(),
                                detail = "${m.ordersThisMonth} abertas no mês",
                                icon = Icons.Default.Build,
                                tint = AppleBlue
                            )
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Aguardando aprovação",
                                value = m.waitingApproval.toString(),
                                detail = "Aguardando o cliente",
                                icon = Icons.Default.Schedule,
                                tint = AppleOrange
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Em manutenção",
                                value = m.inMaintenance.toString(),
                                detail = "Análise, peças ou reparo",
                                icon = Icons.Default.PhoneAndroid,
                                tint = AppleBlue
                            )
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Serviços concluídos",
                                value = m.completedOrders.toString(),
                                detail = "${m.waitingPickup} aguardando entrega",
                                icon = Icons.Default.CheckCircle,
                                tint = AppleGreen
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Total de vendas",
                                value = m.totalSalesCount.toString(),
                                detail = formatMoney(m.totalSalesAmount),
                                icon = Icons.Default.ShoppingCart,
                                tint = AppleBlue
                            )
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Orçamentos pendentes",
                                value = m.pendingQuotesCount.toString(),
                                detail = formatMoney(m.pendingQuotesAmount),
                                icon = Icons.Default.Description,
                                tint = AppleOrange
                            )
                        }

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Faturamento hoje",
                                value = formatMoney(m.revenueToday),
                                detail = "Vendas + OS entregues",
                                icon = Icons.Default.MonetizationOn,
                                tint = AppleTeal
                            )
                            MetricCard(
                                modifier = Modifier.weight(1f),
                                title = "Faturamento do mês",
                                value = formatMoney(m.revenueMonth),
                                detail = "Vendas + OS entregues",
                                icon = Icons.Default.BarChart,
                                tint = AppleTeal
                            )
                        }
                    }
                }

                // Gráfico dos Últimos 14 Dias
                item {
                    var selectedDay by remember { mutableStateOf<DayRevenue?>(null) }
                    val total14 = m.last14Days.sumOf { it.amount }
                    val maxAmount = maxOf(m.last14Days.maxOfOrNull { it.amount } ?: 1.0, 1.0)

                    AppleCard {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Faturamento dos últimos 14 dias",
                                color = TextPrimary,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold
                            )
                            if (selectedDay != null) {
                                Text(
                                    text = "Dia ${selectedDay?.dayLabel}: ${formatMoney(selectedDay?.amount ?: 0.0)}",
                                    color = AppleBlue,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                        Spacer(Modifier.height(4.dp))
                        Row {
                            Text("Total no período: ", color = TextSecondary, fontSize = 12.sp)
                            Text(formatMoney(total14), color = TextPrimary, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.height(16.dp))

                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(110.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.Bottom
                        ) {
                            m.last14Days.forEach { day ->
                                val isSelected = selectedDay?.id == day.id
                                val hasValue = day.amount > 0.0
                                val barRatio = if (hasValue) (day.amount / maxAmount).coerceIn(0.12, 1.0).toFloat() else 0.04f

                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .clickable { selectedDay = if (isSelected) null else day }
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .fillMaxWidth(),
                                        contentAlignment = Alignment.BottomCenter
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .fillMaxHeight(barRatio)
                                                .width(14.dp)
                                                .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                                                .background(
                                                    when {
                                                        isSelected -> AppleYellow
                                                        day.isToday && hasValue -> AppleBlue
                                                        day.isToday -> AppleBlue.copy(alpha = 0.5f)
                                                        hasValue -> AppleBlue.copy(alpha = 0.75f)
                                                        else -> CardBorder
                                                    }
                                                )
                                        )
                                    }
                                    Spacer(Modifier.height(4.dp))
                                    Text(
                                        text = day.dayLabel,
                                        fontSize = 9.sp,
                                        fontWeight = if (day.isToday || isSelected) FontWeight.Bold else FontWeight.Normal,
                                        color = when {
                                            isSelected -> AppleYellow
                                            day.isToday -> AppleBlue
                                            else -> TextSecondary
                                        }
                                    )
                                }
                            }
                        }

                        if (total14 == 0.0) {
                            Spacer(Modifier.height(8.dp))
                            Text(
                                text = "Nenhum faturamento registrado no período selecionado.",
                                color = TextSecondary,
                                fontSize = 11.sp
                            )
                        }
                    }
                }

                // Ordens por Status
                item {
                    AppleCard {
                        Text(
                            text = "Ordens por status",
                            color = TextPrimary,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(Modifier.height(10.dp))

                        val totalCount = maxOf(m.totalOrders, 1)
                        DashboardCalculator.statuses.forEach { statusName ->
                            val count = m.statusDistribution[statusName] ?: 0
                            val ratio = count.toFloat() / totalCount.toFloat()

                            Column(modifier = Modifier.padding(vertical = 4.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(statusName, color = TextSecondary, fontSize = 12.sp)
                                    Text(
                                        count.toString(),
                                        color = TextPrimary,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                Spacer(Modifier.height(4.dp))
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(6.dp)
                                        .clip(RoundedCornerShape(3.dp))
                                        .background(CardBorder)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth(ratio.coerceIn(0f, 1f))
                                            .fillMaxHeight()
                                            .clip(RoundedCornerShape(3.dp))
                                            .background(
                                                when (statusName) {
                                                    "Entregue", "Concluído" -> AppleGreen
                                                    "Em reparo", "Aguardando peças" -> AppleOrange
                                                    else -> AppleBlue
                                                }
                                            )
                                    )
                                }
                            }
                        }
                    }
                }

                // Alertas
                item {
                    AppleCard {
                        Text(
                            text = "Alertas",
                            color = TextPrimary,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(Modifier.height(10.dp))

                        if (m.overdueOrdersCount > 0) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(vertical = 3.dp)
                            ) {
                                Icon(Icons.Default.AccessTime, contentDescription = null, tint = AppleOrange, modifier = Modifier.size(18.dp))
                                Text(
                                    "${m.overdueOrdersCount} OS com prazo vencido.",
                                    color = AppleOrange,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }

                        if (m.lowStockCount > 0) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(vertical = 3.dp)
                            ) {
                                Icon(Icons.Default.Inventory2, contentDescription = null, tint = AppleOrange, modifier = Modifier.size(18.dp))
                                Text(
                                    "${m.lowStockCount} produto(s) com estoque baixo ou zerado.",
                                    color = AppleOrange,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }

                        if (m.overdueOrdersCount == 0 && m.lowStockCount == 0) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(vertical = 3.dp)
                            ) {
                                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = AppleGreen, modifier = Modifier.size(18.dp))
                                Text(
                                    "Nenhum alerta de prazo ou estoque nos dados disponíveis.",
                                    color = TextSecondary,
                                    fontSize = 13.sp
                                )
                            }
                        }
                    }
                }

                lastUpdated?.let { timeStr ->
                    item {
                        Text(
                            text = "Atualizado às $timeStr. Toque no topo para atualizar.",
                            color = TextSecondary,
                            fontSize = 11.sp,
                            modifier = Modifier.padding(start = 4.dp, bottom = 12.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DashboardHeader(userName: String) {
    val firstName = userName.split(" ").firstOrNull() ?: userName
    val sdfDate = SimpleDateFormat("EEEE, d 'de' MMMM", Locale("pt", "BR"))
    val dateStr = sdfDate.format(Date()).replaceFirstChar { it.uppercase() }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(
                Brush.linearGradient(
                    listOf(
                        Color(0xFF1E4FB8),
                        Color(0xFF132A60)
                    )
                )
            )
            .padding(16.dp)
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        Icons.Default.Layers,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        "SMARTCENTER",
                        color = Color.White,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 2.sp
                    )
                }

                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.15f))
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text(
                        "PAINEL",
                        color = Color.White,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    "Olá, $firstName!",
                    color = Color.White,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    "Sua assistência técnica em um só lugar.",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 12.sp
                )
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    Icons.Default.CalendarToday,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.8f),
                    modifier = Modifier.size(13.dp)
                )
                Text(
                    dateStr,
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 11.sp
                )
            }
        }
    }
}

@Composable
private fun MetricCard(
    modifier: Modifier = Modifier,
    title: String,
    value: String,
    detail: String,
    icon: ImageVector,
    tint: Color
) {
    AppleCard(modifier = modifier) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(tint.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
        }

        Spacer(Modifier.height(8.dp))
        Text(title, color = TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Medium, maxLines = 1)
        Spacer(Modifier.height(2.dp))
        Text(value, color = TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        Spacer(Modifier.height(2.dp))
        Text(detail, color = TextSecondary, fontSize = 10.sp, maxLines = 1)
    }
}

private fun formatMoney(value: Double): String {
    val format = NumberFormat.getCurrencyInstance(Locale("pt", "BR"))
    return format.format(value)
}
