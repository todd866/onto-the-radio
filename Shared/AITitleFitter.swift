import Foundation
#if canImport(FoundationModels) && !os(tvOS)
import FoundationModels
#endif

public enum AITitleFitter {
    /// Deterministic, instant editorial title shortener that guarantees `result.count <= maxChars`
    /// and never produces ellipses (`...` or `…`).
    public static func heuristicFit(_ rawTitle: String, maxChars: Int) -> String {
        let budget = max(6, maxChars)
        var s = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count <= budget && !s.contains("...") && !s.contains("…") {
            return s
        }

        // 1. Remove parenthetical and bracketed subtitles: (Lent et douloureux), [Remastered], etc.
        s = s.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*[\)\]]"#, with: "", options: .regularExpression)
        // 2. Remove leading track numbers ("03 - Title" or "01. Title")
        s = s.replacingOccurrences(of: #"^\d{1,2}\s*[-–.]\s+"#, with: "", options: .regularExpression)
        // 3. Remove trailing mix / remaster / featured suffixes
        s = s.replacingOccurrences(of: #"\s+[-–]\s+(?:Remaster(?:ed)?|Live|Radio Edit|Deluxe|Explicit|Bonus Track).*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"\s+(?:feat\.|ft\.)\s+.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        // 4. Remove classical key / catalog bloat when over budget
        if s.count > budget {
            s = s.replacingOccurrences(of: #",?\s+\bin\s+[A-G](?:[#b]|-flat|-sharp)?\s+(?:Major|Minor)\b"#, with: "", options: [.regularExpression, .caseInsensitive])
        }
        if s.count > budget {
            s = s.replacingOccurrences(of: #",?\s+\b(?:BWV|Op\.|K\.|Hob\.|D\.)\s*\d+[a-zA-Z]?\b"#, with: "", options: [.regularExpression, .caseInsensitive])
        }
        if s.count > budget, let colonIdx = s.firstIndex(of: ":"), colonIdx > s.startIndex {
            let tail = s[s.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
            let head = s[..<colonIdx].trimmingCharacters(in: .whitespaces)
            if head.count >= 6 && head.count <= budget {
                s = head
            } else if !tail.isEmpty && tail.count <= budget {
                s = tail
            }
        }

        s = normalizeSpacesAndTrim(s)
        if s.count <= budget {
            return s
        }

        // 5. Drop from comma or dash clause if the main phrase fits cleanly
        for sep in [" — ", " – ", " - ", ", "] {
            if let range = s.range(of: sep) {
                let candidate = normalizeSpacesAndTrim(String(s[..<range.lowerBound]))
                if candidate.count >= 5 && candidate.count <= budget {
                    return candidate
                }
            }
        }

        // 6. Clean word-boundary trim (dropping dangling connectors & punctuation, never "...")
        var words = s.split(separator: " ").map(String.init)
        while words.count > 1 && words.joined(separator: " ").count > budget {
            words.removeLast()
            while let last = words.last,
                  ["of", "the", "and", "or", "in", "on", "to", "a", "for", "&", "-", "–", ":"].contains(last.lowercased()),
                  words.count > 1 {
                words.removeLast()
            }
        }
        var joined = normalizeSpacesAndTrim(words.joined(separator: " "))
        while let lastChar = joined.last, [",", ":", ";", "-", "–", "—", "."].contains(String(lastChar)), joined.count > 1 {
            joined.removeLast()
        }
        joined = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        if joined.count <= budget && !joined.isEmpty {
            return joined
        }
        return String(joined.prefix(budget)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Formats an artist + editorial hook subtitle within `maxChars` without ever emitting ellipses.
    public static func compactSubtitle(creator: String, hook: String?, maxChars: Int) -> String {
        let budget = max(6, maxChars)
        var artist = normalizeSpacesAndTrim(creator)
        let replacements: [(String, String)] = [
            ("Johann Sebastian Bach", "J. S. Bach"),
            ("Modest Mussorgsky", "Mussorgsky"),
            ("Sergei Prokofiev", "Prokofiev"),
            ("Claude Debussy", "Debussy"),
            ("Antonio Vivaldi", "Vivaldi"),
            ("Gustav Holst", "Holst"),
            ("Ludwig van Beethoven", "Beethoven"),
        ]
        for (full, compact) in replacements {
            artist = artist.replacingOccurrences(of: full, with: compact)
        }
        let cleanHook = hook.map { normalizeSpacesAndTrim($0) } ?? ""
        if !cleanHook.isEmpty {
            let fullLine = "\(artist) · \(cleanHook)"
            if fullLine.count <= budget {
                return fullLine
            }
            if let surname = artist.split(separator: " ").last.map(String.init),
               surname != artist {
                let compactLine = "\(surname) · \(cleanHook)"
                if compactLine.count <= budget {
                    return compactLine
                }
            }
            return heuristicFit(cleanHook, maxChars: budget)
        }
        return heuristicFit(artist, maxChars: budget)
    }

    /// Uses Apple on-device FoundationModels (iOS/macOS 26+) when available to compress
    /// an overly long track title naturally into `maxChars` without ellipses.
    public static func aiRewriteIfAvailable(_ rawTitle: String, maxChars: Int) async -> String? {
        #if canImport(FoundationModels) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else { return nil }
            let cleanInput = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanInput.isEmpty else { return nil }
            let prompt = """
            Rewrite the music track title below so it is at most \(maxChars) characters long and fits cleanly in a mobile player UI.
            Rules:
            - Return ONLY the rewritten title, nothing else.
            - No quotation marks, no explanations, and NEVER use "..." or "…".
            - Preserve the core recognizable name cleanly (for classical/jazz, omit catalog numbers or movement keys if needed).
            Title: \(cleanInput)
            """
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                let candidate = response.content
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”`")))
                    .replacingOccurrences(of: "...", with: "")
                    .replacingOccurrences(of: "…", with: "")
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !candidate.isEmpty && candidate.count <= maxChars {
                    return candidate
                }
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    private static func normalizeSpacesAndTrim(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "...", with: "")
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
