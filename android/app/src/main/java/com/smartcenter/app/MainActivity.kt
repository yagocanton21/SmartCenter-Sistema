package com.smartcenter.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.smartcenter.app.data.AuthStore
import com.smartcenter.app.ui.clients.ClientsScreen
import com.smartcenter.app.ui.components.AppDrawerContent
import com.smartcenter.app.ui.components.Screen
import com.smartcenter.app.ui.dashboard.DashboardScreen
import com.smartcenter.app.ui.orders.OrdersScreen
import com.smartcenter.app.ui.quotes.QuotesScreen
import com.smartcenter.app.ui.sales.SalesScreen
import com.smartcenter.app.ui.theme.*
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val authStore = AuthStore(applicationContext)

        setContent {
            SmartCenterTheme {
                MainAppNav(authStore)
            }
        }
    }
}

@Composable
fun MainAppNav(authStore: AuthStore) {
    val currentUser by authStore.currentUser.collectAsState()
    val serverUrl by authStore.serverUrl.collectAsState()

    var showServerDialog by remember { mutableStateOf(false) }

    if (currentUser == null) {
        LoginScreen(
            authStore = authStore,
            onConfigureServer = { showServerDialog = true }
        )
    } else {
        val drawerState = rememberDrawerState(initialValue = DrawerValue.Closed)
        val scope = rememberCoroutineScope()
        var currentScreen by remember { mutableStateOf(Screen.DASHBOARD) }

        ModalNavigationDrawer(
            drawerState = drawerState,
            drawerContent = {
                AppDrawerContent(
                    currentScreen = currentScreen,
                    user = currentUser,
                    serverUrl = serverUrl,
                    onScreenSelected = { screen ->
                        currentScreen = screen
                        scope.launch { drawerState.close() }
                    },
                    onLogoutClick = {
                        scope.launch { authStore.logout() }
                    },
                    onServerConfigClick = { showServerDialog = true }
                )
            }
        ) {
            when (currentScreen) {
                Screen.DASHBOARD -> DashboardScreen(authStore = authStore, onMenuClick = { scope.launch { drawerState.open() } })
                Screen.ORDERS -> OrdersScreen(authStore = authStore, onMenuClick = { scope.launch { drawerState.open() } })
                Screen.QUOTES -> QuotesScreen(authStore = authStore, onMenuClick = { scope.launch { drawerState.open() } })
                Screen.SALES -> SalesScreen(authStore = authStore, onMenuClick = { scope.launch { drawerState.open() } })
                Screen.CLIENTS -> ClientsScreen(authStore = authStore, onMenuClick = { scope.launch { drawerState.open() } })
            }
        }
    }

    if (showServerDialog) {
        var tempUrl by remember { mutableStateOf(serverUrl) }
        AlertDialog(
            onDismissRequest = { showServerDialog = false },
            title = { Text("Endereço do Servidor") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Informe o IP ou domínio do backend SmartCenter:", fontSize = 13.sp, color = TextSecondary)
                    OutlinedTextField(
                        value = tempUrl,
                        onValueChange = { tempUrl = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        placeholder = { Text("http://192.168.1.50:3000") }
                    )
                }
            },
            confirmButton = {
                Button(onClick = {
                    authStore.setServerUrl(tempUrl)
                    showServerDialog = false
                }) {
                    Text("Salvar")
                }
            },
            dismissButton = {
                TextButton(onClick = { showServerDialog = false }) {
                    Text("Cancelar")
                }
            },
            containerColor = CardBackground
        )
    }
}

@Composable
fun LoginScreen(
    authStore: AuthStore,
    onConfigureServer: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val serverUrl by authStore.serverUrl.collectAsState()

    var login by remember { mutableStateOf("admin") }
    var password by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var errorMsg by remember { mutableStateOf<String?>(null) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Brand Icon
            Box(
                modifier = Modifier
                    .size(68.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.linearGradient(listOf(AppleBlue, AppleIndigo))),
                contentAlignment = Alignment.Center
            ) {
                Text("SC", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 28.sp)
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("SmartCenter", color = TextPrimary, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                Text("Assistência Técnica & Gestão", color = TextSecondary, fontSize = 13.sp)
            }

            Spacer(Modifier.height(8.dp))

            // Inputs
            OutlinedTextField(
                value = login,
                onValueChange = { login = it },
                label = { Text("Usuário") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = CardBackground,
                    unfocusedContainerColor = CardBackground,
                    focusedBorderColor = AppleBlue,
                    unfocusedBorderColor = CardBorder,
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary
                )
            )

            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Senha") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedContainerColor = CardBackground,
                    unfocusedContainerColor = CardBackground,
                    focusedBorderColor = AppleBlue,
                    unfocusedBorderColor = CardBorder,
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary
                )
            )

            if (errorMsg != null) {
                Text(text = errorMsg ?: "", color = AppleRed, fontSize = 12.sp)
            }

            Button(
                onClick = {
                    scope.launch {
                        loading = true
                        errorMsg = null
                        val res = authStore.login(login, password)
                        loading = false
                        if (res.isFailure) {
                            errorMsg = res.exceptionOrNull()?.localizedMessage ?: "Falha ao autenticar"
                        }
                    }
                },
                enabled = !loading,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AppleBlue)
            ) {
                if (loading) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                } else {
                    Text("Entrar", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }

            TextButton(onClick = onConfigureServer) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Default.Settings, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(14.dp))
                    Text("Configurar Servidor: $serverUrl", color = TextSecondary, fontSize = 11.sp)
                }
            }
        }
    }
}

