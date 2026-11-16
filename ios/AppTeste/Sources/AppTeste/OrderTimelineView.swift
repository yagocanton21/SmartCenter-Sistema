import SwiftUI

struct TimelineEvent: Identifiable, Sendable {
    let id = UUID()
    let status: String
    let date: String
    let user: String
    let notes: String
}

struct OrderTimelineView: View {
    let history: [OrderJSON]

    private var events: [TimelineEvent] {
        history.compactMap { item -> TimelineEvent? in
            let obj = item.object
            let st = obj["status"]?.text ?? ""
            guard !st.isEmpty else { return nil }
            let dt = obj["data"]?.text ?? ""
            let u = obj["usuario"]?.text ?? "Sistema"
            let n = obj["obs"]?.text ?? ""
            return TimelineEvent(status: st, date: dt, user: u, notes: n)
        }.reversed() // Most recent first
    }

    private func formatDate(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = f.date(from: iso)
        if date == nil {
            let f2 = ISO8601DateFormatter()
            date = f2.date(from: iso)
        }
        guard let d = date else { return String(iso.prefix(16)).replacingOccurrences(of: "T", with: " ") }
        let out = DateFormatter()
        out.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return out.string(from: d)
    }

    var body: some View {
        Section("Linha do tempo / Histórico da OS") {
            if events.isEmpty {
                Text("Nenhuma alteração de status registrada no histórico.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(event.status == "Concluído" || event.status == "Entregue" ? Color.green : Color.blue)
                                .frame(width: 10, height: 10)
                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 14)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(event.status)
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Text(formatDate(event.date))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Por: " + event.user)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                if !event.notes.isEmpty {
                                    Text("· " + event.notes)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.bottom, index < events.count - 1 ? 12 : 2)
                    }
                }
            }
        }
    }
}

