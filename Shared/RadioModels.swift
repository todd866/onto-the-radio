import Foundation

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

    public var id: String { workId }

    public var isPlayable: Bool {
        localBookmark != nil || (streamUrl != nil && !(streamUrl ?? "").isEmpty)
    }
}

public struct RadioLensAnchor: Codable, Equatable, Sendable {
    public var workId: String
    public var weight: Double
    public var mark: String?
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
        maxHeaviness: Double
    ) -> [RankedRadioTrack] {
        let filtered = tracks.filter { track in
            let e = track.energy ?? 0.35
            let h = track.heaviness ?? 0.30
            return e <= maxEnergy + 0.001 && h <= maxHeaviness + 0.001
        }
        let pool = filtered.isEmpty ? tracks : filtered
        guard let lens else {
            return pool.map { RankedRadioTrack(work: $0, score: 0.85) }
        }

        let byId = Dictionary(uniqueKeysWithValues: tracks.map { ($0.workId, $0) })
        let anchorVecs: [(vec: [Int], weight: Double, id: String)] = lens.anchors.compactMap { anc in
            guard let w = byId[anc.workId], let v = w.vec32, !v.isEmpty else {
                return ([], anc.weight, anc.workId)
            }
            return (v, anc.weight, anc.workId)
        }

        return pool.map { cand in
            if let direct = lens.anchors.first(where: { $0.workId == cand.workId }) {
                return RankedRadioTrack(work: cand, score: min(1.0, 0.88 + direct.weight * 0.12))
            }
            guard let cv = cand.vec32, !cv.isEmpty else {
                // Local user-imported files without cloud vectors yet receive neutral inclusion
                return RankedRadioTrack(work: cand, score: 0.62)
            }
            var sum = 0.0
            var wt = 0.0
            var best = 0.0
            for anc in anchorVecs where !anc.vec.isEmpty {
                let s = max(0, cosine(anc.vec, cv))
                sum += s * anc.weight
                wt += anc.weight
                if s > best { best = s }
            }
            let combined = (wt > 0 ? (sum / wt) * 0.7 + best * 0.3 : 0.5)
            return RankedRadioTrack(work: cand, score: max(0.05, min(1.0, combined)))
        }
        .sorted { a, b in
            if a.work.isPlayable != b.work.isPlayable {
                return a.work.isPlayable && !b.work.isPlayable
            }
            return a.score > b.score
        }
    }
}
