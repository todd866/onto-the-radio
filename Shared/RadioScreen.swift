import SwiftUI
import UniformTypeIdentifiers

enum RadioPane: String, CaseIterable, Identifiable {
    case stations = "Stations"
    case queue = "Queue"
    case trust = "Trust"

    var id: String { rawValue }
}

public struct RadioScreen: View {
    @Bindable var engine: RadioEngine
    @State private var pane: RadioPane = .stations
    @Environment(\.colorScheme) private var scheme

    public init(engine: RadioEngine) {
        self.engine = engine
    }

    private var surfaceBg: Color {
        scheme == .dark ? Color(white: 0.08) : Color(white: 0.96)
    }

    private var cardBg: Color {
        scheme == .dark ? Color(white: 0.12) : Color.white
    }

    private var accentRadio: Color {
        scheme == .dark ? Color(red: 0.31, green: 0.66, blue: 0.87) : Color(red: 0.09, green: 0.39, blue: 0.67)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            nowPlayingRow
            Divider()
            steeringRow
            Divider()
            paneSwitcher
            Divider()
            activeListPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(surfaceBg)
        .sheet(isPresented: $engine.showSettings, onDismiss: {
            engine.saveSettings()
            Task { await engine.syncFromManifold() }
        }) {
            RadioSettingsSheet(engine: engine)
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $engine.showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                engine.importLocalFiles(urls)
            }
        }
        #endif
        .task {
            await engine.syncFromManifold()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(accentRadio)
                .accessibilityHidden(true)
            Text("Onto the Radio")
                .font(.headline)
            Spacer(minLength: 0)
            #if !os(tvOS)
            Button {
                engine.showImporter = true
            } label: {
                Label("Add files", systemImage: "folder.badge.plus")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.bordered)
            #endif
            Button {
                engine.showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(cardBg)
    }

    private var nowPlayingRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .fill(accentRadio.opacity(0.18))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: engine.currentWork?.isPlayable == true ? "waveform" : "sparkles")
                        .font(.title3)
                        .foregroundStyle(accentRadio)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.currentWork?.title ?? "Select track")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(engine.currentWork?.creator ?? (engine.activeLens?.name ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(formatTime(engine.elapsedSec)) / \(formatTime(engine.durationSec))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Button {
                    engine.skipPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous")

                Button {
                    engine.togglePlay()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.isPlaying ? "Pause" : "Play")

                Button {
                    engine.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 70)
        .background(cardBg)
    }

    private var steeringRow: some View {
        VStack(spacing: 6) {
            #if os(tvOS)
            HStack(spacing: 18) {
                Text("Energy ≤ \(Int(engine.maxEnergy * 100))%")
                    .font(.caption.monospacedDigit())
                Text("Weight ≤ \(Int(engine.maxHeaviness * 100))%")
                    .font(.caption.monospacedDigit())
                Spacer()
            }
            #else
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(accentRadio)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text("Energy")
                    .font(.caption)
                    .frame(width: 50, alignment: .leading)
                Slider(value: $engine.maxEnergy, in: 0.15...1.0)
                    .tint(accentRadio)
                    .accessibilityLabel("Maximum energy")
                Text(String(format: "%.2f", engine.maxEnergy))
                    .font(.caption.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Image(systemName: "scalemass.fill")
                    .font(.caption)
                    .foregroundStyle(accentRadio)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text("Weight")
                    .font(.caption)
                    .frame(width: 50, alignment: .leading)
                Slider(value: $engine.maxHeaviness, in: 0.15...1.0)
                    .tint(accentRadio)
                    .accessibilityLabel("Maximum heaviness")
                Text(String(format: "%.2f", engine.maxHeaviness))
                    .font(.caption.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
            }
            #endif
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var paneSwitcher: some View {
        HStack(spacing: 8) {
            Picker("View", selection: $pane) {
                Text("Stations \(engine.lenses.count)").tag(RadioPane.stations)
                Text("Queue \(engine.rankedQueue.count)").tag(RadioPane.queue)
                Text("Trust \(engine.contributors.count)").tag(RadioPane.trust)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(cardBg)
    }

    @ViewBuilder
    private var activeListPane: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch pane {
                case .stations:
                    ForEach(engine.lenses) { lens in
                        stationInstrumentRow(lens)
                        Divider()
                    }
                case .queue:
                    ForEach(engine.rankedQueue) { item in
                        trackInstrumentRow(item)
                        Divider()
                    }
                case .trust:
                    ForEach(engine.contributors) { actor in
                        trustInstrumentRow(actor)
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func stationInstrumentRow(_ lens: RadioLens) -> some View {
        let active = engine.activeLens?.id == lens.id
        let comp = Int(((lens.completionRate ?? 0.90) * 100).rounded())
        return Button {
            engine.selectLens(lens)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(active ? accentRadio : .secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(lens.name)
                        .font(.subheadline.weight(active ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(lens.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                GaugeBar(fraction: Double(comp) / 100.0, tint: accentRadio)
                    .frame(width: 48, height: 6)
                Text("\(comp)%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, alignment: .trailing)
                Text("\(lens.subscribers ?? 0) sub")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func trackInstrumentRow(_ entry: RankedRadioTrack) -> some View {
        let isCurrent = engine.currentWork?.workId == entry.work.workId
        return Button {
            engine.play(entry.work, autoStart: true)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: entry.work.isPlayable ? (isCurrent ? "speaker.wave.2.fill" : "play.circle") : "waveform.path")
                    .font(.caption)
                    .foregroundStyle(entry.work.isPlayable ? accentRadio : .secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.work.title)
                        .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(entry.work.creator)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                GaugeBar(fraction: entry.score, tint: accentRadio)
                    .frame(width: 48, height: 6)
                Text(String(format: "%.2f", entry.score))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, alignment: .trailing)
                Text(String(entry.work.year))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func trustInstrumentRow(_ actor: ContributorReputation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(actor.handle)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(actor.tier)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            GaugeBar(fraction: actor.trust, tint: .green)
                .frame(width: 48, height: 6)
            Text(String(format: "%.3f", actor.meanCanaryCosine))
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(width: 44, alignment: .trailing)
            Text("\(actor.credits) cr")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(minHeight: 40)
    }

    private func formatTime(_ sec: Double) -> String {
        let total = max(0, Int(sec.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct GaugeBar: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.22))
                Capsule()
                    .fill(tint)
                    .frame(width: max(3, geo.size.width * min(1, max(0, fraction))))
            }
        }
    }
}

struct RadioSettingsSheet: View {
    @Bindable var engine: RadioEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Home server") {
                    TextField("https://your-mac.example.ts.net:8443", text: $engine.homeServerURL)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }

                Section("Manifold pool") {
                    TextField("https://manifold-chi.vercel.app", text: $engine.hubURL)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    TextField("ed25519 contributor key (optional)", text: $engine.contributorIssuer)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(width: 440, height: 300)
        #endif
    }
}
