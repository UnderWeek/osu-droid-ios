import SpriteKit

/// Renders a spinner with rotation tracking and progress visualization.
final class SpinnerNode: SKNode {
    private let duration: TimeInterval
    private let sceneSize: CGSize

    private var spinnerCircle: SKShapeNode!
    private var progressRing: SKShapeNode!
    private var rpmLabel: SKLabelNode!
    private var clearLabel: SKLabelNode!

    private var totalRotation: CGFloat = 0
    private var rotationsNeeded: CGFloat = 0
    private var isCleared = false

    /// Rotations per minute tracking.
    private var recentRotations: [(time: TimeInterval, angle: CGFloat)] = []
    private(set) var currentRPM: CGFloat = 0

    init(duration: TimeInterval, sceneSize: CGSize) {
        self.duration = duration
        self.sceneSize = sceneSize
        super.init()

        // Calculate rotations needed to clear (scales with duration)
        rotationsNeeded = CGFloat(duration) * 1.5

        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupNodes() {
        let screenRadius = min(sceneSize.width, sceneSize.height) * 0.3

        // Background dimming
        let dim = SKShapeNode(rectOf: CGSize(width: sceneSize.width * 2, height: sceneSize.height * 2))
        dim.fillColor = SKColor(white: 0, alpha: 0.5)
        dim.strokeColor = .clear
        dim.zPosition = -1
        addChild(dim)

        // Outer ring
        let outerRing = SKShapeNode(circleOfRadius: screenRadius)
        outerRing.fillColor = .clear
        outerRing.strokeColor = SKColor(white: 1, alpha: 0.3)
        outerRing.lineWidth = 3
        addChild(outerRing)

        // Spinner circle (rotates)
        spinnerCircle = SKShapeNode(circleOfRadius: screenRadius * 0.7)
        spinnerCircle.fillColor = .clear
        spinnerCircle.strokeColor = .white
        spinnerCircle.lineWidth = 4

        // Add marker line for visual rotation feedback
        let marker = SKShapeNode(rectOf: CGSize(width: 4, height: screenRadius * 0.6))
        marker.fillColor = .white
        marker.strokeColor = .clear
        marker.position = CGPoint(x: 0, y: screenRadius * 0.35)
        spinnerCircle.addChild(marker)

        addChild(spinnerCircle)

        // Progress ring
        let progressPath = CGMutablePath()
        progressPath.addArc(center: .zero, radius: screenRadius * 0.85,
                           startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: false)
        progressRing = SKShapeNode(path: progressPath)
        progressRing.strokeColor = SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.8)
        progressRing.lineWidth = 6
        progressRing.lineCap = .round
        progressRing.fillColor = .clear
        addChild(progressRing)

        // RPM display
        rpmLabel = SKLabelNode(text: "0 RPM")
        rpmLabel.fontName = "Menlo-Bold"
        rpmLabel.fontSize = 18
        rpmLabel.fontColor = .white
        rpmLabel.position = CGPoint(x: 0, y: -screenRadius - 30)
        addChild(rpmLabel)

        // Clear text (hidden initially)
        clearLabel = SKLabelNode(text: "CLEAR!")
        clearLabel.fontName = "Menlo-Bold"
        clearLabel.fontSize = 32
        clearLabel.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1.0)
        clearLabel.alpha = 0
        clearLabel.position = CGPoint(x: 0, y: screenRadius + 30)
        addChild(clearLabel)
    }

    /// Add rotation from touch movement.
    func addRotation(_ delta: CGFloat) {
        totalRotation += abs(delta)
        spinnerCircle.zRotation += delta

        // Track for RPM calculation
        let now = CACurrentMediaTime()
        recentRotations.append((time: now, angle: abs(delta)))

        // Remove old entries (keep last 1 second)
        recentRotations.removeAll { now - $0.time > 1.0 }

        // Calculate RPM
        let totalInWindow = recentRotations.reduce(0) { $0 + $1.angle }
        currentRPM = totalInWindow / (2 * .pi) * 60 // Convert radians/sec to RPM

        // Update progress
        updateProgress()
    }

    /// Update spinner state based on elapsed time.
    func updateSpinner(elapsed: TimeInterval) {
        rpmLabel.text = "\(Int(currentRPM)) RPM"

        if elapsed >= duration {
            // Spinner ended
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()
            self.run(SKAction.sequence([fadeOut, remove]))
        }
    }

    private func updateProgress() {
        let progress = min(totalRotation / (rotationsNeeded * 2 * .pi), 1.0)

        // Update progress ring
        let screenRadius = min(sceneSize.width, sceneSize.height) * 0.3
        let endAngle = -.pi / 2 + progress * 2 * .pi
        let progressPath = CGMutablePath()
        progressPath.addArc(center: .zero, radius: screenRadius * 0.85,
                           startAngle: -.pi / 2, endAngle: endAngle, clockwise: false)
        progressRing.path = progressPath

        // Color transition based on progress
        if progress > 0.8 {
            progressRing.strokeColor = SKColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 0.8)
        } else if progress > 0.5 {
            progressRing.strokeColor = SKColor(red: 0.9, green: 0.9, blue: 0.3, alpha: 0.8)
        }

        // Clear check
        if progress >= 1.0 && !isCleared {
            isCleared = true
            clearLabel.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.scale(by: 1.2, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ]))
        }
    }
}
