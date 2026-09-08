//  AddStationView.swift — tune a station that is not ours. Paste the address of a Transmission.

import SwiftUI

struct AddStationView: View {
    @Environment(Stations.self) private var stations
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add a station").font(Face.display(.title, weight: .black)).foregroundStyle(Ink.ink)
                Text("Paste the address of a Transmission file or a network of them. The set will read the schedule and the clock, and from then on that station is on the dial like any other.")
                    .font(Face.body(.subheadline)).foregroundStyle(Ink.inkSoft)
                TextField("https://…/network.json", text: $address)
                    .font(Face.mono(.footnote))
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Ink.card, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Ink.lineStrong))
                    #if os(iOS)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    #endif
                if let error { Text(error).font(Face.body(.footnote)).foregroundStyle(Ink.signalDeep) }
                HStack {
                    Button("Cancel") { dismiss() }.buttonStyle(.plain).foregroundStyle(Ink.inkSoft)
                    Spacer()
                    Button {
                        Task { await add() }
                    } label: {
                        Stamp(busy ? "Tuning…" : "Tune it in", color: Ink.signalDeep, border: Ink.signalDeep, tilt: 0)
                    }
                    .buttonStyle(.plain)
                    .disabled(busy || URL(string: address.trimmingCharacters(in: .whitespaces)) == nil)
                }
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Ink.paper.ignoresSafeArea())
            .overlay(Grain())
        }
        .presentationDetents([.medium, .large])
    }

    private func add() async {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)) else { return }
        busy = true; error = nil
        do { try await stations.add(station: url); dismiss() } catch { self.error = error.localizedDescription }
        busy = false
    }
}
