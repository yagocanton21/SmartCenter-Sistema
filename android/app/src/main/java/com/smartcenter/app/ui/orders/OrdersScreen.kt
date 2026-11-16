package com.smartcenter.app.ui.orders

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
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
fun OrdersScreen(
    authStore: AuthStore,
    onMenuClick: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var searchQuery by remember { mutableStateOf("") }
    var selectedStatus by remember { mutableStateOf("Todas") }
    var allOrders by remember { mutableStateOf<List<Order>>(emptyList()) }
    var allClients by remember { mutableStateOf<List<Client>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var selectedOrder by remember { mutableStateOf<Order?>(null) }

    // CRUD States
    var showEditorDialog by remember { mutableStateOf(false) }
    var orderToEdit by remember { mutableStateOf<Order?>(null) }

    var currentPage by remember { mutableStateOf(1) }
    val pageSize = 10

    val statusList = listOf(
        "Todas",
        "Recebido",
        "Em análise",
        "Aguardando aprovação",
        "Aguardando peças",
        "Em reparo",
        "Concluído",
        "Entregue"
    )

    fun loadData() {
        scope.launch {
            loading = true
            errorMessage = null
            val res = authStore.fetchDB()
            loading = false
            res.onSuccess { db ->
                val list = (db["os"] as? List<*>) ?: emptyList<Any>()
                val clientsRaw = (db["clientes"] as? List<*>) ?: emptyList<Any>()

                val parsedClients = clientsRaw.mapNotNull { cItem ->
                    val c = cItem as? Map<*, *> ?: return@mapNotNull null
                    Client(
                        id = (c["id"] as? String) ?: "",
                        nome = (c["nome"] as? String) ?: "",
                        telefone = (c["telefone"] as? String) ?: "",
                        whatsapp = (c["whatsapp"] as? String) ?: "",
                        doc = (c["doc"] as? String) ?: "",
                        email = (c["email"] as? String) ?: "",
                        endereco = (c["endereco"] as? String) ?: "",
                        bairro = (c["bairro"] as? String) ?: "",
                        cidade = (c["cidade"] as? String) ?: "",
                        estado = (c["estado"] as? String) ?: "",
                        cep = (c["cep"] as? String) ?: "",
                        obs = (c["obs"] as? String) ?: ""
                    )
                }
                allClients = parsedClients

                @Suppress("UNCHECKED_CAST")
                val clientsMap = parsedClients.associateBy { it.id }

                allOrders = list.mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    val cid = (m["clienteId"] as? String) ?: ""
                    val clientObj = clientsMap[cid]
                    @Suppress("UNCHECKED_CAST")
                    val snap = (m["cliSnap"] as? Map<String, Any?>) ?: clientObj?.let {
                        mapOf(
                            "id" to it.id,
                            "nome" to it.nome,
                            "telefone" to it.telefone,
                            "whatsapp" to it.whatsapp,
                            "doc" to it.doc
                        )
                    } ?: emptyMap<String, Any?>()

                    @Suppress("UNCHECKED_CAST")
                    val devMap = (m["aparelho"] as? Map<String, Any?>) ?: emptyMap<String, Any?>()

                    val pecasList = ((m["pecas"] as? List<*>) ?: emptyList<Any>()).mapNotNull { pItem ->
                        val p = pItem as? Map<*, *> ?: return@mapNotNull null
                        OrderPart(
                            descricao = (p["descricao"] as? String) ?: "",
                            qtd = (p["qtd"] as? Number)?.toDouble() ?: 1.0,
                            valor = (p["valor"] as? Number)?.toDouble() ?: 0.0,
                            preco = (p["preco"] as? Number)?.toDouble() ?: 0.0
                        )
                    }

                    val dEntrada = (m["dataEntrada"] as? String) ?: (m["data"] as? String) ?: ""
                    val dEntrega = (m["dataEntrega"] as? String) ?: ""

                    Order(
                        id = (m["id"] as? String) ?: "",
                        numero = (m["numero"] as? Number)?.toInt() ?: 0,
                        data = dEntrada,
                        dataEntrada = dEntrada,
                        dataEntrega = dEntrega,
                        status = (m["status"] as? String) ?: "Recebido",
                        clienteId = cid,
                        cliSnap = snap,
                        aparelho = DeviceInfo(
                            tipo = (devMap["tipo"] as? String) ?: "Celular",
                            marca = (devMap["marca"] as? String) ?: "",
                            modelo = (devMap["modelo"] as? String) ?: "",
                            cor = (devMap["cor"] as? String) ?: "",
                            serial = (devMap["serial"] as? String) ?: "",
                            defeito = (devMap["defeito"] as? String) ?: "",
                            acessorios = (devMap["acessorios"] as? String) ?: "",
                            condicoes = (devMap["condicoes"] as? String) ?: "",
                            senha = (devMap["senha"] as? String) ?: "",
                            senhaPadrao = (devMap["senhaPadrao"] as? String) ?: ""
                        ),
                        pecas = pecasList,
                        maoDeObra = (m["maoDeObra"] as? Number)?.toDouble() ?: 0.0,
                        valorPecas = (m["valorPecas"] as? Number)?.toDouble() ?: 0.0,
                        desconto = (m["desconto"] as? Number)?.toDouble() ?: 0.0,
                        total = (m["total"] as? Number)?.toDouble() ?: 0.0,
                        formaPagamento = (m["formaPagamento"] as? String) ?: "",
                        prazo = (m["prazo"] as? String) ?: "",
                        garantia = (m["garantia"] as? String) ?: "",
                        obs = (m["obs"] as? String) ?: "",
                        diagnostico = (m["diagnostico"] as? String) ?: "",
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

    val filteredOrders = remember(allOrders, searchQuery, selectedStatus) {
        val q = searchQuery.trim().lowercase()
        allOrders.filter { o ->
            if (selectedStatus != "Todas" && o.status != selectedStatus) return@filter false
            if (q.isEmpty()) return@filter true

            o.numero.toString().contains(q) ||
            o.shortNumber.lowercase().contains(q) ||
            o.clientName.lowercase().contains(q) ||
            o.clientPhone.contains(q) ||
            o.aparelho.title.lowercase().contains(q) ||
            o.aparelho.defeito.lowercase().contains(q)
        }
    }

    val totalPages = remember(filteredOrders.size) {
        maxOf(1, (filteredOrders.size + pageSize - 1) / pageSize)
    }

    val paginatedOrders = remember(filteredOrders, currentPage) {
        val start = (currentPage - 1) * pageSize
        val end = minOf(start + pageSize, filteredOrders.size)
        if (start < filteredOrders.size) filteredOrders.subList(start, end) else emptyList()
    }

    // Se uma ordem estiver selecionada, abre a tela completa de Detalhes (padrão iOS / Android)
    if (selectedOrder != null) {
        OrderDetailScreen(
            order = selectedOrder!!,
            authStore = authStore,
            onBack = { selectedOrder = null },
            onEdit = { order ->
                orderToEdit = order
                showEditorDialog = true
                selectedOrder = null
            },
            onDeleted = {
                selectedOrder = null
                loadData()
            },
            onStatusChanged = { updated ->
                selectedOrder = updated
                loadData()
            }
        )
    } else {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Ordens de Serviço", fontWeight = FontWeight.Bold, color = TextPrimary) },
                    navigationIcon = {
                        IconButton(onClick = onMenuClick) {
                            Icon(Icons.Default.Menu, contentDescription = "Menu", tint = TextPrimary)
                        }
                    },
                    actions = {
                        IconButton(onClick = { loadData() }, enabled = !loading) {
                            Icon(Icons.Default.Refresh, contentDescription = "Recarregar", tint = AppleBlue)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkBackground)
                )
            },
            floatingActionButton = {
                FloatingActionButton(
                    onClick = {
                        orderToEdit = null
                        showEditorDialog = true
                    },
                    containerColor = AppleBlue,
                    contentColor = Color.White,
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = "Nova Ordem de Serviço")
                }
            },
            containerColor = DarkBackground
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Status Chips Horizontal Scroll
                ScrollableTabRow(
                    selectedTabIndex = statusList.indexOf(selectedStatus).coerceAtLeast(0),
                    edgePadding = 0.dp,
                    divider = {},
                    indicator = {},
                    containerColor = Color.Transparent,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    statusList.forEach { status ->
                        val isSelected = status == selectedStatus
                        Surface(
                            modifier = Modifier
                                .padding(end = 8.dp)
                                .clickable {
                                    selectedStatus = status
                                    currentPage = 1
                                },
                            shape = RoundedCornerShape(20.dp),
                            color = if (isSelected) AppleBlue else CardSecondary,
                            border = if (isSelected) null else androidx.compose.foundation.BorderStroke(1.dp, CardBorder)
                        ) {
                            Text(
                                text = status,
                                color = if (isSelected) Color.White else TextSecondary,
                                fontSize = 13.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp)
                            )
                        }
                    }
                }

                // Search Bar
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = {
                        searchQuery = it
                        currentPage = 1
                    },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Buscar por nº, cliente, aparelho, defeito...", color = TextSecondary) },
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

                if (loading && allOrders.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = AppleBlue)
                    }
                } else if (filteredOrders.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(Icons.Default.Build, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(48.dp))
                            Text("Nenhuma ordem de serviço encontrada", color = TextSecondary, fontSize = 15.sp)
                        }
                    }
                } else {
                    Text(
                        text = "${filteredOrders.size} ordens de serviço",
                        color = TextSecondary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )

                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(paginatedOrders, key = { it.id }) { order ->
                            OrderCardRow(
                                order = order,
                                onClick = { selectedOrder = order },
                                onWhatsAppClick = {
                                    WhatsAppHelper.sendOSWhatsApp(context, order)
                                }
                            )
                        }

                        item {
                            PaginationControls(
                                currentPage = currentPage,
                                totalPages = totalPages,
                                totalCount = filteredOrders.size,
                                itemNoun = "OSs",
                                onPrev = { if (currentPage > 1) currentPage-- },
                                onNext = { if (currentPage < totalPages) currentPage++ }
                            )
                        }
                    }
                }
            }
        }
    }

    // Modal de Criação / Edição de OS
    if (showEditorDialog) {
        OrderEditorDialog(
            orderToEdit = orderToEdit,
            clientsList = allClients,
            authStore = authStore,
            onDismiss = {
                showEditorDialog = false
                orderToEdit = null
            },
            onSaved = {
                showEditorDialog = false
                orderToEdit = null
                loadData()
            }
        )
    }
}

@Composable
fun OrderCardRow(
    order: Order,
    onClick: () -> Unit,
    onWhatsAppClick: () -> Unit
) {
    val statusColor = when (order.status) {
        "Entregue", "Concluído" -> AppleGreen
        "Em reparo", "Aguardando peças" -> AppleOrange
        else -> AppleBlue
    }

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
                            text = order.shortNumber,
                            color = TextPrimary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    StatusBadgePill(text = order.status, color = statusColor)
                }

                Text(
                    text = String.format("R$ %.2f", order.total).replace(".", ","),
                    color = TextPrimary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            // Device + Customer
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(AppleBlue.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.PhoneIphone,
                        contentDescription = null,
                        tint = AppleBlue,
                        modifier = Modifier.size(20.dp)
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = order.aparelho.title,
                        color = TextPrimary,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "👤 ${order.clientName} ${if (order.clientPhone.isNotEmpty()) "· ${order.clientPhone}" else ""}",
                        color = TextSecondary,
                        fontSize = 12.sp
                    )
                }
            }

            // Defect Tag Box
            if (order.aparelho.defeito.isNotEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(CardSecondary)
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Build,
                            contentDescription = null,
                            tint = AppleOrange,
                            modifier = Modifier.size(13.dp)
                        )
                        Text(
                            text = order.aparelho.defeito.uppercase(),
                            color = TextSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1
                        )
                    }
                }
            }

            HorizontalDivider(color = CardBorder.copy(alpha = 0.5f))

            // Footer: Date + Circular Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Entrada: ${order.formattedDate}",
                    color = TextSecondary,
                    fontSize = 11.sp
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CircularActionButton(
                        icon = Icons.Default.Message,
                        tint = AppleGreen,
                        contentDescription = "WhatsApp",
                        onClick = onWhatsAppClick
                    )
                }
            }
        }
    }
}
