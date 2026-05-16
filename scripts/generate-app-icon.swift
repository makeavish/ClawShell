#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let source = resources.appendingPathComponent("AgentWake-Source.png", isDirectory: false)
let iconset = resources.appendingPathComponent("AgentWake.iconset", isDirectory: true)
let icns = resources.appendingPathComponent("AgentWake.icns", isDirectory: false)
let preview = resources.appendingPathComponent("AgentWake-Icon.png", isDirectory: false)

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

guard FileManager.default.fileExists(atPath: source.path) else {
    throw NSError(
        domain: "AgentWakeIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing icon source: \(source.path)"]
    )
}

guard let sourceImage = NSImage(contentsOf: source) else {
    throw NSError(
        domain: "AgentWakeIcon",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Unable to read icon source: \(source.path)"]
    )
}
guard let sourceData = sourceImage.tiffRepresentation,
      let sourceRep = NSBitmapImageRep(data: sourceData) else {
    throw NSError(
        domain: "AgentWakeIcon",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Unable to decode icon source: \(source.path)"]
    )
}
let sourcePixels = NSSize(width: sourceRep.pixelsWide, height: sourceRep.pixelsHigh)
let canonicalSource = NSImage(size: sourcePixels)
canonicalSource.addRepresentation(sourceRep)

func savePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AgentWakeIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to render PNG"])
    }
    try png.write(to: url, options: .atomic)
}

func render(size: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
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
    )!
    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    canonicalSource.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: sourcePixels),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

let iconFiles: [(name: String, size: Int)] = [
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

for iconFile in iconFiles {
    try savePNG(render(size: iconFile.size), to: iconset.appendingPathComponent(iconFile.name))
}
try savePNG(render(size: 1024), to: preview)

if FileManager.default.fileExists(atPath: icns.path) {
    try FileManager.default.removeItem(at: icns)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "AgentWakeIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Wrote \(icns.path)")
