import SwiftUI

// MARK: - Store Config View
struct StoreConfigView: View {
    @ObservedObject var auth: AuthStore
    @State private var loading = false
    @State private var saving = false
    @State private var error: String?
    @State private var showSuccessBanner = false
    @State private var selectedTab = 0 // 0 = Loja, 1 = Termos

    // Dados da Loja
    @State private var nomeFantasia = ""
    @State private var razaoSocial = ""
    @State private var cnpj = ""
    @State private var telefone = ""
    @State private var whatsapp = ""
    @State private var email = ""
    @State private var cep = ""
    @State private var cidade = ""
    @State private var endereco = ""
    @State private var responsavel = ""
    @State private var garantiaPadraoDias = 90
    @State private var condicoesPagamento = ""
    @State private var termoGarantia = ""
    @State private var confirmResetTerm = false
    @State private var copiedVariable: String?
    @State private var originalConfig: [String: OrderJSON] = [:]

    private let availableVariables = [
        "{{loja}}", "{{garantia}}", "{{os}}", "{{cliente}}",
        "{{aparelho}}", "{{data}}", "{{telefone}}", "{{endereco}}", "{{cnpj}}"
    ]

    private let defaultTerm = """
# TERMO DE GARANTIA

A {{loja}} garante, pelo prazo de {{garantia}}, contado a partir da data de entrega do aparelho ao cliente, os serviços executados e as peças substituídas na Ordem de Serviço nº {{os}}, nos termos abaixo.

## 1. PRAZO DE GARANTIA
- A garantia é de {{garantia}}, contada da data de entrega do aparelho, e cobre exclusivamente o serviço executado e as peças substituídas descritos na Ordem de Serviço.
- A garantia contratual é complementar à garantia legal prevista no Código de Defesa do Consumidor (Lei nº 8.078/1990).
- Peças e serviços não descritos na Ordem de Serviço não estão cobertos por este termo.

## 2. CONDIÇÕES DE COBERTURA
- Defeito de funcionamento diretamente relacionado ao serviço executado ou à peça substituída.
- Para acionar a garantia, o cliente deve apresentar este termo, a Ordem de Serviço e documento de identificação.
- Constatado o defeito coberto, a peça será reparada ou substituída por outra equivalente, sem custo ao cliente, no prazo legal.
- A peça substituída em garantia passa a ter, como prazo, o restante da garantia original.

## 3. EXCLUSÕES DE GARANTIA
- Danos causados por queda, impacto, pressão, trincas ou tela quebrada após a entrega do aparelho.
- Contato com líquidos, umidade, oxidação ou corrosão.
- Mau uso, uso de carregadores e acessórios fora de especificação, oscilações ou sobrecarga de energia.
- Problemas de software: vírus, atualizações, aplicativos, senhas, bloqueios de conta e desbloqueios.
- Defeitos diferentes do reparo executado ou que não constavam no defeito relatado na Ordem de Serviço.
- Desgaste natural de peças, como baterias, botões, alto-falantes e conectores.
- Perda de dados e arquivos. O cliente deve manter cópia de segurança (backup) antes de entregar o aparelho.

## 4. SITUAÇÕES DE CANCELAMENTO DA GARANTIA
- Rompimento, violação ou remoção dos lacres e etiquetas de garantia.
- Abertura, reparo ou manipulação do aparelho por terceiros não autorizados.
- Danos físicos, marcas de impacto ou contato com líquidos após a entrega.
- Instalação de sistemas ou programas não oficiais (root, jailbreak e similares).
- Não apresentação da Ordem de Serviço e deste termo, ou documentos com rasuras.

## 5. ORIENTAÇÕES AO CONSUMIDOR
- Confira o funcionamento do aparelho no ato da retirada. Reclamações posteriores sobre acessórios ou condições não registrados na Ordem de Serviço não serão aceitas.
- O aparelho deve ser retirado em até 90 dias após o aviso de conclusão. Após esse prazo, poderá ser cobrada taxa de armazenamento e aplicadas as medidas previstas em lei.
- A retirada do aparelho exige a apresentação da Ordem de Serviço e de documento com foto.
- Faça backup dos seus dados com frequência.
- Para acionar a garantia ou tirar dúvidas, procure a {{loja}}: {{telefone}} – {{endereco}}.

Declaro ter lido e concordado com todas as condições deste Termo de Garantia.
"""

    var body: some View {
        VStack(spacing: 0) {
            // Seletor de Abas
            Picker("", selection: $selectedTab) {
                Label("Dados da loja", systemImage: "storefront.fill").tag(0)
                Label("Termo de garantia", systemImage: "checkmark.seal.fill").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGroupedBackground))

            // Banner de Sucesso Flutuante
            if showSuccessBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Configurações salvas com sucesso!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if loading && originalConfig.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Carregando configurações…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                if selectedTab == 0 {
                    storeTabContent
                } else {
                    termsTabContent
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Configurações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await saveConfig() }
                } label: {
                    if saving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Salvar")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                .disabled(loading || saving)
            }
        }
        .confirmationDialog("Restaurar termo padrão?", isPresented: $confirmResetTerm, titleVisibility: .visible) {
            Button("Substituir pelo termo padrão", role: .destructive) {
                termoGarantia = defaultTerm
            }
        } message: {
            Text("O texto atual será substituído pelo modelo oficial padrão do SmartCenter.")
        }
        .refreshable { await loadConfig() }
        .task { await loadConfig() }
    }

    // MARK: - Tab 1: Dados da Loja
    private var storeTabContent: some View {
        List {
            // Hero Card da Empresa
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.1, green: 0.35, blue: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)

                    VStack(spacing: 3) {
                        Text(nomeFantasia.isEmpty ? "SmartCenter" : nomeFantasia)
                            .font(.system(size: 19, weight: .bold))
                            .multilineTextAlignment(.center)

                        if !razaoSocial.isEmpty {
                            Text(razaoSocial)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Text("Os dados abaixo aparecem nos cabeçalhos, termos e notas de serviço impressas.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .padding(.horizontal, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            // Identificação
            Section("Identificação da Loja") {
                configFieldRow(icon: "tag.fill", title: "Nome Fantasia", color: .blue) {
                    TextField("Ex: SmartCenter Assistência", text: $nomeFantasia)
                }

                configFieldRow(icon: "building.2.fill", title: "Razão Social", color: .indigo) {
                    TextField("Razão social da empresa", text: $razaoSocial)
                }

                configFieldRow(icon: "doc.text.fill", title: "CNPJ", color: .purple) {
                    TextField("00.000.000/0000-00", text: $cnpj)
                        .keyboardType(.numberPad)
                }

                configFieldRow(icon: "person.badge.shield.checkmark.fill", title: "Responsável Técnico", color: .teal) {
                    TextField("Nome do responsável", text: $responsavel)
                }
            }

            // Contato
            Section("Canais de Atendimento") {
                configFieldRow(icon: "message.fill", title: "WhatsApp da Loja", color: .green) {
                    TextField("(11) 99999-9999", text: $whatsapp)
                        .keyboardType(.phonePad)
                }

                configFieldRow(icon: "phone.fill", title: "Telefone Fixo", color: .blue) {
                    TextField("(11) 3333-3333", text: $telefone)
                        .keyboardType(.phonePad)
                }

                configFieldRow(icon: "envelope.fill", title: "E-mail Comercial", color: .orange) {
                    TextField("contato@loja.com.br", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }

            // Endereço
            Section("Endereço e Localização") {
                configFieldRow(icon: "number", title: "CEP", color: .gray) {
                    TextField("00000-000", text: $cep)
                        .keyboardType(.numberPad)
                }

                configFieldRow(icon: "mappin.and.ellipse", title: "Endereço Completo", color: .red) {
                    TextField("Rua, número, complemento e bairro", text: $endereco, axis: .vertical)
                        .lineLimit(1...3)
                }

                configFieldRow(icon: "map.fill", title: "Cidade / UF", color: .cyan) {
                    TextField("Cidade - UF", text: $cidade)
                }
            }

            // Operacional
            Section("Regras Operacionais") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                            .frame(width: 20)
                        Text("Garantia Padrão das OS")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(garantiaPadraoDias) dias")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.blue)
                    }

                    Stepper("Garantia padrão", value: $garantiaPadraoDias, in: 0...365, step: 15)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.purple)
                            .frame(width: 20)
                        Text("Condições de Pagamento")
                            .font(.system(size: 13, weight: .medium))
                    }

                    TextField("Ex: Pix à vista com 5% de desconto, Cartão em até 12x", text: $condicoesPagamento, axis: .vertical)
                        .font(.system(size: 13))
                        .lineLimit(2...4)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Tab 2: Termo de Garantia
    private var termsTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Banner Informativo
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Texto do Termo de Garantia")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text("Este texto é impresso automaticamente nas Notas de Serviço entregues ao cliente. Toque em qualquer tag abaixo para copiá-la:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                // Tags / Variáveis Disponíveis
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags dinâmicas disponíveis:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(availableVariables, id: \.self) { variable in
                                Button {
                                    UIPasteboard.general.string = variable
                                    copiedVariable = variable
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        if copiedVariable == variable { copiedVariable = nil }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(variable)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        if copiedVariable == variable {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(
                                        copiedVariable == variable ? Color.green.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(copiedVariable == variable ? Color.green : Color.primary)
                                    .overlay(
                                        Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Editor do Termo
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Editor de Texto")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restaurar padrão") {
                            confirmResetTerm = true
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                    }

                    TextEditor(text: $termoGarantia)
                        .frame(minHeight: 380)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(10)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }

                // Botão de Salvar no Rodapé
                Button {
                    Task { await saveConfig() }
                } label: {
                    HStack {
                        Spacer()
                        if saving {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Salvar Termo de Garantia", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(saving)
                .padding(.top, 4)
            }
            .padding(16)
        }
    }

    // MARK: - Row Helper
    private func configFieldRow<Content: View>(
        icon: String,
        title: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            content()
                .font(.system(size: 14))
        }
        .padding(.vertical, 2)
    }

    // MARK: - API Calls
    private func loadConfig() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let data = try await auth.orderRequest("api/db", permission: "config")
            let envelope = try JSONDecoder().decode(OrderJSON.self, from: data).object
            if let db = envelope["db"]?.object, let cfg = db["config"]?.object {
                originalConfig = cfg
                nomeFantasia = cfg["nomeFantasia"]?.text ?? ""
                razaoSocial = cfg["razaoSocial"]?.text ?? ""
                cnpj = cfg["cnpj"]?.text ?? ""
                telefone = cfg["telefone"]?.text ?? ""
                whatsapp = cfg["whatsapp"]?.text ?? ""
                email = cfg["email"]?.text ?? ""
                cep = cfg["cep"]?.text ?? ""
                cidade = cfg["cidade"]?.text ?? ""
                endereco = cfg["endereco"]?.text ?? ""
                responsavel = cfg["responsavel"]?.text ?? ""
                garantiaPadraoDias = Int(cfg["garantiaPadraoDias"]?.number ?? 90)
                condicoesPagamento = cfg["condicoesPagamento"]?.text ?? ""
                termoGarantia = cfg["termoGarantia"]?.text ?? (cfg["termosGarantia"]?.text ?? defaultTerm)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveConfig() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            var updated = originalConfig
            updated["nomeFantasia"] = .string(nomeFantasia.trimmingCharacters(in: .whitespaces))
            updated["razaoSocial"] = .string(razaoSocial.trimmingCharacters(in: .whitespaces))
            updated["cnpj"] = .string(cnpj.trimmingCharacters(in: .whitespaces))
            updated["telefone"] = .string(telefone.trimmingCharacters(in: .whitespaces))
            updated["whatsapp"] = .string(whatsapp.trimmingCharacters(in: .whitespaces))
            updated["email"] = .string(email.trimmingCharacters(in: .whitespaces))
            updated["cep"] = .string(cep.trimmingCharacters(in: .whitespaces))
            updated["cidade"] = .string(cidade.trimmingCharacters(in: .whitespaces))
            updated["endereco"] = .string(endereco.trimmingCharacters(in: .whitespaces))
            updated["responsavel"] = .string(responsavel.trimmingCharacters(in: .whitespaces))
            updated["garantiaPadraoDias"] = .number(Double(garantiaPadraoDias))
            updated["condicoesPagamento"] = .string(condicoesPagamento.trimmingCharacters(in: .whitespaces))
            let cleanTerm = termoGarantia.trimmingCharacters(in: .whitespacesAndNewlines)
            updated["termoGarantia"] = .string(cleanTerm.isEmpty ? defaultTerm : cleanTerm)
            updated["termosGarantia"] = .string(cleanTerm.isEmpty ? defaultTerm : cleanTerm)

            let change: OrderJSON = .object([
                "entity": .string("config"),
                "id": .string("config"),
                "before": .object(originalConfig),
                "after": .object(updated)
            ])
            let payload = try JSONEncoder().encode(OrderJSON.object(["changes": .array([change])]))
            _ = try await auth.orderRequest("api/changes", body: payload, idempotencyKey: UUID().uuidString, permission: "config")
            originalConfig = updated

            withAnimation {
                showSuccessBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    showSuccessBanner = false
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

