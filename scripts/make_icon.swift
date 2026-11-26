// Regenerates the StatusMonitor app icon.
//
// Usage (from the repository root):
//   swift scripts/make_icon.swift
//
// Writes:
//   Support/AppIcon.iconset/*.png   dark icon at every macOS iconset size
//   Support/AppIcon.icns            built from the iconset with iconutil
//   Support/AppIcon-light.png       light variant, 1024 px, not bundled
//
// Geometry is drawn on a 1024-unit grid (y down) and scaled to each size.
// Uses CoreGraphics and ImageIO only. No network, no files outside the repo.

import CoreGraphics
import Foundation
import ImageIO

struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

struct Palette {
    let tile: RGBA
    let edge: RGBA
    let band: RGBA
    let bandInk: RGBA
    let accent: RGBA
    let warm: RGBA
    let line: RGBA
}

func hex(_ value: UInt32, alpha: CGFloat = 1) -> RGBA {
    let red = CGFloat((value >> 16) & 0xFF) / 255
    let green = CGFloat((value >> 8) & 0xFF) / 255
    let blue = CGFloat(value & 0xFF) / 255
    return RGBA(red: red, green: green, blue: blue, alpha: alpha)
}

let darkPalette = Palette(
    tile: hex(0x16191F),
    edge: hex(0xFFFFFF, alpha: 0.10),
    band: hex(0xFFFFFF, alpha: 0.10),
    bandInk: hex(0xFFFFFF, alpha: 0.45),
    accent: hex(0x2BD4A4),
    warm: hex(0xFF8A3D),
    line: hex(0xFFFFFF)
)

let lightPalette = Palette(
    tile: hex(0xF4F5F7),
    edge: hex(0x000000, alpha: 0.10),
    band: hex(0x000000, alpha: 0.07),
    bandInk: hex(0x000000, alpha: 0.35),
    accent: hex(0x0F9C78),
    warm: hex(0xF06A1D),
    line: hex(0x16191F)
)

func cgColor(_ color: RGBA) -> CGColor {
    CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
}

func roundedRect(
    _ originX: CGFloat, _ originY: CGFloat,
    _ width: CGFloat, _ height: CGFloat,
    _ radius: CGFloat
) -> CGPath {
    CGPath(roundedRect: CGRect(x: originX, y: originY, width: width, height: height),
           cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Draws the top band, its label and the gauge glyph.
func drawBand(in ctx: CGContext, palette: Palette) {
    // Top band
    ctx.setFillColor(cgColor(palette.band))
    ctx.addPath(roundedRect(170, 172, 684, 92, 46))
    ctx.fillPath()

    // Band label
    ctx.setFillColor(cgColor(palette.bandInk))
    ctx.addPath(roundedRect(214, 208, 120, 20, 10))
    ctx.fillPath()

    // Gauge glyph: ring centred at (790, 218), r 20, stroke 9
    ctx.setStrokeColor(cgColor(palette.bandInk))
    ctx.setLineWidth(9)
    ctx.strokeEllipse(in: CGRect(x: 770, y: 198, width: 40, height: 40))
}

/// Renders the icon at `pixels` x `pixels`. Corners outside the tile stay transparent.
func renderIcon(pixels: Int, palette: Palette) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("could not create \(pixels)px bitmap context")
    }

    ctx.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))

    // Map the 1024-unit design grid (y down) onto the bitmap.
    let scale = CGFloat(pixels) / 1024
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Tile
    ctx.setFillColor(cgColor(palette.tile))
    ctx.addPath(roundedRect(100, 100, 824, 824, 185))
    ctx.fillPath()

    // Edge stroke, inset by 1 unit
    ctx.setStrokeColor(cgColor(palette.edge))
    ctx.setLineWidth(3)
    ctx.addPath(roundedRect(101, 101, 822, 822, 184))
    ctx.strokePath()

    drawBand(in: ctx, palette: palette)

    // Four bars; the last one is the warm colour
    ctx.setFillColor(cgColor(palette.accent))
    ctx.addPath(roundedRect(232, 560, 112, 250, 30))
    ctx.addPath(roundedRect(388, 440, 112, 370, 30))
    ctx.addPath(roundedRect(544, 510, 112, 300, 30))
    ctx.fillPath()
    ctx.setFillColor(cgColor(palette.warm))
    ctx.addPath(roundedRect(700, 340, 112, 470, 30))
    ctx.fillPath()

    // Polyline with round caps and joins
    ctx.setStrokeColor(cgColor(palette.line))
    ctx.setLineWidth(14)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 232, y: 470))
    ctx.addLine(to: CGPoint(x: 388, y: 350))
    ctx.addLine(to: CGPoint(x: 544, y: 420))
    ctx.addLine(to: CGPoint(x: 756, y: 250))
    ctx.strokePath()

    // End dot at (756, 250), r 20
    ctx.setFillColor(cgColor(palette.line))
    ctx.fillEllipse(in: CGRect(x: 736, y: 230, width: 40, height: 40))

    guard let image = ctx.makeImage() else {
        fatalError("could not make image at \(pixels)px")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("could not open \(url.path) for writing")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("could not write \(url.path)")
    }
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let supportDir = root.appendingPathComponent("Support")
let iconsetDir = supportDir.appendingPathComponent("AppIcon.iconset")
let icnsURL = supportDir.appendingPathComponent("AppIcon.icns")
let lightURL = supportDir.appendingPathComponent("AppIcon-light.png")

// iconset file name -> pixel size
let iconsetSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

// Start from an empty iconset so stale files cannot linger.
try? fileManager.removeItem(at: iconsetDir)
try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for (name, pixels) in iconsetSizes {
    writePNG(renderIcon(pixels: pixels, palette: darkPalette),
             to: iconsetDir.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}

writePNG(renderIcon(pixels: 1024, palette: lightPalette), to: lightURL)

print("wrote \(iconsetSizes.count) PNGs to \(iconsetDir.path)")
print("wrote \(icnsURL.path)")
print("wrote \(lightURL.path)")
