#!/usr/bin/env swift
//
// generate-proof-photo-large-fixture.swift
//
// Generates a deterministic 4032×3024 JPEG fixture for the Pass 4
// ProofPhoto rendering scenarios. The fixture must be high-entropy enough
// to represent a real iPhone photo for image decode/render measurement
// (Pass 4 plan section A: minimum 3MB JPEG, preferably 4-8MB).
//
// Output: Projects/Feature/ProofPhoto/Example/Resources/proof-photo-prefilled-large.jpg
//
// Re-run after changing parameters:
//     swift Scripts/generate-proof-photo-large-fixture.swift
//
// Content design (deterministic, no RNG):
//   - Per-pixel hash-derived noise on top of a vertical color gradient.
//   - Diagonal grid overlay for additional high-frequency detail.
//   - Color bands per region to keep the image visually identifiable
//     (not pure static), while staying high-entropy enough that JPEG
//     compression at q=0.85 lands in the 3-8MB target.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width = 4032
let height = 3024
let outputDir = "Projects/Feature/ProofPhoto/Example/Resources"
let jpegQuality: CGFloat = 0.85

// Two variants: "large" (initial) and "large-second" (reselect). Same
// dimensions / generation method, different coordinate seed so the byte
// content differs. Re-select scenario must show a different image after
// dispatch to prove the production action replaces state.imageData.
let variants: [(name: String, offset: Int)] = [
    ("proof-photo-prefilled-large", 0),
    ("proof-photo-prefilled-large-second", 1_000_003)
]

let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel
let bufferSize = bytesPerRow * height

func generate(name: String, offset: Int) {
    guard let buffer = malloc(bufferSize)?.assumingMemoryBound(to: UInt8.self) else {
        fputs("malloc failed for buffer\n", stderr)
        exit(1)
    }
    defer { free(buffer) }

    // Deterministic per-pixel content. The xorshift-like mix gives
    // high-entropy noise that resists JPEG compression. Mixed with a
    // gradient + diagonal bands so the result is still visually structured.
    for y in 0..<height {
        let yNorm = Double(y) / Double(height)
        let baseR = 0.20 + yNorm * 0.55
        let baseG = 0.40 - yNorm * 0.15
        let baseB = 0.80 - yNorm * 0.45
        for x in 0..<width {
            let pixelIndex = y * bytesPerRow + x * bytesPerPixel

            var h = UInt64((x + offset) &* 374761393 &+ y &* 668265263)
            h ^= h &>> 13
            h = h &* 1274126177
            h ^= h &>> 16
            let n = Double(h & 0xFF) / 255.0

            let band = sin((Double(x + y + offset) / 32.0)) * 0.5 + 0.5
            let r = (baseR * 0.5 + band * 0.2 + n * 0.3).clamped()
            let g = (baseG * 0.5 + band * 0.25 + n * 0.25).clamped()
            let b = (baseB * 0.5 + band * 0.15 + n * 0.35).clamped()

            buffer[pixelIndex + 0] = UInt8(r * 255.0)
            buffer[pixelIndex + 1] = UInt8(g * 255.0)
            buffer[pixelIndex + 2] = UInt8(b * 255.0)
            buffer[pixelIndex + 3] = 0xFF
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo: UInt32 = CGImageAlphaInfo.noneSkipLast.rawValue
        | CGBitmapInfo.byteOrder32Big.rawValue

    guard let context = CGContext(
        data: buffer,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fputs("CGContext create failed\n", stderr)
        exit(1)
    }

    guard let cgImage = context.makeImage() else {
        fputs("CGContext.makeImage failed\n", stderr)
        exit(1)
    }

    let outputPath = "\(outputDir)/\(name).jpg"
    let outputURL = URL(fileURLWithPath: outputPath)
    try? FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ) else {
        fputs("CGImageDestination create failed\n", stderr)
        exit(1)
    }

    let properties: CFDictionary = [
        kCGImageDestinationLossyCompressionQuality: jpegQuality
    ] as CFDictionary

    CGImageDestinationAddImage(destination, cgImage, properties)
    guard CGImageDestinationFinalize(destination) else {
        fputs("JPEG finalize failed\n", stderr)
        exit(1)
    }

    let attrs = try! FileManager.default.attributesOfItem(atPath: outputPath)
    let bytes = attrs[.size] as? Int ?? 0
    let mib = Double(bytes) / 1024.0 / 1024.0
    print(String(format: "wrote %@ — %d bytes (%.2f MiB), %dx%d, q=%.2f",
                  outputPath, bytes, mib, width, height, jpegQuality))
}

for variant in variants {
    generate(name: variant.name, offset: variant.offset)
}

extension Double {
    fileprivate func clamped() -> Double {
        return Swift.min(1.0, Swift.max(0.0, self))
    }
}
