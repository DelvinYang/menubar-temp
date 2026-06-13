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
    }

    var top = "" { didSet { render() } }
    var bottom = "" { didSet { render() } }
    var rightSymbolName: String? { didSet { render() } }

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

            let topLineW = tw + (iw > 0 ? iw + 2 : 0)
            let w = max(topLineW, bw, 4) + 2
            renderImage(size: NSSize(width: w, height: h)) {
                if !top.isEmpty {
                    let topH = (top as NSString).size(withAttributes: topAttr).height
                    let topX = (w - topLineW) / 2
                    (top as NSString).draw(at: NSPoint(x: topX, y: h - topH - 2), withAttributes: topAttr)
                    if let iconImg, iw > 0 {
                        iconImg.draw(at: NSPoint(x: topX + tw + 2, y: (h - ih) / 2), from: .zero, operation: .sourceOver, fraction: 1)
                    }
                }
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
