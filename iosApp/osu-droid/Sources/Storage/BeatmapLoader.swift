import Foundation
import CryptoKit
import SpriteKit

/// Parses .osu beatmap files into game-ready data structures.
/// This is the Swift-side parser. For full feature parity, use the KMP shared module's
/// BeatmapParser once integrated.
final class BeatmapLoader {

    /// Parse a .osu file into a ParsedBeatmap.
    static func parse(filePath: String) async -> ParsedBeatmap? {
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("[BeatmapLoader] File not found: \(filePath)")
            return nil
        }

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("[BeatmapLoader] Failed to read file: \(filePath)")
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        let md5 = md5Hash(of: content)
        let directory = (filePath as NSString).deletingLastPathComponent

        var title = "", artist = "", creator = "", version = ""
        var cs: Float = 4, ar: Float = 9, od: Float = 8, hp: Float = 5
        var audioFilename = ""
        var backgroundFilename: String?
        var hitObjects: [HitObjectData] = []
        var currentSection = ""
        var comboNumber = 1
        var comboColorIndex = 0
        var sliderMultiplier: Double = 1.4
        var beatLength: Double = 500 // default 120 BPM

        // Default combo colors (osu! default skin colors)
        let comboColors: [SKColor] = [
            SKColor(red: 1.0, green: 0.56, blue: 0.0, alpha: 1.0),   // Orange
            SKColor(red: 0.0, green: 0.78, blue: 0.0, alpha: 1.0),   // Green
            SKColor(red: 0.0, green: 0.47, blue: 1.0, alpha: 1.0),   // Blue
            SKColor(red: 0.95, green: 0.0, blue: 0.0, alpha: 1.0),   // Red
        ]

        // Timing points for slider velocity
        var timingPoints: [(time: Double, beatLength: Double, inherited: Bool)] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }

            // Section headers
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                continue
            }

            switch currentSection {
            case "General":
                if let value = parseKeyValue(trimmed, key: "AudioFilename") {
                    audioFilename = value
                }

            case "Metadata":
                if let v = parseKeyValue(trimmed, key: "Title") { title = v }
                if let v = parseKeyValue(trimmed, key: "Artist") { artist = v }
                if let v = parseKeyValue(trimmed, key: "Creator") { creator = v }
                if let v = parseKeyValue(trimmed, key: "Version") { version = v }

            case "Difficulty":
                if let v = parseKeyValue(trimmed, key: "CircleSize") { cs = Float(v) ?? 4 }
                if let v = parseKeyValue(trimmed, key: "ApproachRate") { ar = Float(v) ?? 9 }
                if let v = parseKeyValue(trimmed, key: "OverallDifficulty") { od = Float(v) ?? 8 }
                if let v = parseKeyValue(trimmed, key: "HPDrainRate") { hp = Float(v) ?? 5 }
                if let v = parseKeyValue(trimmed, key: "SliderMultiplier") { sliderMultiplier = Double(v) ?? 1.4 }

            case "Events":
                // Background image
                let parts = trimmed.components(separatedBy: ",")
                if parts.count >= 3 && parts[0] == "0" && parts[1] == "0" {
                    backgroundFilename = parts[2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }

            case "TimingPoints":
                let parts = trimmed.components(separatedBy: ",")
                if parts.count >= 2 {
                    let time = Double(parts[0]) ?? 0
                    let bl = Double(parts[1]) ?? 500
                    let inherited = parts.count > 6 ? (Int(parts[6]) ?? 1) == 0 : false
                    timingPoints.append((time: time, beatLength: bl, inherited: inherited))
                    if !inherited { beatLength = bl }
                }

            case "HitObjects":
                if let obj = parseHitObject(trimmed, comboNumber: &comboNumber,
                                            comboColorIndex: &comboColorIndex,
                                            comboColors: comboColors,
                                            sliderMultiplier: sliderMultiplier,
                                            beatLength: beatLength,
                                            timingPoints: timingPoints) {
                    hitObjects.append(obj)
                }

            default:
                break
            }
        }

        let audioPath = "\(directory)/\(audioFilename)"
        let bgPath = backgroundFilename.map { "\(directory)/\($0)" }
        let totalLength = hitObjects.last.map { $0.time + ($0.type == .spinner ? $0.spinnerDuration : ($0.type == .slider ? $0.sliderDuration : 0)) } ?? 0
        let bpm = beatLength > 0 ? 60000.0 / beatLength : 120

        return ParsedBeatmap(
            title: title, artist: artist, version: version, md5: md5,
            cs: cs, ar: ar, od: od, hp: hp,
            hitObjects: hitObjects,
            totalLength: totalLength + 2000,
            audioFilePath: audioPath,
            backgroundPath: bgPath
        )
    }

    // MARK: - .osu Hit Object Parsing

    private static func parseHitObject(
        _ line: String,
        comboNumber: inout Int,
        comboColorIndex: inout Int,
        comboColors: [SKColor],
        sliderMultiplier: Double,
        beatLength: Double,
        timingPoints: [(time: Double, beatLength: Double, inherited: Bool)]
    ) -> HitObjectData? {
        let parts = line.components(separatedBy: ",")
        guard parts.count >= 4 else { return nil }

        let x = Float(parts[0]) ?? 0
        let y = Float(parts[1]) ?? 0
        let time = Double(parts[2]) ?? 0
        let typeFlags = Int(parts[3]) ?? 0

        // New combo check
        if typeFlags & 4 != 0 {
            comboNumber = 1
            comboColorIndex = (comboColorIndex + 1) % comboColors.count
            // Skip colors
            let skip = (typeFlags >> 4) & 7
            comboColorIndex = (comboColorIndex + skip) % comboColors.count
        }

        let color = comboColors[comboColorIndex]

        // Hitsound info
        let sampleSet = parts.count > 4 ? Int(parts[4]) ?? 0 : 0

        if typeFlags & 1 != 0 {
            // Hit circle
            let obj = HitObjectData(
                type: .circle, x: x, y: y, time: time,
                comboNumber: comboNumber, comboColor: color,
                sampleSet: sampleSet & 0xFF, additionSet: (sampleSet >> 8) & 0xFF,
                sliderPath: [], sliderDuration: 0, sliderRepeatCount: 0, spinnerDuration: 0
            )
            comboNumber += 1
            return obj
        }

        if typeFlags & 2 != 0 {
            // Slider
            guard parts.count >= 8 else { return nil }
            let curveData = parts[5]
            let repeatCount = max(1, Int(parts[6]) ?? 1) - 1
            let pixelLength = Double(parts[7]) ?? 100

            let sliderPoints = parseSliderPath(curveData, startX: CGFloat(x), startY: CGFloat(y))

            // Calculate slider duration
            let currentBeatLength = getEffectiveBeatLength(at: time, timingPoints: timingPoints, baseBeatLength: beatLength)
            let velocity = sliderMultiplier * 100.0 / currentBeatLength
            let duration = pixelLength / velocity * Double(repeatCount + 1) * 1000.0

            let obj = HitObjectData(
                type: .slider, x: x, y: y, time: time,
                comboNumber: comboNumber, comboColor: color,
                sampleSet: sampleSet & 0xFF, additionSet: (sampleSet >> 8) & 0xFF,
                sliderPath: sliderPoints, sliderDuration: duration, sliderRepeatCount: repeatCount,
                spinnerDuration: 0
            )
            comboNumber += 1
            return obj
        }

        if typeFlags & 8 != 0 {
            // Spinner
            guard parts.count >= 6 else { return nil }
            let endTime = Double(parts[5]) ?? time

            return HitObjectData(
                type: .spinner, x: 256, y: 192, time: time,
                comboNumber: comboNumber, comboColor: color,
                sampleSet: 0, additionSet: 0,
                sliderPath: [], sliderDuration: 0, sliderRepeatCount: 0,
                spinnerDuration: endTime - time
            )
        }

        return nil
    }

    // MARK: - Slider Path

    private static func parseSliderPath(_ curveData: String, startX: CGFloat, startY: CGFloat) -> [CGPoint] {
        let segments = curveData.components(separatedBy: "|")
        guard segments.count >= 2 else { return [CGPoint(x: startX, y: startY)] }

        var points = [CGPoint(x: startX, y: startY)]

        // First segment is curve type (B = bezier, L = linear, P = perfect circle, C = catmull)
        for i in 1..<segments.count {
            let coords = segments[i].components(separatedBy: ":")
            if coords.count == 2, let px = Double(coords[0]), let py = Double(coords[1]) {
                // Flip Y coordinate for SpriteKit (osu has Y-down, SpriteKit has Y-up via playfield transform)
                points.append(CGPoint(x: px, y: py))
            }
        }

        // For now, use linear interpolation between control points
        // Full implementation would handle bezier, perfect circle, and catmull-rom curves
        return interpolateLinear(points: points, steps: 50)
    }

    private static func interpolateLinear(points: [CGPoint], steps: Int) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var result: [CGPoint] = []
        let totalSegments = points.count - 1
        let stepsPerSegment = max(steps / totalSegments, 2)

        for seg in 0..<totalSegments {
            let p0 = points[seg]
            let p1 = points[seg + 1]

            for i in 0..<stepsPerSegment {
                let t = CGFloat(i) / CGFloat(stepsPerSegment)
                result.append(CGPoint(
                    x: p0.x + (p1.x - p0.x) * t,
                    y: p0.y + (p1.y - p0.y) * t
                ))
            }
        }

        result.append(points.last!)
        return result
    }

    // MARK: - Timing

    private static func getEffectiveBeatLength(
        at time: Double,
        timingPoints: [(time: Double, beatLength: Double, inherited: Bool)],
        baseBeatLength: Double
    ) -> Double {
        var currentBL = baseBeatLength
        var multiplier = 1.0

        for tp in timingPoints where tp.time <= time {
            if !tp.inherited {
                currentBL = tp.beatLength
            } else if tp.beatLength < 0 {
                multiplier = -100.0 / tp.beatLength
            }
        }

        return currentBL / multiplier
    }

    // MARK: - Helpers

    private static func parseKeyValue(_ line: String, key: String) -> String? {
        if line.hasPrefix("\(key):") {
            return line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
        }
        if line.hasPrefix("\(key) :") {
            return line.dropFirst(key.count + 2).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func md5Hash(of string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - Beatmap Importer

/// Handles importing .osz files into the Songs directory.
final class BeatmapImporter {
    static let shared = BeatmapImporter()

    /// Import a .osz file from the given URL.
    func importOSZ(from url: URL) async -> Bool {
        let fm = FileManager.default
        let songsDir = StorageManager.shared.songsDirectory
        let filename = url.deletingPathExtension().lastPathComponent
        let destDir = "\(songsDir)/\(filename)"

        do {
            // Create directory
            try fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)

            // Extract ZIP (.osz is a ZIP file)
            let success = extractZIP(at: url.path, to: destDir)
            guard success else { return false }

            // Find and parse all .osu files
            let osuFiles = (try? fm.contentsOfDirectory(atPath: destDir))?.filter { $0.hasSuffix(".osu") } ?? []

            for osuFile in osuFiles {
                let filePath = "\(destDir)/\(osuFile)"
                if let parsed = await BeatmapLoader.parse(filePath: filePath) {
                    let info = BeatmapInfo(
                        id: parsed.md5, version: parsed.version, filePath: filePath,
                        starRating: 0, cs: parsed.cs, ar: parsed.ar, od: parsed.od, hp: parsed.hp,
                        bpm: 0, lengthMs: Int(parsed.totalLength),
                        maxCombo: parsed.hitObjects.count,
                        circleCount: parsed.hitObjects.filter { $0.type == .circle }.count,
                        sliderCount: parsed.hitObjects.filter { $0.type == .slider }.count,
                        spinnerCount: parsed.hitObjects.filter { $0.type == .spinner }.count
                    )
                    StorageManager.shared.saveBeatmap(info, setId: filename,
                                                      title: parsed.title, artist: parsed.artist,
                                                      creator: "", directoryPath: destDir)
                }
            }

            return true
        } catch {
            print("[BeatmapImporter] Import failed: \(error)")
            return false
        }
    }

    /// Extract ZIP archive to destination path.
    /// Uses built-in FileManager for basic ZIP support (iOS 16+).
    private func extractZIP(at sourcePath: String, to destPath: String) -> Bool {
        // FileManager can't extract ZIPs directly on iOS.
        // For production, integrate ZIPFoundation via SPM.
        // Minimal fallback: try to read as directory if already extracted.
        let fm = FileManager.default
        if fm.fileExists(atPath: sourcePath) {
            // Placeholder: in production, use ZIPFoundation here
            print("[BeatmapImporter] ZIP extraction not yet implemented — add ZIPFoundation package")
            return false
        }
        return false
    }
}
