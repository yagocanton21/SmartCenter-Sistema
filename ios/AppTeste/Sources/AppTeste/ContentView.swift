import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthStore()
    @AppStorage("smartcenter.server") private var server = "http://163.176.205.54:8093"
    @AppStorage("smartcenter.remember") private var remember = false
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focused: Field?
    @Environment(\.colorScheme) private var scheme
    private enum Field { case username, password }
    private var surface: Color { scheme == .dark ? Color(red: 0.09, green: 0.12, blue: 0.18) : .white }

    var body: some View {
        NavigationStack {
            if auth.restoring {
                VStack(spacing: 14) {
                    brand
                    ProgressView("Verificando sua sessão…").font(.footnote)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let user = auth.user {
                AppShell(auth: auth, user: user)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        brand.padding(.top, 22)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bem-vindo de volta.").font(.system(size: 27, weight: .bold, design: .rounded))
                            Text("Tudo pronto para mais um dia de trabalho.")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("USUÁRIO").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                                HStack(spacing: 10) {
                                    Image(systemName: "person").foregroundStyle(.secondary).frame(width: 18)
                                    TextField("Seu usuário", text: $username)
                                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                                        .focused($focused, equals: .username).submitLabel(.next)
                                        .onSubmit { focused = .password }
                                }.padding(13).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            }
                            VStack(alignment: .leading, spacing: 7) {
                                Text("SENHA").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                                HStack(spacing: 10) {
                                    Image(systemName: "lock").foregroundStyle(.secondary).frame(width: 18)
                                    Group {
                                        if showPassword { TextField("Sua senha", text: $password) }
                                        else { SecureField("Sua senha", text: $password) }
                                    }.textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                                        .focused($focused, equals: .password).submitLabel(.go).onSubmit { signIn() }
                                    Button { showPassword.toggle() } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(.secondary)
                                    }.accessibilityLabel(showPassword ? "Ocultar senha" : "Mostrar senha")
                                }.padding(13).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            }
                            Toggle(isOn: $remember) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Manter-me conectado").font(.system(size: 13, weight: .medium))
                                    Text("Neste iPhone, enquanto a sessão for válida.").font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }.tint(.blue).controlSize(.small)
                            if let error = auth.error {
                                Label(error, systemImage: "exclamationmark.circle").font(.system(size: 12)).foregroundStyle(.red)
                            }
                            Button(action: signIn) {
                                HStack(spacing: 10) {
                                    if auth.busy { ProgressView().tint(.white) }
                                    Text(auth.busy ? "Entrando…" : "Entrar na minha conta").font(.system(size: 14, weight: .semibold))
                                    if !auth.busy { Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)) }
                                }.foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 46)
                                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                                .disabled(auth.busy || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                                .opacity(username.isEmpty || password.isEmpty ? 0.55 : 1)
                        }.font(.system(size: 14)).padding(20).background(surface, in: RoundedRectangle(cornerRadius: 20))
                            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.06)) }
                            .disabled(auth.busy)
                        DisclosureGroup {
                            TextField("https://seu-servidor", text: $server).font(.system(size: 13))
                                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().padding(.vertical, 10)
                            if server.lowercased().hasPrefix("http://") {
                                Label("Conexão HTTP de teste, sem criptografia.", systemImage: "lock.open")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        } label: {
                            Label("Configuração do servidor", systemImage: "slider.horizontal.3").font(.system(size: 12)).foregroundStyle(.secondary)
                        }.disabled(auth.busy)
                        Text("SMARTCENTER · GESTÃO DE ASSISTÊNCIA TÉCNICA")
                            .font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.bottom, 16)
                    }.padding(24).frame(maxWidth: 440).frame(maxWidth: .infinity)
                }
                .background((scheme == .dark ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.95, green: 0.96, blue: 0.98)).ignoresSafeArea())
                .scrollDismissesKeyboard(.interactively)
            }
        }.task { await auth.restoreSession(server: server, enabled: remember) }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill").font(.system(size: 23)).foregroundStyle(.white)
                .frame(width: 46, height: 46).background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
            Text("Smartcenter").font(.system(size: 20, weight: .bold, design: .rounded))
        }
    }

    private func signIn() {
        guard !auth.busy, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else { return }
        focused = nil
        Task {
            await auth.login(server: server, username: username, password: password, remember: remember)
            password = ""
            showPassword = false
        }
    }
}
