import SwiftUI
import UniformTypeIdentifiers

public struct RadioScreen: View {
    @Bindable var engine: RadioEngine
    @Environment(\.colorScheme) private var scheme

    public init(engine: RadioEngine) {
        self.engine = engine
    }

    private var pal: RadioPalette {
        RadioPalette.forScheme(scheme)
    }

    public var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 680
            let sleeveSize: CGFloat = isCompact ? 124 : 148
            let stationSize: CGFloat = isCompact ? 116 : 148
            let mapHeight: CGFloat = isCompact ? 104 : 168

            ZStack(alignment: .bottom) {
                pal.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Rectangle().fill(pal.line).frame(height: 0.5)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: isCompact ? 12 : 18) {
                            moodStrip

                            if !engine.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                searchResultsSection(isCompact: isCompact)
                            } else {
                                quickPicksSection(tileSize: sleeveSize, isCompact: isCompact)
                                signedLensesSection(tileSize: stationSize, isCompact: isCompact)
                                mapPreviewSection(mapHeight: mapHeight, isCompact: isCompact)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 82)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                VStack(spacing: 6) {
                    if let notice = engine.playbackNotice {
                        Text(notice)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(pal.bg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(pal.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.horizontal, 14)
                    }
                    miniPlayerBar
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .tint(pal.signal)
        }
        .sheet(isPresented: $engine.showSettings, onDismiss: {
            engine.saveSettings()
            Task { await engine.syncFromManifold() }
        }) {
            RadioSettingsSheet(engine: engine)
        }
        #if os(macOS)
        .sheet(isPresented: $engine.showNowPlaying) {
            NowPlayingView(engine: engine)
                .frame(minWidth: 780, minHeight: 540)
        }
        #else
        .fullScreenCover(isPresented: $engine.showNowPlaying) {
            NowPlayingView(engine: engine)
        }
        #endif
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

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                engine.searchQuery = ""
                engine.clearMapTarget()
            } label: {
                HStack(spacing: 0) {
                    Text("Onto")
                        .foregroundStyle(pal.ink)
                    Text("Radio")
                        .foregroundStyle(pal.signal)
                }
                .font(.system(size: 21, weight: .black, design: .serif))
                .italic()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Onto Radio Home")

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(pal.ink3)
                    .accessibilityHidden(true)
                TextField("Search", text: $engine.searchQuery)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(pal.ink)
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                if !engine.searchQuery.isEmpty {
                    Button {
                        engine.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(pal.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(pal.panel, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75)
            }

            #if !os(tvOS)
            Button {
                engine.showImporter = true
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(pal.ink)
                    .frame(width: 34, height: 34)
                    .background(pal.panel, in: Circle())
                    .overlay { Circle().strokeBorder(pal.line, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add local audio files")
            #endif

            Button {
                engine.showSettings = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(pal.ink)
                        .frame(width: 34, height: 34)
                        .background(pal.panel, in: Circle())
                        .overlay { Circle().strokeBorder(pal.line, lineWidth: 0.75) }
                    if engine.homeServerConnected {
                        Circle()
                            .fill(pal.good)
                            .frame(width: 8, height: 8)
                            .offset(x: 1, y: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    private var moodStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RadioMoodPreset.allCases) { preset in
                    let active = engine.moodPreset == preset
                    Button {
                        engine.selectMood(preset)
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 12.5, weight: active ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(active ? pal.bg : pal.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                active ? pal.ink : pal.panel,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(active ? pal.ink : pal.line, lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func quickPicksSection(tileSize: CGFloat, isCompact: Bool) -> some View {
        let items = engine.playableQueue
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Quick picks")
                    .font(.system(size: isCompact ? 19 : 21, weight: .bold, design: .serif))
                    .foregroundStyle(pal.ink)
                Spacer(minLength: 0)
                Text("\(items.count) playable")
                    .font(.system(size: 11, design: .monospaced).monospacedDigit())
                    .foregroundStyle(pal.ink3)
            }
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { entry in
                        trackTile(entry.work, size: tileSize)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private func trackTile(_ work: RadioWork, size: CGFloat) -> some View {
        let isCurrent = engine.currentWork?.workId == work.workId
        return Button {
            engine.play(work, autoStart: true)
            engine.showNowPlaying = true
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                RadioSleeve(
                    title: work.title,
                    subtitle: work.year > 0 ? "\(work.year)" : work.kind,
                    seed: work.workId,
                    colorOverride: work.colorHex,
                    artURL: work.artUrl.flatMap(URL.init(string:)),
                    size: size,
                    badge: work.originBadge,
                    isActive: isCurrent
                )
                Text(work.title)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? pal.signal : pal.ink)
                    .lineLimit(2)
                    .frame(width: size, alignment: .leading)
                Text(shortCreatorName(work.creator))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(pal.ink3)
                    .lineLimit(1)
                    .frame(width: size, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        #if !os(tvOS)
        .contextMenu {
            Button("Play now", systemImage: "play.fill") {
                engine.play(work, autoStart: true)
            }
            Button("Play next", systemImage: "text.insert") {
                engine.queueNext(work)
            }
            Button(
                engine.likedIDs.contains(work.workId) ? "Unlike" : "Like",
                systemImage: engine.likedIDs.contains(work.workId) ? "hand.thumbsup.fill" : "hand.thumbsup"
            ) {
                engine.toggleLike(work)
            }
            Button("Less like this", systemImage: "hand.thumbsdown") {
                engine.dislikeAndSkip(work)
            }
        }
        #endif
    }

    private func signedLensesSection(tileSize: CGFloat, isCompact: Bool) -> some View {
        let stations = engine.allLenses
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Signed lenses")
                    .font(.system(size: isCompact ? 19 : 21, weight: .bold, design: .serif))
                    .foregroundStyle(pal.ink)
                Spacer(minLength: 0)
                Label("Ed25519", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(pal.good)
            }
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(stations) { lens in
                        let active = engine.activeLens?.id == lens.id
                        let rate = Int(((lens.completionRate ?? 0.90) * 100).rounded())
                        let subs = lens.subscribers ?? 0
                        Button {
                            engine.selectLens(lens)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                RadioSleeve(
                                    title: lens.name,
                                    subtitle: "@\(lens.issuerHandle)",
                                    seed: lens.id,
                                    colorOverride: lens.colorHex,
                                    artURL: lens.artUrl.flatMap(URL.init(string:)),
                                    size: tileSize,
                                    badge: "\(rate)%",
                                    isActive: active
                                )
                                Text(lens.name)
                                    .font(.system(size: 13, weight: active ? .semibold : .medium))
                                    .foregroundStyle(active ? pal.signal : pal.ink)
                                    .lineLimit(1)
                                    .frame(width: tileSize, alignment: .leading)
                                Text("\(rate)% fit · \(subs) sub")
                                    .font(.system(size: 11, design: .monospaced).monospacedDigit())
                                    .foregroundStyle(pal.ink3)
                                    .lineLimit(1)
                                    .frame(width: tileSize, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private func mapPreviewSection(mapHeight: CGFloat, isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("On the map")
                    .font(.system(size: isCompact ? 19 : 21, weight: .bold, design: .serif))
                    .foregroundStyle(pal.ink)
                Spacer(minLength: 0)
                Button("Open map") {
                    engine.nowPlayingTab = .map
                    engine.showNowPlaying = true
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(pal.signal)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)

            VStack(spacing: 0) {
                LatentMapCanvas(
                    works: engine.allWorks,
                    currentWork: engine.currentWork,
                    trail: Array(engine.playableQueue.prefix(6).map(\.work)),
                    activeLens: engine.activeLens,
                    mapTarget: engine.mapTarget
                ) { x, y in
                    engine.tuneToMap(x: x, y: y)
                }
                .frame(height: mapHeight)

                Rectangle().fill(pal.line).frame(height: 0.5)

                HStack(spacing: 8) {
                    Circle()
                        .fill(pal.signal)
                        .frame(width: 7, height: 7)
                    if let label = engine.mapTargetLabel {
                        Text("Tuned: \(label)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(pal.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Button("Reset") {
                            engine.clearMapTarget()
                        }
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(pal.signal)
                        .buttonStyle(.plain)
                    } else if let cur = engine.currentWork {
                        Text("\(engine.allWorks.count) coordinates · \(cur.title)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(pal.ink2)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("Tap to steer")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(pal.ink3)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(pal.panel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(pal.line, lineWidth: 0.75)
            }
            .padding(.horizontal, 14)
        }
    }

    private func searchResultsSection(isCompact: Bool) -> some View {
        let playable = engine.filteredPlayable
        let discovery = engine.filteredDiscovery
        let cols = [GridItem(.adaptive(minimum: isCompact ? 150 : 168), spacing: 12, alignment: .top)]

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Playable matches")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(pal.ink)
                Spacer(minLength: 0)
                Text("\(playable.count)")
                    .font(.system(size: 12, design: .monospaced).monospacedDigit())
                    .foregroundStyle(pal.ink3)
            }
            .padding(.horizontal, 14)

            if playable.isEmpty {
                Text("No matching playable files. Add audio files or connect your home server.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(pal.ink2)
                    .padding(.horizontal, 14)
            } else {
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(playable) { entry in
                        trackTile(entry.work, size: isCompact ? 156 : 168)
                    }
                }
                .padding(.horizontal, 14)
            }

            if !discovery.isEmpty {
                HStack {
                    Text("Manifold reference pool")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(pal.ink2)
                    Spacer(minLength: 0)
                    Text("\(discovery.count)")
                        .font(.system(size: 12, design: .monospaced).monospacedDigit())
                        .foregroundStyle(pal.ink3)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)

                VStack(spacing: 0) {
                    ForEach(discovery.prefix(12)) { entry in
                        discoveryRow(entry)
                        Rectangle().fill(pal.line).frame(height: 0.5)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private func discoveryRow(_ entry: RankedRadioTrack) -> some View {
        HStack(spacing: 10) {
            RadioSleeve(
                title: entry.work.title,
                subtitle: String(entry.work.year),
                seed: entry.work.workId,
                size: 40,
                compact: true
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.work.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(pal.ink)
                    .lineLimit(1)
                Text("\(entry.work.creator) · \(entry.work.year)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(pal.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(String(format: "%.2f", entry.score))
                .font(.system(size: 11.5, design: .monospaced).monospacedDigit())
                .foregroundStyle(pal.ink2)
        }
        .padding(.vertical, 7)
    }

    private var miniPlayerBar: some View {
        let cur = engine.currentWork
        let progress = engine.durationSec > 0 ? min(1, max(0, engine.elapsedSec / engine.durationSec)) : 0
        return ZStack(alignment: .bottomLeading) {
            HStack(spacing: 10) {
                Button {
                    engine.showNowPlaying = true
                } label: {
                    HStack(spacing: 10) {
                        RadioSleeve(
                            title: cur?.title ?? "Onto",
                            subtitle: cur?.creator ?? "",
                            seed: cur?.workId ?? "idle",
                            colorOverride: cur?.colorHex,
                            artURL: cur?.artUrl.flatMap(URL.init(string:)),
                            size: 44,
                            compact: true
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cur?.title ?? "Select track")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(pal.ink)
                                .lineLimit(1)
                            Text("\(shortCreatorName(cur?.creator ?? "")) · \(engine.activeLens?.name ?? "")")
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(pal.ink2)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open now playing")

                Button {
                    engine.togglePlay()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(pal.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.isPlaying ? "Pause" : "Play")

                Button {
                    engine.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(pal.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next track")
            }
            .padding(.horizontal, 8)
            .frame(height: 60)

            GeometryReader { geo in
                Rectangle()
                    .fill(pal.signal)
                    .frame(width: geo.size.width * progress, height: 2.5)
            }
            .frame(height: 2.5)
            .allowsHitTesting(false)
        }
        .background(pal.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(pal.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.45 : 0.14), radius: 12, y: 4)
    }
}

private func shortCreatorName(_ raw: String) -> String {
    let head = raw.split(separator: "·", maxSplits: 1).first.map(String.init) ?? raw
    return head.trimmingCharacters(in: .whitespacesAndNewlines)
}

public struct NowPlayingView: View {
    @Bindable var engine: RadioEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    public init(engine: RadioEngine) {
        self.engine = engine
    }

    private var pal: RadioPalette {
        RadioPalette.forScheme(scheme)
    }

    private var cur: RadioWork? {
        engine.currentWork ?? engine.playableQueue.first?.work
    }

    private var canvasBg: Color {
        let rgb = RadioSwatches.sleeveRGB(for: cur?.workId ?? "idle", colorOverride: cur?.colorHex)
        return pal.tintedCanvas(rgb: rgb, scheme: scheme)
    }

    public var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width >= 720
            ZStack {
                canvasBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar

                    if isWide {
                        HStack(alignment: .top, spacing: 24) {
                            playerColumnWide
                                .frame(width: 296)
                            detailPanel(cornerAll: true)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                    } else {
                        VStack(spacing: 10) {
                            playerClusterCompact
                                .padding(.horizontal, 16)
                            detailPanel(cornerAll: false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .tint(pal.signal)
    }

    private var headerBar: some View {
        HStack {
            Button {
                engine.showNowPlaying = false
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close now playing")

            Spacer(minLength: 0)

            Text(engine.activeLens?.name ?? "Now playing")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(pal.ink2)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                engine.showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(pal.ink)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
    }

    private var playerClusterCompact: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                RadioSleeve(
                    title: cur?.title ?? "Onto the Radio",
                    subtitle: cur?.year ?? 0 > 0 ? "\(cur?.year ?? 0)" : (cur?.kind ?? ""),
                    seed: cur?.workId ?? "idle",
                    colorOverride: cur?.colorHex,
                    artURL: cur?.artUrl.flatMap(URL.init(string:)),
                    size: 112,
                    badge: cur?.originBadge
                )

                VStack(alignment: .leading, spacing: 4) {
                    RecoverableTitle(
                        text: cur?.title ?? "Select track",
                        font: .system(size: 18, weight: .bold, design: .serif),
                        color: pal.ink,
                        lineLimit: 2
                    )
                    Text(cur?.creator ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(pal.ink2)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if let src = cur?.originBadge {
                            factPill(src)
                        }
                        if let year = cur?.year, year > 0 {
                            factPill(String(year))
                        }
                        if let score = currentScore {
                            factPill("\(Int((score * 100).rounded()))%")
                        }
                    }
                    .padding(.top, 2)
                }
            }

            scrubberView
            transportCluster
        }
    }

    private var playerColumnWide: some View {
        VStack(alignment: .leading, spacing: 14) {
            RadioSleeve(
                title: cur?.title ?? "Onto the Radio",
                subtitle: cur?.year ?? 0 > 0 ? "\(cur?.year ?? 0)" : (cur?.kind ?? ""),
                seed: cur?.workId ?? "idle",
                colorOverride: cur?.colorHex,
                artURL: cur?.artUrl.flatMap(URL.init(string:)),
                size: 272,
                badge: cur?.originBadge
            )

            VStack(alignment: .leading, spacing: 4) {
                RecoverableTitle(
                    text: cur?.title ?? "Select track",
                    font: .system(size: 22, weight: .bold, design: .serif),
                    color: pal.ink,
                    lineLimit: 2
                )
                Text(cur?.creator ?? "")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(pal.ink2)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let src = cur?.originBadge {
                        factPill(src)
                    }
                    if let year = cur?.year, year > 0 {
                        factPill(String(year))
                    }
                    if let score = currentScore {
                        factPill("\(Int((score * 100).rounded()))%")
                    }
                }
                .padding(.top, 4)
            }

            scrubberView
            transportCluster
            Spacer(minLength: 0)
        }
    }

    private func factPill(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(pal.ink2)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(pal.panel, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(pal.line, lineWidth: 0.6)
            }
    }

    private var scrubberView: some View {
        let dur = max(1, engine.durationSec)
        let frac = min(1, max(0, engine.elapsedSec / dur))
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(pal.line)
                        .frame(height: 3.5)
                    Capsule()
                        .fill(pal.ink)
                        .frame(width: max(3, geo.size.width * frac), height: 3.5)
                    Circle()
                        .fill(pal.ink)
                        .frame(width: 11, height: 11)
                        .offset(x: max(0, min(geo.size.width - 11, geo.size.width * frac - 5.5)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                #if !os(tvOS)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let ratio = min(1, max(0, val.location.x / max(1, geo.size.width)))
                            engine.seek(to: ratio * dur)
                        }
                )
                #endif
            }
            .frame(height: 22)

            HStack {
                Text(formatTime(engine.elapsedSec))
                Spacer()
                Text(formatTime(engine.durationSec))
            }
            .font(.system(size: 11, design: .monospaced).monospacedDigit())
            .foregroundStyle(pal.ink2)
        }
    }

    private var transportCluster: some View {
        let isLiked = cur.map { engine.likedIDs.contains($0.workId) } ?? false
        let isDisliked = cur.map { engine.dislikedIDs.contains($0.workId) } ?? false

        return HStack {
            Button {
                if let cur { engine.dislikeAndSkip(cur) }
            } label: {
                Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 17))
                    .foregroundStyle(isDisliked ? pal.bad : pal.ink2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dislike and skip")

            Spacer()

            Button {
                engine.skipPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(pal.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous track")

            Spacer()

            Button {
                engine.togglePlay()
            } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(pal.bg)
                    .frame(width: 56, height: 56)
                    .background(pal.ink, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.isPlaying ? "Pause" : "Play")

            Spacer()

            Button {
                engine.skipNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(pal.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next track")

            Spacer()

            Button {
                if let cur { engine.toggleLike(cur) }
            } label: {
                Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 17))
                    .foregroundStyle(isLiked ? pal.signal : pal.ink2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLiked ? "Unlike" : "Like")
        }
    }

    private func detailPanel(cornerAll: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                ForEach(NowPlayingTab.allCases) { tab in
                    let active = engine.nowPlayingTab == tab
                    Button {
                        engine.nowPlayingTab = tab
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 12.5, weight: active ? .semibold : .regular, design: .monospaced))
                                .foregroundStyle(active ? pal.ink : pal.ink3)
                            Rectangle()
                                .fill(active ? pal.ink : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Rectangle().fill(pal.line).frame(height: 0.75)

            Group {
                switch engine.nowPlayingTab {
                case .why:
                    whyThisView
                case .upNext:
                    upNextView
                case .map:
                    mapTabView
                case .trust:
                    trustTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(pal.panel)
        .clipShape(
            cornerAll
                ? AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                : AnyShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
        )
        .overlay {
            if cornerAll {
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(pal.line, lineWidth: 0.75)
            }
        }
    }

    private var whyThisView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let cur {
                    VStack(spacing: 7) {
                        factRow("Lens", value: engine.activeLens?.name ?? "None")
                        factRow("Axis", value: cur.kind)
                        factRow(
                            "Energy / Wt",
                            value: String(
                                format: "%.2f / %.2f",
                                cur.energy ?? 0.35,
                                cur.heaviness ?? 0.30
                            )
                        )
                        if let x = cur.x, let y = cur.y {
                            factRow("Map pos", value: String(format: "(%.2f, %.2f)", x, y))
                        }
                    }

                    Rectangle().fill(pal.line).frame(height: 0.5)

                    Text(cur.summary)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(pal.ink2)
                        .fixedSize(horizontal: false, vertical: true)

                    let nearest = engine.nearestWorks(to: cur, limit: 5)
                    if !nearest.isEmpty {
                        Rectangle().fill(pal.line).frame(height: 0.5)

                        Text("Nearest on Manifold")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundStyle(pal.ink)

                        VStack(spacing: 0) {
                            ForEach(nearest) { entry in
                                Button {
                                    engine.play(entry.work, autoStart: true)
                                } label: {
                                    HStack(spacing: 10) {
                                        RadioSleeve(
                                            title: entry.work.title,
                                            subtitle: "",
                                            seed: entry.work.workId,
                                            colorOverride: entry.work.colorHex,
                                            artURL: entry.work.artUrl.flatMap(URL.init(string:)),
                                            size: 36,
                                            compact: true
                                        )
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(entry.work.title)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(pal.ink)
                                                .lineLimit(1)
                                            Text("\(shortCreatorName(entry.work.creator)) · \(entry.work.originBadge)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(pal.ink3)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 6)
                                        Text(String(format: "%.2f", entry.score))
                                            .font(.system(size: 11.5, design: .monospaced).monospacedDigit())
                                            .foregroundStyle(pal.ink2)
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Rectangle().fill(pal.line).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func factRow(_ key: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(pal.ink3)
                .frame(width: 94, alignment: .leading)
            Text(value)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(pal.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var upNextView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(engine.playableQueue) { entry in
                    let isCur = engine.currentWork?.workId == entry.work.workId
                    Button {
                        engine.play(entry.work, autoStart: true)
                    } label: {
                        HStack(spacing: 10) {
                            RadioSleeve(
                                title: entry.work.title,
                                subtitle: "",
                                seed: entry.work.workId,
                                colorOverride: entry.work.colorHex,
                                artURL: entry.work.artUrl.flatMap(URL.init(string:)),
                                size: 42,
                                compact: true,
                                isActive: isCur
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.work.title)
                                    .font(.system(size: 13.5, weight: isCur ? .semibold : .medium))
                                    .foregroundStyle(isCur ? pal.signal : pal.ink)
                                    .lineLimit(1)
                                Text("\(shortCreatorName(entry.work.creator)) · \(entry.work.year)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(pal.ink3)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Text(String(format: "%.2f", entry.score))
                                .font(.system(size: 11.5, design: .monospaced).monospacedDigit())
                                .foregroundStyle(pal.ink2)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 16)
                        .background(isCur ? pal.signal.opacity(0.08) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Rectangle().fill(pal.line).frame(height: 0.5).padding(.horizontal, 16)
                }

                if !engine.discoveryWorks.isEmpty {
                    HStack {
                        Text("Manifold reference pool")
                            .font(.system(size: 13.5, weight: .bold, design: .serif))
                            .foregroundStyle(pal.ink2)
                        Spacer()
                        Text("Coords only")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(pal.ink3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                    ForEach(engine.discoveryWorks) { entry in
                        HStack(spacing: 10) {
                            RadioSleeve(
                                title: entry.work.title,
                                subtitle: "",
                                seed: entry.work.workId,
                                size: 36,
                                compact: true
                            )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.work.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(pal.ink2)
                                    .lineLimit(1)
                                Text("\(shortCreatorName(entry.work.creator)) · \(entry.work.year)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(pal.ink3)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Text(String(format: "%.2f", entry.score))
                                .font(.system(size: 11, design: .monospaced).monospacedDigit())
                                .foregroundStyle(pal.ink3)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        Rectangle().fill(pal.line).frame(height: 0.5).padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var mapTabView: some View {
        VStack(spacing: 8) {
            LatentMapCanvas(
                works: engine.allWorks,
                currentWork: cur,
                trail: Array(engine.playableQueue.prefix(6).map(\.work)),
                activeLens: engine.activeLens,
                mapTarget: engine.mapTarget
            ) { x, y in
                engine.tuneToMap(x: x, y: y)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            HStack(spacing: 10) {
                legendDot(LatentMapCanvas.regionColors[0], "High")
                legendDot(LatentMapCanvas.regionColors[1], "Warm")
                legendDot(LatentMapCanvas.regionColors[2], "Deep")
                legendDot(LatentMapCanvas.regionColors[3], "Chill")
                Spacer(minLength: 0)
                if engine.mapTarget != nil {
                    Button("Reset map") {
                        engine.clearMapTarget()
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(pal.signal)
                    .buttonStyle(.plain)
                } else {
                    Text("Tap to steer")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(pal.ink3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(pal.ink2)
        }
    }

    private var trustTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let lens = engine.activeLens {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(lens.name)
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .foregroundStyle(pal.ink)
                            Spacer()
                            Label(
                                lens.signatureValid == false ? "Unverified" : "Ed25519 verified",
                                systemImage: lens.signatureValid == false ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"
                            )
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(lens.signatureValid == false ? pal.bad : pal.good)
                        }
                        factRow("Curator", value: "@\(lens.issuerHandle)")
                        factRow("Space", value: lens.modelId)
                        factRow("Anchors", value: "\(lens.anchors.count) works")
                        Text(lens.summary)
                            .font(.system(size: 12.5, design: .serif))
                            .foregroundStyle(pal.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Rectangle().fill(pal.line).frame(height: 0.5)
                }

                Text("Canary reputation ledger")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(pal.ink)

                if engine.contributors.isEmpty {
                    Text("Syncing contributor trust scores from Manifold hub.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(pal.ink3)
                } else {
                    ForEach(engine.contributors) { actor in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(pal.good)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("@\(actor.handle)")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(pal.ink)
                                Text(actor.tier)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(pal.ink3)
                            }
                            Spacer(minLength: 6)
                            Text(String(format: "%.3f cos", actor.meanCanaryCosine))
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced).monospacedDigit())
                                .foregroundStyle(pal.ink)
                            Text("\(actor.credits) cr")
                                .font(.system(size: 11, design: .monospaced).monospacedDigit())
                                .foregroundStyle(pal.ink2)
                                .frame(width: 48, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        Rectangle().fill(pal.line).frame(height: 0.5)
                    }
                }
            }
            .padding(16)
        }
    }

    private var currentScore: Double? {
        guard let cur else { return nil }
        return engine.rankedQueue.first(where: { $0.work.workId == cur.workId })?.score
    }

    private func formatTime(_ sec: Double) -> String {
        let total = max(0, Int(sec.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct RadioSettingsSheet: View {
    @Bindable var engine: RadioEngine
    @State private var serverPassword: String = ""
    @State private var busyConnect = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var pal: RadioPalette {
        RadioPalette.forScheme(scheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Home radio server (6IAN / music-core)") {
                    TextField("https://your-radio.example.com", text: $engine.homeServerURL)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                    SecureField("Server password (saved in Keychain)", text: $serverPassword)
                        .autocorrectionDisabled()
                    HStack {
                        Button(busyConnect ? "Connecting..." : (engine.homeServerConnected ? "Reconnect" : "Connect")) {
                            busyConnect = true
                            Task {
                                await engine.connectHomeServer(password: serverPassword)
                                busyConnect = false
                            }
                        }
                        .disabled(busyConnect || engine.homeServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if engine.homeServerConnected {
                            Spacer()
                            Button("Disconnect", role: .destructive) {
                                serverPassword = ""
                                engine.disconnectHomeServer()
                            }
                        }
                    }
                    Text(engine.homeServerStatus)
                        .font(.caption.monospaced())
                        .foregroundStyle(engine.homeServerConnected ? pal.good : .secondary)
                }

                #if !os(tvOS)
                Section("Local files") {
                    Button("Add audio files") {
                        dismiss()
                        engine.showImporter = true
                    }
                    if !engine.localWorks.isEmpty {
                        Button("Clear \(engine.localWorks.count) imported file(s)", role: .destructive) {
                            engine.clearLocalFiles()
                        }
                    }
                }
                #endif

                Section("Manifold embedding pool") {
                    TextField("https://manifold-chi.vercel.app", text: $engine.hubURL)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                    TextField("Ed25519 contributor key (optional)", text: $engine.contributorIssuer)
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
        .tint(pal.signal)
        .onAppear {
            if serverPassword.isEmpty, !engine.homeServerURL.isEmpty {
                serverPassword = RadioKeychain.loadPassword(server: engine.homeServerURL) ?? ""
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 420)
        #endif
    }
}
