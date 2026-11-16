package com.smartcenter.app.ui.clients

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.smartcenter.app.data.AuthStore
import com.smartcenter.app.data.Client
import com.smartcenter.app.data.WhatsAppHelper
import com.smartcenter.app.ui.components.*
import com.smartcenter.app.ui.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClientsScreen(
    authStore: AuthStore,
    onMenuClick: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var searchQuery by remember { mutableStateOf("") }
    var allClients by remember { mutableStateOf<List<Client>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var selectedClient by remember { mutableStateOf<Client?>(null) }

    var currentPage by remember { mutableStateOf(1) }
    val pageSize = 10

    fun loadData() {
        scope.launch {
            loading = true
            errorMessage = null
            val res = authStore.fetchDB()
            loading = false
            res.onSuccess { db ->
                val list = (db["clientes"] as? List<*>) ?: emptyList<Any>()
                allClients = list.mapNotNull { item ->
                    val m = item as? Map<*, *> ?: return@mapNotNull null
                    Client(
                        id = (m["id"] as? String) ?: "",
                        nome = (m["nome"] as? String) ?: "Sem nome",
                        telefone = (m["telefone"] as? String) ?: "",
                        whatsapp = (m["whatsapp"] as? String) ?: "",
                        doc = (m["doc"] as? String) ?: "",
                        email = (m["email"] as? String) ?: "",
                        endereco = (m["endereco"] as? String) ?: "",
                        bairro = (m["bairro"] as? String) ?: "",
                        cidade = (m["cidade"] as? String) ?: "",
                        estado = (m["estado"] as? String) ?: "",
                        cep = (m["cep"] as? String) ?: "",
                        obs = (m["obs"] as? String) ?: ""
                    )
                }.sortedBy { it.nome.lowercase() }
            }.onFailure {
                errorMessage = it.localizedMessage
            }
        }
    }

    LaunchedEffect(Unit) {
        loadData()
    }

    val filteredClients = remember(allClients, searchQuery) {
        val q = searchQuery.trim().lowercase()
        if (q.isEmpty()) allClients
        else allClients.filter {
            it.nome.lowercase().contains(q) ||
            it.telefone.contains(q) ||
            it.whatsapp.contains(q) ||
            it.doc.contains(q) ||
            it.email.lowercase().contains(q)
        }
    }

    val totalPages = remember(filteredClients.size) {
        maxOf(1, (filteredClients.size + pageSize - 1) / pageSize)
    }

    val paginatedClients = remember(filteredClients, currentPage) {
        val start = (currentPage - 1) * pageSize
        if (start >= filteredClients.size) emptyList()
        else filteredClients.subList(start, minOf(start + pageSize, filteredClients.size))
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Clientes", fontWeight = FontWeight.Bold, color = TextPrimary) },
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
            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = {
                    searchQuery = it
                    currentPage = 1
                },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Buscar por nome, telefone, CPF...", color = TextSecondary) },
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

            if (loading && allClients.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = AppleBlue)
                }
            } else if (filteredClients.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.PersonSearch, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(48.dp))
                        Text("Nenhum cliente encontrado", color = TextSecondary, fontSize = 15.sp)
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    items(paginatedClients, key = { it.id }) { client ->
                        ClientRowCard(
                            client = client,
                            onClick = { selectedClient = client },
                            onWhatsAppClick = {
                                WhatsAppHelper.openWhatsApp(context, client.effectivePhone, "Olá, ${client.nome}!")
                            }
                        )
                    }

                    item {
                        PaginationControls(
                            currentPage = currentPage,
                            totalPages = totalPages,
                            totalCount = filteredClients.size,
                            itemNoun = "clientes",
                            onPrev = { if (currentPage > 1) currentPage-- },
                            onNext = { if (currentPage < totalPages) currentPage++ }
                        )
                    }
                }
            }
        }
    }

    // Client Detail Bottom Sheet
    selectedClient?.let { client ->
        ModalBottomSheet(
            onDismissRequest = { selectedClient = null },
            containerColor = CardBackground,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    AvatarGradientBox(initials = client.initials, size = 56)
                    Column {
                        Text(client.nome, color = TextPrimary, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        if (client.effectivePhone.isNotEmpty()) {
                            Text(client.effectivePhone, color = TextSecondary, fontSize = 13.sp)
                        }
                    }
                }

                Divider(color = CardBorder)

                if (client.doc.isNotEmpty()) {
                    DetailRowItem(label = "CPF / CNPJ", value = client.doc)
                }
                if (client.email.isNotEmpty()) {
                    DetailRowItem(label = "E-mail", value = client.email)
                }
                val address = listOf(client.endereco, client.bairro, client.cidade, client.estado).filter { it.isNotBlank() }.joinToString(" - ")
                if (address.isNotEmpty()) {
                    DetailRowItem(label = "Endereço", value = address)
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = {
                            WhatsAppHelper.openWhatsApp(context, client.effectivePhone, "Olá, ${client.nome}!")
                        },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = AppleGreen),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Message, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("WhatsApp", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

@Composable
fun ClientRowCard(
    client: Client,
    onClick: () -> Unit,
    onWhatsAppClick: () -> Unit
) {
    AppleCard(onClick = onClick) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.weight(1f)
            ) {
                AvatarGradientBox(initials = client.initials, size = 42)

                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = client.nome,
                        color = TextPrimary,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    if (client.effectivePhone.isNotEmpty()) {
                        Text(
                            text = client.effectivePhone,
                            color = TextSecondary,
                            fontSize = 12.sp
                        )
                    }
                }
            }

            if (client.effectivePhone.isNotEmpty()) {
                CircularActionButton(
                    icon = Icons.Default.Message,
                    tint = AppleGreen,
                    contentDescription = "Enviar WhatsApp",
                    onClick = onWhatsAppClick
                )
            }
        }
    }
}

@Composable
fun AvatarGradientBox(initials: String, size: Int = 42) {
    Box(
        modifier = Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(
                Brush.linearGradient(
                    listOf(AppleBlue, AppleIndigo)
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = initials,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = (size * 0.38).sp
        )
    }
}


