#!/usr/bin/env swift
// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Foundation

enum AwakeLogoState {
    case off
    case on
}

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render-awake-assets.swift <output-dir>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconsetDirectory = outputDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? fileManager.removeItem(at: iconsetDirectory)
try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

func writePNG(size: Int, url: URL, drawing: (NSRect) -> Void) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "AwakeAssetRenderer", code: 1)
    }

    bitmap.size = NSSize(width: CGFloat(size), height: CGFloat(size))
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let rect = NSRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    NSColor.clear.setFill()
    rect.fill()
    drawing(rect)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AwakeAssetRenderer", code: 2)
    }
    try data.write(to: url, options: .atomic)
}

func drawRoundedBackground(in rect: NSRect, fill color: NSColor) {
    let radius = rect.width * 0.23
    let path = NSBezierPath(
        roundedRect: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04),
        xRadius: radius,
        yRadius: radius
    )
    color.setFill()
    path.fill()
}

func logoPoint(_ x: CGFloat, _ y: CGFloat, in rect: NSRect) -> CGPoint {
    let designWidth: CGFloat = 360
    let designHeight: CGFloat = 320
    let targetRect = rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.06)
    let scale = min(targetRect.width / designWidth, targetRect.height / designHeight)
    let drawnWidth = designWidth * scale
    let drawnHeight = designHeight * scale
    let originX = targetRect.midX - drawnWidth / 2
    let originY = targetRect.midY - drawnHeight / 2
    return CGPoint(x: originX + x * scale, y: originY + (designHeight - y) * scale)
}

func makeOuterAPath(in rect: NSRect) -> CGPath {
    let path = CGMutablePath()
    path.move(to: logoPoint(118, 286, in: rect))
    path.addLine(to: logoPoint(200, 36, in: rect))
    path.addLine(to: logoPoint(322, 286, in: rect))
    path.addLine(to: logoPoint(258, 286, in: rect))
    path.addLine(to: logoPoint(232, 214, in: rect))
    path.addLine(to: logoPoint(168, 214, in: rect))
    path.addLine(to: logoPoint(142, 286, in: rect))
    path.closeSubpath()
    return path
}

func makeInnerCutoutPath(in rect: NSRect) -> CGPath {
    let path = CGMutablePath()
    path.move(to: logoPoint(181, 178, in: rect))
    path.addLine(to: logoPoint(200, 126, in: rect))
    path.addLine(to: logoPoint(219, 178, in: rect))
    path.closeSubpath()
    return path
}

func makeLeftFlourishPath(in rect: NSRect) -> CGPath {
    let path = CGMutablePath()
    path.move(to: logoPoint(56, 246, in: rect))
    path.addLine(to: logoPoint(87, 217, in: rect))
    path.addLine(to: logoPoint(147, 217, in: rect))
    return path
}

func drawLetterA(state: AwakeLogoState, in rect: NSRect, color: NSColor, outlineWidth: CGFloat) {
    guard let context = NSGraphicsContext.current?.cgContext else {
        return
    }

    let outerPath = makeOuterAPath(in: rect)
    let innerCutoutPath = makeInnerCutoutPath(in: rect)
    let leftFlourishPath = makeLeftFlourishPath(in: rect)

    context.saveGState()
    context.setLineJoin(.round)
    context.setLineCap(.round)
    context.setStrokeColor(color.cgColor)
    context.setFillColor(color.cgColor)

    switch state {
    case .off:
        context.setLineWidth(outlineWidth)
        context.addPath(outerPath)
        context.strokePath()
        context.addPath(innerCutoutPath)
        context.strokePath()
        context.addPath(leftFlourishPath)
        context.strokePath()
    case .on:
        context.addPath(outerPath)
        context.addPath(innerCutoutPath)
        context.drawPath(using: .eoFill)

        context.setLineWidth(outlineWidth)
        context.addPath(outerPath)
        context.strokePath()
        context.addPath(innerCutoutPath)
        context.strokePath()
        context.addPath(leftFlourishPath)
        context.strokePath()
    }

    context.restoreGState()
}

func drawFullColorLogo(state: AwakeLogoState, in rect: NSRect) {
    let backgroundColor: NSColor
    switch state {
    case .off:
        backgroundColor = NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.25, alpha: 1.0)
    case .on:
        backgroundColor = NSColor(calibratedRed: 0.97, green: 0.70, blue: 0.22, alpha: 1.0)
    }

    drawRoundedBackground(in: rect, fill: backgroundColor)
    drawLetterA(state: state, in: rect, color: .white, outlineWidth: max(rect.width * 0.075, 4.0))
}

func drawTemplateStatusIcon(state: AwakeLogoState, in rect: NSRect) {
    drawLetterA(state: state, in: rect, color: .black, outlineWidth: max(rect.width * 0.11, 2.0))
}

let iconsetSizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, filename) in iconsetSizes {
    try writePNG(size: size, url: iconsetDirectory.appendingPathComponent(filename)) { rect in
        drawFullColorLogo(state: .off, in: rect)
    }
}

try writePNG(size: 1024, url: outputDirectory.appendingPathComponent("AppIcon.png")) { rect in
    drawFullColorLogo(state: .off, in: rect)
}

try writePNG(size: 384, url: outputDirectory.appendingPathComponent("NotificationOff.png")) { rect in
    drawFullColorLogo(state: .off, in: rect)
}

try writePNG(size: 384, url: outputDirectory.appendingPathComponent("NotificationOn.png")) { rect in
    drawFullColorLogo(state: .on, in: rect)
}

try writePNG(size: 36, url: outputDirectory.appendingPathComponent("StatusOffTemplate.png")) { rect in
    drawTemplateStatusIcon(state: .off, in: rect)
}

try writePNG(size: 36, url: outputDirectory.appendingPathComponent("StatusOnTemplate.png")) { rect in
    drawTemplateStatusIcon(state: .on, in: rect)
}
