import Foundation
import SwiftUI

public struct RadioRGB: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public var color: Color {
        Color(red: r, green: g, blue: b)
    }

    public func blended(into base: RadioRGB, amount: Double) -> Color {
        let t = min(1, max(0, amount))
        return Color(
            red: base.r * (1 - t) + r * t,
            green: base.g * (1 - t) + g * t,
            blue: base.b * (1 - t) + b * t
        )
    }
}

public struct RadioPalette: Sendable {
    public var bgRGB: RadioRGB
    public var bg: Color
    public var panel: Color
    public var panelElevated: Color
    public var ink: Color
    public var ink2: Color
    public var ink3: Color
    public var line: Color
    public var signal: Color
    public var signalInk: Color
    public var good: Color
    public var bad: Color

    public static let light = RadioPalette(
        bgRGB: RadioRGB(r: 0.949, g: 0.929, b: 0.890),          // #F2EDE3
        bg: Color(red: 0.949, green: 0.929, blue: 0.890),
        panel: Color(red: 0.914, green: 0.890, blue: 0.839),     // #E9E3D6
        panelElevated: Color(red: 0.878, green: 0.851, blue: 0.796),
        ink: Color(red: 0.090, green: 0.078, blue: 0.059),       // #17140F
        ink2: Color(red: 0.353, green: 0.322, blue: 0.278),      // #5A5247
        ink3: Color(red: 0.541, green: 0.506, blue: 0.455),      // #8A8174
        line: Color(red: 0.839, green: 0.808, blue: 0.749),      // #D6CEBF
        signal: Color(red: 0.725, green: 0.282, blue: 0.122),    // #B9481F
        signalInk: Color(red: 0.980, green: 0.965, blue: 0.940), // #FAF6F0
        good: Color(red: 0.184, green: 0.490, blue: 0.310),      // #2F7D4F
        bad: Color(red: 0.698, green: 0.227, blue: 0.227)        // #B23A3A
    )

    public static let dark = RadioPalette(
        bgRGB: RadioRGB(r: 0.063, g: 0.059, b: 0.051),          // #100F0D
        bg: Color(red: 0.063, green: 0.059, blue: 0.051),
        panel: Color(red: 0.102, green: 0.094, blue: 0.082),     // #1A1815
        panelElevated: Color(red: 0.145, green: 0.133, blue: 0.118),
        ink: Color(red: 0.937, green: 0.910, blue: 0.855),       // #EFE8DA
        ink2: Color(red: 0.702, green: 0.667, blue: 0.604),      // #B3AA9A
        ink3: Color(red: 0.490, green: 0.459, blue: 0.408),      // #7D7568
        line: Color(red: 0.173, green: 0.161, blue: 0.141),      // #2C2924
        signal: Color(red: 0.910, green: 0.690, blue: 0.290),    // #E8B04A
        signalInk: Color(red: 0.063, green: 0.059, blue: 0.051), // #100F0D
        good: Color(red: 0.424, green: 0.769, blue: 0.553),      // #6CC48D
        bad: Color(red: 0.906, green: 0.455, blue: 0.435)        // #E7746F
    )

    public static func forScheme(_ scheme: ColorScheme) -> RadioPalette {
        scheme == .dark ? dark : light
    }

    public func tintedCanvas(rgb: RadioRGB, scheme: ColorScheme) -> Color {
        rgb.blended(into: bgRGB, amount: scheme == .dark ? 0.20 : 0.11)
    }
}

public struct SleeveColorPair: Equatable, Sendable {
    public var ground: RadioRGB
    public var accent: RadioRGB
    public var highlight: RadioRGB
}

public enum RadioSwatches {
    private static let editorialTriads: [SleeveColorPair] = [
        // 0: Ochre gold / espresso ink / warm linen
        SleeveColorPair(
            ground: RadioRGB(r: 0.580, g: 0.408, b: 0.165),
            accent: RadioRGB(r: 0.145, g: 0.125, b: 0.106),
            highlight: RadioRGB(r: 0.937, g: 0.898, b: 0.824)
        ),
        // 1: Deep slate navy / dusty sand / vermilion
        SleeveColorPair(
            ground: RadioRGB(r: 0.145, g: 0.188, b: 0.267),
            accent: RadioRGB(r: 0.835, g: 0.776, b: 0.678),
            highlight: RadioRGB(r: 0.769, g: 0.286, b: 0.169)
        ),
        // 2: Terracotta clay / matte charcoal / warm bone
        SleeveColorPair(
            ground: RadioRGB(r: 0.694, g: 0.275, b: 0.165),
            accent: RadioRGB(r: 0.122, g: 0.110, b: 0.098),
            highlight: RadioRGB(r: 0.945, g: 0.910, b: 0.847)
        ),
        // 3: Deep moss / olive sage / sunlit brass
        SleeveColorPair(
            ground: RadioRGB(r: 0.169, g: 0.282, b: 0.247),
            accent: RadioRGB(r: 0.467, g: 0.569, b: 0.486),
            highlight: RadioRGB(r: 0.886, g: 0.706, b: 0.349)
        ),
        // 4: Espresso umber / burnt amber / pale cream
        SleeveColorPair(
            ground: RadioRGB(r: 0.255, g: 0.192, b: 0.165),
            accent: RadioRGB(r: 0.796, g: 0.459, b: 0.200),
            highlight: RadioRGB(r: 0.933, g: 0.894, b: 0.831)
        ),
        // 5: Oxide burgundy / blush sandstone / obsidian
        SleeveColorPair(
            ground: RadioRGB(r: 0.486, g: 0.184, b: 0.204),
            accent: RadioRGB(r: 0.859, g: 0.722, b: 0.659),
            highlight: RadioRGB(r: 0.118, g: 0.098, b: 0.094)
        ),
        // 6: Cobalt ink / mineral cyan / parchment
        SleeveColorPair(
            ground: RadioRGB(r: 0.173, g: 0.278, b: 0.388),
            accent: RadioRGB(r: 0.396, g: 0.620, b: 0.678),
            highlight: RadioRGB(r: 0.945, g: 0.922, b: 0.875)
        ),
        // 7: Matte walnut / soft terracotta / parchment
        SleeveColorPair(
            ground: RadioRGB(r: 0.333, g: 0.294, b: 0.239),
            accent: RadioRGB(r: 0.745, g: 0.380, b: 0.255),
            highlight: RadioRGB(r: 0.925, g: 0.886, b: 0.808)
        ),
    ]

    public static func hashSeed(_ seed: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for b in seed.utf8 {
            hash ^= UInt64(b)
            hash = hash &* 1099511628211
        }
        return hash
    }

    public static func sleeveTriad(for seed: String, colorOverride: String? = nil) -> SleeveColorPair {
        let baseIdx: Int
        switch seed {
        case "lens:radio:late-wire": baseIdx = 1
        case "lens:radio:motorik-pulse": baseIdx = 2
        case "lens:radio:chamber-focus": baseIdx = 0
        default:
            baseIdx = Int(hashSeed(seed) % UInt64(editorialTriads.count))
        }
        var triad = editorialTriads[baseIdx]
        if let parsed = parseColorRGB(colorOverride) {
            triad.ground = parsed
        }
        return triad
    }

    public static func sleeveRGB(for seed: String, colorOverride: String? = nil) -> RadioRGB {
        sleeveTriad(for: seed, colorOverride: colorOverride).ground
    }

    public static func parseColorRGB(_ raw: String?) -> RadioRGB? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") {
            let hex = String(s.dropFirst())
            guard hex.count == 6, let val = UInt32(hex, radix: 16) else { return nil }
            let r = Double((val >> 16) & 0xff) / 255.0
            let g = Double((val >> 8) & 0xff) / 255.0
            let b = Double(val & 0xff) / 255.0
            return RadioRGB(r: r, g: g, b: b)
        }
        if s.lowercased().hasPrefix("hsl("), s.hasSuffix(")") {
            let inner = s.dropFirst(4).dropLast()
            let parts = inner
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "%", with: "")
                .split(whereSeparator: { $0.isWhitespace })
                .compactMap { Double($0) }
            guard parts.count >= 3 else { return nil }
            return hslToRGB(h: parts[0], s: parts[1] / 100.0, l: parts[2] / 100.0)
        }
        return nil
    }

    private static func hslToRGB(h: Double, s: Double, l: Double) -> RadioRGB {
        let hue = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360.0
        let sat = min(1, max(0, s))
        let lig = min(1, max(0, l))
        if sat == 0 {
            return RadioRGB(r: lig, g: lig, b: lig)
        }
        let q = lig < 0.5 ? lig * (1 + sat) : lig + sat - lig * sat
        let p = 2 * lig - q
        func component(_ tIn: Double) -> Double {
            var t = tIn
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6.0 { return p + (q - p) * 6.0 * t }
            if t < 1.0 / 2.0 { return q }
            if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6.0 }
            return p
        }
        return RadioRGB(
            r: component(hue + 1.0 / 3.0),
            g: component(hue),
            b: component(hue - 1.0 / 3.0)
        )
    }
}

/// Pure-visual modernist album or station cover. Tracks display zero text inside artwork;
/// stations optionally carry a single bottom-left wordmark.
public struct RadioCoverArt: View {
    public var seed: String
    public var colorOverride: String?
    public var artURL: URL?
    public var localArtData: Data?
    public var stationTitle: String?
    public var energy: Double
    public var size: CGFloat
    public var cornerRadius: CGFloat
    public var isActive: Bool

    @Environment(\.colorScheme) private var scheme

    public init(
        seed: String,
        colorOverride: String? = nil,
        artURL: URL? = nil,
        localArtData: Data? = nil,
        stationTitle: String? = nil,
        energy: Double = 0.35,
        size: CGFloat,
        cornerRadius: CGFloat? = nil,
        isActive: Bool = false
    ) {
        self.seed = seed
        self.colorOverride = colorOverride
        self.artURL = artURL
        self.localArtData = localArtData
        self.stationTitle = stationTitle
        self.energy = energy
        self.size = size
        self.cornerRadius = cornerRadius ?? (size <= 56 ? 6 : 10)
        self.isActive = isActive
    }

    public var body: some View {
        let pal = RadioPalette.forScheme(scheme)
        let triad = RadioSwatches.sleeveTriad(for: seed, colorOverride: colorOverride)
        let h = RadioSwatches.hashSeed(seed)
        let motif = Int((h >> 8) % 4)
        let flip = ((h >> 16) & 1) == 1

        ZStack(alignment: .bottomLeading) {
            triad.ground.color

            GeometryReader { geo in
                let w = geo.size.width
                let hgt = geo.size.height

                switch motif {
                case 0:
                    // Concentric Vinyl Disc
                    let outerD = w * 1.04
                    let cx = flip ? w * 0.62 : w * 0.38
                    let cy = flip ? hgt * 0.42 : hgt * 0.56
                    ZStack {
                        Circle()
                            .fill(triad.accent.color.opacity(0.92))
                            .frame(width: outerD, height: outerD)
                        ForEach([0.76, 0.56, 0.38], id: \.self) { step in
                            Circle()
                                .strokeBorder(triad.highlight.color.opacity(0.28), lineWidth: max(0.75, w * 0.008))
                                .frame(width: outerD * step, height: outerD * step)
                        }
                        Circle()
                            .fill(triad.highlight.color)
                            .frame(width: outerD * 0.24, height: outerD * 0.24)
                        Circle()
                            .fill(triad.ground.color)
                            .frame(width: outerD * 0.07, height: outerD * 0.07)
                    }
                    .position(x: cx, y: cy)

                case 1:
                    // Bauhaus Architectural Split
                    let blockW = w * 0.44
                    let blockX = flip ? w - blockW * 0.5 : blockW * 0.5
                    let circD = w * 0.68
                    let cx = flip ? w * 0.42 : w * 0.58
                    let cy = hgt * 0.44
                    ZStack {
                        Rectangle()
                            .fill(triad.accent.color.opacity(0.90))
                            .frame(width: blockW, height: hgt)
                            .position(x: blockX, y: hgt * 0.5)
                        Circle()
                            .fill(triad.highlight.color.opacity(0.95))
                            .frame(width: circD, height: circD)
                            .position(x: cx, y: cy)
                        Rectangle()
                            .fill(triad.ground.color.opacity(0.88))
                            .frame(width: w, height: max(3, hgt * 0.05))
                            .position(x: w * 0.5, y: hgt * 0.74)
                    }

                case 2:
                    // Harmonic Strata
                    let bands = 5
                    let bandH = hgt * 0.075
                    let gap = hgt * 0.045
                    let totalH = CGFloat(bands) * bandH + CGFloat(bands - 1) * gap
                    let startY = (hgt - totalH) * 0.58
                    let dotD = w * 0.20
                    let dx = flip ? w * 0.22 : w * 0.78
                    ZStack(alignment: .topLeading) {
                        Circle()
                            .fill(triad.highlight.color)
                            .frame(width: dotD, height: dotD)
                            .position(x: dx, y: hgt * 0.20)
                        ForEach(0..<bands, id: \.self) { i in
                            let frac = 0.42 + 0.46 * ((Double((h >> (i * 5)) & 0xff) / 255.0) * 0.6 + energy * 0.4)
                            let bw = w * min(0.88, frac)
                            let bx = flip ? (w - bw - w * 0.10) : w * 0.10
                            let by = startY + CGFloat(i) * (bandH + gap)
                            RoundedRectangle(cornerRadius: bandH * 0.3, style: .continuous)
                                .fill(i == bands - 1 ? triad.highlight.color : triad.accent.color.opacity(0.88))
                                .frame(width: bw, height: bandH)
                                .position(x: bx + bw * 0.5, y: by + bandH * 0.5)
                        }
                    }

                default:
                    // Orbital Field
                    let d1 = w * 0.72
                    let d2 = w * 0.56
                    let c1x = flip ? w * 0.42 : w * 0.58
                    let c1y = hgt * 0.40
                    let c2x = flip ? w * 0.62 : w * 0.36
                    let c2y = hgt * 0.60
                    let ringD = w * 0.88
                    ZStack {
                        Circle()
                            .fill(triad.accent.color.opacity(0.88))
                            .frame(width: d1, height: d1)
                            .position(x: c1x, y: c1y)
                        Circle()
                            .fill(triad.highlight.color.opacity(0.90))
                            .frame(width: d2, height: d2)
                            .position(x: c2x, y: c2y)
                        Circle()
                            .strokeBorder(triad.highlight.color.opacity(0.42), lineWidth: max(0.8, w * 0.01))
                            .frame(width: ringD, height: ringD)
                            .position(x: w * 0.5, y: hgt * 0.5)
                    }
                }
            }

            if let data = localArtData, let localImg = decodeLocalImage(data) {
                localImg
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else if let artURL {
                CookieArtworkImage(url: artURL)
                    .frame(width: size, height: size)
                    .clipped()
            }

            if let stationTitle, !stationTitle.isEmpty, size >= 90 {
                Text(stationTitle)
                    .font(.system(size: min(17, max(13, size * 0.11)), weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.980, green: 0.965, blue: 0.933))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.07, green: 0.06, blue: 0.05).opacity(0.72))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(isActive ? pal.signal : Color.black.opacity(0.10), lineWidth: isActive ? 2.0 : 0.6)
        }
        .accessibilityHidden(true)
    }

    private func decodeLocalImage(_ data: Data) -> Image? {
        #if os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #else
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #endif
    }
}

private struct CookieArtworkImage: View {
    let url: URL
    @State private var loadedImage: Image?

    var body: some View {
        Group {
            if let loadedImage {
                loadedImage
                    .resizable()
                    .scaledToFill()
            }
        }
        .task(id: url) {
            loadedImage = await ArtworkFetchCache.shared.image(for: url)
        }
    }
}

private actor ArtworkFetchCache {
    static let shared = ArtworkFetchCache()
    private var memory: [URL: Image] = [:]

    func image(for url: URL) async -> Image? {
        if let hit = memory[url] { return hit }
        var req = URLRequest(url: url)
        req.setValue("OntoTheRadio/1.0 (https://github.com/todd866/onto-the-radio)", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return nil
        }
        guard let img = decodeImage(from: data) else { return nil }
        if memory.count > 120 { memory.removeAll() }
        memory[url] = img
        return img
    }

    private func decodeImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #else
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #endif
    }
}

public struct LatentMapCanvas: View {
    public var works: [RadioWork]
    public var currentWork: RadioWork?
    public var trail: [RadioWork]
    public var activeLens: RadioLens?
    public var mapTarget: (x: Double, y: Double)?
    public var onTune: ((Double, Double) -> Void)?

    @Environment(\.colorScheme) private var scheme

    public init(
        works: [RadioWork],
        currentWork: RadioWork?,
        trail: [RadioWork],
        activeLens: RadioLens?,
        mapTarget: (x: Double, y: Double)? = nil,
        onTune: ((Double, Double) -> Void)? = nil
    ) {
        self.works = works
        self.currentWork = currentWork
        self.trail = trail
        self.activeLens = activeLens
        self.mapTarget = mapTarget
        self.onTune = onTune
    }

    public static let regionColors: [Color] = [
        Color(red: 0.239, green: 0.482, blue: 0.851), // Dance / energetic blue
        Color(red: 0.851, green: 0.533, blue: 0.239), // Alt / ochre
        Color(red: 0.788, green: 0.310, blue: 0.427), // Deep / nocturnal rose
        Color(red: 0.239, green: 0.659, blue: 0.561), // Chill / ambient teal
    ]

    public var body: some View {
        let pal = RadioPalette.forScheme(scheme)
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let pad: CGFloat = 18

            Canvas { ctx, size in
                let mapW = max(1, size.width - pad * 2)
                let mapH = max(1, size.height - pad * 2)
                func pt(_ x: Double, _ y: Double) -> CGPoint {
                    let nx = (min(1, max(-1, x)) + 1) * 0.5
                    let ny = (1 - min(1, max(-1, y))) * 0.5
                    return CGPoint(x: pad + nx * mapW, y: pad + ny * mapH)
                }

                var axes = Path()
                axes.move(to: CGPoint(x: pad, y: size.height / 2))
                axes.addLine(to: CGPoint(x: size.width - pad, y: size.height / 2))
                axes.move(to: CGPoint(x: size.width / 2, y: pad))
                axes.addLine(to: CGPoint(x: size.width / 2, y: size.height - pad))
                ctx.stroke(axes, with: .color(pal.line.opacity(0.65)), lineWidth: 0.6)

                let labels: [(String, Double, Double)] = [
                    ("Chamber", -0.78, 0.78),
                    ("Ambient", -0.20, 0.44),
                    ("Motorik", 0.34, 0.56),
                    ("Club", 0.56, -0.58),
                    ("Nocturne", -0.44, -0.78),
                ]
                for (text, lx, ly) in labels {
                    let p = pt(lx, ly)
                    ctx.draw(
                        Text(text)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(pal.ink3),
                        at: p
                    )
                }

                let plotted = works.filter { $0.x != nil && $0.y != nil }
                let anchorIDs = Set(activeLens?.anchors.map(\.workId) ?? [])

                for item in plotted {
                    guard let ix = item.x, let iy = item.y else { continue }
                    let c = pt(ix, iy)
                    let regIdx = quadrantColorIndex(for: item)
                    let col = Self.regionColors[regIdx]
                    let r: CGFloat = item.isPlayable ? 4.5 : 3.0
                    let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(item.isPlayable ? col : col.opacity(0.45)))
                    if anchorIDs.contains(item.workId) {
                        let ar: CGFloat = 7.0
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: c.x - ar, y: c.y - ar, width: ar * 2, height: ar * 2)),
                            with: .color(pal.ink2.opacity(0.65)),
                            lineWidth: 1.0
                        )
                    }
                }

                let trailPoints = trail.compactMap { t -> CGPoint? in
                    guard let tx = t.x, let ty = t.y else { return nil }
                    return pt(tx, ty)
                }
                if trailPoints.count >= 2 {
                    var line = Path()
                    line.move(to: trailPoints[0])
                    for p in trailPoints.dropFirst() {
                        line.addLine(to: p)
                    }
                    ctx.stroke(
                        line,
                        with: .color(pal.ink.opacity(0.75)),
                        style: StrokeStyle(lineWidth: 1.25, dash: [3, 3])
                    )
                    for p in trailPoints {
                        let r: CGFloat = 3.0
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                            with: .color(pal.ink)
                        )
                    }
                }

                if let target = mapTarget {
                    let tp = pt(target.x, target.y)
                    let tr: CGFloat = 9.5
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: tp.x - tr, y: tp.y - tr, width: tr * 2, height: tr * 2)),
                        with: .color(pal.ink2),
                        style: StrokeStyle(lineWidth: 1.4, dash: [2, 2])
                    )
                }

                if let cur = currentWork, let cx = cur.x, let cy = cur.y {
                    let p = pt(cx, cy)
                    let r: CGFloat = 9.0
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                        with: .color(pal.signal),
                        lineWidth: 2.4
                    )
                }
            }
            .background(pal.panel)
            #if !os(tvOS)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard let onTune else { return }
                        let mapW = max(1, w - pad * 2)
                        let mapH = max(1, h - pad * 2)
                        let nx = min(1, max(0, (value.location.x - pad) / mapW))
                        let ny = min(1, max(0, (value.location.y - pad) / mapH))
                        let coordX = nx * 2 - 1
                        let coordY = 1 - ny * 2
                        onTune(coordX, coordY)
                    }
            )
            #endif
        }
    }

    private func quadrantColorIndex(for work: RadioWork) -> Int {
        let e = work.energy ?? 0.35
        let h = work.heaviness ?? 0.25
        if e >= 0.65 { return 0 }
        if h >= 0.45 { return 2 }
        if e <= 0.28 { return 3 }
        return 1
    }
}

public struct RecoverableTitle: View {
    public var text: String
    public var font: Font
    public var color: Color
    public var lineLimit: Int

    @State private var showFull = false

    public init(text: String, font: Font, color: Color, lineLimit: Int = 2) {
        self.text = text
        self.font = font
        self.color = color
        self.lineLimit = lineLimit
    }

    public var body: some View {
        Button {
            showFull = true
        } label: {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .sheet(isPresented: $showFull) {
            Text(text)
                .font(.body)
                .padding(24)
        }
        #else
        .popover(isPresented: $showFull) {
            Text(text)
                .font(.body)
                .padding(16)
                .frame(maxWidth: 320)
        }
        #endif
    }
}
