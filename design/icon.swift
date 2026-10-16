// The Food & Friends mark, drawn rather than generated, in the journal's own
// faces and inks. Run from the repo root:
//
//     swift design/icon.swift
//
// Writes design/icon-a.png, icon-b.png, icon-c.png (1024², the paper edition)
// and design/icon-candidates.png (all three, masked the way iOS shows them).
import AppKit

let size: CGFloat = 1024

// The ramp, from FoodAndFriends/Assets.xcassets — the paper edition.
let paper = NSColor(srgbRed: 0xF6/255, green: 0xF1/255, blue: 0xE7/255, alpha: 1)
let ink = NSColor(srgbRed: 0x2B/255, green: 0x26/255, blue: 0x20/255, alpha: 1)
let paprika = NSColor(srgbRed: 0xB8/255, green: 0x3A/255, blue: 0x26/255, alpha: 1)

func serif(_ size: CGFloat, _ weight: NSFont.Weight = .bold, italic: Bool = false) -> NSFont {
    var descriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif)!
    if italic { descriptor = descriptor.withSymbolicTraits(.italic) }
    return NSFont(descriptor: descriptor, size: size)!
}

/// Draws into a fresh 1024² bitmap with the origin at the top left.
func render(_ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.translateBy(x: 0, y: size)
    cg.scaleBy(x: 1, y: -1)
    paper.setFill()
    cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
    draw(cg)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Thick-over-thin, the mark that opens every plate in the app.
func doubleRule(_ cg: CGContext, y: CGFloat, from x0: CGFloat = 150, to x1: CGFloat = 874) {
    ink.setFill()
    cg.fill(CGRect(x: x0, y: y, width: x1 - x0, height: 16))
    ink.withAlphaComponent(0.55).setFill()
    cg.fill(CGRect(x: x0, y: y + 26, width: x1 - x0, height: 5))
}

func hairline(_ cg: CGContext, y: CGFloat, from x0: CGFloat = 150, to x1: CGFloat = 874) {
    ink.withAlphaComponent(0.55).setFill()
    cg.fill(CGRect(x: x0, y: y, width: x1 - x0, height: 5))
}

/// Text centred on a point, in a top-left-origin context.
func drawCentered(_ text: NSAttributedString, centerX: CGFloat, centerY: CGFloat) {
    let bounds = text.boundingRect(with: NSSize(width: 4000, height: 4000), options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.current!.cgContext.saveGState()
    let cg = NSGraphicsContext.current!.cgContext
    // Flip back for AppKit text, which draws bottom-up.
    cg.translateBy(x: 0, y: size)
    cg.scaleBy(x: 1, y: -1)
    let origin = NSPoint(x: centerX - bounds.width / 2, y: size - centerY - bounds.height / 2)
    text.draw(at: origin)
    cg.restoreGState()
}

// MARK: - A — the ampersand

let iconA = render { cg in
    doubleRule(cg, y: 150)
    let amp = NSAttributedString(string: "&", attributes: [.font: serif(640, .regular, italic: true), .foregroundColor: paprika])
    drawCentered(amp, centerX: 512, centerY: 530)
    hairline(cg, y: 860)
}

// MARK: - B — the pot

let iconB = render { cg in
    cg.setLineCap(.round)
    cg.setLineJoin(.round)

    // Steam — three paprika curls rising off the lid.
    paprika.setStroke()
    cg.setLineWidth(24)
    for x in [400.0, 512.0, 624.0] {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: 300))
        path.addCurve(to: CGPoint(x: x, y: 150), control1: CGPoint(x: x - 46, y: 250), control2: CGPoint(x: x + 46, y: 200))
        cg.addPath(path)
    }
    cg.strokePath()

    ink.setStroke()
    cg.setLineWidth(28)

    // Lid — a low dome, a knob on top.
    let lid = CGMutablePath()
    lid.move(to: CGPoint(x: 236, y: 476))
    lid.addCurve(to: CGPoint(x: 788, y: 476), control1: CGPoint(x: 330, y: 370), control2: CGPoint(x: 694, y: 370))
    cg.addPath(lid)
    cg.addRect(CGRect(x: 474, y: 352, width: 76, height: 40))

    // Rim.
    cg.move(to: CGPoint(x: 200, y: 476))
    cg.addLine(to: CGPoint(x: 824, y: 476))

    // Body — square shoulders, rounded base.
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 248, y: 476))
    body.addLine(to: CGPoint(x: 248, y: 700))
    body.addQuadCurve(to: CGPoint(x: 348, y: 800), control: CGPoint(x: 248, y: 800))
    body.addLine(to: CGPoint(x: 676, y: 800))
    body.addQuadCurve(to: CGPoint(x: 776, y: 700), control: CGPoint(x: 776, y: 800))
    body.addLine(to: CGPoint(x: 776, y: 476))
    cg.addPath(body)

    // Handles.
    cg.move(to: CGPoint(x: 248, y: 540))
    cg.addLine(to: CGPoint(x: 178, y: 540))
    cg.addLine(to: CGPoint(x: 178, y: 610))
    cg.addLine(to: CGPoint(x: 248, y: 610))
    cg.move(to: CGPoint(x: 776, y: 540))
    cg.addLine(to: CGPoint(x: 846, y: 540))
    cg.addLine(to: CGPoint(x: 846, y: 610))
    cg.addLine(to: CGPoint(x: 776, y: 610))
    cg.strokePath()

    // A hairline of broth — the one ink line inside.
    ink.withAlphaComponent(0.45).setStroke()
    cg.setLineWidth(10)
    cg.move(to: CGPoint(x: 300, y: 560))
    cg.addLine(to: CGPoint(x: 724, y: 560))
    cg.strokePath()
}

// MARK: - C — the monogram

let iconC = render { cg in
    doubleRule(cg, y: 230)
    let mark = NSMutableAttributedString(string: "F", attributes: [.font: serif(400, .bold), .foregroundColor: ink])
    mark.append(NSAttributedString(string: "&", attributes: [.font: serif(330, .regular, italic: true), .foregroundColor: paprika]))
    mark.append(NSAttributedString(string: "F", attributes: [.font: serif(400, .bold), .foregroundColor: ink]))
    drawCentered(mark, centerX: 512, centerY: 520)
    hairline(cg, y: 780)
}

// MARK: - Writing them out

func write(_ rep: NSBitmapImageRep, _ name: String) {
    let url = URL(fileURLWithPath: "design/\(name)")
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path)")
}

write(iconA, "icon-a.png")
write(iconB, "icon-b.png")
write(iconC, "icon-c.png")

// The three side by side, masked to iOS's rounded square, on a neutral ground.
let tile: CGFloat = 300, gap: CGFloat = 60
let sheet = NSImage(size: NSSize(width: tile * 3 + gap * 4, height: tile + gap * 2 + 60))
sheet.lockFocus()
NSColor(white: 0.18, alpha: 1).setFill()
NSRect(origin: .zero, size: sheet.size).fill()
for (index, (rep, label)) in [(iconA, "A"), (iconB, "B"), (iconC, "C")].enumerated() {
    let x = gap + CGFloat(index) * (tile + gap)
    let rect = NSRect(x: x, y: gap + 60, width: tile, height: tile)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: tile * 0.2237, yRadius: tile * 0.2237).addClip()
    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    let caption = NSAttributedString(string: label, attributes: [.font: NSFont.systemFont(ofSize: 34, weight: .semibold), .foregroundColor: NSColor.white])
    caption.draw(at: NSPoint(x: x + tile / 2 - 10, y: 18))
}
sheet.unlockFocus()
let sheetRep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
write(sheetRep, "icon-candidates.png")
