import SpriteKit

/// Renders a slider with body path, slider ball, ticks, and repeat arrows.
final class SliderNode: SKNode {
    private let sliderPath: [CGPoint]
    private let radius: CGFloat
    private let comboNumber: Int
    private let comboColor: SKColor
    private let duration: TimeInterval
    private let repeatCount: Int
    private let approachDuration: TimeInterval

    private var bodyNode: SKShapeNode!
    private var headCircle: HitCircleNode!
    private var sliderBall: SKShapeNode!
    private var followCircle: SKShapeNode!
    private var isTracking = false
    private var currentRepeat = 0

    /// Path positions interpolated at regular intervals for slider ball movement.
    private var interpolatedPath: [CGPoint] = []

    init(path: [CGPoint], radius: CGFloat, comboNumber: Int, comboColor: SKColor,
         duration: TimeInterval, repeatCount: Int, approachDuration: TimeInterval) {
        self.sliderPath = path
        self.radius = radius
        self.comboNumber = comboNumber
        self.comboColor = comboColor
        self.duration = duration
        self.repeatCount = repeatCount
        self.approachDuration = approachDuration
        super.init()
        interpolatePath()
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func interpolatePath() {
        guard sliderPath.count >= 2 else {
            interpolatedPath = sliderPath
            return
        }

        // Create interpolated points along the slider path
        let segments = 100
        interpolatedPath = [sliderPath[0]]

        let totalLength = calculateTotalLength()
        guard totalLength > 0 else {
            interpolatedPath = sliderPath
            return
        }

        for i in 1...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let targetDist = t * totalLength
            let point = pointAtDistance(targetDist)
            interpolatedPath.append(point)
        }
    }

    private func calculateTotalLength() -> CGFloat {
        var length: CGFloat = 0
        for i in 1..<sliderPath.count {
            length += hypot(sliderPath[i].x - sliderPath[i-1].x, sliderPath[i].y - sliderPath[i-1].y)
        }
        return length
    }

    private func pointAtDistance(_ distance: CGFloat) -> CGPoint {
        var remaining = distance
        for i in 1..<sliderPath.count {
            let segLen = hypot(sliderPath[i].x - sliderPath[i-1].x, sliderPath[i].y - sliderPath[i-1].y)
            if remaining <= segLen {
                let t = remaining / segLen
                return CGPoint(
                    x: sliderPath[i-1].x + (sliderPath[i].x - sliderPath[i-1].x) * t,
                    y: sliderPath[i-1].y + (sliderPath[i].y - sliderPath[i-1].y) * t
                )
            }
            remaining -= segLen
        }
        return sliderPath.last ?? .zero
    }

    private func setupNodes() {
        // Slider body
        let bodyPath = CGMutablePath()
        if let first = sliderPath.first {
            bodyPath.move(to: first)
            for point in sliderPath.dropFirst() {
                bodyPath.addLine(to: point)
            }
        }

        bodyNode = SKShapeNode(path: bodyPath.copy(strokingWithWidth: radius * 2, lineCap: .round, lineJoin: .round, miterLimit: 1))
        bodyNode.fillColor = comboColor.withAlphaComponent(0.4)
        bodyNode.strokeColor = .clear
        bodyNode.alpha = 0
        addChild(bodyNode)

        // Body border
        let borderNode = SKShapeNode(path: bodyPath)
        borderNode.strokeColor = .white.withAlphaComponent(0.6)
        borderNode.lineWidth = radius * 2
        borderNode.lineCap = .round
        borderNode.lineJoin = .round
        borderNode.fillColor = .clear
        borderNode.alpha = 0
        borderNode.name = "sliderBorder"

        let innerBorderNode = SKShapeNode(path: bodyPath)
        innerBorderNode.strokeColor = comboColor.withAlphaComponent(0.5)
        innerBorderNode.lineWidth = radius * 2 - 4
        innerBorderNode.lineCap = .round
        innerBorderNode.lineJoin = .round
        innerBorderNode.fillColor = .clear
        borderNode.addChild(innerBorderNode)
        addChild(borderNode)

        // Slider ball (hidden initially)
        sliderBall = SKShapeNode(circleOfRadius: radius * 0.6)
        sliderBall.fillColor = .white
        sliderBall.strokeColor = comboColor
        sliderBall.lineWidth = 3
        sliderBall.alpha = 0
        sliderBall.zPosition = 5
        addChild(sliderBall)

        // Follow circle
        followCircle = SKShapeNode(circleOfRadius: radius * 1.5)
        followCircle.fillColor = .clear
        followCircle.strokeColor = comboColor.withAlphaComponent(0.5)
        followCircle.lineWidth = 2
        followCircle.alpha = 0
        followCircle.zPosition = 4
        addChild(followCircle)
    }

    func startApproach() {
        let fadeIn = SKAction.fadeIn(withDuration: min(approachDuration * 0.4, 0.4))
        bodyNode.run(fadeIn)
        children.first(where: { $0.name == "sliderBorder" })?.run(fadeIn)
    }

    /// Update slider ball position based on elapsed time.
    func updateSlider(elapsed: TimeInterval) {
        guard elapsed >= 0 else { return }

        let singleDuration = duration / Double(repeatCount + 1)
        guard singleDuration > 0 else { return }

        // Show slider ball when slider starts
        if sliderBall.alpha == 0 && elapsed >= 0 {
            sliderBall.alpha = 1
            if isTracking { followCircle.alpha = 1 }
        }

        // Calculate position along path
        var t = elapsed / singleDuration
        currentRepeat = Int(t)

        if currentRepeat > repeatCount {
            // Slider is done
            return
        }

        t = t - Double(currentRepeat)

        // Reverse on odd repeats
        if currentRepeat % 2 == 1 {
            t = 1.0 - t
        }

        t = max(0, min(1, t))

        let pathIndex = Int(t * Double(interpolatedPath.count - 1))
        let clampedIndex = min(max(pathIndex, 0), interpolatedPath.count - 1)
        let ballPos = interpolatedPath[clampedIndex]

        sliderBall.position = ballPos
        followCircle.position = ballPos

        // End slider
        if elapsed >= duration {
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            let remove = SKAction.removeFromParent()
            self.run(SKAction.sequence([fadeOut, remove]))
        }
    }

    func updateTracking(cursorPosition: CGPoint, radius: CGFloat) {
        let dist = hypot(cursorPosition.x - sliderBall.position.x - position.x,
                        cursorPosition.y - sliderBall.position.y - position.y)
        isTracking = dist <= radius * 2.4

        followCircle.alpha = isTracking ? 1 : 0
    }

    func releaseTracking() {
        isTracking = false
        followCircle.alpha = 0
    }
}
