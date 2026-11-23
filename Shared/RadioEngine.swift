import AVFoundation
import Foundation
import MediaPlayer
import Observation

public enum RadioRootTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case map = "Map"
    case library = "Library"

    public var id: String { rawValue }
}

public enum NowPlayingStageMode: String, CaseIterable, Identifiable {
    case song = "Song"
    case map = "Map"

    public var id: String { rawValue }
}

public enum NowPlayingTab: String, CaseIterable, Identifiable {
    case upNext = "Up next"
    case why = "Why this"
    case map = "Map"
    case trust = "Trust"

    public var id: String { rawValue }
}

@MainActor
@Observable
public final class RadioEngine {
    public var hubURL: String
    public var homeServerURL: String
    public var contributorIssuer: String

    public var works: [RadioWork] = ManifoldRadioClient.bundledWorks
    public var homeWorks: [RadioWork] = []
    public var localWorks: [RadioWork] = []
    public var lenses: [RadioLens] = ManifoldRadioClient.bundledLenses
    public var homeStations: [RadioLens] = []
    public var contributors: [ContributorReputation] = []

    public var selectedLensID: String = "lens:radio:late-wire"
    public var moodPreset: RadioMoodPreset = .all
    public var maxEnergy: Double = 1.0
    public var maxHeaviness: Double = 1.0
    public var searchQuery: String = ""
    public var activeTab: RadioRootTab = .home
    public var showSearch: Bool = false

    public var likedIDs: Set<String> = []
    public var dislikedIDs: Set<String> = []
    public var queuedNextIDs: [String] = []
    public var mapTarget: (x: Double, y: Double)? = nil
    public var mapTargetLabel: String? = nil

    public var currentWork: RadioWork?
    public var isPlaying: Bool = false
    public var elapsedSec: Double = 0
    public var durationSec: Double = 0
    public var showSettings: Bool = false
    public var showImporter: Bool = false
    public var showNowPlaying: Bool = false
    public var showNowPlayingDrawer: Bool = false
    public var nowPlayingStage: NowPlayingStageMode = .song
    public var nowPlayingTab: NowPlayingTab = .upNext
    public var homeServerConnected: Bool = false
    public var homeServerStatus: String = "Local + Manifold CC0"
    public var playbackNotice: String? = nil

    public let cloudPass = CloudPassStore()

    private let defaults: UserDefaults
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var itemStatusObs: NSKeyValueObservation?
    private var consecutiveFailures: Int = 0
    private let silentQA: Bool

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedHub = defaults.string(forKey: "otr.hubURL")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.hubURL = savedHub.isEmpty ? ManifoldRadioClient.defaultHub : savedHub
        self.homeServerURL = defaults.string(forKey: "otr.homeServerURL") ?? ""
        self.contributorIssuer = defaults.string(forKey: "otr.contributorIssuer") ?? ""
        self.silentQA = ProcessInfo.processInfo.arguments.contains("-onto.silentQA")
            || ProcessInfo.processInfo.environment["MUSIC_SILENT_QA"] == "1"

        if silentQA {
            player.isMuted = true
            player.volume = 0
        }

        if let savedLocal = defaults.data(forKey: "otr.localWorks"),
           let decoded = try? JSONDecoder().decode([RadioWork].self, from: savedLocal) {
            self.localWorks = decoded
        }
        if let savedLikes = defaults.stringArray(forKey: "otr.likedIDs") {
            self.likedIDs = Set(savedLikes)
        }
        if let savedDislikes = defaults.stringArray(forKey: "otr.dislikedIDs") {
            self.dislikedIDs = Set(savedDislikes)
        }

        self.currentWork = playableQueue.first?.work ?? rankedQueue.first?.work ?? works.first
        if let dur = currentWork?.durationSec {
            self.durationSec = Double(dur)
        }
        installObservers()
        if !silentQA {
            setupRemoteCommands()
        }
    }

    public var allLenses: [RadioLens] {
        homeStations + lenses
    }

    public var activeLens: RadioLens? {
        allLenses.first(where: { $0.id == selectedLensID }) ?? allLenses.first
    }

    public var allWorks: [RadioWork] {
        var seen = Set<String>()
        var combined: [RadioWork] = []
        for w in localWorks + homeWorks + works {
            if seen.insert(w.workId).inserted {
                combined.append(w)
            }
        }
        return combined
    }

    public var rankedQueue: [RankedRadioTrack] {
        RadioMath.rankTracks(
            tracks: allWorks,
            lens: activeLens,
            maxEnergy: maxEnergy,
            maxHeaviness: maxHeaviness,
            likedIDs: likedIDs,
            dislikedIDs: dislikedIDs,
            mapTarget: mapTarget,
            preferHighEnergy: moodPreset.prefersHigherEnergy
        )
    }

    public var playableQueue: [RankedRadioTrack] {
        let base = rankedQueue.filter { $0.work.isPlayable }
        if queuedNextIDs.isEmpty { return base }
        let byId = Dictionary(uniqueKeysWithValues: base.map { ($0.work.workId, $0) })
        var pinned: [RankedRadioTrack] = []
        var pinnedSet = Set<String>()
        for id in queuedNextIDs {
            if let hit = byId[id], pinnedSet.insert(id).inserted {
                pinned.append(hit)
            }
        }
        let rest = base.filter { !pinnedSet.contains($0.work.workId) }
        return pinned + rest
    }

    public var discoveryWorks: [RankedRadioTrack] {
        rankedQueue.filter { !$0.work.isPlayable }
    }

    public var filteredPlayable: [RankedRadioTrack] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return playableQueue }
        return playableQueue.filter { matchesSearch($0.work, query: q) }
    }

    public var filteredDiscovery: [RankedRadioTrack] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return discoveryWorks }
        return discoveryWorks.filter { matchesSearch($0.work, query: q) }
    }

    public func nearestWorks(to work: RadioWork, limit: Int = 5) -> [RankedRadioTrack] {
        let byId = Dictionary(uniqueKeysWithValues: allWorks.map { ($0.workId, $0) })
        if let nbs = work.neighbours, !nbs.isEmpty {
            let mapped = nbs.compactMap { n -> RankedRadioTrack? in
                guard let w = byId[n.workId] else { return nil }
                return RankedRadioTrack(work: w, score: n.sim)
            }
            if !mapped.isEmpty {
                return Array(mapped.prefix(limit))
            }
        }
        guard let v = work.vec32, !v.isEmpty else {
            return Array(rankedQueue.filter { $0.work.workId != work.workId }.prefix(limit))
        }
        return Array(
            allWorks
                .filter { $0.workId != work.workId }
                .compactMap { cand -> RankedRadioTrack? in
                    guard let cv = cand.vec32, !cv.isEmpty else { return nil }
                    return RankedRadioTrack(work: cand, score: max(0, RadioMath.cosine(v, cv)))
                }
                .sorted { $0.score > $1.score }
                .prefix(limit)
        )
    }

    public func syncFromManifold() async {
        do {
            let snap = try await ManifoldRadioClient.fetchSnapshot(hubBase: hubURL)
            if !snap.works.isEmpty {
                works = snap.works
                if let cur = currentWork,
                   cur.localBookmark == nil,
                   let fresh = snap.works.first(where: { $0.workId == cur.workId }) {
                    currentWork = fresh
                }
            }
            if !snap.lenses.isEmpty {
                lenses = snap.lenses
                if !allLenses.contains(where: { $0.id == selectedLensID }), let first = allLenses.first {
                    selectedLensID = first.id
                }
            }
            contributors = snap.contributors
            if currentWork == nil || currentWork?.isPlayable == false {
                currentWork = playableQueue.first?.work ?? rankedQueue.first?.work
            }
        } catch {
            // Bundled verified CC0 works & lenses stay active offline
        }
        if !homeServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !homeServerConnected {
            if let pw = RadioKeychain.loadPassword(server: homeServerURL) {
                await connectHomeServer(password: pw, silent: true)
            } else {
                await refreshHomeLibrary(silent: true)
            }
        }
        await cloudPass.refresh()
    }

    public func connectHomeServer(password: String, silent: Bool = false) async {
        let server = RadioKeychain.normalizedServer(homeServerURL)
        guard !server.isEmpty else {
            homeServerStatus = "Enter server URL"
            return
        }
        homeServerURL = server
        saveSettings()
        do {
            if !password.isEmpty {
                _ = try await HomeRadioClient.signIn(baseURL: server, password: password)
                RadioKeychain.savePassword(password, server: server)
            }
            try await loadHomeData(server: server)
        } catch {
            homeServerConnected = false
            if !silent {
                homeServerStatus = error.localizedDescription
            }
        }
    }

    public func refreshHomeLibrary(silent: Bool = false) async {
        let server = RadioKeychain.normalizedServer(homeServerURL)
        guard !server.isEmpty else { return }
        do {
            try await loadHomeData(server: server)
        } catch {
            homeServerConnected = false
            if !silent {
                homeServerStatus = error.localizedDescription
            }
        }
    }

    private func loadHomeData(server: String) async throws {
        let home = try await HomeRadioClient.fetchHome(baseURL: server)
        homeWorks = home.tracks
        homeStations = home.stations
        homeServerConnected = true
        homeServerStatus = "Connected · \(home.tracks.count) tracks"
        if currentWork == nil, let first = playableQueue.first?.work {
            currentWork = first
        }
    }

    public func disconnectHomeServer() {
        let server = RadioKeychain.normalizedServer(homeServerURL)
        if !server.isEmpty {
            RadioKeychain.deletePassword(server: server)
        }
        homeWorks = []
        homeStations = []
        homeServerConnected = false
        homeServerStatus = "Local + Manifold CC0"
        if selectedLensID.hasPrefix("home-station:"), let first = lenses.first {
            selectedLensID = first.id
        }
    }

    public func selectLens(_ lens: RadioLens) {
        selectedLensID = lens.id
        mapTarget = nil
        mapTargetLabel = nil
        if lens.id.hasPrefix("home-station:") {
            let stationKey = String(lens.id.dropFirst("home-station:".count))
            let server = homeServerURL
            Task {
                if let picks = try? await HomeRadioClient.fetchStationQueue(baseURL: server, mood: "station:\(stationKey)"),
                   !picks.isEmpty {
                    await MainActor.run {
                        self.homeWorks = picks
                        if let first = picks.first {
                            self.play(first, autoStart: true)
                        }
                    }
                }
            }
            return
        }
        if let top = playableQueue.first?.work {
            play(top, autoStart: isPlaying)
        }
    }

    public func selectMood(_ preset: RadioMoodPreset) {
        let resolved: RadioMoodPreset = (preset == moodPreset && preset != .all) ? .all : preset
        moodPreset = resolved
        maxEnergy = resolved.maxEnergy
        maxHeaviness = resolved.maxHeaviness
        if let cur = currentWork, !playableQueue.contains(where: { $0.work.workId == cur.workId }),
           let top = playableQueue.first?.work {
            play(top, autoStart: isPlaying)
        }
    }

    public func tuneToMap(x: Double, y: Double) {
        mapTarget = (x, y)
        let ranked = playableQueue
        if let best = ranked.first?.work {
            mapTargetLabel = best.title
            play(best, autoStart: isPlaying)
        } else {
            mapTargetLabel = String(format: "(%.2f, %.2f)", x, y)
        }
    }

    public func clearMapTarget() {
        mapTarget = nil
        mapTargetLabel = nil
    }

    public func toggleLike(_ work: RadioWork) {
        if likedIDs.contains(work.workId) {
            likedIDs.remove(work.workId)
        } else {
            likedIDs.insert(work.workId)
            dislikedIDs.remove(work.workId)
            sendHomeEvent(work, event: "like")
        }
        persistTaste()
    }

    public func dislikeAndSkip(_ work: RadioWork) {
        dislikedIDs.insert(work.workId)
        likedIDs.remove(work.workId)
        persistTaste()
        sendHomeEvent(work, event: "dislike")
        if currentWork?.workId == work.workId {
            skipNext()
        }
    }

    public func queueNext(_ work: RadioWork) {
        guard work.isPlayable else { return }
        queuedNextIDs.removeAll { $0 == work.workId }
        queuedNextIDs.insert(work.workId, at: 0)
        setNotice("Up next: \(work.title)")
    }

    public func play(_ work: RadioWork, autoStart: Bool = true) {
        guard work.isPlayable else {
            setNotice("Reference track only — import local audio or connect Home Server to play")
            return
        }
        currentWork = work
        queuedNextIDs.removeAll { $0 == work.workId }
        elapsedSec = 0
        durationSec = Double(work.durationSec ?? 180)
        playbackNotice = nil
        consecutiveFailures = 0

        let targetURL = resolvePlaybackURL(for: work)
        guard let url = targetURL else {
            isPlaying = false
            return
        }

        let item: AVPlayerItem
        if url.isFileURL {
            item = AVPlayerItem(url: url)
        } else {
            var opts: [String: Any] = [
                AVURLAssetHTTPUserAgentKey: ManifoldRadioClient.httpUserAgent
            ]
            if let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty {
                opts[AVURLAssetHTTPCookiesKey] = cookies
            }
            let asset = AVURLAsset(url: url, options: opts)
            item = AVPlayerItem(asset: asset)
        }

        observeItemStatus(item, work: work)
        player.replaceCurrentItem(with: item)
        if silentQA {
            player.isMuted = true
            player.volume = 0
        }
        if autoStart {
            activateAudioSessionIfNeeded()
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
        updateNowPlayingInfo()
    }

    public func togglePlay() {
        if isPlaying {
            player.pause()
            isPlaying = false
            updateNowPlayingInfo()
        } else {
            if player.currentItem == nil {
                if let w = currentWork, w.isPlayable {
                    play(w, autoStart: true)
                } else if let first = playableQueue.first?.work {
                    play(first, autoStart: true)
                }
            } else {
                activateAudioSessionIfNeeded()
                if silentQA {
                    player.isMuted = true
                    player.volume = 0
                }
                player.play()
                isPlaying = true
                updateNowPlayingInfo()
            }
        }
    }

    public func seek(to seconds: Double) {
        let clamped = min(max(0, seconds), max(1, durationSec))
        elapsedSec = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        updateNowPlayingInfo()
    }

    public func skipNext() {
        let q = playableQueue
        guard !q.isEmpty else { return }
        if let cur = currentWork, let idx = q.firstIndex(where: { $0.work.workId == cur.workId }) {
            let nextIdx = (idx + 1) % q.count
            play(q[nextIdx].work, autoStart: isPlaying)
        } else if let first = q.first?.work {
            play(first, autoStart: isPlaying)
        }
    }

    public func skipPrevious() {
        if elapsedSec > 4 {
            seek(to: 0)
            return
        }
        let q = playableQueue
        guard !q.isEmpty else { return }
        if let cur = currentWork, let idx = q.firstIndex(where: { $0.work.workId == cur.workId }) {
            let prevIdx = (idx - 1 + q.count) % q.count
            play(q[prevIdx].work, autoStart: isPlaying)
        } else if let first = q.first?.work {
            play(first, autoStart: isPlaying)
        }
    }

    public func importLocalFiles(_ urls: [URL]) {
        var added: [RadioWork] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            #if os(macOS)
            let bmk = try? url.bookmarkData(options: [.withSecurityScope])
            #else
            let bmk = try? url.bookmarkData()
            #endif
            let baseName = url.deletingPathExtension().lastPathComponent
            let work = RadioWork(
                workId: "local:\(baseName.lowercased().replacingOccurrences(of: " ", with: "-"))",
                title: baseName,
                creator: "Local library",
                year: Calendar.current.component(.year, from: Date()),
                kind: url.pathExtension.lowercased(),
                summary: "Local audio file",
                energy: 0.45,
                heaviness: 0.35,
                streamUrl: nil,
                durationSec: 210,
                vec32: nil,
                localBookmark: bmk,
                sourceLabel: "Local"
            )
            added.append(work)
        }
        if !added.isEmpty {
            localWorks.insert(contentsOf: added, at: 0)
            persistLocalWorks()
            if let first = added.first {
                play(first, autoStart: true)
            }
            for work in added {
                extractLocalMetadata(for: work)
            }
        }
    }

    private func persistLocalWorks() {
        let lightweight = localWorks.map { item -> RadioWork in
            var copy = item
            if (copy.localArtData?.count ?? 0) > 120_000 {
                copy.localArtData = nil
            }
            return copy
        }
        if let encoded = try? JSONEncoder().encode(lightweight) {
            defaults.set(encoded, forKey: "otr.localWorks")
        }
    }

    private func extractLocalMetadata(for work: RadioWork) {
        guard let url = resolvePlaybackURL(for: work) else { return }
        Task {
            let asset = AVURLAsset(url: url)
            let metadata = (try? await asset.load(.commonMetadata)) ?? []
            let durTime = try? await asset.load(.duration)

            var extractedTitle: String?
            var extractedArtist: String?
            var extractedArt: Data?

            for item in metadata {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let s = try? await item.load(.stringValue), !s.isEmpty { extractedTitle = s }
                case .commonKeyArtist:
                    if let s = try? await item.load(.stringValue), !s.isEmpty { extractedArtist = s }
                case .commonKeyArtwork:
                    if let d = try? await item.load(.dataValue), !d.isEmpty { extractedArt = d }
                default:
                    break
                }
            }

            let durSec: Int? = if let sec = durTime?.seconds, sec.isFinite, sec > 0 { Int(sec.rounded()) } else { nil }
            await MainActor.run {
                guard let idx = self.localWorks.firstIndex(where: { $0.workId == work.workId }) else { return }
                if let t = extractedTitle { self.localWorks[idx].title = t }
                if let a = extractedArtist { self.localWorks[idx].creator = a }
                if let art = extractedArt { self.localWorks[idx].localArtData = art }
                if let d = durSec { self.localWorks[idx].durationSec = d }
                let updated = self.localWorks[idx]
                if self.currentWork?.workId == updated.workId {
                    self.currentWork = updated
                    if let d = durSec { self.durationSec = Double(d) }
                }
                self.persistLocalWorks()
            }
        }
    }

    public func clearLocalFiles() {
        localWorks = []
        defaults.removeObject(forKey: "otr.localWorks")
    }

    public func saveSettings() {
        defaults.set(hubURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "otr.hubURL")
        defaults.set(homeServerURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "otr.homeServerURL")
        defaults.set(contributorIssuer.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "otr.contributorIssuer")
    }

    private func persistTaste() {
        defaults.set(Array(likedIDs), forKey: "otr.likedIDs")
        defaults.set(Array(dislikedIDs), forKey: "otr.dislikedIDs")
    }

    private func matchesSearch(_ w: RadioWork, query: String) -> Bool {
        w.title.lowercased().contains(query)
            || w.creator.lowercased().contains(query)
            || w.kind.lowercased().contains(query)
            || w.summary.lowercased().contains(query)
    }

    private func resolvePlaybackURL(for work: RadioWork) -> URL? {
        if let bmk = work.localBookmark {
            var stale = false
            #if os(macOS)
            let u = try? URL(resolvingBookmarkData: bmk, options: [.withSecurityScope], bookmarkDataIsStale: &stale)
            #else
            let u = try? URL(resolvingBookmarkData: bmk, options: [], bookmarkDataIsStale: &stale)
            #endif
            _ = u?.startAccessingSecurityScopedResource()
            return u
        }
        if let s = work.streamUrl, let u = URL(string: s) {
            return u
        }
        return nil
    }

    private func sendHomeEvent(_ work: RadioWork, event: String) {
        guard let token = work.pickToken, !homeServerURL.isEmpty else { return }
        let server = homeServerURL
        let pos = elapsedSec
        Task {
            await HomeRadioClient.sendEvent(baseURL: server, pickToken: token, event: event, pos: pos)
        }
    }

    private func setNotice(_ msg: String) {
        playbackNotice = msg
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            if self?.playbackNotice == msg {
                self?.playbackNotice = nil
            }
        }
    }

    private func activateAudioSessionIfNeeded() {
        guard !silentQA else { return }
        #if os(iOS) || os(tvOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // Safe fallback if simulator denies category change
        }
        #endif
    }

    private func installObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let sec = time.seconds
                if sec.isFinite && sec >= 0 {
                    self.elapsedSec = sec
                }
                if let itemDur = self.player.currentItem?.duration.seconds, itemDur.isFinite && itemDur > 0 {
                    self.durationSec = itemDur
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self, let finished = note.object as? AVPlayerItem,
                      finished === self.player.currentItem else { return }
                if let cur = self.currentWork {
                    self.sendHomeEvent(cur, event: "finish")
                }
                self.skipNext()
            }
        }
    }

    private func observeItemStatus(_ item: AVPlayerItem, work: RadioWork) {
        itemStatusObs = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            guard observed.status == .failed else { return }
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === observed else { return }
                self.consecutiveFailures += 1
                self.setNotice("Stream unavailable for \(work.title)")
                if self.consecutiveFailures < max(2, self.playableQueue.count) {
                    self.skipNext()
                } else {
                    self.isPlaying = false
                }
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == false { self?.togglePlay() }
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true { self?.togglePlay() }
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlay() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] ev in
            guard let posEv = ev as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: posEv.positionTime) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard !silentQA, let cur = currentWork else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: cur.title,
            MPMediaItemPropertyArtist: cur.creator,
            MPMediaItemPropertyPlaybackDuration: durationSec,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedSec,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let lensName = activeLens?.name {
            info[MPMediaItemPropertyAlbumTitle] = lensName
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
