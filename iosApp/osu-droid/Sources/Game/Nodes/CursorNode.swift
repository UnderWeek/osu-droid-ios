import SpriteKit

/// Player cursor with trail effect.
final class CursorNode: SKNode {
    private var cursorSprite: SKShapeNode!
    private var trailEmitter: SKEmitterNode?
    private var trailPoints: [CGPoint] = []

    private let maxTrailLength = 20
    private var trailNodes: [SKShapeNode] = []

    override init() {
        super.init()
        setupCursor()
        setupTrail()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCursor() {
        // Main cursor circle
        cursorSprite = SKShapeNode(circleOfRadius: 12)
        cursorSprite.fillColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.9)
        cursorSprite.strokeColor = .white
        cursorSprite.lineWidth = 2
        cursorSprite.zPosition = 200
        cursorSprite.alpha = 0

        // Inner glow
        let innerGlow = SKShapeNode(circleOfRadius: 6)
        innerGlow.fillColor = .white
        innerGlow.strokeColor = .clear
        innerGlow.alpha = 0.8
        cursorSprite.addChild(innerGlow)

        addChild(cursorSprite)
    }

    private func setupTrail() {
        // Pre-create trail nodes for reuse
        for i in 0..<maxTrailLength {
            let node = SKShapeNode(circleOfRadius: CGFloat(12 - i) * 0.5 + 2)
            node.fillColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: CGFloat(maxTrailLength - i) / CGFloat(maxTrailLength) * 0.4)
            node.strokeColor = .clear
            node.zPosition = 199
            node.alpha = 0
            addChild(node)
            trailNodes.append(node)
        }
    }

    func show() {
        cursorSprite.run(SKAction.fadeIn(withDuration: 0.05))
    }

    func hide() {
        cursorSprite.run(SKAction.fadeOut(withDuration: 0.1))
        // Fade trail
        for node in trailNodes {
            node.run(SKAction.fadeOut(withDuration: 0.2))
        }
        trailPoints.removeAll()
    }

    func updatePosition(_ newPosition: CGPoint) {
        let previousPosition = position
        position = newPosition

        // Add to trail
        trailPoints.insert(previousPosition, at: 0)
        if trailPoints.count > maxTrailLength {
            trailPoints.removeLast()
        }

        // Update trail nodes
        for (i, trailNode) in trailNodes.enumerated() {
            if i < trailPoints.count {
                // Trail nodes are children of self, so convert to local coordinates
                trailNode.position = CGPoint(
                    x: trailPoints[i].x - newPosition.x,
                    y: trailPoints[i].y - newPosition.y
                )
                trailNode.alpha = CGFloat(trailPoints.count - i) / CGFloat(trailPoints.count) * 0.4
            } else {
                trailNode.alpha = 0
            }
        }
    }
}
