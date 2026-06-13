import AppKit

@MainActor
final class TwoLineView {
    let item: NSStatusItem
    private let topFont: NSFont
    private let bottomFont: NSFont
    private let color = NSColor.black
    private let mode: Mode

    enum Mode {
        case center
        /// Fixed-width layout with prefix + right-padded value on each line
        case arrowSpeed(maxValueChars: Int, prefixTop: String, prefixBottom: String)
        case disk
    }

    var top = "" { didSet { render() } }
    var bottom = "" { didSet { render() } }
    var rightSymbolName: String? { didSet { render() } }
    var fanAngle: CGFloat = 0 { didSet { render() } }
    var fillValue: CGFloat = 0 { didSet { render() } }

    private let fixedWidth: CGFloat?
    private let imageHeight: CGFloat = 28
    private let arrowValueGap: CGFloat = -2

    init(item: NSStatusItem, mode: Mode = .center, topFontSize: CGFloat = 10, bottomFontSize: CGFloat = 10) {
        self.item = item
        self.mode = mode
        self.topFont = NSFont.monospacedSystemFont(ofSize: topFontSize, weight: .regular)
        self.bottomFont = NSFont.monospacedSystemFont(ofSize: bottomFontSize, weight: .regular)
        item.button?.title = ""
        item.button?.imagePosition = .imageOnly

        if case .arrowSpeed(let maxValueChars, let pfTop, _) = mode {
            let attr: [NSAttributedString.Key: Any] = [.font: topFont]
            let refVal = String(repeating: "0", count: maxValueChars)
            let pfW = ceil((pfTop as NSString).size(withAttributes: attr).width)
            let valW = ceil((refVal as NSString).size(withAttributes: attr).width)
            fixedWidth = pfW + arrowValueGap + valW + 2
        } else {
            fixedWidth = nil
        }
    }

    private func render() {
        let topAttr: [NSAttributedString.Key: Any] = [.font: topFont, .foregroundColor: color]
        let botAttr: [NSAttributedString.Key: Any] = [.font: bottomFont, .foregroundColor: color]
        let h = imageHeight

        switch mode {
        case .center:
            let tw = (top as NSString).size(withAttributes: topAttr).width
            let bw = (bottom as NSString).size(withAttributes: botAttr).width

            var iconImg: NSImage?
            var iw: CGFloat = 0
            var ih: CGFloat = 0
            if let name = rightSymbolName, let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                iconImg = img.withSymbolConfiguration(cfg)
                iw = iconImg?.size.width ?? 0
                ih = iconImg?.size.height ?? 0
            }

            let gap: CGFloat = 5
            let baseW = max(tw, bw, 4) + 2
            let w = baseW + (iw > 0 ? gap + iw : 0)
            renderImage(size: NSSize(width: w, height: h)) {
                if !top.isEmpty {
                    let topH = (top as NSString).size(withAttributes: topAttr).height
                    (top as NSString).draw(at: NSPoint(x: (baseW - tw) / 2, y: h - topH - 2), withAttributes: topAttr)
                }
                if !bottom.isEmpty {
                    (bottom as NSString).draw(at: NSPoint(x: (baseW - bw) / 2, y: 2), withAttributes: botAttr)
                }
                if let iconImg, iw > 0 {
                    let textRightEdge = max((baseW - tw) / 2 + tw, (baseW - bw) / 2 + bw)
                    let cx = textRightEdge + gap + iw / 2
                    let cy = h / 2
                    let ctx = NSGraphicsContext.current!.cgContext
                    ctx.saveGState()
                    ctx.translateBy(x: cx, y: cy)
                    ctx.rotate(by: fanAngle)
                    iconImg.draw(at: NSPoint(x: -iw / 2, y: -ih / 2), from: .zero, operation: .sourceOver, fraction: 1)
                    ctx.restoreGState()
                }
            }
            item.length = w

        case .disk:
            let pctStr = top
            let pctSize = (pctStr as NSString).size(withAttributes: topAttr)
            let bw = (bottom as NSString).size(withAttributes: botAttr).width

            let barW: CGFloat = 24
            let barH: CGFloat = 7
            let gap: CGFloat = 3
            let topLineW = barW + gap + pctSize.width
            let w = max(topLineW, bw, 4) + 4

            let pct = min(max(fillValue, 0), 1)
            let barColor: NSColor = pct > 0.9 ? .systemRed : pct > 0.7 ? .systemOrange : .systemGreen
            let topY: CGFloat = h - (top as NSString).size(withAttributes: topAttr).height - 2

            renderImage(size: NSSize(width: w, height: h)) {
                let topX = (w - topLineW) / 2
                let barY = topY + (topFont.ascender + topFont.descender) / 2 - barH / 2

                let barRect = NSRect(x: topX, y: barY, width: barW, height: barH)
                let bgPath = NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2)
                NSColor.black.withAlphaComponent(0.12).setFill()
                bgPath.fill()
                NSColor.black.withAlphaComponent(0.3).setStroke()
                bgPath.lineWidth = 0.5
                bgPath.stroke()

                let fillRect = NSRect(x: topX + 1, y: barY + 1, width: max(0, (barW - 2) * pct), height: barH - 2)
                let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.5, yRadius: 1.5)
                barColor.setFill()
                fillPath.fill()

                (pctStr as NSString).draw(at: NSPoint(x: topX + barW + gap, y: topY), withAttributes: topAttr)

                if !bottom.isEmpty {
                    (bottom as NSString).draw(at: NSPoint(x: (w - bw) / 2, y: 2), withAttributes: botAttr)
                }
            }
            item.length = w

        case .arrowSpeed(let maxChars, let pfTop, let pfBot):
            let pad = { (s: String) in String(repeating: " ", count: max(0, maxChars - s.count)) + s }
            let valTop = pad(top)
            let valBot = pad(bottom)
            let pfSize = (pfTop as NSString).size(withAttributes: topAttr)
            let vtSize = (valTop as NSString).size(withAttributes: topAttr)
            let vbSize = (valBot as NSString).size(withAttributes: botAttr)
            let maxValW = max(vtSize.width, vbSize.width)
            let w = fixedWidth ?? (pfSize.width + arrowValueGap + maxValW) + 2
            let valX = 1 + pfSize.width + arrowValueGap
            renderImage(size: NSSize(width: w, height: h)) {
                (pfTop as NSString).draw(at: NSPoint(x: 1, y: h - pfSize.height - 2), withAttributes: topAttr)
                (pfBot as NSString).draw(at: NSPoint(x: 1, y: 2), withAttributes: botAttr)
                (valTop as NSString).draw(at: NSPoint(x: valX, y: h - vtSize.height - 2), withAttributes: topAttr)
                (valBot as NSString).draw(at: NSPoint(x: valX, y: 2), withAttributes: botAttr)
            }
            item.length = w
        }
    }

    private func renderImage(size: NSSize, draw: () -> Void) {
        let image = NSImage(size: size)
        image.lockFocus()
        draw()
        image.unlockFocus()
        item.button?.image = image
    }
}
