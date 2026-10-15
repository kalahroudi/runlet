// Draws the RunLet app icon. Usage: swiftc make-icon.swift -o make-icon && ./make-icon out.png [size]
import AppKit

let size = CGFloat(Int(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "1024") ?? 1024)
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let s = size / 1024

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

// macOS icon grid: artwork is 824 of 1024 with a soft shadow beneath.
let art = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
let shape = NSBezierPath(roundedRect: art, xRadius: 185 * s, yRadius: 185 * s)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s, color: NSColor(white: 0, alpha: 0.28).cgColor)
rgb(0xFF5B2E).setFill(); shape.fill()
ctx.restoreGState()

ctx.saveGState()
shape.addClip()
NSGradient(starting: rgb(0xFF8A4C), ending: rgb(0xFF3D2E))!.draw(in: art, angle: -50)
// soft top gloss
NSGradient(starting: NSColor(white: 1, alpha: 0.30), ending: NSColor(white: 1, alpha: 0))!
    .draw(in: NSRect(x: art.minX, y: art.midY, width: art.width, height: art.height / 2), angle: -90)
ctx.restoreGState()

// prompt chevron
let chev = NSBezierPath()
chev.move(to: NSPoint(x: 330 * s, y: 690 * s))
chev.line(to: NSPoint(x: 560 * s, y: 512 * s))
chev.line(to: NSPoint(x: 330 * s, y: 334 * s))
chev.lineWidth = 96 * s; chev.lineCapStyle = .round; chev.lineJoinStyle = .round
NSColor.white.setStroke(); chev.stroke()

// cursor bar
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 610 * s, y: 300 * s, width: 190 * s, height: 86 * s), xRadius: 43 * s, yRadius: 43 * s).fill()

// spark
NSColor(white: 1, alpha: 0.92).setFill()
NSBezierPath(ovalIn: NSRect(x: 698 * s, y: 664 * s, width: 56 * s, height: 56 * s)).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
