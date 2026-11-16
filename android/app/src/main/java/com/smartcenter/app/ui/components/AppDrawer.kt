package com.smartcenter.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.smartcenter.app.data.AuthStore
import com.smartcenter.app.data.User
import com.smartcenter.app.ui.theme.*
import kotlinx.coroutines.launch

enum class Screen(val perm: String, val title: String, val icon: ImageVector) {
    DASHBOARD("dashboard", "Painel", Icons.Default.Dashboard),
    ORDERS("os", "Ordens de serviço", Icons.Default.Build),
    QUOTES("orcamentos", "Orçamentos", Icons.Default.Description),
    SALES("vendas", "Vendas", Icons.Default.ShoppingCart),
    CLIENTS("clientes", "Clientes", Icons.Default.People)
}

@Composable
fun AppDrawerContent(
    currentScreen: Screen,
    user: User?,
    serverUrl: String,
    onScreenSelected: (Screen) -> Unit,
    onLogoutClick: () -> Unit,
    onServerConfigClick: () -> Unit
) {
    ModalDrawerSheet(
        drawerContainerColor = CardBackground,
        drawerContentColor = TextPrimary,
        modifier = Modifier.width(300.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight()
                .padding(20.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                // Brand Header
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(42.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                Brush.linearGradient(
                                    listOf(AppleBlue, AppleIndigo)
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "SC",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp
                        )
                    }

                    Column {
                        Text(
                            text = "SmartCenter",
                            color = TextPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 17.sp
                        )
                        Text(
                            text = "Assistência técnica",
                            color = TextSecondary,
                            fontSize = 12.sp
                        )
                    }
                }

                Divider(color = CardBorder)

                // Menu Rows
                Screen.values().filter { user?.can(it.perm) ?: true }.forEach { screen ->
                    val isSelected = screen == currentScreen
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isSelected) AppleBlue.copy(alpha = 0.15f) else Color.Transparent)
                            .clickable { onScreenSelected(screen) }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        Icon(
                            imageVector = screen.icon,
                            contentDescription = null,
                            tint = if (isSelected) AppleBlue else TextSecondary,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            text = screen.title,
                            color = if (isSelected) AppleBlue else TextPrimary,
                            fontSize = 14.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                        )
                    }
                }
            }

            // Footer
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Divider(color = CardBorder)

                // Server IP shortcut
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .clickable { onServerConfigClick() }
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(Icons.Default.Dns, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(14.dp))
                    Text(
                        text = "Servidor: $serverUrl",
                        color = TextSecondary,
                        fontSize = 11.sp,
                        maxLines = 1
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(user?.nome ?: "Usuário", color = TextPrimary, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                        Text(user?.perfil?.replaceFirstChar { it.uppercase() } ?: "", color = TextSecondary, fontSize = 12.sp)
                    }

                    IconButton(onClick = onLogoutClick) {
                        Icon(Icons.Default.ExitToApp, contentDescription = "Sair", tint = AppleRed)
                    }
                }
            }
        }
    }
}

