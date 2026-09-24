#!/usr/bin/env swift
// Renders the TopDock app icon into an .iconset directory.
// Usage: swift scripts/make-icon.swift <output.iconset>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func render(pixels: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let s = CGFloat(pixels) / 1024
    ctx.scaleBy(x: s, y: s)
    ctx.interpolationQuality = .high

    // Body: macOS icon grid (824pt squircle-ish rounded rect centered in 1024).
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = roundedRect(body, 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x1B1F3B))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: space,
        colors: [color(0x2D6BFF), color(0x6A3DF0), color(0xB23CD9)] as CFArray,
        locations: [0, 0.6, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Soft light from the top.
    let glow = CGGradient(
        colorsSpace: space,
        colors: [color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        glow, startCenter: CGPoint(x: 512, y: 880), startRadius: 0,
        endCenter: CGPoint(x: 512, y: 880), endRadius: 620, options: []
    )

    // Menu bar strip.
    let barHeight: CGFloat = 150
    let bar = CGRect(x: body.minX, y: body.maxY - barHeight, width: body.width, height: barHeight)
    ctx.setFillColor(color(0xFFFFFF, 0.2))
    ctx.fill(bar)
    ctx.setFillColor(color(0xFFFFFF, 0.35))
    ctx.fill(CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: 3))

    // Tiny "menu" and "status item" marks at the bar edges.
    ctx.setFillColor(color(0xFFFFFF, 0.7))
    for (index, width) in [CGFloat(38), 64].enumerated() {
        let x = body.minX + 70 + CGFloat(index) * 90
        ctx.addPath(roundedRect(CGRect(x: x, y: bar.midY - 9, width: width, height: 18), 9))
    }
    for index in 0..<2 {
        let x = body.maxX - 90 - CGFloat(index) * 50
        ctx.addPath(roundedRect(CGRect(x: x, y: bar.midY - 11, width: 22, height: 22), 11))
    }
    ctx.fillPath()

    // Dock icons in the center of the bar; the middle one is magnified and hangs below.
    let tiles: [(UInt32, UInt32, CGFloat)] = [
        (0xFFB340, 0xFF7A1A, 1.0),
        (0x4CE08A, 0x14B862, 1.25),
        (0xFFFFFF, 0xDDE3FF, 1.75),
        (0x5AD8FF, 0x1E9BFF, 1.25),
        (0xFF6B9A, 0xFF2D6B, 1.0),
    ]
    let base: CGFloat = 54
    let gap: CGFloat = 16
    let totalWidth = tiles.reduce(0) { $0 + base * $1.2 } + gap * CGFloat(tiles.count - 1)
    var x = 512 - totalWidth / 2
    let top = bar.maxY - (barHeight - base) / 2
    for (start, end, scale) in tiles {
        let size = base * scale
        let rect = CGRect(x: x, y: top - size, width: size, height: size)
        let path = roundedRect(rect, size * 0.26)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x000000, 0.3))
        ctx.addPath(path)
        ctx.setFillColor(color(end))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let tile = CGGradient(colorsSpace: space, colors: [color(start), color(end)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(tile, start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
        ctx.restoreGState()

        // Running indicator dot.
        ctx.setFillColor(color(0xFFFFFF, 0.9))
        ctx.fillEllipse(in: CGRect(x: rect.midX - 6, y: rect.minY - 22, width: 12, height: 12))

        x += size + gap
    }

    // Faint window silhouettes in the lower part to read as "desktop".
    ctx.setFillColor(color(0xFFFFFF, 0.1))
    ctx.addPath(roundedRect(CGRect(x: 190, y: 190, width: 400, height: 260), 28))
    ctx.fillPath()
    ctx.setFillColor(color(0xFFFFFF, 0.14))
    ctx.addPath(roundedRect(CGRect(x: 470, y: 250, width: 360, height: 230), 28))
    ctx.fillPath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Failed to write \(url.path)") }
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    writePNG(render(pixels: points), to: output.appendingPathComponent("icon_\(points)x\(points).png"))
    writePNG(render(pixels: points * 2), to: output.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
print("Wrote \(output.path)")
