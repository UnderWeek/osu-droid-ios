import SwiftUI

/// SwiftUI overlay for gameplay HUD elements that work better as SwiftUI views
/// (complementing the SpriteKit HUD for real-time counters).
struct HUDOverlay: View {
    @ObservedObject var hudState: HUDState

    var body: some View {
        ZStack {
            // Skip button (appears during breaks or intro)
            if hudState.showSkipButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { hudState.onSkip?() }) {
                            Text("Skip >>")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.6))
                                )
                        }
                        .padding(20)
                    }
                }
            }

            // Key overlay (shows touch positions for spectating/replays)
            if hudState.showKeyOverlay {
                VStack {
                    Spacer()
                    HStack {
                        KeyOverlayView(touches: hudState.activeTouches)
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 60)
                }
            }

            // PP Counter (optional)
            if hudState.showPPCounter {
                VStack {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0fpp", hudState.currentPP))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 80)
                    }
                    Spacer()
                }
            }

            // Hit error meter
            if hudState.showHitErrorMeter {
                VStack {
                    Spacer()
                    HitErrorMeterView(errors: hudState.hitErrors)
                        .frame(height: 20)
                        .padding(.horizontal, 60)
                        .padding(.bottom, 40)
                }
            }
        }
        .allowsHitTesting(hudState.showSkipButton) // Only intercept touches when skip button is visible
    }
}

// MARK: - HUD State

class HUDState: ObservableObject {
    @Published var showSkipButton = false
    @Published var showKeyOverlay = false
    @Published var showPPCounter = false
    @Published var showHitErrorMeter = true
    @Published var currentPP: Double = 0
    @Published var activeTouches: Int = 0
    @Published var hitErrors: [Double] = [] // ms offset from perfect hit

    var onSkip: (() -> Void)?
}

// MARK: - Key Overlay

struct KeyOverlayView: View {
    let touches: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(i < touches ? Color(red: 0.953, green: 0.451, blue: 0.451) : Color.white.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("M\(i + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

// MARK: - Hit Error Meter

struct HitErrorMeterView: View {
    let errors: [Double]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 4)

                // Center line (perfect hit)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 12)

                // Hit windows visualization
                let width = geo.size.width
                let center = width / 2

                // 300 window (cyan)
                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: width * 0.2, height: 6)

                // 100 window (green)
                Rectangle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: width * 0.5, height: 4)

                // Error ticks
                ForEach(Array(errors.suffix(20).enumerated()), id: \.offset) { idx, error in
                    let normalized = max(-1, min(1, error / 100.0)) // Normalize to -1...1
                    let x = center + CGFloat(normalized) * (width / 2 - 10)

                    Circle()
                        .fill(colorForError(error))
                        .frame(width: 3, height: 3)
                        .position(x: x, y: geo.size.height / 2)
                        .opacity(Double(errors.count - idx) / 20.0)
                }

                // Average error line
                if !errors.isEmpty {
                    let avg = errors.reduce(0, +) / Double(errors.count)
                    let normalized = max(-1, min(1, avg / 100.0))
                    let x = center + CGFloat(normalized) * (width / 2 - 10)

                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 2, height: 10)
                        .position(x: x, y: geo.size.height / 2)
                }
            }
        }
    }

    private func colorForError(_ error: Double) -> Color {
        let absError = abs(error)
        if absError < 20 { return .cyan }
        if absError < 50 { return .green }
        if absError < 100 { return .yellow }
        return .red
    }
}
