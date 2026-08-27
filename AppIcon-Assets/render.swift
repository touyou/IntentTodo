import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Render IntentTodo app-icon foreground layers to transparent 1024x1024 PNGs.
// Drawn with CoreGraphics (not SVG) so Icon Composer's build-time rasterizer
// can't misparse masks / <use> / <defs>.

let size = 1024.0

func rgb(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
    CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: 1)
}
let green = rgb(52, 199, 89)   // #34C759
let gold  = rgb(255, 196, 0)   // #FFC400
let gray  = rgb(142, 147, 155) // #8E939B
let barD  = rgb(91, 96, 104)   // #5B6068
let barL  = rgb(194, 200, 208) // #C2C8D0
let mono  = rgb(28, 28, 30)    // #1C1C1E

// Star (5-point) points relative to its center, outer radius 62.
let starPts: [(Double, Double)] = [
    (0, -62), (14.70, -20.23), (58.97, -19.16), (23.78, 7.73), (36.44, 50.16),
    (0, 25), (-36.44, 50.16), (-23.78, 7.73), (-58.97, -19.16), (-14.70, -20.23)
]

func starPath(cx: Double, cy: Double) -> CGPath {
    let p = CGMutablePath()
    for (i, pt) in starPts.enumerated() {
        let x = cx + pt.0, y = cy + pt.1
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

// rows: (y, barWidth)
let rows = [(312.0, 240.0), (512.0, 190.0), (712.0, 225.0)]
let cxCircle = 282.0, cxStar = 742.0, barX = 392.0

func draw(mono isMono: Bool, to url: URL) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip so we can use SVG-style top-left coordinates.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)

    let circleFill = isMono ? mono : green
    let starFill   = isMono ? mono : gold
    let outline    = isMono ? mono : gray
    let barDark    = isMono ? mono : barD
    let barLight   = isMono ? mono : barL

    for (idx, row) in rows.enumerated() {
        let y = row.0, w = row.1

        // --- circle ---
        if idx == 0 {
            // filled circle with knocked-out checkmark
            ctx.saveGState()
            ctx.setFillColor(circleFill)
            ctx.fillEllipse(in: CGRect(x: cxCircle - 62, y: y - 62, width: 124, height: 124))
            // punch check to transparent
            ctx.setBlendMode(.clear)
            ctx.setLineWidth(24)
            ctx.move(to: CGPoint(x: 254, y: 312))
            ctx.addLine(to: CGPoint(x: 275, y: 334))
            ctx.addLine(to: CGPoint(x: 312, y: 289))
            ctx.strokePath()
            ctx.restoreGState()
        } else {
            ctx.setStrokeColor(outline)
            ctx.setLineWidth(22)
            ctx.strokeEllipse(in: CGRect(x: cxCircle - 51, y: y - 51, width: 102, height: 102))
        }

        // --- text bar ---
        ctx.setFillColor(idx == 0 ? barLight : barDark)
        let bar = CGPath(roundedRect: CGRect(x: barX, y: y - 28, width: w, height: 56),
                         cornerWidth: 28, cornerHeight: 28, transform: nil)
        ctx.addPath(bar); ctx.fillPath()

        // --- star ---
        let sp = starPath(cx: cxStar, cy: y)
        if idx == 1 {
            // outline star
            ctx.setStrokeColor(outline)
            ctx.setLineWidth(18)
            ctx.addPath(sp); ctx.strokePath()
        } else {
            ctx.setFillColor(starFill)
            ctx.addPath(sp); ctx.fillPath()
        }
    }

    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.lastPathComponent)")
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
draw(mono: false, to: dir.appendingPathComponent("icon-foreground-color.png"))
draw(mono: true,  to: dir.appendingPathComponent("icon-foreground-mono.png"))
