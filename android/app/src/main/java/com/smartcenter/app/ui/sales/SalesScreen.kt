package com.smartcenter.app.ui.sales

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.smartcenter.app.data.*
import com.smartcenter.app.ui.components.*
import com.smartcenter.app.ui.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SalesScreen(
    authStore: AuthStore,
    onMenuClick: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var searchQuery by remember { mutableStateOf("") }
    var selectedStatus by remember { mutableStateOf("Todas") }
    var allSales by remember { mutableStateOf<List<Sale>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var selectedSale by remember { mutableStateOf<Sale?>(null) }
    var saleToCancel by remember { mutableStateOf<Sale?>(null) }

    var currentPage by remember { mutableStateOf(1) }
    val pageSize = 10

    val currentUser by authStore.currentUser.collectAsState()

    fun loadData() {
        scope.launch {
            loading = true
            errorMessage = null
            val res = authStore.fetchDB()
            loading = false
            res.onSuccess { db ->
                val list = (db["vendas"] as? List<*>) ?: emptyList<Any>()
                val clientsList = (db["clientes"] as? List<*>) ?: emptyList<Any>()
                @Suppress("UNCHECKED_CAST")
                val clientsMap = clientsList.mapNotNull { it as? Map<String, Any?> }.associateBy {
                    (it["id"] as? String) ?: ""
                }

                allSales = list.mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    val cid = (m["clienteId"] as? String) ?: ""
                    @Suppress("UNCHECKED_CAST")
                    val snap = (m["cliSnap"] as? Map<String, Any?>) ?: clientsMap[cid] ?: emptyMap<String, Any?>()

                    val itemsList = ((m["itens"] as? List<*>) ?: emptyList<Any>()).mapNotNull { iItem ->
                        val i = iItem as? Map<*, *> ?: return@mapNotNull null
                        SaleItem(
                            id = (i["id"] as? String) ?: "",
                            produtoId = i["produtoId"] as? String,
                            descricao = (i["descricao"] as? String) ?: "Item avulso",
                            qtd = (i["qtd"] as? Number)?.toDouble() ?: 1.0,
                            preco = (i["preco"] as? Number)?.toDouble() ?: 0.0,
                            custo = (i["custo"] as? Number)?.toDouble() ?: 0.0
                        )
                    }

                    Sale(
                        id = (m["id"] as? String) ?: "",
                        numero = (m["numero"] as? Number)?.toInt() ?: 0,
                        data = (m["data"] as? String) ?: "",
                        clienteId = if (cid.isEmpty()) null else cid,
                        cliSnap = snap,
                        itens = itemsList,
                        subtotal = (m["subtotal"] as? Number)?.toDouble() ?: 0.0,
                        desconto = (m["desconto"] as? Number)?.toDouble() ?: 0.0,
                        total = (m["total"] as? Number)?.toDouble() ?: 0.0,
                        lucro = (m["lucro"] as? Number)?.toDouble() ?: 0.0,
                        formaPagamento = (m["formaPagamento"] as? String) ?: "À vista",
                        parcelas = (m["parcelas"] as? Number)?.toInt() ?: 1,
                        status = (m["status"] as? String) ?: "Concluída",
                        usuario = (m["usuario"] as? String) ?: "SmartCenter",
                        obs = (m["obs"] as? String) ?: "",
                        raw = m as Map<String, Any?>
                    )
                }.sortedByDescending { it.numero }
            }.onFailure {
                errorMessage = it.localizedMessage
            }
        }
    }

    LaunchedEffect(Unit) {
        loadData()
    }

    // Financial Metrics
    val completedSales = remember(allSales) { allSales.filter { !it.isCancelled } }
    val totalRevenue = remember(completedSales) { completedSales.sumOf { it.total } }
    val averageTicket = remember(completedSales, totalRevenue) {
        if (completedSales.isEmpty()) 0.0 else totalRevenue / completedSales.size
    }
    val totalProfit = remember(completedSales) { completedSales.sumOf { it.lucro } }

    val filteredSales = remember(allSales, searchQuery, selectedStatus) {
        val q = searchQuery.trim().lowercase()
        allSales.filter { s ->
            if (selectedStatus != "Todas" && s.status != selectedStatus) return@filter false
            if (q.isEmpty()) return@filter true

            s.numero.toString().contains(q) ||
            s.shortNumber.lowercase().contains(q) ||
            s.clientName.lowercase().contains(q) ||
            s.clientPhone.contains(q) ||
            s.formaPagamento.lowercase().contains(q) ||
            s.itens.any { it.descricao.lowercase().contains(q) }
        }
    }

    val totalPages = remember(filteredSales.size) {
        maxOf(1, (filteredSales.size + pageSize - 1) / pageSize)
    }

    val paginatedSales = remember(filteredSales, currentPage) {
        val start = (currentPage - 1) * pageSize
        if (start >= filteredSales.size) emptyList()
        else filteredSales.subList(start, minOf(start + pageSize, filteredSales.size))
    }

    val statusCounts = remember(allSales) {
        mapOf(
            "Todas" to allSales.size,
            "Concluída" to allSales.count { it.status == "Concluída" },
            "Cancelada" to allSales.count { it.status == "Cancelada" }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Vendas", fontWeight = FontWeight.Bold, color = TextPrimary) },
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, contentDescription = "Menu", tint = TextPrimary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkBackground)
            )
        },
        containerColor = DarkBackground
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Financial Highlights
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                HighlightMetricCard(
                    title = "Total Vendido",
                    value = String.format("R$ %.2f", totalRevenue).replace(".", ","),
                    icon = Icons.Default.TrendingUp,
                    accent = AppleGreen,
                    badge = "${completedSales.size} vendas"
                )

                HighlightMetricCard(
                    title = "Ticket Médio",
                    value = String.format("R$ %.2f", averageTicket).replace(".", ","),
                    icon = Icons.Default.CreditCard,
                    accent = AppleBlue,
                    badge = "Por compra"
                )

                if (currentUser?.perfil == "admin") {
                    HighlightMetricCard(
                        title = "Lucro Estimado",
                        value = String.format("R$ %.2f", totalProfit).replace(".", ","),
                        icon = Icons.Default.AttachMoney,
                        accent = AppleIndigo,
                        badge = "Líquido"
                    )
                }
            }

            // Status Filter Chips
            StatusFilterChipsRow(
                statuses = listOf("Todas", "Concluída", "Cancelada"),
                selectedStatus = selectedStatus,
                counts = statusCounts,
                onStatusSelected = {
                    selectedStatus = it
                    currentPage = 1
                }
            )

            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = {
                    searchQuery = it
                    currentPage = 1
                },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Buscar por nº, cliente, produto...", color = TextSecondary) },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = TextSecondary) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = ""; currentPage = 1 }) {
                            Icon(Icons.Default.Clear, contentDescription = "Limpar", tint = TextSecondary)
                        }
                    }
                },
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = CardBackground,
                    unfocusedContainerColor = CardBackground,
                    focusedBorderColor = AppleBlue,
                    unfocusedBorderColor = CardBorder,
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary
                ),
                singleLine = true
            )

            if (errorMessage != null) {
                Text(
                    text = errorMessage ?: "",
                    color = AppleRed,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(4.dp)
                )
            }

            if (loading && allSales.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = AppleBlue)
                }
            } else if (filteredSales.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.ShoppingCart, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(48.dp))
                        Text("Nenhuma venda encontrada", color = TextSecondary, fontSize = 15.sp)
                    }
                }
            } else {
                Text(
                    text = "${filteredSales.size} vendas encontradas",
                    color = TextSecondary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )

                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(paginatedSales, key = { it.id }) { sale ->
                        SaleCardRow(
                            sale = sale,
                            onClick = { selectedSale = sale },
                            onWhatsAppClick = {
                                WhatsAppHelper.sendSaleWhatsApp(context, sale)
                            },
                            onCancelClick = {
                                saleToCancel = sale
                            }
                        )
                    }

                    item {
                        PaginationControls(
                            currentPage = currentPage,
                            totalPages = totalPages,
                            totalCount = filteredSales.size,
                            itemNoun = "vendas",
                            onPrev = { if (currentPage > 1) currentPage-- },
                            onNext = { if (currentPage < totalPages) currentPage++ }
                        )
                    }
                }
            }
        }
    }

    // Cancel Sale Dialog
    saleToCancel?.let { sale ->
        AlertDialog(
            onDismissRequest = { saleToCancel = null },
            title = { Text("Cancelar Venda ${sale.shortNumber}?") },
            text = { Text("Esta ação cancelará a venda e devolverá todos os produtos ao estoque automaticamente.") },
            confirmButton = {
                Button(
                    onClick = {
                        scope.launch {
                            val res = authStore.cancelSale(sale.id)
                            saleToCancel = null
                            if (res.isSuccess) {
                                loadData()
                            } else {
                                errorMessage = res.exceptionOrNull()?.localizedMessage
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AppleRed)
                ) {
                    Text("Cancelar Venda", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { saleToCancel = null }) {
                    Text("Voltar", color = TextSecondary)
                }
            },
            containerColor = CardBackground
        )
    }

    // Sale Detail Bottom Sheet
    selectedSale?.let { sale ->
        ModalBottomSheet(
            onDismissRequest = { selectedSale = null },
            containerColor = CardBackground,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(sale.shortNumber, color = TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                    StatusBadgePill(
                        text = sale.status,
                        color = if (sale.isCancelled) AppleRed else AppleGreen
                    )
                }

                Divider(color = CardBorder)

                DetailRowItem("Cliente", "${sale.clientName} ${if (sale.clientPhone.isNotEmpty()) "· ${sale.clientPhone}" else ""}")
                DetailRowItem("Forma de Pagamento", if (sale.parcelas > 1) "${sale.formaPagamento} em ${sale.parcelas}x" else sale.formaPagamento)
                DetailRowItem("Atendente", sale.usuario)

                Text("ITENS VENDIDOS", color = TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                sale.itens.forEach { item ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("${item.qtd.toInt()}× ${item.descricao}", color = TextPrimary, fontSize = 13.sp)
                        Text(String.format("R$ %.2f", item.subtotal).replace(".", ","), color = TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    }
                }

                Divider(color = CardBorder)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Total Pago", color = TextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Text(
                        String.format("R$ %.2f", sale.total).replace(".", ","),
                        color = AppleBlue,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Button(
                    onClick = {
                        WhatsAppHelper.sendSaleWhatsApp(context, sale)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = AppleGreen),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Message, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Enviar Comprovante WhatsApp", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
fun SaleCardRow(
    sale: Sale,
    onClick: () -> Unit,
    onWhatsAppClick: () -> Unit,
    onCancelClick: () -> Unit
) {
    AppleCard(onClick = onClick) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Header: #0001 + Status Pill + Price
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(CardSecondary)
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = sale.shortNumber,
                            color = TextPrimary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    StatusBadgePill(
                        text = sale.status,
                        color = if (sale.isCancelled) AppleRed else AppleGreen
                    )
                }

                Text(
                    text = String.format("R$ %.2f", sale.total).replace(".", ","),
                    color = if (sale.isCancelled) TextSecondary else TextPrimary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            // Customer
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.Person, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(16.dp))
                Text(
                    text = "${sale.clientName} ${if (sale.clientPhone.isNotEmpty()) "· ${sale.clientPhone}" else ""}",
                    color = TextPrimary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            // Items Summary
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Default.ShoppingBag, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(16.dp))
                Text(
                    text = sale.itemsSummary,
                    color = TextPrimary.copy(alpha = 0.9f),
                    fontSize = 12.sp,
                    maxLines = 1
                )
            }

            // Payment and Date
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(Icons.Default.CreditCard, contentDescription = null, tint = AppleOrange, modifier = Modifier.size(12.dp))
                    val parDesc = if (sale.parcelas > 1) "${sale.formaPagamento} (${sale.parcelas}x)" else sale.formaPagamento
                    Text(parDesc, color = TextSecondary, fontSize = 11.sp)
                }

                Text("📅 ${sale.formattedDate}", color = TextSecondary, fontSize = 11.sp)
            }

            Divider(color = CardBorder.copy(alpha = 0.5f))

            // Footer: Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CircularActionButton(
                        icon = Icons.Default.Message,
                        tint = AppleGreen,
                        contentDescription = "WhatsApp",
                        onClick = onWhatsAppClick
                    )

                    if (!sale.isCancelled) {
                        CircularActionButton(
                            icon = Icons.Default.Close,
                            tint = AppleRed,
                            contentDescription = "Cancelar Venda",
                            onClick = onCancelClick
                        )
                    }
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text("Ver detalhes", color = TextSecondary, fontSize = 12.sp)
                    Icon(Icons.Default.ChevronRight, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}

