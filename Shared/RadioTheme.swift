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
        rgb.blended(into: bgRGB, amount: scheme == .dark ? 0.16 : 0.10)
    }
}

public enum RadioSwatches {
    private static let archivalSwatches: [RadioRGB] = [
        RadioRGB(r: 0.463, g: 0.341, b: 0.204), // ochre brown
        RadioRGB(r: 0.259, g: 0.275, b: 0.310), // slate ink
        RadioRGB(r: 0.333, g: 0.314, b: 0.251), // warm olive
        RadioRGB(r: 0.592, g: 0.231, b: 0.208), // oxide red
        RadioRGB(r: 0.369, g: 0.298, b: 0.278), // umber plum
        RadioRGB(r: 0.220, g: 0.345, b: 0.322), // deep moss teal
        RadioRGB(r: 0.282, g: 0.318, b: 0.388), // cobalt slate
        RadioRGB(r: 0.545, g: 0.376, b: 0.169), // amber rust
    ]

    public static func sleeveRGB(for seed: String, colorOverride: String? = nil) -> RadioRGB {
        if let parsed = parseColorRGB(colorOverride) {
            return parsed
        }
        switch seed {
        case "lens:radio:late-wire":
            return RadioRGB(r: 0.145, g: 0.188, b: 0.259) // #253042 deep slate-indigo
        case "lens:radio:motorik-pulse":
            return RadioRGB(r: 0.725, g: 0.216, b: 0.137) // #B93723 vermilion
        case "lens:radio:chamber-focus":
            return RadioRGB(r: 0.604, g: 0.420, b: 0.141) // #9A6B24 archival ochre
        default:
            break
        }
        var hash: UInt64 = 14695981039346656037
        for b in seed.utf8 {
            hash ^= UInt64(b)
            hash = hash &* 1099511628211
        }
        return archivalSwatches[Int(hash % UInt64(archivalSwatches.count))]
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

public struct RadioSleeve: View {
    public var title: String
    public var subtitle: String
    public var seed: String
    public var colorOverride: String?
    public var artURL: URL?
    public var size: CGFloat
    public var compact: Bool
    public var badge: String?
    public var isActive: Bool

    @Environment(\.colorScheme) private var scheme

    public init(
        title: String,
        subtitle: String,
        seed: String,
        colorOverride: String? = nil,
        artURL: URL? = nil,
        size: CGFloat,
        compact: Bool = false,
        badge: String? = nil,
        isActive: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.seed = seed
        self.colorOverride = colorOverride
        self.artURL = artURL
        self.size = size
        self.compact = compact
        self.badge = badge
        self.isActive = isActive
    }

    public var body: some View {
        let pal = RadioPalette.forScheme(scheme)
        let rgb = RadioSwatches.sleeveRGB(for: seed, colorOverride: colorOverride)
        let corner: CGFloat = compact ? 5 : 8

        ZStack(alignment: .bottomLeading) {
            rgb.color

            if !compact {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let badge, !badge.isEmpty {
                            Text(badge)
                                .font(.system(size: max(9, size * 0.068), weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(red: 0.94, green: 0.91, blue: 0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 4))
                        }
                        Spacer(minLength: 0)
                    }

                    Spacer(minLength: 0)

                    Text(title)
                        .font(.system(size: max(13, min(30, size * 0.14)), weight: .bold, design: .serif))
                        .foregroundStyle(Color(red: 0.980, green: 0.965, blue: 0.933))
                        .lineSpacing(-2)
                        .lineLimit(3)
                        .minimumScaleFactor(0.68)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: max(9.5, min(12, size * 0.074)), weight: .regular, design: .monospaced))
                            .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.89).opacity(0.84))
                            .lineLimit(1)
                    }
                }
                .padding(max(8, size * 0.08))
            }

            if let artURL {
                CookieArtworkImage(url: artURL)
                    .frame(width: size, height: size)
                    .clipped()
            }

            if isActive {
                Rectangle()
                    .fill(pal.signal)
                    .frame(height: compact ? 2 : 3)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(isActive ? pal.signal : Color.black.opacity(0.08), lineWidth: isActive ? 1.5 : 0.5)
        }
        .accessibilityHidden(true)
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
            let pad: CGFloat = 16

            Canvas { ctx, size in
                let mapW = max(1, size.width - pad * 2)
                let mapH = max(1, size.height - pad * 2)
                func pt(_ x: Double, _ y: Double) -> CGPoint {
                    let nx = (min(1, max(-1, x)) + 1) * 0.5
                    let ny = (1 - min(1, max(-1, y))) * 0.5
                    return CGPoint(x: pad + nx * mapW, y: pad + ny * mapH)
                }

                // Subtle crosshair axes
                var axes = Path()
                axes.move(to: CGPoint(x: pad, y: size.height / 2))
                axes.addLine(to: CGPoint(x: size.width - pad, y: size.height / 2))
                axes.move(to: CGPoint(x: size.width / 2, y: pad))
                axes.addLine(to: CGPoint(x: size.width / 2, y: size.height - pad))
                ctx.stroke(axes, with: .color(pal.line.opacity(0.65)), lineWidth: 0.6)

                // Region labels placed away from dense track clusters
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
                            .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(pal.ink3),
                        at: p
                    )
                }

                let plotted = works.filter { $0.x != nil && $0.y != nil }
                let anchorIDs = Set(activeLens?.anchors.map(\.workId) ?? [])

                // All coordinate points
                for item in plotted {
                    guard let ix = item.x, let iy = item.y else { continue }
                    let c = pt(ix, iy)
                    let regIdx = quadrantColorIndex(for: item)
                    let col = Self.regionColors[regIdx]
                    let r: CGFloat = item.isPlayable ? 4.2 : 2.8
                    let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                    if item.isPlayable {
                        ctx.fill(Path(ellipseIn: rect), with: .color(col))
                    } else {
                        ctx.fill(Path(ellipseIn: rect), with: .color(col.opacity(0.45)))
                    }
                    if anchorIDs.contains(item.workId) {
                        let ar: CGFloat = 6.5
                        let arect = CGRect(x: c.x - ar, y: c.y - ar, width: ar * 2, height: ar * 2)
                        ctx.stroke(Path(ellipseIn: arect), with: .color(pal.ink2.opacity(0.7)), lineWidth: 1.0)
                    }
                }

                // Ranked trail
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
                        style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
                    )
                    for p in trailPoints {
                        let r: CGFloat = 2.8
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                            with: .color(pal.ink)
                        )
                    }
                }

                // Pinned target reticle if user tapped map
                if let target = mapTarget {
                    let tp = pt(target.x, target.y)
                    let tr: CGFloat = 9
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: tp.x - tr, y: tp.y - tr, width: tr * 2, height: tr * 2)),
                        with: .color(pal.ink2),
                        style: StrokeStyle(lineWidth: 1.4, dash: [2, 2])
                    )
                }

                // Current work reticle
                if let cur = currentWork, let cx = cur.x, let cy = cur.y {
                    let p = pt(cx, cy)
                    let r: CGFloat = 8.5
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                        with: .color(pal.signal),
                        lineWidth: 2.2
                    )
                }
            }
            .background(pal.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
