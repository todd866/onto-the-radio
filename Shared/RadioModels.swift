import Foundation

public struct RadioNeighbour: Codable, Equatable, Sendable {
    public var workId: String
    public var sim: Double

    public init(workId: String, sim: Double) {
        self.workId = workId
        self.sim = sim
    }
}

public struct RadioResonance: Codable, Equatable, Sendable {
    public var workId: String
    public var domain: String
    public var sim: Double

    public init(workId: String, domain: String, sim: Double) {
        self.workId = workId
        self.domain = domain
        self.sim = sim
    }
}

public struct RadioWork: Identifiable, Codable, Equatable, Sendable {
    public var workId: String
    public var title: String
    public var creator: String
    public var year: Int
    public var kind: String
    public var summary: String
    public var energy: Double?
    public var heaviness: Double?
    public var streamUrl: String?
    public var durationSec: Int?
    public var vec32: [Int]?
    public var localBookmark: Data?
    public var x: Double?
    public var y: Double?
    public var neighbours: [RadioNeighbour]?
    public var resonances: [RadioResonance]?
    public var artUrl: String?
    public var colorHex: String?
    public var sourceLabel: String?
    public var pickToken: String?
    public var localArtData: Data?

    public init(
        workId: String,
        title: String,
        creator: String,
        year: Int,
        kind: String,
        summary: String,
        energy: Double? = nil,
        heaviness: Double? = nil,
        streamUrl: String? = nil,
        durationSec: Int? = nil,
        vec32: [Int]? = nil,
        localBookmark: Data? = nil,
        x: Double? = nil,
        y: Double? = nil,
        neighbours: [RadioNeighbour]? = nil,
        resonances: [RadioResonance]? = nil,
        artUrl: String? = nil,
        colorHex: String? = nil,
        sourceLabel: String? = nil,
        pickToken: String? = nil,
        localArtData: Data? = nil
    ) {
        self.workId = workId
        self.title = title
        self.creator = creator
        self.year = year
        self.kind = kind
        self.summary = summary
        self.energy = energy
        self.heaviness = heaviness
        self.streamUrl = streamUrl
        self.durationSec = durationSec
        self.vec32 = vec32
        self.localBookmark = localBookmark
        self.x = x
        self.y = y
        self.neighbours = neighbours
        self.resonances = resonances
        self.artUrl = artUrl
        self.colorHex = colorHex
        self.sourceLabel = sourceLabel
        self.pickToken = pickToken
        self.localArtData = localArtData
    }

    public var id: String { workId }

    public var isPlayable: Bool {
        localBookmark != nil || (streamUrl != nil && !(streamUrl ?? "").isEmpty)
    }

    public var originBadge: String {
        if let sourceLabel, !sourceLabel.isEmpty { return sourceLabel }
        if localBookmark != nil { return "Local" }
        if isPlayable { return "CC0" }
        return "Pool"
    }
}

public enum RadioMoodPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All"
    case chill = "Chill"
    case late = "Late"
    case focus = "Focus"
    case pulse = "Pulse"
    case high = "High"

    public var id: String { rawValue }

    public var maxEnergy: Double {
        switch self {
        case .all: return 1.0
        case .chill: return 0.30
        case .late: return 0.48
        case .focus: return 0.58
        case .pulse: return 0.85
        case .high: return 1.0
        }
    }

    public var maxHeaviness: Double {
        switch self {
        case .all: return 1.0
        case .chill: return 0.25
        case .late: return 0.40
        case .focus: return 0.35
        case .pulse: return 0.72
        case .high: return 1.0
        }
    }

    public var prefersHigherEnergy: Bool {
        self == .high || self == .pulse
    }
}

public struct RadioLensAnchor: Codable, Equatable, Sendable {
    public var workId: String
    public var weight: Double
    public var mark: String?

    public init(workId: String, weight: Double, mark: String? = nil) {
        self.workId = workId
        self.weight = weight
        self.mark = mark
    }
}

public struct RadioLens: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var domain: String
    public var name: String
    public var summary: String
    public var issuer: String
    public var issuerHandle: String
    public var modelId: String
    public var subscribers: Int?
    public var completionRate: Double?
    public var anchors: [RadioLensAnchor]
    public var signatureValid: Bool?
    public var colorHex: String?
    public var artUrl: String?

    public init(
        id: String,
        domain: String,
        name: String,
        summary: String,
        issuer: String,
        issuerHandle: String,
        modelId: String,
        subscribers: Int? = nil,
        completionRate: Double? = nil,
        anchors: [RadioLensAnchor],
        signatureValid: Bool? = nil,
        colorHex: String? = nil,
        artUrl: String? = nil
    ) {
        self.id = id
        self.domain = domain
        self.name = name
        self.summary = summary
        self.issuer = issuer
        self.issuerHandle = issuerHandle
        self.modelId = modelId
        self.subscribers = subscribers
        self.completionRate = completionRate
        self.anchors = anchors
        self.signatureValid = signatureValid
        self.colorHex = colorHex
        self.artUrl = artUrl
    }
}

public struct RankedRadioTrack: Identifiable, Equatable, Sendable {
    public var work: RadioWork
    public var score: Double

    public var id: String { work.workId }
}

public struct ContributorReputation: Identifiable, Codable, Equatable, Sendable {
    public var issuer: String
    public var handle: String
    public var tier: String
    public var trust: Double
    public var verifiedVectors: Int
    public var meanCanaryCosine: Double
    public var credits: Int

    public var id: String { issuer }
}

public enum RadioMath {
    public static func cosine(_ a: [Int], _ b: [Int]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var dot = 0.0
        var na = 0.0
        var nb = 0.0
        for i in 0..<n {
            let va = Double(a[i])
            let vb = Double(b[i])
            dot += va * vb
            na += va * va
            nb += vb * vb
        }
        let den = na.squareRoot() * nb.squareRoot()
        return den > 0 ? dot / den : 0
    }

    public static func rankTracks(
        tracks: [RadioWork],
        lens: RadioLens?,
        maxEnergy: Double,
        maxHeaviness: Double,
        likedIDs: Set<String> = [],
        dislikedIDs: Set<String> = [],
        mapTarget: (x: Double, y: Double)? = nil,
        preferHighEnergy: Bool = false
    ) -> [RankedRadioTrack] {
        let filtered = tracks.filter { track in
            let e = track.energy ?? 0.35
            let h = track.heaviness ?? 0.30
            return e <= maxEnergy + 0.001 && h <= maxHeaviness + 0.001
        }
        let pool = filtered.isEmpty ? tracks : filtered
        let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.workId, $0) })

        let anchorVecs: [(vec: [Int], weight: Double, id: String)] = (lens?.anchors ?? []).compactMap { anc in
            guard let w = byId[anc.workId], let v = w.vec32, !v.isEmpty else {
                return ([], anc.weight, anc.workId)
            }
            return (v, anc.weight, anc.workId)
        }
        let likedVecs: [[Int]] = likedIDs.compactMap { id in
            guard let v = byId[id]?.vec32, !v.isEmpty else { return nil }
            return v
        }
        let dislikedVecs: [[Int]] = dislikedIDs.compactMap { id in
            guard let v = byId[id]?.vec32, !v.isEmpty else { return nil }
            return v
        }

        return pool.map { cand in
            var baseScore = 0.72
            if let lens {
                if let direct = lens.anchors.first(where: { $0.workId == cand.workId }) {
                    baseScore = min(1.0, 0.88 + direct.weight * 0.12)
                } else if let cv = cand.vec32, !cv.isEmpty {
                    var sum = 0.0
                    var wt = 0.0
                    var best = 0.0
                    for anc in anchorVecs where !anc.vec.isEmpty {
                        let s = max(0, cosine(anc.vec, cv))
                        sum += s * anc.weight
                        wt += anc.weight
                        if s > best { best = s }
                    }
                    baseScore = wt > 0 ? (sum / wt) * 0.7 + best * 0.3 : 0.55
                } else {
                    baseScore = 0.64
                }
            }

            var adjusted = baseScore

            if likedIDs.contains(cand.workId) {
                adjusted += 0.16
            } else if let cv = cand.vec32, !cv.isEmpty, !likedVecs.isEmpty {
                let bestLike = likedVecs.map { max(0, cosine($0, cv)) }.max() ?? 0
                adjusted += bestLike * 0.14
            }

            if dislikedIDs.contains(cand.workId) {
                adjusted -= 0.55
            } else if let cv = cand.vec32, !cv.isEmpty, !dislikedVecs.isEmpty {
                let bestDislike = dislikedVecs.map { max(0, cosine($0, cv)) }.max() ?? 0
                if bestDislike > 0.65 {
                    adjusted -= (bestDislike - 0.65) * 0.45
                }
            }

            if let target = mapTarget, let cx = cand.x, let cy = cand.y {
                let dx = cx - target.x
                let dy = cy - target.y
                let dist = (dx * dx + dy * dy).squareRoot()
                let prox = max(0, 1.0 - dist / 1.414)
                adjusted = adjusted * 0.35 + prox * 0.65
            }

            if preferHighEnergy {
                adjusted += (cand.energy ?? 0.35) * 0.14
            }

            return RankedRadioTrack(work: cand, score: max(0.02, min(1.0, adjusted)))
        }
        .sorted { a, b in
            if a.work.isPlayable != b.work.isPlayable {
                return a.work.isPlayable && !b.work.isPlayable
            }
            return a.score > b.score
        }
    }
}
