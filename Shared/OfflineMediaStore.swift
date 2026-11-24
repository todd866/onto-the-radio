import Foundation

public struct OfflineCatalogSnapshot: Codable, Sendable {
    public var homeWorks: [RadioWork]
    public var homeStations: [RadioLens]
    public var works: [RadioWork]
    public var lenses: [RadioLens]
    public var contributors: [ContributorReputation]
    public var savedAt: Date

    public init(
        homeWorks: [RadioWork],
        homeStations: [RadioLens],
        works: [RadioWork],
        lenses: [RadioLens],
        contributors: [ContributorReputation],
        savedAt: Date = Date()
    ) {
        self.homeWorks = homeWorks
        self.homeStations = homeStations
        self.works = works
        self.lenses = lenses
        self.contributors = contributors
        self.savedAt = savedAt
    }
}

/// Manages local offline audio, cover art, and catalog snapshots inside Documents/OfflineRadio.
public final class OfflineMediaStore: @unchecked Sendable {
    public static let shared = OfflineMediaStore()

    public let rootURL: URL
    public let audioDir: URL
    public let artDir: URL
    public let catalogURL: URL
    private let maxAudioBytes: Int64
    private let fm = FileManager.default
    private let lock = NSLock()

    public init(rootURL: URL? = nil, maxAudioBytes: Int64 = 1_500_000_000) {
        let base = rootURL ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineRadio", isDirectory: true)
        self.rootURL = base
        self.audioDir = base.appendingPathComponent("audio", isDirectory: true)
        self.artDir = base.appendingPathComponent("art", isDirectory: true)
        self.catalogURL = base.appendingPathComponent("catalog.json")
        self.maxAudioBytes = maxAudioBytes
        ensureDirectories()
    }

    private func ensureDirectories() {
        for dir in [rootURL, audioDir, artDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            excludeFromBackup(dir)
        }
    }

    private func excludeFromBackup(_ url: URL) {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutable.setResourceValues(values)
    }

    public func mediaKey(for work: RadioWork) -> String {
        var raw = work.workId
        if raw.hasPrefix("home:") {
            raw = String(raw.dropFirst("home:".count))
        } else if raw.hasPrefix("local:") {
            raw = String(raw.dropFirst("local:".count))
        }
        let cleaned = sanitizeKey(raw)
        if !cleaned.isEmpty { return cleaned }
        return stableHex(work.workId)
    }

    public func mediaKey(fromArtURL url: URL) -> String? {
        let comps = url.pathComponents
        if let idx = comps.firstIndex(of: "art"), idx + 1 < comps.count {
            let candidate = sanitizeKey(comps[idx + 1])
            return candidate.isEmpty ? nil : candidate
        }
        return nil
    }

    private func sanitizeKey(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(raw.unicodeScalars.filter { allowed.contains($0) })
    }

    private func stableHex(_ raw: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in raw.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }

    public func saveCatalog(_ snapshot: OfflineCatalogSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        ensureDirectories()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: catalogURL, options: .atomic)
        excludeFromBackup(catalogURL)
    }

    public func loadCatalog() -> OfflineCatalogSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: catalogURL) else { return nil }
        return try? JSONDecoder().decode(OfflineCatalogSnapshot.self, from: data)
    }

    public func localAudioURL(for work: RadioWork) -> URL? {
        let key = mediaKey(for: work)
        for ext in ["m4a", "mp3", "flac", "aac", "ogg"] {
            let cand = audioDir.appendingPathComponent("\(key).\(ext)")
            if fm.isReadableFile(atPath: cand.path) {
                return cand
            }
        }
        return nil
    }

    public func isAudioCached(_ work: RadioWork) -> Bool {
        localAudioURL(for: work) != nil
    }

    public func localArtURL(for work: RadioWork) -> URL? {
        artFileURL(forKey: mediaKey(for: work))
    }

    public func localArtURL(forRemoteURL url: URL) -> URL? {
        guard let key = mediaKey(fromArtURL: url) else { return nil }
        return artFileURL(forKey: key)
    }

    private func artFileURL(forKey key: String) -> URL? {
        guard !key.isEmpty else { return nil }
        for ext in ["jpg", "png", "jpeg"] {
            let cand = artDir.appendingPathComponent("\(key).\(ext)")
            if fm.isReadableFile(atPath: cand.path) {
                return cand
            }
        }
        return nil
    }

    @discardableResult
    public func saveAudio(_ data: Data, for work: RadioWork, ext: String = "m4a") -> URL? {
        guard !data.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        ensureDirectories()
        let key = mediaKey(for: work)
        let cleanExt = sanitizeKey(ext).lowercased()
        let finalExt = cleanExt.isEmpty ? "m4a" : cleanExt
        let dest = audioDir.appendingPathComponent("\(key).\(finalExt)")
        do {
            try data.write(to: dest, options: .atomic)
            excludeFromBackup(dest)
            trimAudioIfNeeded()
            return dest
        } catch {
            return nil
        }
    }

    @discardableResult
    public func saveArt(_ data: Data, for key: String) -> URL? {
        let cleanKey = sanitizeKey(key)
        guard !cleanKey.isEmpty, data.count > 16 else { return nil }
        lock.lock()
        defer { lock.unlock() }
        ensureDirectories()
        let isPNG = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
        let dest = artDir.appendingPathComponent("\(cleanKey).\(isPNG ? "png" : "jpg")")
        do {
            try data.write(to: dest, options: .atomic)
            excludeFromBackup(dest)
            return dest
        } catch {
            return nil
        }
    }

    public func stats() -> (trackCount: Int, totalBytes: Int64) {
        lock.lock()
        defer { lock.unlock() }
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let audioFiles = (try? fm.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        var count = 0
        var total: Int64 = 0
        for url in audioFiles {
            if let vals = try? url.resourceValues(forKeys: Set(keys)), vals.isRegularFile == true {
                count += 1
                total += Int64(vals.fileSize ?? 0)
            }
        }
        let artFiles = (try? fm.contentsOfDirectory(at: artDir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        for url in artFiles {
            if let vals = try? url.resourceValues(forKeys: Set(keys)), vals.isRegularFile == true {
                total += Int64(vals.fileSize ?? 0)
            }
        }
        return (count, total)
    }

    public func clearMedia() {
        lock.lock()
        defer { lock.unlock() }
        try? fm.removeItem(at: audioDir)
        try? fm.removeItem(at: artDir)
        ensureDirectories()
    }

    private func trimAudioIfNeeded() {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let urls = try? fm.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return
        }
        var items: [(url: URL, size: Int64, date: Date)] = []
        var total: Int64 = 0
        for url in urls {
            guard let vals = try? url.resourceValues(forKeys: Set(keys)), vals.isRegularFile == true else { continue }
            let sz = Int64(vals.fileSize ?? 0)
            let dt = vals.contentModificationDate ?? .distantPast
            total += sz
            items.append((url, sz, dt))
        }
        guard total > maxAudioBytes else { return }
        items.sort { $0.date < $1.date }
        for item in items {
            if total <= maxAudioBytes { break }
            if (try? fm.removeItem(at: item.url)) != nil {
                total -= item.size
            }
        }
    }
}
