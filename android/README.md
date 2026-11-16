# SmartCenter Mobile — Android (Jetpack Compose)

App nativo Android construído em **Kotlin + Jetpack Compose**, mantendo rigorosamente a mesma linguagem de design, fluidez e componentes desenvolvidos no app iOS.

---

## 🎨 Design System e Funcionalidades

- **Tema Escuro Nativo:** Superfícies em `#000000` e `#1C1C1E` com bordas sutis e tipografia moderna.
- **Módulos Prontos:**
  - 📋 **Ordens de Serviço (`OrdersScreen`):** Cards com `#0001`, chips de status horizontais, badges, defeito reclamado, botão WhatsApp (34dp) e folha de detalhes.
  - 📄 **Orçamentos (`QuotesScreen`):** Listagem de propostas, filtros de situação, envio de proposta via WhatsApp e folha de detalhes.
  - 🛒 **Vendas (`SalesScreen`):** Cards de métricas financeiras (Total Vendido, Ticket Médio, Lucro Líquido), listagem de vendas, itens vendidos, comprovante no WhatsApp, cancelamento transacional com devolução automática de estoque e folha de detalhes.
  - 👥 **Clientes (`ClientsScreen`):** Avatares dinâmicos com gradiente e iniciais, busca em tempo real, paginação de 10 por página, atalho de WhatsApp e visualizador de ficha de cliente.
- **Comunicação com o Backend:** Reutilização total da API REST (`/api/login`, `/api/db`, `/api/changes`, `/api/vendas/:id/cancelar`) com controle automático de cookies e token CSRF.

---

## 🚀 Como Abrir e Executar

### Opção 1: Via Android Studio (Recomendado)
1. Abra o **Android Studio**.
2. Clique em **Open** e selecione a pasta:
   ```
   SmartCenter-Sistema/android
   ```
3. O Android Studio sincronizará o Gradle automaticamente. Caso o Android SDK 34 ainda não esteja baixado na sua máquina, ele exibirá um aviso para baixar com um clique.
4. Conecte seu aparelho Android via USB (com a opção **Depuração USB** ativada nas Opções do Desenvolvedor) ou abra um emulador.
5. Clique no botão verde de **Run (Play)** no topo do Android Studio.

### Opção 2: Via Linha de Comando (com Celular Conectado)
No terminal PowerShell:
```powershell
cd android
$env:JAVA_HOME = "C:\Users\Yago Canton\tools\jdk-21.0.12.1+1"
.\gradlew.bat installDebug
```

