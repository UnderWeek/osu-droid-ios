import SpriteKit

/// Renders a single hit circle with approach circle animation.
final class HitCircleNode: SKNode {
    private let radius: CGFloat
    private let comboNumber: Int
    private let comboColor: SKColor
    private let approachDuration: TimeInterval

    private var circleSprite: SKShapeNode!
    private var approachCircle: SKShapeNode!
    private var numberLabel: SKLabelNode!
    private var overlayCircle: SKShapeNode!

    init(radius: CGFloat, comboNumber: Int, comboColor: SKColor, approachDuration: TimeInterval) {
        self.radius = radius
        self.comboNumber = comboNumber
        self.comboColor = comboColor
        self.approachDuration = approachDuration
        super.init()
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupNodes() {
        // Main circle body
        circleSprite = SKShapeNode(circleOfRadius: radius)
        circleSprite.fillColor = comboColor
        circleSprite.strokeColor = .white
        circleSprite.lineWidth = 2
        circleSprite.alpha = 0
        addChild(circleSprite)

        // Circle overlay (white border highlight)
        overlayCircle = SKShapeNode(circleOfRadius: radius - 2)
        overlayCircle.fillColor = .clear
        overlayCircle.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        overlayCircle.lineWidth = 1
        circleSprite.addChild(overlayCircle)

        // Combo number
        numberLabel = SKLabelNode(text: "\(comboNumber)")
        numberLabel.fontName = "Menlo-Bold"
        numberLabel.fontSize = radius * 0.8
        numberLabel.fontColor = .white
        numberLabel.verticalAlignmentMode = .center
        numberLabel.horizontalAlignmentMode = .center
        circleSprite.addChild(numberLabel)

        // Approach circle (starts large, shrinks to match)
        approachCircle = SKShapeNode(circleOfRadius: radius * 3)
        approachCircle.fillColor = .clear
        approachCircle.strokeColor = comboColor
        approachCircle.lineWidth = 2.5
        approachCircle.alpha = 0
        addChild(approachCircle)
    }

    func startApproach() {
        // Fade in
        let fadeIn = SKAction.fadeIn(withDuration: min(approachDuration * 0.4, 0.4))

        circleSprite.run(fadeIn)
        approachCircle.run(fadeIn)

        // Approach circle shrinks from 3x to 1x radius
        let shrink = SKAction.scale(to: 1.0 / 3.0, duration: approachDuration)
        shrink.timingMode = .linear
        approachCircle.run(shrink)

        // Auto-remove after hit window passes (handled by GameScene)
    }

    /// Animate the circle being hit.
    func animateHit(judgement: HitJudgement) {
        approachCircle.removeAllActions()
        approachCircle.run(SKAction.fadeOut(withDuration: 0.1))

        let expand = SKAction.scale(by: 1.4, duration: 0.15)
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let group = SKAction.group([expand, fadeOut])
        let remove = SKAction.removeFromParent()
        self.run(SKAction.sequence([group, remove]))
    }

    /// Animate a miss.
    func animateMiss() {
        approachCircle.removeAllActions()
        approachCircle.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))

        let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 0.3)
        let shrink = SKAction.scale(to: 0.8, duration: 0.3)
        let group = SKAction.group([fadeOut, shrink])
        let remove = SKAction.removeFromParent()
        self.run(SKAction.sequence([group, remove]))
    }
}
