#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics

// Genera tutte le risoluzioni dell'icona HelpMe («Sotto lo stesso tetto»)
// per macOS e iPadOS/iOS all'interno di Helpme/Assets.xcassets/AppIcon.appiconset/

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardized
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let iconsetDir = projectRoot.appendingPathComponent("Helpme/Assets.xcassets/AppIcon.appiconset")

try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Impossibile creare il CGContext per dimensione \(size)")
    }

    // Origine in alto a sinistra (conforme a SVG e coordinate standard)
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1.0, y: -1.0)

    let s = CGFloat(size)

    // 1. Fondo: quadrato con angoli arrotondati (58/256 ≈ 0.2266), verde istituzionale #1E4620
    let cornerRadius = max(2.0, s * 0.2266)
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(bgPath)
    context.setFillColor(red: 30.0 / 255.0, green: 70.0 / 255.0, blue: 32.0 / 255.0, alpha: 1.0)
    context.fillPath()

    // 2. Tetto a spiovente con correzione ottica dell'opacità e dello spessore
    let alphaTetto: CGFloat
    if size >= 128 {
        alphaTetto = 107.0 / 255.0 // ~42%
    } else if size >= 48 {
        alphaTetto = 153.0 / 255.0 // ~60%
    } else if size >= 32 {
        alphaTetto = 190.0 / 255.0 // ~75%
    } else {
        alphaTetto = 235.0 / 255.0 // ~92% per massima nitidezza
    }

    let spessoreTetto: CGFloat
    if size >= 128 {
        spessoreTetto = s * (24.0 / 256.0)
    } else if size >= 64 {
        spessoreTetto = s * 0.10
    } else if size >= 32 {
        spessoreTetto = 3.5
    } else if size >= 24 {
        spessoreTetto = 2.8
    } else {
        spessoreTetto = 2.0
    }

    var pX1 = s * (44.0 / 256.0)
    var pY1 = s * (134.0 / 256.0)
    var pX2 = s * 0.5
    var pY2 = s * (62.0 / 256.0)
    var pX3 = s * (212.0 / 256.0)
    var pY3 = s * (134.0 / 256.0)

    if size <= 16 {
        pX1 = 2.5;  pY1 = 8.5
        pX2 = 8.0;  pY2 = 3.5
        pX3 = 13.5; pY3 = 8.5
    } else if size <= 24 {
        pX1 = 4.0;  pY1 = 13.0
        pX2 = 12.0; pY2 = 5.8
        pX3 = 20.0; pY3 = 13.0
    }

    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(spessoreTetto)
    // Colore Carta #F8FAF9 con trasparenza
    context.setStrokeColor(red: 248.0 / 255.0, green: 250.0 / 255.0, blue: 249.0 / 255.0, alpha: alphaTetto)
    context.beginPath()
    context.move(to: CGPoint(x: pX1, y: pY1))
    context.addLine(to: CGPoint(x: pX2, y: pY2))
    context.addLine(to: CGPoint(x: pX3, y: pY3))
    context.strokePath()

    // 3. I tre punti (2 colore carta, 1 verde mela accento #4ADE80)
    let raggioPunti: CGFloat
    let cy: CGFloat
    let cx1: CGFloat
    let cx2: CGFloat
    let cx3: CGFloat

    if size >= 128 {
        raggioPunti = s * (19.5 / 256.0)
        cy = s * (180.0 / 256.0)
        cx1 = s * (86.0 / 256.0)
        cx2 = s * (128.0 / 256.0)
        cx3 = s * (170.0 / 256.0)
    } else if size >= 48 {
        raggioPunti = s * 0.075
        cy = s * 0.70
        cx1 = s * 0.33
        cx2 = s * 0.50
        cx3 = s * 0.67
    } else if size >= 32 {
        raggioPunti = 2.3
        cy = 22.5
        cx1 = 10.0
        cx2 = 16.0
        cx3 = 22.0
    } else if size >= 24 {
        raggioPunti = 1.7
        cy = 17.0
        cx1 = 7.5
        cx2 = 12.0
        cx3 = 16.5
    } else {
        raggioPunti = 1.35
        cy = 12.0
        cx1 = 5.0
        cx2 = 8.0
        cx3 = 11.0
    }

    // Punti 1 e 2: Colore Carta #F8FAF9
    context.setFillColor(red: 248.0 / 255.0, green: 250.0 / 255.0, blue: 249.0 / 255.0, alpha: 1.0)
    context.fillEllipse(in: CGRect(x: cx1 - raggioPunti, y: cy - raggioPunti, width: raggioPunti * 2, height: raggioPunti * 2))
    context.fillEllipse(in: CGRect(x: cx2 - raggioPunti, y: cy - raggioPunti, width: raggioPunti * 2, height: raggioPunti * 2))

    // Punto 3: Verde mela #4ADE80 (inclusione)
    context.setFillColor(red: 74.0 / 255.0, green: 222.0 / 255.0, blue: 128.0 / 255.0, alpha: 1.0)
    context.fillEllipse(in: CGRect(x: cx3 - raggioPunti, y: cy - raggioPunti, width: raggioPunti * 2, height: raggioPunti * 2))

    guard let cgImage = context.makeImage() else { fatalError("Make image fallito per dimensione \(size)") }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Generazione PNG fallita per dimensione \(size)")
    }
    return pngData
}

// Mappatura risoluzioni per macOS e universal iOS
let iconSpecs: [(filename: String, pixelSize: Int)] = [
    ("AppIcon-16.png", 16),
    ("AppIcon-16@2x.png", 32),
    ("AppIcon-32.png", 32),
    ("AppIcon-32@2x.png", 64),
    ("AppIcon-128.png", 128),
    ("AppIcon-128@2x.png", 256),
    ("AppIcon-256.png", 256),
    ("AppIcon-256@2x.png", 512),
    ("AppIcon-512.png", 512),
    ("AppIcon-512@2x.png", 1024),
    ("AppIcon-1024.png", 1024)
]

for spec in iconSpecs {
    let png = drawIcon(size: spec.pixelSize)
    let destURL = iconsetDir.appendingPathComponent(spec.filename)
    try png.write(to: destURL)
    print("✓ Generata icona \(spec.filename) (\(spec.pixelSize)x\(spec.pixelSize) px)")
}

// Contents.json per AppIcon.appiconset
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "AppIcon-16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "AppIcon-32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "AppIcon-128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "AppIcon-256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "AppIcon-512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "AppIcon-512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsURL = iconsetDir.appendingPathComponent("Contents.json")
try contentsJSON.write(to: contentsURL, atomically: true, encoding: .utf8)
print("✓ Aggiornato Contents.json in \(iconsetDir.path)")
