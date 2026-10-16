// Turns the engraved Dutch-oven drawing into the three app-icon variants,
// set on the journal's own paper and stone.
//
//   swift design/make-icon.swift design/icon-source.png FoodAndFriends/Assets.xcassets/AppIcon.appiconset
//
// The drawing is read as ink on paper: how much ink a pixel carries, and
// whether that ink is the paprika steam or the black line. Each variant then
// re-inks it — black on paper (light), paper on stone (dark), white on black
// (tinted, which iOS colours itself).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let inset = 0.90 // the drawing's share of the icon, leaving room for the mask

struct RGB { var r, g, b: Double }
let paper = RGB(r: 0xF6 / 255, g: 0xF1 / 255, b: 0xE7 / 255)
let stone = RGB(r: 0x12 / 255, g: 0x10 / 255, b: 0x0E / 255)
let cream = RGB(r: 0xEC / 255, g: 0xE4 / 255, b: 0xD4 / 255) // ink on stone

func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
    RGB(r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t)
}

let args = CommandLine.arguments
guard args.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let drawing = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("usage: make-icon.swift <source.png> <appiconset dir>")
}
let outDir = URL(fileURLWithPath: args[2])

func context() -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}

// The drawing, scaled in, on its own paper (sampled from its corners).
let base = context()
let sample = context()
sample.draw(drawing, in: CGRect(x: 0, y: 0, width: size, height: size))
let samplePixels = sample.data!.bindMemory(to: UInt8.self, capacity: size * size * 4)
var src = RGB(r: 0, g: 0, b: 0)
let corners = [(8, 8), (size - 9, 8), (8, size - 9), (size - 9, size - 9)]
for (x, y) in corners {
    let i = (y * size + x) * 4
    src.r += Double(samplePixels[i]) / 255 / 4
    src.g += Double(samplePixels[i + 1]) / 255 / 4
    src.b += Double(samplePixels[i + 2]) / 255 / 4
}
base.setFillColor(red: src.r, green: src.g, blue: src.b, alpha: 1)
base.fill(CGRect(x: 0, y: 0, width: size, height: size))
base.interpolationQuality = .high
let side = Double(size) * inset
base.draw(drawing, in: CGRect(x: (Double(size) - side) / 2, y: (Double(size) - side) / 2, width: side, height: side))
let pixels = base.data!.bindMemory(to: UInt8.self, capacity: size * size * 4)

func render(_ name: String, _ ink: (_ pixel: RGB, _ amount: Double, _ redness: Double) -> RGB) {
    let out = context()
    let o = out.data!.bindMemory(to: UInt8.self, capacity: size * size * 4)
    for p in 0 ..< size * size {
        let i = p * 4
        // As a fraction of the drawing's paper, so the paper itself reads as 1.
        let c = RGB(r: min(1, Double(pixels[i]) / 255 / src.r),
                    g: min(1, Double(pixels[i + 1]) / 255 / src.g),
                    b: min(1, Double(pixels[i + 2]) / 255 / src.b))
        let amount = max(0, min(1, 1 - (0.299 * c.r + 0.587 * c.g + 0.114 * c.b)))
        let redness = max(0, min(1, (c.r - max(c.g, c.b)) / 0.45))
        let v = ink(c, amount, redness)
        o[i] = UInt8(max(0, min(255, (v.r * 255).rounded())))
        o[i + 1] = UInt8(max(0, min(255, (v.g * 255).rounded())))
        o[i + 2] = UInt8(max(0, min(255, (v.b * 255).rounded())))
        o[i + 3] = 255
    }
    let url = outDir.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, out.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote", url.path)
}

// Light: the drawing as it is, its paper swapped for the journal's.
render("icon-light.png") { c, _, _ in
    RGB(r: c.r * paper.r, g: c.g * paper.g, b: c.b * paper.b)
}

// Dark: cream line on stone; the steam keeps its paprika.
render("icon-dark.png") { c, amount, redness in
    let line = mix(stone, cream, amount)
    let steam = RGB(r: c.r * paper.r, g: c.g * paper.g, b: c.b * paper.b)
    return mix(line, steam, redness)
}

// Tinted: ink as white on black — iOS supplies the colour.
render("icon-tinted.png") { _, amount, redness in
    let v = max(amount, redness * 0.85)
    return RGB(r: v, g: v, b: v)
}
