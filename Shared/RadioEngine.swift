import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
public final class RadioEngine {
    public var hubURL: String
    public var homeServerURL: String
    public var contributorIssuer: String

    public var works: [RadioWork] = ManifoldRadioClient.bundledWorks
    public var localWorks: [RadioWork] = []
    public var lenses: [RadioLens] = ManifoldRadioClient.bundledLenses
    public var contributors: [ContributorReputation] = []

    public var selectedLensID: String = "lens:radio:late-wire"
    public var maxEnergy: Double = 0.85
    public var maxHeaviness: Double = 0.85

    public var currentWork: RadioWork?
    public var isPlaying: Bool = false
    public var elapsedSec: Double = 0
    public var durationSec: Double = 0
    public var errorText: String?
    public var showSettings: Bool = false
    public var showImporter: Bool = false

    public let cloudPass = CloudPassStore()

    private let defaults: UserDefaults
    private let player = AVPlayer()
    private var timeObserver: Any?
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

        self.currentWork = rankedQueue.first?.work ?? works.first
        if let dur = currentWork?.durationSec {
            self.durationSec = Double(dur)
        }
        installTimeObserver()
    }

    public var activeLens: RadioLens? {
        lenses.first(where: { $0.id == selectedLensID }) ?? lenses.first
    }

    public var allWorks: [RadioWork] {
        var seen = Set<String>()
        var combined: [RadioWork] = []
        for w in localWorks + works {
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
            maxHeaviness: maxHeaviness
        )
    }

    public func syncFromManifold() async {
        do {
            let snap = try await ManifoldRadioClient.fetchSnapshot(hubBase: hubURL)
            if !snap.works.isEmpty {
                works = snap.works
            }
            if !snap.lenses.isEmpty {
                lenses = snap.lenses
                if !lenses.contains(where: { $0.id == selectedLensID }), let first = lenses.first {
                    selectedLensID = first.id
                }
            }
            contributors = snap.contributors
            if currentWork == nil {
                currentWork = rankedQueue.first?.work
            }
            errorText = nil
        } catch {
            // Keep bundled CC0 works & lenses active offline
            errorText = nil
        }
        await cloudPass.refresh()
    }

    public func selectLens(_ lens: RadioLens) {
        selectedLensID = lens.id
        if let top = rankedQueue.first(where: { $0.work.isPlayable })?.work ?? rankedQueue.first?.work {
            play(top, autoStart: isPlaying)
        }
    }

    public func play(_ work: RadioWork, autoStart: Bool = true) {
        currentWork = work
        elapsedSec = 0
        durationSec = Double(work.durationSec ?? 180)

        var targetURL: URL?
        if let bmk = work.localBookmark {
            var stale = false
            #if os(macOS)
            targetURL = try? URL(resolvingBookmarkData: bmk, options: [.withSecurityScope], bookmarkDataIsStale: &stale)
            #else
            targetURL = try? URL(resolvingBookmarkData: bmk, options: [], bookmarkDataIsStale: &stale)
            #endif
            _ = targetURL?.startAccessingSecurityScopedResource()
        } else if let s = work.streamUrl, let u = URL(string: s) {
            targetURL = u
        }

        guard let url = targetURL else {
            isPlaying = false
            return
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if silentQA {
            player.isMuted = true
            player.volume = 0
        }
        if autoStart {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }

    public func togglePlay() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if player.currentItem == nil, let w = currentWork ?? rankedQueue.first?.work {
                play(w, autoStart: true)
            } else {
                if silentQA {
                    player.isMuted = true
                    player.volume = 0
                }
                player.play()
                isPlaying = true
            }
        }
    }

    public func skipNext() {
        let q = rankedQueue
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
            player.seek(to: .zero)
            elapsedSec = 0
            return
        }
        let q = rankedQueue
        guard !q.isEmpty else { return }
        if let cur = currentWork, let idx = q.firstIndex(where: { $0.work.workId == cur.workId }) {
            let prevIdx = (idx - 1 + q.count) % q.count
            play(q[prevIdx].work, autoStart: isPlaying)
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
                localBookmark: bmk
            )
            added.append(work)
        }
        if !added.isEmpty {
            localWorks.insert(contentsOf: added, at: 0)
            if let encoded = try? JSONEncoder().encode(localWorks) {
                defaults.set(encoded, forKey: "otr.localWorks")
            }
        }
    }

    public func saveSettings() {
        defaults.set(hubURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "otr.hubURL")
        defaults.set(homeServerURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "otr.homeServerURL")
        defaults.set(contributorIssuer.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "otr.contributorIssuer")
    }

    private func installTimeObserver() {
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
    }
}
