import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthStore()
    @AppStorage("smartcenter.server") private var server = "http://163.176.205.54:8093"
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focused: Field?
    private enum Field { case username, password }

    var body: some View {
        NavigationStack {
            if let user = auth.user {
                AppShell(auth: auth, user: user)
            } else {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("SC").font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white).frame(width: 76, height: 76)
                            .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 22))
                        Text("Smartcenter").font(.largeTitle.bold())
                        Text("Gestão de assistência técnica").foregroundStyle(.secondary)
                    }.padding(.top, 36)

                    Group {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Entre na sua conta").font(.title2.bold())
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Usuário").font(.subheadline.weight(.medium))
                                TextField("Seu usuário", text: $username)
                                    .textContentType(.username).textInputAutocapitalization(.never)
                                    .autocorrectionDisabled().focused($focused, equals: .username)
                                    .submitLabel(.next).onSubmit { focused = .password }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Senha").font(.subheadline.weight(.medium))
                                SecureField("Sua senha", text: $password)
                                    .textContentType(.password).focused($focused, equals: .password)
                                    .submitLabel(.go).onSubmit { signIn() }
                            }
                            Button(action: signIn) {
                                HStack {
                                    if auth.busy { ProgressView().tint(.white) }
                                    Text(auth.busy ? "Entrando…" : "Entrar").fontWeight(.semibold)
                                }.frame(maxWidth: .infinity).padding(.vertical, 8)
                            }.buttonStyle(.borderedProminent)
                                .disabled(auth.busy || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                            DisclosureGroup("Servidor") {
                                TextField("https://seu-servidor", text: $server)
                                    .keyboardType(.URL).textInputAutocapitalization(.never)
                                    .autocorrectionDisabled().padding(.top, 10)
                            }.font(.subheadline)
                            if server.lowercased().hasPrefix("http://") {
                                Label("Conexão HTTP de teste, sem criptografia.", systemImage: "lock.open")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.textFieldStyle(.roundedBorder).padding(24)
                            .background(.background, in: RoundedRectangle(cornerRadius: 20))
                            .disabled(auth.busy)
                    }
                    if let error = auth.error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red).font(.subheadline)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }.padding(24).frame(maxWidth: 500).frame(maxWidth: .infinity)
            }.background(Color(uiColor: .systemGroupedBackground))
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private func signIn() {
        guard !auth.busy, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else { return }
        focused = nil
        Task {
            await auth.login(server: server, username: username, password: password)
            password = ""
        }
    }
}
