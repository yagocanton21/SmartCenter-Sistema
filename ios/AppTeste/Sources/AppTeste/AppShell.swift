import SwiftUI

enum MobilePage: String, CaseIterable, Identifiable {
    case dashboard, os, notas, orcamentos, vendas, produtos, clientes, config, usuarios, backup
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: "Painel"
        case .os: "Ordens de serviço"
        case .notas: "Notas de serviço"
        case .orcamentos: "Orçamentos"
        case .vendas: "Vendas"
        case .produtos: "Produtos e estoque"
        case .clientes: "Clientes"
        case .config: "Configurações"
        case .usuarios: "Usuários"
        case .backup: "Backup"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .os: "wrench.and.screwdriver"
        case .notas: "checkmark.seal"
        case .orcamentos: "doc.text"
        case .vendas: "cart"
        case .produtos: "shippingbox"
        case .clientes: "person.2"
        case .config: "gearshape"
        case .usuarios: "person.badge.shield.checkmark"
        case .backup: "arrow.down.doc"
        }
    }
    var isSettings: Bool {
        switch self {
        case .config, .usuarios, .backup: true
        default: false
        }
    }
}

struct AppShell: View {
    @ObservedObject var auth: AuthStore
    let user: LoginUser
    @State private var page: MobilePage = .dashboard
    @State private var menuOpen = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .leading) {
            Group {
                switch page {
                case .dashboard:
                    DashboardView(auth: auth, user: user)
                case .os:
                    OrdersView(auth: auth)
                case .notas:
                    ServiceNotesView(auth: auth)
                case .orcamentos:
                    QuotesView(auth: auth)
                case .vendas:
                    SalesView(auth: auth)
                case .config:
                    StoreConfigView(auth: auth)
                case .usuarios:
                    UsersManagerView(auth: auth)
                case .backup:
                    BackupView(auth: auth)
                case .clientes:
                    ClientsView(auth: auth)
                default:
                    RecordsView(auth: auth, page: page).id(page)
                }
            }.allowsHitTesting(!menuOpen).accessibilityHidden(menuOpen)
            if menuOpen {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { closeMenu() }.accessibilityLabel("Fechar menu")
                sidebar.transition(.move(edge: .leading)).zIndex(1)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { withAnimation(.easeInOut(duration: 0.22)) { menuOpen.toggle() } } label: {
                    Image(systemName: menuOpen ? "xmark" : "line.3.horizontal")
                }.accessibilityLabel(menuOpen ? "Fechar menu" : "Abrir menu")
            }
        }
        .onAppear {
            if !user.can(page.rawValue), let first = MobilePage.allCases.first(where: { user.can($0.rawValue) }) { page = first }
        }
    }

    private func closeMenu() { withAnimation(.easeInOut(duration: 0.22)) { menuOpen = false } }

    private func menuRow(_ item: MobilePage) -> some View {
        Button {
            page = item
            closeMenu()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.icon).frame(width: 24)
                Text(item.title).font(.system(size: 14, weight: .medium))
                Spacer()
                if page == item { Circle().fill(.blue).frame(width: 6, height: 6) }
            }.padding(11).foregroundStyle(page == item ? Color.blue : Color.primary)
                .background(page == item ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("SC").font(.title3.bold()).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.blue.gradient, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smartcenter").font(.system(size: 16, weight: .semibold))
                    Text("Assistência técnica").font(.caption).foregroundStyle(.secondary)
                }
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(MobilePage.allCases.filter { !$0.isSettings && user.can($0.rawValue) }) { item in
                        menuRow(item)
                    }
                    let settingsPages = MobilePage.allCases.filter { $0.isSettings && user.can($0.rawValue) }
                    if !settingsPages.isEmpty {
                        HStack {
                            Text("ADMINISTRAÇÃO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 10)
                                .padding(.horizontal, 10)
                            Spacer()
                        }
                        ForEach(settingsPages) { item in
                            menuRow(item)
                        }
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text(user.nome).font(.subheadline.bold())
                Text(user.perfil.capitalized).font(.caption).foregroundStyle(.secondary)
            }
            Button(role: .destructive) { Task { await auth.logout() } } label: {
                Label("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right")
            }.disabled(auth.busy || auth.loadingDashboard)
        }.padding(18).frame(maxWidth: 280, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemGroupedBackground)).shadow(radius: 20)
            .accessibilityAction(.escape) { closeMenu() }
    }
}
