package com.smartcenter.app.ui.orders

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.smartcenter.app.data.*
import com.smartcenter.app.ui.components.AppleCard
import com.smartcenter.app.ui.theme.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrderEditorDialog(
    orderToEdit: Order? = null,
    clientsList: List<Client>,
    authStore: AuthStore,
    onDismiss: () -> Unit,
    onSaved: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val isNew = orderToEdit == null

    var selectedClientId by remember { mutableStateOf(orderToEdit?.clienteId ?: "") }
    var clientSearchQuery by remember { mutableStateOf("") }
    var showClientDropdown by remember { mutableStateOf(false) }

    // Aparelho
    var devTipo by remember { mutableStateOf(orderToEdit?.aparelho?.tipo ?: "Celular") }
    var devMarca by remember { mutableStateOf(orderToEdit?.aparelho?.marca ?: "") }
    var devModelo by remember { mutableStateOf(orderToEdit?.aparelho?.modelo ?: "") }
    var devCor by remember { mutableStateOf(orderToEdit?.aparelho?.cor ?: "") }
    var devSerial by remember { mutableStateOf(orderToEdit?.aparelho?.serial ?: "") }
    var devDefeito by remember { mutableStateOf(orderToEdit?.aparelho?.defeito ?: "") }
    var devAcessorios by remember { mutableStateOf(orderToEdit?.aparelho?.acessorios ?: "") }
    var devCondicoes by remember { mutableStateOf(orderToEdit?.aparelho?.condicoes ?: "") }

    // Senha / Segurança
    var lockType by remember {
        mutableStateOf(
            when {
                !orderToEdit?.aparelho?.senhaPadrao.isNullOrEmpty() -> "padrao"
                !orderToEdit?.aparelho?.senha.isNullOrEmpty() -> "senha"
                else -> "nenhuma"
            }
        )
    }
    var passwordText by remember { mutableStateOf(orderToEdit?.aparelho?.senha ?: "") }
    var patternSequence by remember { mutableStateOf(orderToEdit?.aparelho?.senhaPadrao ?: "") }

    // Checklist
    val checklistItems = remember {
        mutableStateMapOf<String, Boolean>().apply {
            val rawChecklist = orderToEdit?.raw?.get("checklist") as? Map<*, *>
            listOf("Liga", "Touch / Tela", "Câmera Frontal", "Câmera Traseira", "Conector Carga", "Som", "Microfone", "Biometria", "Botões").forEach { item ->
                put(item, (rawChecklist?.get(item) as? Boolean) ?: false)
            }
        }
    }

    // Serviço e Valores
    var status by remember { mutableStateOf(orderToEdit?.status ?: "Recebido") }
    var diagnostico by remember { mutableStateOf(orderToEdit?.diagnostico ?: "") }
    var maoDeObraStr by remember { mutableStateOf(if (orderToEdit != null && orderToEdit.maoDeObra > 0) String.format(Locale.US, "%.2f", orderToEdit.maoDeObra) else "") }
    var descontoStr by remember { mutableStateOf(if (orderToEdit != null && orderToEdit.desconto > 0) String.format(Locale.US, "%.2f", orderToEdit.desconto) else "") }
    var formaPagamento by remember { mutableStateOf(orderToEdit?.formaPagamento ?: "Pix") }
    var prazoStr by remember {
        mutableStateOf(
            orderToEdit?.prazo?.ifEmpty {
                val c = Calendar.getInstance()
                c.add(Calendar.DAY_OF_YEAR, 2)
                SimpleDateFormat("yyyy-MM-dd", Locale.US).format(c.time)
            } ?: ""
        )
    }
    var garantiaStr by remember { mutableStateOf(orderToEdit?.garantia ?: "90 dias") }
    var observacoes by remember { mutableStateOf(orderToEdit?.obs ?: "") }

    // Peças
    val pecas = remember {
        mutableStateListOf<OrderPart>().apply {
            orderToEdit?.pecas?.let { addAll(it) }
        }
    }

    var saving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val laborValue = maoDeObraStr.replace(",", ".").toDoubleOrNull() ?: 0.0
    val discountValue = descontoStr.replace(",", ".").toDoubleOrNull() ?: 0.0
    val partsTotal = pecas.sumOf { it.subtotal }
    val calculatedTotal = (laborValue + partsTotal - discountValue).coerceAtLeast(0.0)

    val selectedClient = clientsList.find { it.id == selectedClientId }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 16.dp),
            shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
            color = DarkBackground
        ) {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = {
                            Text(
                                if (isNew) "Nova Ordem de Serviço" else "Editar ${orderToEdit?.shortNumber}",
                                fontWeight = FontWeight.Bold,
                                color = TextPrimary,
                                fontSize = 18.sp
                            )
                        },
                        navigationIcon = {
                            IconButton(onClick = onDismiss) {
                                Icon(Icons.Default.Close, contentDescription = "Fechar", tint = TextSecondary)
                            }
                        },
                        actions = {
                            Button(
                                onClick = {
                                    if (selectedClientId.isEmpty()) {
                                        errorMessage = "Selecione um cliente para a OS."
                                        return@Button
                                    }
                                    if (devMarca.isBlank() && devModelo.isBlank()) {
                                        errorMessage = "Informe ao menos a marca ou modelo do aparelho."
                                        return@Button
                                    }

                                    saving = true
                                    errorMessage = null

                                    scope.launch {
                                        val osId = orderToEdit?.id ?: UUID.randomUUID().toString()
                                        val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())

                                        val aparelhoMap = mutableMapOf<String, Any?>(
                                            "tipo" to devTipo,
                                            "marca" to devMarca.trim(),
                                            "modelo" to devModelo.trim(),
                                            "cor" to devCor.trim(),
                                            "serial" to devSerial.trim(),
                                            "defeito" to devDefeito.trim(),
                                            "acessorios" to devAcessorios.trim(),
                                            "condicoes" to devCondicoes.trim(),
                                            "senha" to (if (lockType == "senha") passwordText.trim() else ""),
                                            "senhaPadrao" to (if (lockType == "padrao") patternSequence.trim() else "")
                                        )

                                        val pecasPayload = pecas.map { p ->
                                            mapOf(
                                                "descricao" to p.descricao,
                                                "qtd" to p.qtd,
                                                "valor" to (if (p.valor > 0) p.valor else p.preco)
                                            )
                                        }

                                        val clientSnap = selectedClient?.let {
                                            mapOf(
                                                "id" to it.id,
                                                "nome" to it.nome,
                                                "telefone" to it.telefone,
                                                "whatsapp" to it.whatsapp,
                                                "doc" to it.doc
                                            )
                                        } ?: orderToEdit?.cliSnap ?: emptyMap<String, Any?>()

                                        val payload = mutableMapOf<String, Any?>(
                                            "id" to osId,
                                            "clienteId" to selectedClientId,
                                            "cliSnap" to clientSnap,
                                            "aparelho" to aparelhoMap,
                                            "pecas" to pecasPayload,
                                            "maoDeObra" to laborValue,
                                            "valorPecas" to partsTotal,
                                            "desconto" to discountValue,
                                            "total" to calculatedTotal,
                                            "status" to status,
                                            "formaPagamento" to formaPagamento,
                                            "prazo" to prazoStr,
                                            "garantia" to garantiaStr,
                                            "obs" to observacoes.trim(),
                                            "diagnostico" to diagnostico.trim(),
                                            "checklist" to checklistItems.toMap()
                                        )

                                        if (isNew) {
                                            payload["dataEntrada"] = nowIso
                                        } else {
                                            orderToEdit?.raw?.let { payload["before"] = it }
                                        }

                                        val res = authStore.saveOrder(payload)
                                        saving = false
                                        res.onSuccess {
                                            onSaved()
                                        }.onFailure { err ->
                                            errorMessage = err.localizedMessage ?: "Erro ao salvar OS"
                                        }
                                    }
                                },
                                enabled = !saving,
                                colors = ButtonDefaults.buttonColors(containerColor = AppleBlue),
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                if (saving) {
                                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                                } else {
                                    Text("Salvar", fontWeight = FontWeight.Bold)
                                }
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
                    contentPadding = PaddingValues(bottom = 32.dp)
                ) {
                    if (errorMessage != null) {
                        item {
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = AppleRed.copy(alpha = 0.15f),
                                border = androidx.compose.foundation.BorderStroke(1.dp, AppleRed.copy(alpha = 0.4f))
                            ) {
                                Row(
                                    modifier = Modifier.padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Icon(Icons.Default.Error, contentDescription = null, tint = AppleRed)
                                    Text(errorMessage ?: "", color = AppleRed, fontSize = 13.sp)
                                }
                            }
                        }
                    }

                    // Seção 1: Cliente
                    item {
                        SectionCard(title = "Cliente", icon = Icons.Default.Person) {
                            if (selectedClient != null) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text(selectedClient.nome, color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                                        Text(selectedClient.effectivePhone.ifEmpty { "Sem telefone" }, color = TextSecondary, fontSize = 12.sp)
                                    }
                                    TextButton(onClick = { selectedClientId = "" }) {
                                        Text("Trocar", color = AppleBlue, fontSize = 12.sp)
                                    }
                                }
                            } else {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    OutlinedTextField(
                                        value = clientSearchQuery,
                                        onValueChange = {
                                            clientSearchQuery = it
                                            showClientDropdown = true
                                        },
                                        modifier = Modifier.fillMaxWidth(),
                                        placeholder = { Text("Buscar cliente por nome ou telefone...") },
                                        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = TextSecondary) },
                                        singleLine = true
                                    )

                                    val filteredClients = clientsList.filter {
                                        clientSearchQuery.isNotBlank() && (it.nome.contains(clientSearchQuery, ignoreCase = true) || it.effectivePhone.contains(clientSearchQuery))
                                    }.take(5)

                                    if (filteredClients.isNotEmpty() && showClientDropdown) {
                                        Column(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clip(RoundedCornerShape(8.dp))
                                                .background(CardSecondary)
                                        ) {
                                            filteredClients.forEach { c ->
                                                Row(
                                                    modifier = Modifier
                                                        .fillMaxWidth()
                                                        .clickable {
                                                            selectedClientId = c.id
                                                            clientSearchQuery = ""
                                                            showClientDropdown = false
                                                        }
                                                        .padding(12.dp),
                                                    horizontalArrangement = Arrangement.SpaceBetween
                                                ) {
                                                    Text(c.nome, color = TextPrimary, fontSize = 14.sp)
                                                    Text(c.effectivePhone, color = TextSecondary, fontSize = 12.sp)
                                                }
                                                Divider(color = CardBorder)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Seção 2: Aparelho
                    item {
                        SectionCard(title = "Aparelho & Equipamento", icon = Icons.Default.PhoneAndroid) {
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    listOf("Celular", "Tablet", "Notebook", "Outro").forEach { t ->
                                        FilterChip(
                                            selected = devTipo == t,
                                            onClick = { devTipo = t },
                                            label = { Text(t, fontSize = 12.sp) }
                                        )
                                    }
                                }

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    OutlinedTextField(
                                        value = devMarca,
                                        onValueChange = { devMarca = it },
                                        label = { Text("Marca") },
                                        placeholder = { Text("Ex: Samsung, Apple") },
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                    OutlinedTextField(
                                        value = devModelo,
                                        onValueChange = { devModelo = it },
                                        label = { Text("Modelo") },
                                        placeholder = { Text("Ex: Galaxy S23, A54") },
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                }

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    OutlinedTextField(
                                        value = devCor,
                                        onValueChange = { devCor = it },
                                        label = { Text("Cor") },
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                    OutlinedTextField(
                                        value = devSerial,
                                        onValueChange = { devSerial = it },
                                        label = { Text("Nº Série / IMEI") },
                                        modifier = Modifier.weight(1.5f),
                                        singleLine = true
                                    )
                                }

                                OutlinedTextField(
                                    value = devDefeito,
                                    onValueChange = { devDefeito = it },
                                    label = { Text("Defeito Reclamado pelo Cliente *") },
                                    placeholder = { Text("Ex: Não liga, tela piscando, touch falhando...") },
                                    modifier = Modifier.fillMaxWidth(),
                                    minLines = 2
                                )

                                OutlinedTextField(
                                    value = devAcessorios,
                                    onValueChange = { devAcessorios = it },
                                    label = { Text("Acessórios Deixados") },
                                    placeholder = { Text("Ex: Capinha, carregador original, cartão SD...") },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
                                )

                                OutlinedTextField(
                                    value = devCondicoes,
                                    onValueChange = { devCondicoes = it },
                                    label = { Text("Condições Físicas de Entrada") },
                                    placeholder = { Text("Ex: Vidro traseiro trincado, riscos na tela...") },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
                                )
                            }
                        }
                    }

                    // Seção 3: Senha / Padrão de Desbloqueio
                    item {
                        SectionCard(title = "Bloqueio do Aparelho", icon = Icons.Default.Lock) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    FilterChip(
                                        selected = lockType == "nenhuma",
                                        onClick = { lockType = "nenhuma" },
                                        label = { Text("Sem senha") }
                                    )
                                    FilterChip(
                                        selected = lockType == "senha",
                                        onClick = { lockType = "senha" },
                                        label = { Text("Senha / PIN") }
                                    )
                                    FilterChip(
                                        selected = lockType == "padrao",
                                        onClick = { lockType = "padrao" },
                                        label = { Text("Padrão Desenho") }
                                    )
                                }

                                if (lockType == "senha") {
                                    OutlinedTextField(
                                        value = passwordText,
                                        onValueChange = { passwordText = it },
                                        label = { Text("Senha / PIN do Aparelho") },
                                        modifier = Modifier.fillMaxWidth(),
                                        singleLine = true
                                    )
                                } else if (lockType == "padrao") {
                                    PatternLockInput(
                                        sequence = patternSequence,
                                        onSequenceChanged = { patternSequence = it }
                                    )
                                }
                            }
                        }
                    }

                    // Seção 4: Checklist Técnico
                    item {
                        SectionCard(title = "Checklist de Inspeção", icon = Icons.Default.Checklist) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Itens testados na entrada do equipamento:", color = TextSecondary, fontSize = 12.sp)
                                val items = checklistItems.keys.toList()
                                for (i in items.indices step 2) {
                                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                        val item1 = items[i]
                                        ChecklistToggle(
                                            title = item1,
                                            checked = checklistItems[item1] ?: false,
                                            onCheckedChange = { checklistItems[item1] = it },
                                            modifier = Modifier.weight(1f)
                                        )
                                        if (i + 1 < items.size) {
                                            val item2 = items[i + 1]
                                            ChecklistToggle(
                                                title = item2,
                                                checked = checklistItems[item2] ?: false,
                                                onCheckedChange = { checklistItems[item2] = it },
                                                modifier = Modifier.weight(1f)
                                            )
                                        } else {
                                            Spacer(Modifier.weight(1f))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Seção 5: Diagnóstico e Peças
                    item {
                        SectionCard(title = "Diagnóstico Técnico & Peças", icon = Icons.Default.Build) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                OutlinedTextField(
                                    value = diagnostico,
                                    onValueChange = { diagnostico = it },
                                    label = { Text("Diagnóstico / Laudo Técnico") },
                                    placeholder = { Text("Constatado curto na placa, necessidade de troca do módulo...") },
                                    modifier = Modifier.fillMaxWidth(),
                                    minLines = 2
                                )

                                Text("Peças e Componentes Utilizados:", color = TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)

                                pecas.forEachIndexed { index, part ->
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(CardSecondary)
                                            .padding(8.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(part.descricao, color = TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                                            Text("${part.qtd.toInt()}× R$ ${String.format(Locale.US, "%.2f", part.valor).replace('.', ',')}", color = TextSecondary, fontSize = 11.sp)
                                        }
                                        Text(
                                            String.format("R$ %.2f", part.subtotal).replace('.', ','),
                                            color = AppleBlue,
                                            fontSize = 13.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                        IconButton(onClick = { pecas.removeAt(index) }, modifier = Modifier.size(28.dp)) {
                                            Icon(Icons.Default.Delete, contentDescription = "Remover", tint = AppleRed, modifier = Modifier.size(16.dp))
                                        }
                                    }
                                }

                                AddPartRow(onAdd = { desc, qtd, valor ->
                                    pecas.add(OrderPart(descricao = desc, qtd = qtd, valor = valor))
                                })
                            }
                        }
                    }

                    // Seção 6: Valores, Prazo e Status
                    item {
                        SectionCard(title = "Status, Valores e Fechamento", icon = Icons.Default.AttachMoney) {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                // Status
                                Text("Status Atual:", color = TextSecondary, fontSize = 12.sp)
                                val statusList = listOf("Recebido", "Em análise", "Aguardando aprovação", "Aguardando peças", "Em reparo", "Concluído", "Entregue")
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 4.dp),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    statusList.take(4).forEach { s ->
                                        FilterChip(
                                            selected = status == s,
                                            onClick = { status = s },
                                            label = { Text(s, fontSize = 10.sp) }
                                        )
                                    }
                                }
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 2.dp),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    statusList.drop(4).forEach { s ->
                                        FilterChip(
                                            selected = status == s,
                                            onClick = { status = s },
                                            label = { Text(s, fontSize = 10.sp) }
                                        )
                                    }
                                }

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    OutlinedTextField(
                                        value = maoDeObraStr,
                                        onValueChange = { maoDeObraStr = it },
                                        label = { Text("Mão de Obra (R$)") },
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                    OutlinedTextField(
                                        value = descontoStr,
                                        onValueChange = { descontoStr = it },
                                        label = { Text("Desconto (R$)") },
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                }

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    OutlinedTextField(
                                        value = prazoStr,
                                        onValueChange = { prazoStr = it },
                                        label = { Text("Prazo de Entrega") },
                                        placeholder = { Text("YYYY-MM-DD") },
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                    OutlinedTextField(
                                        value = garantiaStr,
                                        onValueChange = { garantiaStr = it },
                                        label = { Text("Garantia") },
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                }

                                OutlinedTextField(
                                    value = formaPagamento,
                                    onValueChange = { formaPagamento = it },
                                    label = { Text("Forma de Pagamento Prevista") },
                                    placeholder = { Text("Ex: Pix, Dinheiro, Cartão 3x") },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
                                )

                                OutlinedTextField(
                                    value = observacoes,
                                    onValueChange = { observacoes = it },
                                    label = { Text("Observações Gerais") },
                                    modifier = Modifier.fillMaxWidth(),
                                    minLines = 2
                                )

                                // Resumo do Total
                                Surface(
                                    shape = RoundedCornerShape(12.dp),
                                    color = CardSecondary,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(14.dp),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text("Valor Total da OS:", color = TextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                                        Text(
                                            String.format("R$ %.2f", calculatedTotal).replace('.', ','),
                                            color = AppleBlue,
                                            fontSize = 20.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    AppleCard {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(bottom = 10.dp)
        ) {
            Icon(icon, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(18.dp))
            Text(title, color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
        content()
    }
}

@Composable
private fun ChecklistToggle(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        onClick = { onCheckedChange(!checked) },
        shape = RoundedCornerShape(8.dp),
        color = if (checked) AppleGreen.copy(alpha = 0.15f) else CardSecondary,
        border = androidx.compose.foundation.BorderStroke(1.dp, if (checked) AppleGreen else CardBorder),
        modifier = modifier
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(title, color = if (checked) AppleGreen else TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            Icon(
                if (checked) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                contentDescription = null,
                tint = if (checked) AppleGreen else TextTertiary,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
private fun AddPartRow(onAdd: (String, Double, Double) -> Unit) {
    var desc by remember { mutableStateOf("") }
    var qtdStr by remember { mutableStateOf("1") }
    var valStr by remember { mutableStateOf("") }
    var showForm by remember { mutableStateOf(false) }

    if (!showForm) {
        OutlinedButton(
            onClick = { showForm = true },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(8.dp)
        ) {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Adicionar Peça / Serviço")
        }
    } else {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(CardSecondary)
                .padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = desc,
                onValueChange = { desc = it },
                label = { Text("Descrição da peça/serviço") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = qtdStr,
                    onValueChange = { qtdStr = it },
                    label = { Text("Qtd") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f),
                    singleLine = true
                )
                OutlinedTextField(
                    value = valStr,
                    onValueChange = { valStr = it },
                    label = { Text("Valor Unit. (R$)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.weight(1.5f),
                    singleLine = true
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(onClick = { showForm = false }) {
                    Text("Cancelar", color = TextSecondary)
                }
                Spacer(Modifier.width(8.dp))
                Button(
                    onClick = {
                        val q = qtdStr.toDoubleOrNull() ?: 1.0
                        val v = valStr.replace(',', '.').toDoubleOrNull() ?: 0.0
                        if (desc.isNotBlank()) {
                            onAdd(desc.trim(), q, v)
                            desc = ""
                            valStr = ""
                            qtdStr = "1"
                            showForm = false
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AppleBlue),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("Incluir")
                }
            }
        }
    }
}

@Composable
fun PatternLockInput(
    sequence: String,
    onSequenceChanged: (String) -> Unit
) {
    val selectedPoints = remember(sequence) {
        if (sequence.isBlank()) emptyList<Int>()
        else sequence.split("-", ",").mapNotNull { it.trim().toIntOrNull() }
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text("Toque nos pontos na ordem do desenho do padrão:", color = TextSecondary, fontSize = 12.sp)

        Box(
            modifier = Modifier
                .size(200.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(CardSecondary)
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.SpaceBetween,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                for (row in 0..2) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        for (col in 0..2) {
                            val pointIndex = row * 3 + col + 1
                            val isSelected = selectedPoints.contains(pointIndex)
                            val orderNum = if (isSelected) (selectedPoints.indexOf(pointIndex) + 1).toString() else ""

                            Box(
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(CircleShape)
                                    .background(if (isSelected) AppleBlue else CardBackground)
                                    .border(
                                        2.dp,
                                        if (isSelected) AppleBlue else TextSecondary.copy(alpha = 0.4f),
                                        CircleShape
                                    )
                                    .clickable {
                                        if (!selectedPoints.contains(pointIndex)) {
                                            val newList = selectedPoints + pointIndex
                                            onSequenceChanged(newList.joinToString("-"))
                                        }
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                if (isSelected) {
                                    Text(orderNum, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                } else {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(TextSecondary.copy(alpha = 0.6f))
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        if (selectedPoints.isNotEmpty()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    "Sequência: ${selectedPoints.joinToString(" → ")}",
                    color = AppleBlue,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                TextButton(onClick = { onSequenceChanged("") }) {
                    Text("Limpar", color = AppleRed, fontSize = 12.sp)
                }
            }
        }
    }
}
