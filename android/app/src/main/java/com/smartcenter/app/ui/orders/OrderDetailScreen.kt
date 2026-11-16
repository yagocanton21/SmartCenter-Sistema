package com.smartcenter.app.ui.orders

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.smartcenter.app.data.AuthStore
import com.smartcenter.app.data.Order
import com.smartcenter.app.data.WhatsAppHelper
import com.smartcenter.app.ui.components.AppleCard
import com.smartcenter.app.ui.components.DetailRowItem
import com.smartcenter.app.ui.components.StatusBadgePill
import com.smartcenter.app.ui.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrderDetailScreen(
    order: Order,
    authStore: AuthStore,
    onBack: () -> Unit,
    onEdit: (Order) -> Unit,
    onDeleted: () -> Unit,
    onStatusChanged: (Order) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var currentStatus by remember(order.status) { mutableStateOf(order.status) }
    var showStatusDialog by remember { mutableStateOf(false) }
    var showDeleteConfirmDialog by remember { mutableStateOf(false) }
    var updatingStatus by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val statusColor = when (currentStatus) {
        "Entregue", "Concluído" -> AppleGreen
        "Em reparo", "Aguardando peças" -> AppleOrange
        else -> AppleBlue
    }

    val availableStatuses = listOf(
        "Recebido",
        "Em análise",
        "Aguardando aprovação",
        "Aguardando peças",
        "Em reparo",
        "Concluído",
        "Entregue"
    )

    BackHandler(onBack = onBack)

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "Ordem ${order.shortNumber}",
                            fontWeight = FontWeight.Bold,
                            color = TextPrimary,
                            fontSize = 18.sp,
                            fontFamily = FontFamily.Monospace
                        )
                        Text(
                            text = "Entrada: ${order.formattedDate}",
                            color = TextSecondary,
                            fontSize = 11.sp
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Voltar", tint = TextPrimary)
                    }
                },
                actions = {
                    IconButton(onClick = { onEdit(order) }) {
                        Icon(Icons.Default.Edit, contentDescription = "Editar OS", tint = AppleBlue)
                    }
                    IconButton(onClick = { showDeleteConfirmDialog = true }) {
                        Icon(Icons.Default.Delete, contentDescription = "Excluir OS", tint = AppleRed)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = DarkBackground)
            )
        },
        bottomBar = {
            Surface(
                color = CardBackground,
                border = androidx.compose.foundation.BorderStroke(1.dp, CardBorder)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    // Botão Largo de WhatsApp
                    Button(
                        onClick = {
                            WhatsAppHelper.sendOSWhatsApp(context, order)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AppleGreen),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Message, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color.White)
                        Spacer(Modifier.width(8.dp))
                        Text("Enviar Notificação WhatsApp", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Color.White)
                    }

                    // Ações Secundárias em Linha
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        OutlinedButton(
                            onClick = { showStatusDialog = true },
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp),
                            shape = RoundedCornerShape(10.dp),
                            border = androidx.compose.foundation.BorderStroke(1.dp, AppleBlue.copy(alpha = 0.5f))
                        ) {
                            Icon(Icons.Default.SyncAlt, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Mudar Status", color = AppleBlue, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }

                        Button(
                            onClick = { onEdit(order) },
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp),
                            shape = RoundedCornerShape(10.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = AppleBlue)
                        ) {
                            Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color.White)
                            Spacer(Modifier.width(6.dp))
                            Text("Editar OS", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        },
        containerColor = DarkBackground
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            contentPadding = PaddingValues(vertical = 12.dp)
        ) {
            if (errorMessage != null) {
                item {
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = AppleRed.copy(alpha = 0.15f),
                        border = androidx.compose.foundation.BorderStroke(1.dp, AppleRed.copy(alpha = 0.4f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(errorMessage ?: "", color = AppleRed, fontSize = 13.sp, modifier = Modifier.padding(12.dp))
                    }
                }
            }

            // Card 1: Status Atual com Botão de Troca Rápida
            item {
                AppleCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Status da Ordem", color = TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                            Spacer(Modifier.height(4.dp))
                            StatusBadgePill(text = currentStatus, color = statusColor)
                        }

                        Button(
                            onClick = { showStatusDialog = true },
                            colors = ButtonDefaults.buttonColors(containerColor = CardSecondary),
                            shape = RoundedCornerShape(8.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text("Alterar", color = AppleBlue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Card 2: Cliente
            item {
                AppleCard {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(bottom = 6.dp)
                    ) {
                        Icon(Icons.Default.Person, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(18.dp))
                        Text("Dados do Cliente", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }

                    HorizontalDivider(color = CardBorder)
                    Spacer(Modifier.height(6.dp))

                    DetailRowItem("Nome Completo", order.clientName)
                    if (order.clientPhone.isNotEmpty()) {
                        DetailRowItem("Telefone / WhatsApp", order.clientPhone)
                        Spacer(Modifier.height(4.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = {
                                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${order.clientPhone.filter { it.isDigit() }}"))
                                    context.startActivity(intent)
                                },
                                shape = RoundedCornerShape(8.dp),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                            ) {
                                Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(14.dp))
                                Spacer(Modifier.width(4.dp))
                                Text("Ligar", fontSize = 11.sp)
                            }

                            OutlinedButton(
                                onClick = {
                                    val digits = order.clientPhone.filter { it.isDigit() }
                                    val full = if (digits.length <= 11) "55$digits" else digits
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$full"))
                                    context.startActivity(intent)
                                },
                                shape = RoundedCornerShape(8.dp),
                                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp)
                            ) {
                                Icon(Icons.Default.Chat, contentDescription = null, modifier = Modifier.size(14.dp), tint = AppleGreen)
                                Spacer(Modifier.width(4.dp))
                                Text("Conversar", fontSize = 11.sp, color = AppleGreen)
                            }
                        }
                    }
                }
            }

            // Card 3: Aparelho e Defeito
            item {
                AppleCard {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(bottom = 6.dp)
                    ) {
                        Icon(Icons.Default.PhoneAndroid, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(18.dp))
                        Text("Aparelho & Equipamento", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }

                    HorizontalDivider(color = CardBorder)
                    Spacer(Modifier.height(6.dp))

                    DetailRowItem("Tipo / Marca / Modelo", "${order.aparelho.tipo} · ${order.aparelho.title}")
                    if (order.aparelho.cor.isNotEmpty()) {
                        DetailRowItem("Cor", order.aparelho.cor)
                    }
                    if (order.aparelho.serial.isNotEmpty()) {
                        DetailRowItem("Nº Série / IMEI", order.aparelho.serial)
                    }
                    DetailRowItem("Defeito Reclamado", order.aparelho.defeito.ifEmpty { "Não informado" })
                    if (order.aparelho.acessorios.isNotEmpty()) {
                        DetailRowItem("Acessórios Deixados", order.aparelho.acessorios)
                    }
                    if (order.aparelho.condicoes.isNotEmpty()) {
                        DetailRowItem("Condições Físicas de Entrada", order.aparelho.condicoes)
                    }
                }
            }

            // Card 4: Senha / Padrão de Desbloqueio (se houver)
            if (order.aparelho.senha.isNotEmpty() || order.aparelho.senhaPadrao.isNotEmpty()) {
                item {
                    AppleCard {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.padding(bottom = 6.dp)
                        ) {
                            Icon(Icons.Default.Lock, contentDescription = null, tint = AppleOrange, modifier = Modifier.size(18.dp))
                            Text("Segurança do Aparelho", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        }

                        HorizontalDivider(color = CardBorder)
                        Spacer(Modifier.height(6.dp))

                        if (order.aparelho.senha.isNotEmpty()) {
                            DetailRowItem("Senha / PIN Digitada", order.aparelho.senha)
                        }

                        if (order.aparelho.senhaPadrao.isNotEmpty()) {
                            Text("Padrão de Desenho:", color = TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                            Spacer(Modifier.height(4.dp))
                            PatternLockDisplay(sequence = order.aparelho.senhaPadrao)
                        }
                    }
                }
            }

            // Card 5: Laudo Técnico e Peças
            item {
                AppleCard {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(bottom = 6.dp)
                    ) {
                        Icon(Icons.Default.Build, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(18.dp))
                        Text("Serviços & Peças", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }

                    HorizontalDivider(color = CardBorder)
                    Spacer(Modifier.height(6.dp))

                    if (order.diagnostico.isNotEmpty()) {
                        DetailRowItem("Diagnóstico Técnico", order.diagnostico)
                        Spacer(Modifier.height(6.dp))
                    }

                    if (order.pecas.isNotEmpty()) {
                        Text("Peças Utilizadas:", color = TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                        order.pecas.forEach { p ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 3.dp),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text("• ${p.qtd.toInt()}× ${p.descricao}", color = TextPrimary, fontSize = 13.sp)
                                Text(String.format("R$ %.2f", p.subtotal).replace('.', ','), color = TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                        Spacer(Modifier.height(6.dp))
                    }

                    if (order.maoDeObra > 0) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Mão de Obra:", color = TextSecondary, fontSize = 13.sp)
                            Text(String.format("R$ %.2f", order.maoDeObra).replace('.', ','), color = TextPrimary, fontSize = 13.sp)
                        }
                    }

                    if (order.desconto > 0) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Desconto:", color = AppleRed, fontSize = 13.sp)
                            Text("- " + String.format("R$ %.2f", order.desconto).replace('.', ','), color = AppleRed, fontSize = 13.sp)
                        }
                    }

                    Spacer(Modifier.height(6.dp))
                    HorizontalDivider(color = CardBorder)
                    Spacer(Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Valor Total da OS", color = TextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Text(
                            String.format("R$ %.2f", order.total).replace('.', ','),
                            color = AppleBlue,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Card 6: Informações Adicionais (Prazo, Garantia, Pagamento)
            item {
                AppleCard {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.padding(bottom = 6.dp)
                    ) {
                        Icon(Icons.Default.Info, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(18.dp))
                        Text("Prazos & Condições", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }

                    HorizontalDivider(color = CardBorder)
                    Spacer(Modifier.height(6.dp))

                    if (order.prazo.isNotEmpty()) {
                        DetailRowItem("Prazo de Entrega", order.prazo)
                    }
                    if (order.garantia.isNotEmpty()) {
                        DetailRowItem("Garantia", order.garantia)
                    }
                    if (order.formaPagamento.isNotEmpty()) {
                        DetailRowItem("Forma de Pagamento", order.formaPagamento)
                    }
                    if (order.obs.isNotEmpty()) {
                        DetailRowItem("Observações Internas", order.obs)
                    }
                }
            }

            // Espaçamento final para rolagem
            item {
                Spacer(Modifier.height(20.dp))
            }
        }
    }

    // Diálogo de Alteração de Status
    if (showStatusDialog) {
        AlertDialog(
            onDismissRequest = { showStatusDialog = false },
            title = { Text("Alterar Status da OS", color = TextPrimary) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    availableStatuses.forEach { st ->
                        Surface(
                            onClick = {
                                if (st != currentStatus && !updatingStatus) {
                                    updatingStatus = true
                                    scope.launch {
                                        val res = authStore.changeRecordStatus("os", order.id, order.raw, st)
                                        updatingStatus = false
                                        showStatusDialog = false
                                        if (res.isSuccess) {
                                            currentStatus = st
                                            onStatusChanged(order.copy(status = st))
                                        } else {
                                            errorMessage = res.exceptionOrNull()?.localizedMessage
                                        }
                                    }
                                } else {
                                    showStatusDialog = false
                                }
                            },
                            shape = RoundedCornerShape(8.dp),
                            color = if (currentStatus == st) AppleBlue.copy(alpha = 0.2f) else Color.Transparent,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 14.dp, vertical = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    st,
                                    color = if (currentStatus == st) AppleBlue else TextPrimary,
                                    fontSize = 14.sp,
                                    fontWeight = if (currentStatus == st) FontWeight.Bold else FontWeight.Normal
                                )
                                if (currentStatus == st) {
                                    Icon(Icons.Default.Check, contentDescription = null, tint = AppleBlue, modifier = Modifier.size(16.dp))
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showStatusDialog = false }) {
                    Text("Cancelar", color = TextSecondary)
                }
            },
            containerColor = CardBackground
        )
    }

    // Diálogo de Confirmação de Exclusão
    if (showDeleteConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmDialog = false },
            title = { Text("Excluir Ordem de Serviço", color = TextPrimary) },
            text = {
                Text("Deseja realmente excluir a OS ${order.shortNumber}? Esta ação não pode ser desfeita.", color = TextSecondary)
            },
            confirmButton = {
                Button(
                    onClick = {
                        deleting = true
                        scope.launch {
                            val res = authStore.deleteRecord("os", order.id, order.raw)
                            deleting = false
                            showDeleteConfirmDialog = false
                            if (res.isSuccess) {
                                onDeleted()
                            } else {
                                errorMessage = res.exceptionOrNull()?.localizedMessage
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AppleRed)
                ) {
                    Text("Excluir Definitivamente", fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmDialog = false }) {
                    Text("Cancelar", color = TextSecondary)
                }
            },
            containerColor = CardBackground
        )
    }
}

@Composable
fun PatternLockDisplay(sequence: String) {
    val points = sequence.split("-", ",").mapNotNull { it.trim().toIntOrNull() }

    Box(
        modifier = Modifier
            .size(160.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(CardSecondary)
            .padding(12.dp),
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
                        val isSelected = points.contains(pointIndex)
                        val orderNum = if (isSelected) (points.indexOf(pointIndex) + 1).toString() else ""

                        Box(
                            modifier = Modifier
                                .size(34.dp)
                                .clip(CircleShape)
                                .background(if (isSelected) AppleBlue else CardBackground)
                                .border(
                                    2.dp,
                                    if (isSelected) AppleBlue else TextSecondary.copy(alpha = 0.3f),
                                    CircleShape
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            if (isSelected) {
                                Text(orderNum, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                            } else {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(TextSecondary.copy(alpha = 0.4f))
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (points.isNotEmpty()) {
        Spacer(Modifier.height(4.dp))
        Text(
            text = "Ordem: ${points.joinToString(" → ")}",
            color = AppleBlue,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
