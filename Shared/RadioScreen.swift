import SwiftUI
import UniformTypeIdentifiers

public enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case liked = "Liked"
    case local = "Local"
    case pool = "Pool"

    public var id: String { rawValue }
}

public struct RadioScreen: View {
    @Bindable var engine: RadioEngine
    @State private var libraryFilter: LibraryFilter = .all
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
            let stationSize: CGFloat = isCompact ? 154 : 172

            ZStack(alignment: .bottom) {
                pal.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    if engine.showSearch || !engine.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        searchResultsBody
                    } else {
                        switch engine.activeTab {
                        case .home:
                            homeBody(stationSize: stationSize, isCompact: isCompact)
                        case .map:
                            mapBody
                        case .library:
                            libraryBody
                        }
                    }

                    bottomDock
                }

                if let notice = engine.playbackNotice {
                    Text(notice)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(pal.bg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(pal.ink, in: Capsule(style: .continuous))
                        .padding(.bottom, 122)
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

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            if engine.showSearch {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(pal.ink3)
                        .accessibilityHidden(true)
                    TextField("Search songs, artists, moods", text: $engine.searchQuery)
                        .font(.system(size: 15))
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
                                .font(.system(size: 14))
                                .foregroundStyle(pal.ink3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(pal.panel, in: Capsule(style: .continuous))

                Button("Cancel") {
                    engine.searchQuery = ""
                    engine.showSearch = false
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(pal.ink)
                .buttonStyle(.plain)
            } else {
                Button {
                    engine.activeTab = .home
                    engine.clearMapTarget()
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(pal.signal)
                                .frame(width: 26, height: 26)
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(pal.signalInk)
                                .offset(x: 1)
                        }
                        Text("Onto")
                            .font(.system(size: 21, weight: .bold, design: .serif))
                            .foregroundStyle(pal.ink)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Onto Home")

                Spacer(minLength: 0)

                Button {
                    engine.showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(pal.ink)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search")

                Button {
                    engine.showSettings = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(pal.ink)
                            .frame(width: 34, height: 34)
                            .background(pal.panel, in: Circle())
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
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    // MARK: - Home Tab

    private func homeBody(stationSize: CGFloat, isCompact: Bool) -> some View {
        let quickTracks = Array(engine.homeQuickPicks.prefix(isCompact ? 4 : 6))
        let jazz = Array(engine.jazzPicks.prefix(10))
        let classical = Array(engine.classicalPicks.prefix(10))
        let stations = engine.allLenses
        let shelfCardSize: CGFloat = isCompact ? 142 : 158

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                moodStrip

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        Text("Quick picks")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(pal.ink)
                        Spacer(minLength: 0)
                        Button("Play all") {
                            if let first = quickTracks.first {
                                engine.play(first, autoStart: true)
                                engine.showNowPlaying = true
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(pal.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(pal.panel, in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 4) {
                        ForEach(quickTracks) { work in
                            trackRow(work)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !jazz.isEmpty {
                    visualWorkShelf(
                        title: "Jazz",
                        tag: "Miles orbit",
                        works: jazz,
                        cardSize: shelfCardSize
                    )
                }

                if !classical.isEmpty {
                    visualWorkShelf(
                        title: "Classical",
                        tag: "Heavy & hypnotic",
                        works: classical,
                        cardSize: shelfCardSize
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Stations")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(pal.ink)
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(stations) { lens in
                                let active = engine.activeLens?.id == lens.id
                                Button {
                                    engine.selectLens(lens)
                                    engine.showNowPlaying = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        RadioCoverArt(
                                            seed: lens.id,
                                            colorOverride: lens.colorHex,
                                            artURL: lens.artUrl.flatMap(URL.init(string:)),
                                            stationTitle: lens.name,
                                            size: stationSize,
                                            isActive: active
                                        )
                                        Text(stationSubtitle(lens))
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(active ? pal.signal : pal.ink2)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                            .frame(width: stationSize, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func visualWorkShelf(title: String, tag: String, works: [RadioWork], cardSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(pal.ink)
                Spacer(minLength: 0)
                Text(tag)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(pal.ink3)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(works) { work in
                        let isCur = engine.currentWork?.workId == work.workId
                        Button {
                            if work.isPlayable {
                                engine.play(work, autoStart: true)
                            } else {
                                engine.currentWork = work
                                engine.nowPlayingTab = .why
                            }
                            engine.showNowPlaying = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RadioCoverArt(
                                    seed: work.workId,
                                    colorOverride: work.colorHex,
                                    artURL: work.artUrl.flatMap(URL.init(string:)),
                                    localArtData: work.localArtData,
                                    energy: work.energy ?? 0.35,
                                    size: cardSize,
                                    isActive: isCur
                                )
                                Text(engine.fittedTitle(for: work, maxChars: 19))
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(isCur ? pal.signal : pal.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.84)
                                    .frame(width: cardSize, alignment: .leading)

                                Text(AITitleFitter.heuristicFit(work.hook ?? shortCreatorName(work.creator), maxChars: 22))
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(pal.ink2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .frame(width: cardSize, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var moodStrip: some View {
        let presets = RadioMoodPreset.allCases.filter { $0 != .all }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    let active = engine.moodPreset == preset
                    Button {
                        engine.selectMood(preset)
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(active ? pal.bg : pal.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(
                                active ? pal.ink : pal.panel,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(active ? pal.ink : pal.line, lineWidth: 0.75)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func trackRow(_ work: RadioWork, showPoolPill: Bool = false) -> some View {
        let isCurrent = engine.currentWork?.workId == work.workId
        return HStack(spacing: 12) {
            Button {
                if work.isPlayable {
                    engine.play(work, autoStart: true)
                    engine.showNowPlaying = true
                } else {
                    engine.currentWork = work
                    engine.nowPlayingTab = .why
                    engine.showNowPlaying = true
                }
            } label: {
                HStack(spacing: 12) {
                    RadioCoverArt(
                        seed: work.workId,
                        colorOverride: work.colorHex,
                        artURL: work.artUrl.flatMap(URL.init(string:)),
                        localArtData: work.localArtData,
                        energy: work.energy ?? 0.35,
                        size: 48,
                        isActive: isCurrent
                    )
                    .opacity(work.isPlayable ? 1.0 : 0.72)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(engine.fittedTitle(for: work, maxChars: 24))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isCurrent ? pal.signal : (work.isPlayable ? pal.ink : pal.ink2))
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                        Text(AITitleFitter.compactSubtitle(creator: shortCreatorName(work.creator), hook: work.hook, maxChars: 34))
                            .font(.system(size: 12.5))
                            .foregroundStyle(pal.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showPoolPill && !work.isPlayable {
                Text("Coords")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(pal.ink3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(pal.panel, in: Capsule(style: .continuous))
            } else {
                #if !os(tvOS)
                Menu {
                    if work.isPlayable {
                        Button("Play now", systemImage: "play.fill") {
                            engine.play(work, autoStart: true)
                        }
                        Button("Play next", systemImage: "text.insert") {
                            engine.queueNext(work)
                        }
                    }
                    Button(
                        engine.likedIDs.contains(work.workId) ? "Remove like" : "Like",
                        systemImage: engine.likedIDs.contains(work.workId) ? "hand.thumbsup.fill" : "hand.thumbsup"
                    ) {
                        engine.toggleLike(work)
                    }
                    Button("Less like this", systemImage: "hand.thumbsdown") {
                        engine.dislikeAndSkip(work)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundStyle(pal.ink3)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More for \(work.title)")
                #endif
            }
        }
        .frame(height: 56)
    }

    // MARK: - Map Tab

    private var mapBody: some View {
        ZStack(alignment: .topLeading) {
            LatentMapCanvas(
                works: engine.allWorks,
                currentWork: engine.currentWork,
                trail: Array(engine.playableQueue.prefix(6).map(\.work)),
                activeLens: engine.activeLens,
                mapTarget: engine.mapTarget
            ) { x, y in
                engine.tuneToMap(x: x, y: y)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(pal.line, lineWidth: 0.75)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Circle()
                    .fill(pal.signal)
                    .frame(width: 7, height: 7)
                Text(engine.mapTargetLabel ?? (engine.currentWork?.title ?? "Tap anywhere to steer"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(pal.ink)
                    .lineLimit(1)
                if engine.mapTarget != nil {
                    Button("Reset") {
                        engine.clearMapTarget()
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(pal.signal)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(pal.bg.opacity(0.92), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75)
            }
            .padding(.top, 18)
            .padding(.leading, 24)
        }
    }

    // MARK: - Library Tab

    private var libraryBody: some View {
        let items: [RadioWork] = switch libraryFilter {
        case .all:
            engine.playableQueue.map(\.work)
        case .liked:
            engine.allWorks.filter { engine.likedIDs.contains($0.workId) }
        case .local:
            engine.localWorks
        case .pool:
            engine.discoveryWorks.map(\.work)
        }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    #if !os(tvOS)
                    Button {
                        engine.showImporter = true
                    } label: {
                        Label("Add files", systemImage: "plus")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(pal.bg)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(pal.ink, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    #endif

                    Button {
                        engine.showSettings = true
                    } label: {
                        HStack(spacing: 6) {
                            if engine.homeServerConnected {
                                Circle().fill(pal.good).frame(width: 7, height: 7)
                            }
                            Text(engine.homeServerConnected ? "Home connected" : "Home server")
                        }
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(pal.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(pal.panel, in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LibraryFilter.allCases) { f in
                            let active = libraryFilter == f
                            Button {
                                libraryFilter = f
                            } label: {
                                Text(f.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(active ? pal.bg : pal.ink)
                                    .padding(.horizontal, 13)
                                    .frame(height: 30)
                                    .background(active ? pal.ink : pal.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(active ? pal.ink : pal.line, lineWidth: 0.75)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if items.isEmpty {
                    Text(libraryEmptyMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(pal.ink2)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(items) { work in
                            trackRow(work, showPoolPill: libraryFilter == .pool)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var libraryEmptyMessage: String {
        switch libraryFilter {
        case .liked: return "Tracks you like appear here."
        case .local: return "Import audio files from Files to play offline."
        case .pool: return "Manifold reference coordinates will appear after sync."
        case .all: return "No playable tracks found."
        }
    }

    // MARK: - Search Body

    private var searchResultsBody: some View {
        let playable = engine.filteredPlayable
        let discovery = engine.filteredDiscovery

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(playable) { entry in
                    trackRow(entry.work)
                }
                if !discovery.isEmpty {
                    Text("Reference pool")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(pal.ink2)
                        .padding(.top, 12)
                    ForEach(discovery.prefix(12)) { entry in
                        trackRow(entry.work, showPoolPill: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Docked Mini-Player + Bottom Tab Bar

    private var bottomDock: some View {
        VStack(spacing: 0) {
            miniPlayerBar
            Rectangle().fill(pal.line).frame(height: 0.5)
            HStack(spacing: 0) {
                tabButton(.home, icon: "house.fill")
                tabButton(.map, icon: "circle.hexagongrid")
                tabButton(.library, icon: "music.note.list")
            }
            .frame(height: 50)
            .background(pal.bg)
        }
    }

    private func tabButton(_ tab: RadioRootTab, icon: String) -> some View {
        let active = engine.activeTab == tab && !engine.showSearch
        return Button {
            engine.showSearch = false
            engine.searchQuery = ""
            engine.activeTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: active ? .semibold : .regular))
                Text(tab.rawValue)
                    .font(.system(size: 10.5, weight: active ? .semibold : .regular))
            }
            .foregroundStyle(active ? pal.signal : pal.ink3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var miniPlayerBar: some View {
        let cur = engine.currentWork
        let progress = engine.durationSec > 0 ? min(1, max(0, engine.elapsedSec / engine.durationSec)) : 0
        return ZStack(alignment: .bottomLeading) {
            HStack(spacing: 12) {
                Button {
                    engine.showNowPlaying = true
                } label: {
                    HStack(spacing: 12) {
                        RadioCoverArt(
                            seed: cur?.workId ?? "idle",
                            colorOverride: cur?.colorHex,
                            artURL: cur?.artUrl.flatMap(URL.init(string:)),
                            localArtData: cur?.localArtData,
                            energy: cur?.energy ?? 0.35,
                            size: 42
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cur.map { engine.fittedTitle(for: $0, maxChars: 20) } ?? "Onto Radio")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(pal.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)
                            Text(shortCreatorName(cur?.creator ?? ""))
                                .font(.system(size: 12))
                                .foregroundStyle(pal.ink2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
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
            .padding(.horizontal, 14)
            .frame(height: 58)

            GeometryReader { geo in
                Rectangle()
                    .fill(pal.signal)
                    .frame(width: geo.size.width * progress, height: 2)
            }
            .frame(height: 2)
            .allowsHitTesting(false)
        }
        .background(pal.panel)
    }

    private func stationSubtitle(_ lens: RadioLens) -> String {
        switch lens.id {
        case "lens:radio:jazz-miles-orbit": return "Miles · Rhodes & groove"
        case "lens:radio:classical-heavy": return "5/4 thunder & synth"
        case "lens:radio:late-wire": return "Ambient · Nocturnal piano"
        case "lens:radio:motorik-pulse": return "Krautrock · Synth drive"
        case "lens:radio:chamber-focus": return "Goldberg · Cello suites"
        default: return AITitleFitter.heuristicFit(lens.summary, maxChars: 24)
        }
    }
}

// MARK: - Hero Artwork Now Playing

public struct NowPlayingView: View {
    @Bindable var engine: RadioEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

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
                        HStack(alignment: .top, spacing: 26) {
                            wideLeftColumn(artSize: min(310, geo.size.height * 0.45))
                                .frame(width: 318)
                            drawerPanelContent
                                .background(pal.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(pal.line, lineWidth: 0.75)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    } else {
                        compactPlayerBody(heroSize: min(geo.size.width - 56, max(250, geo.size.height - 418)))
                    }
                }
            }
        }
        .tint(pal.signal)
        .sheet(isPresented: $engine.showNowPlayingDrawer) {
            NavigationStack {
                drawerPanelContent
                    .background(pal.panel)
                    .navigationTitle(engine.nowPlayingTab.rawValue)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { engine.showNowPlayingDrawer = false }
                        }
                    }
            }
            .tint(pal.signal)
            #if !os(tvOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                engine.showNowPlaying = false
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(pal.ink)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close now playing")

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                ForEach(NowPlayingStageMode.allCases) { mode in
                    let active = engine.nowPlayingStage == mode
                    Button {
                        engine.nowPlayingStage = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(active ? pal.bg : pal.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(active ? pal.ink : Color.clear, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(pal.panel.opacity(0.9), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75)
            }

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
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    private func compactPlayerBody(heroSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            heroStage(size: heroSize)

            Spacer(minLength: 14)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    RecoverableTitle(
                        text: cur?.title ?? "Onto Radio",
                        font: .system(size: 21, weight: .bold, design: .serif),
                        color: pal.ink,
                        lineLimit: 3
                    )
                    Text(creatorAndHookLine)
                        .font(.system(size: 14.5))
                        .foregroundStyle(pal.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                actionPillsRow
                scrubberView
                transportCluster
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)

            collapsedDrawerDock
        }
    }

    private func wideLeftColumn(artSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            heroStage(size: artSize)

            VStack(alignment: .leading, spacing: 3) {
                RecoverableTitle(
                    text: cur?.title ?? "Onto Radio",
                    font: .system(size: 21, weight: .bold, design: .serif),
                    color: pal.ink,
                    lineLimit: 3
                )
                Text(creatorAndHookLine)
                    .font(.system(size: 14))
                    .foregroundStyle(pal.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            actionPillsRow
            scrubberView
            transportCluster
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func heroStage(size: CGFloat) -> some View {
        if engine.nowPlayingStage == .map {
            LatentMapCanvas(
                works: engine.allWorks,
                currentWork: cur,
                trail: Array(engine.playableQueue.prefix(6).map(\.work)),
                activeLens: engine.activeLens,
                mapTarget: engine.mapTarget
            ) { x, y in
                engine.tuneToMap(x: x, y: y)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(pal.line, lineWidth: 0.75)
            }
        } else {
            RadioCoverArt(
                seed: cur?.workId ?? "idle",
                colorOverride: cur?.colorHex,
                artURL: cur?.artUrl.flatMap(URL.init(string:)),
                localArtData: cur?.localArtData,
                energy: cur?.energy ?? 0.35,
                size: size,
                cornerRadius: 12
            )
        }
    }

    private var actionPillsRow: some View {
        let isLiked = cur.map { engine.likedIDs.contains($0.workId) } ?? false
        let isDisliked = cur.map { engine.dislikedIDs.contains($0.workId) } ?? false

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    Button {
                        if let cur { engine.toggleLike(cur) }
                    } label: {
                        Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 14))
                            .foregroundStyle(isLiked ? pal.signal : pal.ink)
                            .frame(width: 42, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isLiked ? "Unlike" : "Like")

                    Rectangle()
                        .fill(pal.line)
                        .frame(width: 0.75, height: 18)

                    Button {
                        if let cur { engine.dislikeAndSkip(cur) }
                    } label: {
                        Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.system(size: 14))
                            .foregroundStyle(isDisliked ? pal.bad : pal.ink)
                            .frame(width: 42, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dislike and skip")
                }
                .background(pal.panel, in: Capsule(style: .continuous))
                .overlay { Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75) }

                if let amStr = cur?.appleMusicUrl, let amURL = URL(string: amStr) {
                    Button {
                        openURL(amURL)
                    } label: {
                        Label("Apple Music", systemImage: "music.note")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(pal.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(pal.panel, in: Capsule(style: .continuous))
                            .overlay { Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75) }
                    }
                    .buttonStyle(.plain)
                }

                if let cur, let ytURL = AppleMusicCatalog.youtubeMusicSearchURL(title: cur.shortTitle ?? cur.title, creator: cur.creator) {
                    Button {
                        openURL(ytURL)
                    } label: {
                        Label("YouTube", systemImage: "play.rectangle")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(pal.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(pal.panel, in: Capsule(style: .continuous))
                            .overlay { Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75) }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    engine.nowPlayingTab = .why
                    engine.showNowPlayingDrawer = true
                } label: {
                    Label("Why this", systemImage: "sparkles")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(pal.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(pal.panel, in: Capsule(style: .continuous))
                        .overlay { Capsule(style: .continuous).strokeBorder(pal.line, lineWidth: 0.75) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var creatorAndHookLine: String {
        guard let cur else { return "" }
        return AITitleFitter.compactSubtitle(
            creator: shortCreatorName(cur.creator),
            hook: cur.hook,
            maxChars: 38
        )
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
                Text(cur?.isPreviewOnly == true ? "0:30 · Preview" : formatTime(engine.durationSec))
            }
            .font(.system(size: 11.5, design: .monospaced).monospacedDigit())
            .foregroundStyle(pal.ink2)
        }
    }

    private var transportCluster: some View {
        HStack {
            Button {
                engine.nowPlayingTab = .upNext
                engine.showNowPlayingDrawer = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundStyle(pal.ink2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Up next queue")

            Spacer()

            Button {
                engine.skipPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(pal.ink)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous track")

            Spacer()

            Button {
                engine.togglePlay()
            } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(pal.bg)
                    .frame(width: 66, height: 66)
                    .background(pal.ink, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.isPlaying ? "Pause" : "Play")

            Spacer()

            Button {
                engine.skipNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(pal.ink)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next track")

            Spacer()

            Button {
                engine.nowPlayingStage = (engine.nowPlayingStage == .song ? .map : .song)
            } label: {
                Image(systemName: engine.nowPlayingStage == .map ? "square.stack.fill" : "circle.hexagongrid")
                    .font(.system(size: 18))
                    .foregroundStyle(engine.nowPlayingStage == .map ? pal.signal : pal.ink2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle map stage")
        }
    }

    private var collapsedDrawerDock: some View {
        HStack(spacing: 0) {
            ForEach([NowPlayingTab.upNext, .why, .trust]) { tab in
                Button {
                    engine.nowPlayingTab = tab
                    engine.showNowPlayingDrawer = true
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(pal.ink2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
        .background(pal.panel)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle().fill(pal.line).frame(height: 0.75)
        }
    }

    private var drawerPanelContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                ForEach(NowPlayingTab.allCases) { tab in
                    let active = engine.nowPlayingTab == tab
                    Button {
                        engine.nowPlayingTab = tab
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: active ? .semibold : .regular))
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
                case .upNext:
                    upNextView
                case .why:
                    whyThisView
                case .map:
                    mapTabView
                case .trust:
                    trustTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        HStack(spacing: 12) {
                            RadioCoverArt(
                                seed: entry.work.workId,
                                colorOverride: entry.work.colorHex,
                                artURL: entry.work.artUrl.flatMap(URL.init(string:)),
                                localArtData: entry.work.localArtData,
                                energy: entry.work.energy ?? 0.35,
                                size: 44,
                                isActive: isCur
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(engine.fittedTitle(for: entry.work, maxChars: 24))
                                    .font(.system(size: 14.5, weight: isCur ? .semibold : .medium))
                                    .foregroundStyle(isCur ? pal.signal : pal.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.84)
                                Text("\(shortCreatorName(entry.work.creator)) · \(entry.work.originBadge)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(pal.ink2)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            Text(String(format: "%.2f", entry.score))
                                .font(.system(size: 11.5, design: .monospaced).monospacedDigit())
                                .foregroundStyle(pal.ink3)
                        }
                        .padding(.vertical, 8)
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
                            .font(.system(size: 14, weight: .bold))
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
                        HStack(spacing: 12) {
                            RadioCoverArt(
                                seed: entry.work.workId,
                                energy: entry.work.energy ?? 0.35,
                                size: 38
                            )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(engine.fittedTitle(for: entry.work, maxChars: 24))
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(pal.ink2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.84)
                                Text("\(shortCreatorName(entry.work.creator)) · \(entry.work.year)")
                                    .font(.system(size: 11.5))
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
            .padding(.vertical, 8)
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
                            value: String(format: "%.2f / %.2f", cur.energy ?? 0.35, cur.heaviness ?? 0.30)
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
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(pal.ink)

                        VStack(spacing: 0) {
                            ForEach(nearest) { entry in
                                Button {
                                    engine.play(entry.work, autoStart: true)
                                } label: {
                                    HStack(spacing: 10) {
                                        RadioCoverArt(
                                            seed: entry.work.workId,
                                            colorOverride: entry.work.colorHex,
                                            artURL: entry.work.artUrl.flatMap(URL.init(string:)),
                                            localArtData: entry.work.localArtData,
                                            energy: entry.work.energy ?? 0.35,
                                            size: 38
                                        )
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(engine.fittedTitle(for: entry.work, maxChars: 24))
                                                .font(.system(size: 13.5, weight: .medium))
                                                .foregroundStyle(pal.ink)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.84)
                                            Text("\(shortCreatorName(entry.work.creator)) · \(entry.work.originBadge)")
                                                .font(.system(size: 11.5))
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(pal.signal)
                    .buttonStyle(.plain)
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
                .font(.system(size: 11))
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
                                .font(.system(size: 15, weight: .bold))
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
                            .font(.system(size: 13))
                            .foregroundStyle(pal.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Rectangle().fill(pal.line).frame(height: 0.5)
                }

                Text("Canary reputation ledger")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(pal.ink)

                if engine.contributors.isEmpty {
                    Text("Syncing contributor trust scores from Manifold hub.")
                        .font(.system(size: 12))
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
                                    .font(.system(size: 11))
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

    private func formatTime(_ sec: Double) -> String {
        let total = max(0, Int(sec.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private func shortCreatorName(_ raw: String) -> String {
    let head = raw.split(separator: "·", maxSplits: 1).first.map(String.init) ?? raw
    return head.trimmingCharacters(in: .whitespacesAndNewlines)
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
                Section("Home radio server (music-core)") {
                    TextField("https://your-radio.example.com", text: $engine.homeServerURL)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                    SecureField("Server password (saved in Keychain)", text: $serverPassword)
                        .autocorrectionDisabled()
                    HStack {
                        Button(busyConnect ? "Connecting" : (engine.homeServerConnected ? "Reconnect" : "Connect")) {
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
