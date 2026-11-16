package com.smartcenter.app.ui.quotes

import androidx.compose.foundation.background
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
fun QuotesScreen(
    authStore: AuthStore,
    onMenuClick: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var searchQuery by remember { mutableStateOf("") }
    var selectedStatus by remember { mutableStateOf("Todos") }
    var allQuotes by remember { mutableStateOf<List<Quote>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var selectedQuote by remember { mutableStateOf<Quote?>(null) }

    var currentPage by remember { mutableStateOf(1) }
    val pageSize = 10

    val statusList = listOf("Todos", "Pendente", "Aprovado", "Recusado")

    fun loadData() {
        scope.launch {
            loading = true
            errorMessage = null
            val res = authStore.fetchDB()
            loading = false
            res.onSuccess { db ->
                val list = (db["orcamentos"] as? List<*>) ?: emptyList<Any>()
                val clientsList = (db["clientes"] as? List<*>) ?: emptyList<Any>()
                @Suppress("UNCHECKED_CAST")
                val clientsMap = clientsList.mapNotNull { it as? Map<String, Any?> }.associateBy {
                    (it["id"] as? String) ?: ""
                }

                allQuotes = list.mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    val cid = (m["clienteId"] as? String) ?: ""
                    @Suppress("UNCHECKED_CAST")
                    val snap = (m["cliSnap"] as? Map<String, Any?>) ?: clientsMap[cid] ?: emptyMap<String, Any?>()
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

                    Quote(
                        id = (m["id"] as? String) ?: "",
                        numero = (m["numero"] as? Number)?.toInt() ?: 0,
                        data = (m["data"] as? String) ?: "",
                        validade = (m["validade"] as? String) ?: "",
                        status = (m["status"] as? String) ?: "Pendente",
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
                            condicoes = (devMap["condicoes"] as? String) ?: ""
                        ),
                        pecas = pecasList,
                        maoDeObra = (m["maoDeObra"] as? Number)?.toDouble() ?: 0.0,
                        valorPecas = (m["valorPecas"] as? Number)?.toDouble() ?: 0.0,
                        total = (m["total"] as? Number)?.toDouble() ?: 0.0,
                        diagnostico = (m["diagnostico"] as? String) ?: "",
                        observacoes = (m["observacoes"] as? String) ?: "",
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

    val filteredQuotes = remember(allQuotes, searchQuery, selectedStatus) {
        val q = searchQuery.trim().lowercase()
        allQuotes.filter { o ->
            if (selectedStatus != "Todos" && o.status != selectedStatus) return@filter false
            if (q.isEmpty()) return@filter true

            o.numero.toString().contains(q) ||
            o.shortNumber.lowercase().contains(q) ||
            o.clientName.lowercase().contains(q) ||
            o.clientPhone.contains(q) ||
            o.aparelho.title.lowercase().contains(q) ||
            o.aparelho.defeito.lowercase().contains(q)
        }
    }

    val totalPages = remember(filteredQuotes.size) {
        maxOf(1, (filteredQuotes.size + pageSize - 1) / pageSize)
    }

    val paginatedQuotes = remember(filteredQuotes, currentPage) {
        val start = (currentPage - 1) * pageSize
        if (start >= filteredQuotes.size) emptyList()
        else filteredQuotes.subList(start, minOf(start + pageSize, filteredQuotes.size))
    }

    val statusCounts = remember(allQuotes) {
        mapOf(
            "Todos" to allQuotes.size,
            "Pendente" to allQuotes.count { it.status == "Pendente" },
            "Aprovado" to allQuotes.count { it.status == "Aprovado" },
            "Recusado" to allQuotes.count { it.status == "Recusado" }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Orçamentos", fontWeight = FontWeight.Bold, color = TextPrimary) },
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
            // Status Filters Chips
            StatusFilterChipsRow(
                statuses = statusList,
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

            if (loading && allQuotes.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = AppleBlue)
                }
            } else if (filteredQuotes.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.Description, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(48.dp))
                        Text("Nenhum orçamento encontrado", color = TextSecondary, fontSize = 15.sp)
                    }
                }
            } else {
                Text(
                    text = "${filteredQuotes.size} orçamentos encontrados",
                    color = TextSecondary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )

                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(paginatedQuotes, key = { it.id }) { quote ->
                        QuoteCardRow(
                            quote = quote,
                            onClick = { selectedQuote = quote },
                            onWhatsAppClick = {
                                WhatsAppHelper.sendQuoteWhatsApp(context, quote)
                            }
                        )
                    }

                    item {
                        PaginationControls(
                            currentPage = currentPage,
                            totalPages = totalPages,
                            totalCount = filteredQuotes.size,
                            itemNoun = "orçamentos",
                            onPrev = { if (currentPage > 1) currentPage-- },
                            onNext = { if (currentPage < totalPages) currentPage++ }
                        )
                    }
                }
            }
        }
    }

    // Quote Detail Bottom Sheet
    selectedQuote?.let { quote ->
        ModalBottomSheet(
            onDismissRequest = { selectedQuote = null },
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
                    Text(quote.shortNumber, color = TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                    StatusBadgePill(
                        text = quote.status,
                        color = when (quote.status) {
                            "Aprovado" -> AppleGreen
                            "Recusado" -> AppleRed
                            else -> AppleOrange
                        }
                    )
                }

                Divider(color = CardBorder)

                DetailRowItem("Cliente", "${quote.clientName} ${if (quote.clientPhone.isNotEmpty()) "· ${quote.clientPhone}" else ""}")
                DetailRowItem("Aparelho", quote.aparelho.title)
                DetailRowItem("Defeito", quote.aparelho.defeito.ifEmpty { "Não informado" })

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Valor da Proposta", color = TextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Text(
                        String.format("R$ %.2f", quote.total).replace(".", ","),
                        color = AppleBlue,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Button(
                    onClick = {
                        WhatsAppHelper.sendQuoteWhatsApp(context, quote)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = AppleGreen),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(Icons.Default.Message, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Enviar Proposta no WhatsApp", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
fun QuoteCardRow(
    quote: Quote,
    onClick: () -> Unit,
    onWhatsAppClick: () -> Unit
) {
    val statusColor = when (quote.status) {
        "Aprovado" -> AppleGreen
        "Recusado" -> AppleRed
        else -> AppleOrange
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
                            text = quote.shortNumber,
                            color = TextPrimary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    StatusBadgePill(text = quote.status, color = statusColor)
                }

                Text(
                    text = String.format("R$ %.2f", quote.total).replace(".", ","),
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
                        .background(AppleOrange.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Description,
                        contentDescription = null,
                        tint = AppleOrange,
                        modifier = Modifier.size(20.dp)
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = quote.aparelho.title,
                        color = TextPrimary,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "👤 ${quote.clientName} ${if (quote.clientPhone.isNotEmpty()) "· ${quote.clientPhone}" else ""}",
                        color = TextSecondary,
                        fontSize = 12.sp
                    )
                }
            }

            // Defect Tag Box
            if (quote.aparelho.defeito.isNotEmpty()) {
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
                            text = quote.aparelho.defeito.uppercase(),
                            color = TextSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1
                        )
                    }
                }
            }

            Divider(color = CardBorder.copy(alpha = 0.5f))

            // Footer: Date + Actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Data: ${quote.formattedDate}",
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

