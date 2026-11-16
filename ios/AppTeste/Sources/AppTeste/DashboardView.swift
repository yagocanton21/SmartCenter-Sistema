import SwiftUI

struct DashboardView: View {
    @ObservedObject var auth: AuthStore
    let user: LoginUser
    @Environment(\.colorScheme) private var colorScheme
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private var surface: Color { colorScheme == .dark ? Color(red: 0.09, green: 0.12, blue: 0.18) : .white }
    private var canvas: Color { colorScheme == .dark ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.95, green: 0.96, blue: 0.98) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !user.can("dashboard") {
                    ContentUnavailableView("Painel indisponível", systemImage: "lock", description: Text("Seu perfil não tem acesso ao painel."))
                } else {
                    if let error = auth.dashboardError {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                            Button("Tentar novamente") { Task { await auth.loadDashboard() } }.disabled(auth.loadingDashboard)
                        }.padding().background(surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if let data = auth.dashboard {
                        HStack {
                            Text("Visão geral").font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text("Hoje").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        }
                        metrics(data)
                        if user.can("os") || user.can("notas") {
                            section("Ordens por status") {
                                ForEach(DashboardData.statuses, id: \.self) { status in
                                    VStack(spacing: 8) {
                                        HStack {
                                            Text(status).foregroundStyle(.secondary)
                                            Spacer()
                                            Text("\(data.count([status]))").bold().monospacedDigit()
                                        }.font(.system(size: 12))
                                        GeometryReader { geometry in
                                            Capsule().fill(Color.blue.opacity(0.10))
                                                .overlay(alignment: .leading) {
                                                    Capsule().fill(Color.blue.gradient)
                                                        .frame(width: geometry.size.width * CGFloat(data.count([status])) / CGFloat(max(data.os.count, 1)))
                                                }
                                        }.frame(height: 5)
                                    }.padding(.vertical, 4)
                                }
                            }
                        }
                        section("Alertas") {
                            if data.overdue > 0 {
                                Label("\(data.overdue) OS com prazo vencido.", systemImage: "clock.badge.exclamationmark").foregroundStyle(.orange)
                            }
                            if data.lowStock > 0 {
                                Label("\(data.lowStock) produto(s) com estoque baixo ou zerado.", systemImage: "shippingbox").foregroundStyle(.orange)
                            }
                            if data.overdue == 0 && data.lowStock == 0 {
                                Label("Nenhum alerta de prazo ou estoque nos dados disponíveis.", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                            }
                        }
                        if let date = auth.updatedAt {
                            Text("Atualizado às \(date.formatted(date: .omitted, time: .shortened)). Puxe para atualizar.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else if auth.loadingDashboard {
                        ProgressView("Carregando painel…").frame(maxWidth: .infinity).padding(40)
                    }
                }
                if let error = auth.error { Text(error).foregroundStyle(.red).font(.footnote) }
            }.padding(16).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(canvas.ignoresSafeArea())
        .navigationTitle("Smartcenter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Text(user.nome)
                    Button("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right") { Task { await auth.logout() } }
                } label: {
                    Image(systemName: "person.crop.circle").font(.title3)
                }.disabled(auth.busy || auth.loadingDashboard).accessibilityLabel("Conta")
            }
        }
        .task { await auth.loadDashboard() }
        .refreshable { await auth.loadDashboard() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text("SMARTCENTER").font(.caption.weight(.bold)).tracking(2)
                }
                Spacer()
                Text("PAINEL").font(.system(size: 10, weight: .bold)).tracking(1)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.15), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Olá, \(user.nome.components(separatedBy: " ").first ?? user.nome)!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Sua assistência, em um só lugar.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
            }
            Label(Date.now.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "pt_BR"))), systemImage: "calendar")
                .font(.caption).foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white).padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.31, blue: 0.79), Color(red: 0.12, green: 0.20, blue: 0.47)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12)) }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }

    private func metrics(_ data: DashboardData) -> some View {
        let today = DashboardData.dateKey()
        let month = String(today.prefix(7))
        return LazyVGrid(columns: columns, spacing: 12) {
            if user.can("os") || user.can("notas") {
                card("Ordens de serviço", value: "\(data.os.count)", icon: "wrench.and.screwdriver", detail: "\(data.os.filter { ($0.dataEntrada ?? "").hasPrefix(month) }.count) abertas no mês")
                card("Aguardando aprovação", value: "\(data.count(["Aguardando aprovação"]))", icon: "clock", detail: "Aguardando o cliente")
                card("Em manutenção", value: "\(data.count(["Em análise", "Aguardando peças", "Em reparo"]))", icon: "iphone", detail: "Análise, peças ou reparo")
                card("Serviços concluídos", value: "\(data.count(["Concluído", "Entregue"]))", icon: "checkmark.circle", detail: "\(data.count(["Concluído"])) aguardando retirada")
            }
            if user.can("vendas") {
                card("Total de vendas", value: "\(data.validSales.count)", icon: "cart", detail: money(data.validSales.reduce(0) { $0 + ($1.total ?? 0) }))
            }
            if user.can("vendas") || user.can("os") || user.can("notas") {
                card("Faturamento hoje", value: money(data.revenue(prefix: today)), icon: "brazilianrealsign.circle", detail: "Vendas + OS entregues")
                card("Faturamento do mês", value: money(data.revenue(prefix: month)), icon: "chart.bar", detail: "Vendas + OS entregues")
            }
            if user.can("orcamentos") {
                card("Orçamentos pendentes", value: "\(data.pendingQuotes.count)", icon: "doc.text", detail: money(data.pendingQuotes.reduce(0) { $0 + ($1.total ?? 0) }))
            }
        }
    }

    private func card(_ title: String, value: String, icon: String, detail: String) -> some View {
        let tone: Color = icon == "clock" || icon == "doc.text" ? .orange : icon == "checkmark.circle" ? .green : icon == "chart.bar" || icon == "brazilianrealsign.circle" ? .teal : .blue
        return VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(tone)
                .frame(width: 28, height: 28).background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.55).lineLimit(1)
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(12).background(surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)) }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.10 : 0.035), radius: 10, y: 4)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 14, weight: .semibold))
            content()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)) }
    }
}
