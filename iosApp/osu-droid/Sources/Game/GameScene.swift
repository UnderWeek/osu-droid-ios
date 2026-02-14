import SpriteKit
import SwiftUI

/// Main SpriteKit scene for osu! gameplay.
/// Renders hit objects, handles touch input, manages game timing.
final class GameScene: SKScene {

    // MARK: - Constants

    /// osu! standard playfield dimensions.
    static let playfieldWidth: CGFloat = 512
    static let playfieldHeight: CGFloat = 384

    /// Stack leniency for overlapping objects.
    private let stackLeniency: Float = 0.7

    // MARK: - Game State

    private(set) var beatmapData: ParsedBeatmap?
    private var hitObjects: [HitObjectData] = []
    private var activeNodes: [Int: SKNode] = [:]

    private var currentTime: Double = 0 // milliseconds
    private var startTime: Date?
    private var audioOffset: Double = 0
    private var isPaused = false
    private var isGameActive = false

    // MARK: - Scoring

    private(set) var score: Int = 0
    private(set) var combo: Int = 0
    private(set) var maxCombo: Int = 0
    private(set) var accuracy: Double = 1.0
    private(set) var health: Double = 1.0
    private var count300: Int = 0
    private var count100: Int = 0
    private var count50: Int = 0
    private var countMiss: Int = 0

    // MARK: - Layers

    private let playfieldNode = SKNode()
    private let hitObjectLayer = SKNode()
    private let approachCircleLayer = SKNode()
    private let cursorLayer = SKNode()
    private let hudLayer = SKNode()
    private let judgementLayer = SKNode()

    // MARK: - HUD Elements

    private var scoreLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var accuracyLabel: SKLabelNode!
    private var healthBar: SKShapeNode!
    private var healthFill: SKShapeNode!
    private var progressBar: SKShapeNode!

    // MARK: - Configuration

    var circleSize: Float = 4.0
    var approachRate: Float = 9.0
    var overallDifficulty: Float = 8.0
    var hpDrain: Float = 5.0
    var activeMods: [String] = []

    // MARK: - Delegates

    weak var gameDelegate: GameSceneDelegate?

    // MARK: - Computed Properties

    /// Circle radius in osu! pixels based on CS.
    private var circleRadius: CGFloat {
        CGFloat(54.4 - 4.48 * circleSize)
    }

    /// Scale factor to map osu! playfield to screen.
    private var playfieldScale: CGFloat {
        min(size.width / GameScene.playfieldWidth, size.height / GameScene.playfieldHeight) * 0.85
    }

    /// Approach rate in milliseconds (time the approach circle is visible).
    private var approachDuration: Double {
        if approachRate < 5 {
            return 1200.0 + 600.0 * (5.0 - Double(approachRate)) / 5.0
        } else if approachRate > 5 {
            return 1200.0 - 750.0 * (Double(approachRate) - 5.0) / 5.0
        }
        return 1200.0
    }

    /// Hit window for 300 (Great) in milliseconds.
    private var hitWindow300: Double { 80.0 - 6.0 * Double(overallDifficulty) }
    /// Hit window for 100 (Good) in milliseconds.
    private var hitWindow100: Double { 140.0 - 8.0 * Double(overallDifficulty) }
    /// Hit window for 50 (Meh) in milliseconds.
    private var hitWindow50: Double { 200.0 - 10.0 * Double(overallDifficulty) }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        setupLayers()
        setupHUD()
    }

    private func setupLayers() {
        // Center playfield
        playfieldNode.position = CGPoint(
            x: size.width / 2 - (GameScene.playfieldWidth * playfieldScale) / 2,
            y: size.height / 2 - (GameScene.playfieldHeight * playfieldScale) / 2
        )
        playfieldNode.setScale(playfieldScale)
        addChild(playfieldNode)

        playfieldNode.addChild(hitObjectLayer)
        playfieldNode.addChild(approachCircleLayer)
        playfieldNode.addChild(judgementLayer)
        addChild(cursorLayer)
        addChild(hudLayer)
    }

    private func setupHUD() {
        // Score
        scoreLabel = SKLabelNode(text: "00000000")
        scoreLabel.fontName = "Menlo-Bold"
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width - 20, y: size.height - 40)
        hudLayer.addChild(scoreLabel)

        // Accuracy
        accuracyLabel = SKLabelNode(text: "100.00%")
        accuracyLabel.fontName = "Menlo"
        accuracyLabel.fontSize = 16
        accuracyLabel.fontColor = .white
        accuracyLabel.horizontalAlignmentMode = .right
        accuracyLabel.position = CGPoint(x: size.width - 20, y: size.height - 65)
        hudLayer.addChild(accuracyLabel)

        // Combo
        comboLabel = SKLabelNode(text: "0x")
        comboLabel.fontName = "Menlo-Bold"
        comboLabel.fontSize = 28
        comboLabel.fontColor = .white
        comboLabel.horizontalAlignmentMode = .left
        comboLabel.verticalAlignmentMode = .bottom
        comboLabel.position = CGPoint(x: 20, y: 20)
        hudLayer.addChild(comboLabel)

        // Health bar
        let healthWidth: CGFloat = size.width * 0.4
        let healthHeight: CGFloat = 8
        let healthX: CGFloat = size.width / 2 - healthWidth / 2
        let healthY: CGFloat = size.height - 20

        healthBar = SKShapeNode(rect: CGRect(x: healthX, y: healthY, width: healthWidth, height: healthHeight), cornerRadius: 4)
        healthBar.fillColor = SKColor(white: 0.2, alpha: 0.5)
        healthBar.strokeColor = .clear
        hudLayer.addChild(healthBar)

        healthFill = SKShapeNode(rect: CGRect(x: healthX, y: healthY, width: healthWidth, height: healthHeight), cornerRadius: 4)
        healthFill.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.8)
        healthFill.strokeColor = .clear
        hudLayer.addChild(healthFill)

        // Progress bar
        progressBar = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 0, height: 3))
        progressBar.fillColor = SKColor(red: 0.953, green: 0.451, blue: 0.451, alpha: 0.8)
        progressBar.strokeColor = .clear
        hudLayer.addChild(progressBar)
    }

    // MARK: - Game Flow

    func loadBeatmap(_ parsed: ParsedBeatmap) {
        beatmapData = parsed
        circleSize = parsed.cs
        approachRate = parsed.ar
        overallDifficulty = parsed.od
        hpDrain = parsed.hp
        hitObjects = parsed.hitObjects.enumerated().map { index, obj in
            var data = obj
            data.index = index
            return data
        }

        // Sort by time
        hitObjects.sort { $0.time < $1.time }
    }

    func startGame() {
        score = 0
        combo = 0
        maxCombo = 0
        count300 = 0
        count100 = 0
        count50 = 0
        countMiss = 0
        health = 1.0
        accuracy = 1.0
        currentTime = 0
        isGameActive = true
        startTime = Date()

        gameDelegate?.gameDidStart()

        // Start audio via delegate
        gameDelegate?.requestAudioStart()
    }

    func pauseGame() {
        isPaused = true
        isGameActive = false
        gameDelegate?.gameDidPause()
    }

    func resumeGame() {
        isPaused = false
        isGameActive = true
        startTime = Date().addingTimeInterval(-currentTime / 1000.0)
        gameDelegate?.gameDidResume()
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard isGameActive, let startTime = startTime else { return }

        // Calculate current game time in milliseconds
        self.currentTime = Date().timeIntervalSince(startTime) * 1000.0 + audioOffset

        // Spawn approaching objects
        spawnHitObjects()

        // Check for missed objects
        checkMisses()

        // Update active objects (slider balls, spinner rotation, etc.)
        updateActiveObjects()

        // Update HUD
        updateHUD()

        // Update health drain
        updateHealthDrain()

        // Check game end
        checkGameEnd()
    }

    private func spawnHitObjects() {
        for obj in hitObjects where !obj.isSpawned && !obj.isHit && !obj.isMissed {
            let spawnTime = obj.time - approachDuration
            if self.currentTime >= spawnTime {
                spawnNode(for: obj)
                hitObjects[obj.index].isSpawned = true
            }
        }
    }

    private func spawnNode(for obj: HitObjectData) {
        let position = CGPoint(x: CGFloat(obj.x), y: GameScene.playfieldHeight - CGFloat(obj.y))

        switch obj.type {
        case .circle:
            let node = HitCircleNode(
                radius: circleRadius,
                comboNumber: obj.comboNumber,
                comboColor: obj.comboColor,
                approachDuration: approachDuration / 1000.0
            )
            node.position = position
            node.name = "hitobject_\(obj.index)"
            hitObjectLayer.addChild(node)
            activeNodes[obj.index] = node
            node.startApproach()

        case .slider:
            let node = SliderNode(
                path: obj.sliderPath,
                radius: circleRadius,
                comboNumber: obj.comboNumber,
                comboColor: obj.comboColor,
                duration: obj.sliderDuration / 1000.0,
                repeatCount: obj.sliderRepeatCount,
                approachDuration: approachDuration / 1000.0
            )
            node.position = position
            node.name = "hitobject_\(obj.index)"
            hitObjectLayer.addChild(node)
            activeNodes[obj.index] = node
            node.startApproach()

        case .spinner:
            let node = SpinnerNode(
                duration: obj.spinnerDuration / 1000.0,
                sceneSize: size
            )
            node.position = CGPoint(x: GameScene.playfieldWidth / 2, y: GameScene.playfieldHeight / 2)
            node.name = "hitobject_\(obj.index)"
            hitObjectLayer.addChild(node)
            activeNodes[obj.index] = node
        }
    }

    private func checkMisses() {
        for obj in hitObjects where obj.isSpawned && !obj.isHit && !obj.isMissed {
            if self.currentTime > obj.time + hitWindow50 {
                registerJudgement(.miss, at: obj.index)
            }
        }
    }

    private func updateActiveObjects() {
        for (index, node) in activeNodes {
            guard index < hitObjects.count else { continue }
            let obj = hitObjects[index]

            if let sliderNode = node as? SliderNode, obj.type == .slider {
                let elapsed = self.currentTime - obj.time
                sliderNode.updateSlider(elapsed: elapsed / 1000.0)
            }

            if let spinnerNode = node as? SpinnerNode, obj.type == .spinner {
                let elapsed = self.currentTime - obj.time
                spinnerNode.updateSpinner(elapsed: elapsed / 1000.0)
            }
        }
    }

    private func updateHUD() {
        scoreLabel.text = String(format: "%08d", score)
        comboLabel.text = "\(combo)x"
        accuracyLabel.text = String(format: "%.2f%%", accuracy * 100)

        // Health bar width
        let healthWidth = size.width * 0.4
        let healthX = size.width / 2 - healthWidth / 2
        let fillWidth = healthWidth * CGFloat(health)
        healthFill.path = CGPath(
            roundedRect: CGRect(x: healthX, y: size.height - 20, width: fillWidth, height: 8),
            cornerWidth: 4, cornerHeight: 4, transform: nil
        )

        let healthColor: SKColor
        if health > 0.5 {
            healthColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.8)
        } else if health > 0.2 {
            healthColor = SKColor(red: 0.8, green: 0.8, blue: 0.2, alpha: 0.8)
        } else {
            healthColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.8)
        }
        healthFill.fillColor = healthColor

        // Progress bar
        if let beatmap = beatmapData {
            let totalTime = beatmap.totalLength
            let progress = totalTime > 0 ? min(self.currentTime / totalTime, 1.0) : 0
            progressBar.path = CGPath(
                rect: CGRect(x: 0, y: 0, width: size.width * CGFloat(progress), height: 3),
                transform: nil
            )
        }
    }

    private func updateHealthDrain() {
        let drainRate = Double(hpDrain) * 0.00004
        health = max(0, health - drainRate)

        if health <= 0 && !activeMods.contains("NF") {
            // Game over
            isGameActive = false
            gameDelegate?.gameDidFail()
        }
    }

    private func checkGameEnd() {
        guard let beatmap = beatmapData else { return }
        let allProcessed = hitObjects.allSatisfy { $0.isHit || $0.isMissed }
        if allProcessed && self.currentTime > beatmap.totalLength + 1000 {
            isGameActive = false
            let finalScore = GameScore(
                beatmapId: beatmap.md5,
                score: score,
                accuracy: accuracy,
                maxCombo: maxCombo,
                count300: count300,
                count100: count100,
                count50: count50,
                countMiss: countMiss,
                mods: activeMods,
                grade: calculateGrade(),
                date: Date()
            )
            gameDelegate?.gameDidEnd(score: finalScore)
        }
    }

    // MARK: - Touch Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameActive else { return }

        for touch in touches {
            let locationInScene = touch.location(in: self)
            let locationInPlayfield = playfieldNode.convert(locationInScene, from: self)

            // Show cursor
            showCursorAt(touch.location(in: self))

            // Find closest hittable object
            if let hitIndex = findHittableObject(at: locationInPlayfield) {
                processHit(at: hitIndex, touchPosition: locationInPlayfield)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameActive else { return }

        for touch in touches {
            let locationInScene = touch.location(in: self)
            updateCursor(at: locationInScene)

            // Check slider tracking
            let locationInPlayfield = playfieldNode.convert(locationInScene, from: self)
            updateSliderTracking(at: locationInPlayfield)

            // Spinner rotation
            updateSpinnerRotation(touch: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        hideCursor()
        releaseSliders()
    }

    // MARK: - Hit Detection

    private func findHittableObject(at point: CGPoint) -> Int? {
        var closestIndex: Int?
        var closestTime = Double.infinity

        for obj in hitObjects where obj.isSpawned && !obj.isHit && !obj.isMissed {
            let timeDiff = abs(self.currentTime - obj.time)
            guard timeDiff <= hitWindow50 else { continue }

            let objPos = CGPoint(x: CGFloat(obj.x), y: GameScene.playfieldHeight - CGFloat(obj.y))
            let distance = hypot(point.x - objPos.x, point.y - objPos.y)

            if distance <= circleRadius && timeDiff < closestTime {
                closestTime = timeDiff
                closestIndex = obj.index
            }
        }

        return closestIndex
    }

    private func processHit(at index: Int, touchPosition: CGPoint) {
        let obj = hitObjects[index]
        let timeDiff = abs(self.currentTime - obj.time)

        let judgement: HitJudgement
        if timeDiff <= hitWindow300 {
            judgement = .great
        } else if timeDiff <= hitWindow100 {
            judgement = .good
        } else if timeDiff <= hitWindow50 {
            judgement = .meh
        } else {
            return // Outside hit window
        }

        registerJudgement(judgement, at: index)

        // Play hit sound
        gameDelegate?.requestHitSound(sampleSet: obj.sampleSet, addition: obj.additionSet)
    }

    // MARK: - Judgement

    private func registerJudgement(_ judgement: HitJudgement, at index: Int) {
        hitObjects[index].isHit = judgement != .miss
        hitObjects[index].isMissed = judgement == .miss

        // Remove node
        if let node = activeNodes.removeValue(forKey: index) {
            let position = node.position
            node.removeFromParent()

            // Show judgement animation
            showJudgement(judgement, at: position)
        }

        // Update scoring
        switch judgement {
        case .great:
            score += 300 * (combo + 1)
            combo += 1
            count300 += 1
            health = min(1, health + 0.04)
        case .good:
            score += 100 * (combo + 1)
            combo += 1
            count100 += 1
            health = min(1, health + 0.02)
        case .meh:
            score += 50 * (combo + 1)
            combo += 1
            count50 += 1
            health = min(1, health + 0.01)
        case .miss:
            combo = 0
            countMiss += 1
            health = max(0, health - 0.05)
        }

        maxCombo = max(maxCombo, combo)
        updateAccuracy()
    }

    private func updateAccuracy() {
        let totalHits = count300 + count100 + count50 + countMiss
        guard totalHits > 0 else { accuracy = 1.0; return }
        accuracy = Double(count300 * 300 + count100 * 100 + count50 * 50) / Double(totalHits * 300)
    }

    private func calculateGrade() -> ScoreGrade {
        let totalHits = count300 + count100 + count50 + countMiss
        guard totalHits > 0 else { return .d }

        let ratio300 = Double(count300) / Double(totalHits)
        let ratio50 = Double(count50) / Double(totalHits)

        if ratio300 == 1.0 { return .ss }
        if ratio300 > 0.9 && ratio50 <= 0.01 && countMiss == 0 { return .s }
        if (ratio300 > 0.8 && countMiss == 0) || ratio300 > 0.9 { return .a }
        if (ratio300 > 0.7 && countMiss == 0) || ratio300 > 0.8 { return .b }
        if ratio300 > 0.6 { return .c }
        return .d
    }

    // MARK: - Visual Effects

    private func showJudgement(_ judgement: HitJudgement, at position: CGPoint) {
        let label = SKLabelNode(text: judgement.text)
        label.fontName = "Menlo-Bold"
        label.fontSize = 22
        label.fontColor = judgement.color
        label.position = position
        label.zPosition = 100
        judgementLayer.addChild(label)

        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([group, remove]))
    }

    // MARK: - Cursor

    private var cursorNode: CursorNode?

    private func showCursorAt(_ position: CGPoint) {
        if cursorNode == nil {
            cursorNode = CursorNode()
            cursorLayer.addChild(cursorNode!)
        }
        cursorNode?.position = position
        cursorNode?.show()
    }

    private func updateCursor(at position: CGPoint) {
        cursorNode?.updatePosition(position)
    }

    private func hideCursor() {
        cursorNode?.hide()
    }

    // MARK: - Slider Tracking

    private func updateSliderTracking(at playfieldPoint: CGPoint) {
        for (index, node) in activeNodes {
            guard hitObjects[index].type == .slider,
                  let sliderNode = node as? SliderNode else { continue }
            sliderNode.updateTracking(cursorPosition: playfieldPoint, radius: circleRadius)
        }
    }

    private func releaseSliders() {
        for (_, node) in activeNodes {
            if let sliderNode = node as? SliderNode {
                sliderNode.releaseTracking()
            }
        }
    }

    // MARK: - Spinner

    private func updateSpinnerRotation(touch: UITouch) {
        let location = touch.location(in: playfieldNode)
        let previousLocation = touch.previousLocation(in: playfieldNode)
        let center = CGPoint(x: GameScene.playfieldWidth / 2, y: GameScene.playfieldHeight / 2)

        let angle1 = atan2(previousLocation.y - center.y, previousLocation.x - center.x)
        let angle2 = atan2(location.y - center.y, location.x - center.x)
        var delta = angle2 - angle1

        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }

        for (_, node) in activeNodes {
            if let spinnerNode = node as? SpinnerNode {
                spinnerNode.addRotation(delta)
            }
        }
    }
}

// MARK: - Delegate Protocol

protocol GameSceneDelegate: AnyObject {
    func gameDidStart()
    func gameDidPause()
    func gameDidResume()
    func gameDidFail()
    func gameDidEnd(score: GameScore)
    func requestAudioStart()
    func requestHitSound(sampleSet: Int, addition: Int)
}

// MARK: - Hit Judgement

enum HitJudgement {
    case great, good, meh, miss

    var text: String {
        switch self {
        case .great: return "300"
        case .good: return "100"
        case .meh: return "50"
        case .miss: return "MISS"
        }
    }

    var color: SKColor {
        switch self {
        case .great: return SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        case .good: return SKColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1.0)
        case .meh: return SKColor(red: 0.9, green: 0.9, blue: 0.3, alpha: 1.0)
        case .miss: return SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }
}

// MARK: - Hit Object Data

struct HitObjectData {
    var index: Int = 0
    let type: HitObjectType
    let x: Float
    let y: Float
    let time: Double // milliseconds
    let comboNumber: Int
    let comboColor: SKColor
    let sampleSet: Int
    let additionSet: Int

    // Slider-specific
    let sliderPath: [CGPoint]
    let sliderDuration: Double
    let sliderRepeatCount: Int

    // Spinner-specific
    let spinnerDuration: Double

    var isSpawned: Bool = false
    var isHit: Bool = false
    var isMissed: Bool = false
}

enum HitObjectType {
    case circle, slider, spinner
}

// MARK: - Parsed Beatmap

struct ParsedBeatmap {
    let title: String
    let artist: String
    let version: String
    let md5: String
    let cs: Float
    let ar: Float
    let od: Float
    let hp: Float
    let hitObjects: [HitObjectData]
    let totalLength: Double // milliseconds
    let audioFilePath: String
    let backgroundPath: String?
}
