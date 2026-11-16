import SwiftUI
import UIKit

struct PatternLockView: View {
    @Binding var sequence: String
    private let pointRadius: CGFloat = 20
    private let gridSize: CGFloat = 220

    @State private var dragCurrent: CGPoint? = nil

    private var selectedPoints: [Int] {
        sequence.split(separator: "-").compactMap { Int($0) }
    }

    private func pointCenter(for index: Int, in size: CGSize) -> CGPoint {
        let col = CGFloat((index - 1) % 3)
        let row = CGFloat((index - 1) / 3)
        let stepX = size.width / 2.0
        let stepY = size.height / 2.0
        return CGPoint(x: col * stepX, y: row * stepY)
    }

    private func findHit(point: CGPoint, in size: CGSize) -> Int? {
        for n in 1...9 {
            let center = pointCenter(for: n, in: size)
            let dx = point.x - center.x
            let dy = point.y - center.y
            if (dx * dx + dy * dy) <= (pointRadius * pointRadius * 2.2) {
                return n
            }
        }
        return nil
    }

    private func addPoint(_ n: Int) {
        var points = selectedPoints
        if !points.contains(n) {
            points.append(n)
            sequence = points.map(String.init).joined(separator: "-")
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let pad: CGFloat = 24
                let innerWidth = max(0, geo.size.width - pad * 2)
                let innerHeight = max(0, geo.size.height - pad * 2)
                let innerSize = CGSize(width: innerWidth, height: innerHeight)

                ZStack {
                    Path { path in
                        let points = selectedPoints
                        if !points.isEmpty {
                            let first = pointCenter(for: points[0], in: innerSize)
                            path.move(to: CGPoint(x: first.x + pad, y: first.y + pad))
                            for idx in points.dropFirst() {
                                let pt = pointCenter(for: idx, in: innerSize)
                                path.addLine(to: CGPoint(x: pt.x + pad, y: pt.y + pad))
                            }
                            if let drag = dragCurrent {
                                path.addLine(to: drag)
                            }
                        }
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                    ForEach(1...9, id: \.self) { n in
                        let center = pointCenter(for: n, in: innerSize)
                        let isSelected = selectedPoints.contains(n)
                        let order = (selectedPoints.firstIndex(of: n) ?? -1) + 1

                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.blue : Color(uiColor: .systemGray5))
                                .frame(width: pointRadius * 2, height: pointRadius * 2)
                                .overlay(
                                    Circle().stroke(isSelected ? Color.blue : Color.gray.opacity(0.4), lineWidth: 1.5)
                                )

                            if isSelected {
                                Text("\(order)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.6))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .position(x: center.x + pad, y: center.y + pad)
                        .onTapGesture {
                            addPoint(n)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let localPoint = CGPoint(x: value.location.x - pad, y: value.location.y - pad)
                            if let hit = findHit(point: localPoint, in: innerSize) {
                                addPoint(hit)
                            }
                            dragCurrent = value.location
                        }
                        .onEnded { _ in
                            dragCurrent = nil
                        }
                )
            }
            .frame(width: gridSize, height: gridSize)
            .padding(8)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            HStack {
                if !sequence.isEmpty {
                    Text("Sequência: " + selectedPoints.map(String.init).joined(separator: " → "))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text("Desenhe arrastando pelos pontos")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !sequence.isEmpty {
                    Button(role: .destructive) {
                        sequence = ""
                    } label: {
                        Text("Limpar").font(.system(size: 12, weight: .medium))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DeviceLockPickerView: View {
    @Binding var lockType: String
    @Binding var password: String
    @Binding var patternSequence: String

    var body: some View {
        Section("Acesso ao aparelho (senha)") {
            Picker("Tipo de senha", selection: $lockType) {
                Text("Sem senha").tag("nenhuma")
                Text("Padrão").tag("padrao")
                Text("PIN / Senha").tag("alfa")
            }
            .pickerStyle(.segmented)

            if lockType == "alfa" {
                TextField("PIN ou senha de desbloqueio", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else if lockType == "padrao" {
                PatternLockView(sequence: $patternSequence)
            }
        }
    }
}

struct ChecklistItem: Identifiable, Sendable {
    let id: String
    let label: String
}

let allChecklistItems: [ChecklistItem] = [
    .init(id: "liga", label: "Liga"),
    .init(id: "tela", label: "Tela / display"),
    .init(id: "touch", label: "Touch"),
    .init(id: "cam_t", label: "Câmera traseira"),
    .init(id: "cam_f", label: "Câmera frontal"),
    .init(id: "alto", label: "Alto-falante"),
    .init(id: "auric", label: "Áudio de chamada"),
    .init(id: "mic", label: "Microfone"),
    .init(id: "wifi", label: "Wi-Fi"),
    .init(id: "bt", label: "Bluetooth"),
    .init(id: "sinal", label: "Sinal / chip"),
    .init(id: "bio", label: "Biometria / Face ID"),
    .init(id: "botoes", label: "Botões"),
    .init(id: "carga", label: "Carregamento"),
    .init(id: "vibra", label: "Vibração"),
    .init(id: "sensor", label: "Sensores"),
    .init(id: "carcaca", label: "Carcaça / tampa"),
    .init(id: "fone", label: "Entrada de fone")
]

struct ChecklistSectionView: View {
    @Binding var checklist: [String: String]
    @Binding var observations: String

    var body: some View {
        Section {
            HStack {
                Button("Marcar todos OK") {
                    for item in allChecklistItems {
                        checklist[item.id] = "ok"
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption.bold())
                .foregroundStyle(.blue)

                Spacer()

                Button("Limpar (N/T)") {
                    for item in allChecklistItems {
                        checklist[item.id] = "nt"
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            ForEach(allChecklistItems) { item in
                let current = checklist[item.id] ?? "nt"
                HStack {
                    Text(item.label)
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { current },
                        set: { checklist[item.id] = $0 }
                    )) {
                        Text("OK").tag("ok")
                        Text("Def").tag("def")
                        Text("N/T").tag("nt")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 150)
                }
            }

            TextField("Observações do checklist", text: $observations, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(2...4)
        } header: {
            Text("Checklist de entrada")
        } footer: {
            Text("OK = funcionando · Def = com defeito · N/T = não testado")
        }
    }
}

