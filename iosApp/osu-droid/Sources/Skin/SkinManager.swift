import Foundation
import SpriteKit
import SwiftUI

/// Manages osu! skin loading, caching, and fallback to default assets.
final class SkinManager: ObservableObject {
    static let shared = SkinManager()

    @Published var currentSkinName: String = "default"
    @Published var availableSkins: [String] = ["default"]

    /// Cached textures for the current skin.
    private var textureCache: [String: SKTexture] = [:]

    /// Skin configuration from skin.ini.
    private(set) var skinConfig = SkinConfig()

    private init() {
        loadAvailableSkins()
    }

    // MARK: - Skin Discovery

    func loadAvailableSkins() {
        let fm = FileManager.default
        let skinsDir = StorageManager.shared.skinsDirectory

        var skins = ["default"]
        if let contents = try? fm.contentsOfDirectory(atPath: skinsDir) {
            for dir in contents {
                let path = "\(skinsDir)/\(dir)"
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    skins.append(dir)
                }
            }
        }
        availableSkins = skins
    }

    // MARK: - Skin Loading

    func loadSkin(name: String) {
        textureCache.removeAll()
        currentSkinName = name

        if name == "default" {
            skinConfig = SkinConfig()
            return
        }

        let skinDir = "\(StorageManager.shared.skinsDirectory)/\(name)"
        let iniPath = "\(skinDir)/skin.ini"

        if FileManager.default.fileExists(atPath: iniPath) {
            skinConfig = parseSkinINI(path: iniPath)
        } else {
            skinConfig = SkinConfig()
        }
    }

    // MARK: - Texture Loading

    /// Get a texture by element name. Checks skin directory first, falls back to assets.
    func texture(for elementName: String) -> SKTexture {
        if let cached = textureCache[elementName] {
            return cached
        }

        let texture = loadTexture(name: elementName)
        textureCache[elementName] = texture
        return texture
    }

    private func loadTexture(name: String) -> SKTexture {
        // Try skin directory first (if not default)
        if currentSkinName != "default" {
            let skinDir = "\(StorageManager.shared.skinsDirectory)/\(currentSkinName)"
            for ext in ["png", "jpg"] {
                // Try @2x first for retina
                let path2x = "\(skinDir)/\(name)@2x.\(ext)"
                if FileManager.default.fileExists(atPath: path2x),
                   let image = UIImage(contentsOfFile: path2x) {
                    return SKTexture(image: image)
                }

                let path = "\(skinDir)/\(name).\(ext)"
                if FileManager.default.fileExists(atPath: path),
                   let image = UIImage(contentsOfFile: path) {
                    return SKTexture(image: image)
                }
            }
        }

        // Fall back to bundled assets
        if let image = UIImage(named: name) {
            return SKTexture(image: image)
        }

        // Generate placeholder
        return generatePlaceholderTexture(name: name)
    }

    /// Get a hitsound audio file path. Checks skin directory first, falls back to assets.
    func hitSoundPath(for name: String) -> String? {
        if currentSkinName != "default" {
            let skinDir = "\(StorageManager.shared.skinsDirectory)/\(currentSkinName)"
            for ext in ["wav", "ogg", "mp3"] {
                let path = "\(skinDir)/\(name).\(ext)"
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
        }

        // Fall back to bundled SFX
        return Bundle.main.path(forResource: name, ofType: "ogg", inDirectory: "SFX")
            ?? Bundle.main.path(forResource: name, ofType: "wav", inDirectory: "SFX")
    }

    // MARK: - Beatmap Skin Support

    /// Load textures from beatmap directory (beatmap-specific skin elements).
    func loadBeatmapSkin(directoryPath: String) {
        // Beatmap skins override current skin for specific elements
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directoryPath) else { return }

        let skinElements = files.filter { $0.hasSuffix(".png") || $0.hasSuffix(".jpg") }
        for file in skinElements {
            let name = (file as NSString).deletingPathExtension
                .replacingOccurrences(of: "@2x", with: "")
            let path = "\(directoryPath)/\(file)"
            if let image = UIImage(contentsOfFile: path) {
                textureCache["beatmap_\(name)"] = SKTexture(image: image)
            }
        }
    }

    // MARK: - skin.ini Parsing

    private func parseSkinINI(path: String) -> SkinConfig {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return SkinConfig()
        }

        var config = SkinConfig()
        var currentSection = ""

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                continue
            }

            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            switch currentSection {
            case "General":
                switch key {
                case "Name": config.name = value
                case "Author": config.author = value
                case "CursorExpand": config.cursorExpand = value == "1"
                case "CursorTrailRotate": config.cursorTrailRotate = value == "1"
                case "SliderBallFlip": config.sliderBallFlip = value == "1"
                default: break
                }

            case "Colours":
                if key.hasPrefix("Combo") {
                    let rgb = value.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    if rgb.count >= 3 {
                        config.comboColors.append(
                            SKColor(red: CGFloat(rgb[0]) / 255.0,
                                   green: CGFloat(rgb[1]) / 255.0,
                                   blue: CGFloat(rgb[2]) / 255.0,
                                   alpha: 1.0)
                        )
                    }
                }

            case "Fonts":
                if key == "HitCirclePrefix" { config.hitCirclePrefix = value }
                if key == "ScorePrefix" { config.scorePrefix = value }
                if key == "HitCircleOverlap" { config.hitCircleOverlap = Int(value) ?? 0 }

            default: break
            }
        }

        return config
    }

    // MARK: - Placeholder

    private func generatePlaceholderTexture(name: String) -> SKTexture {
        let size = CGSize(width: 64, height: 64)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.gray.withAlphaComponent(0.3).setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return SKTexture(image: image)
    }
}

// MARK: - Skin Config

struct SkinConfig {
    var name: String = "default"
    var author: String = ""
    var cursorExpand: Bool = true
    var cursorTrailRotate: Bool = false
    var sliderBallFlip: Bool = false
    var comboColors: [SKColor] = []
    var hitCirclePrefix: String = "default"
    var scorePrefix: String = "score"
    var hitCircleOverlap: Int = -2
}
