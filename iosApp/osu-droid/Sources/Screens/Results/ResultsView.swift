import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager
    let score: GameScore

    @State private var showAnimation = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            HStack(spacing: 20) {
                // Left: Grade + Score
                VStack(spacing: 16) {
                    // Grade
                    Text(score.grade.rawValue)
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(score.grade.color)
                        .scaleEffect(showAnimation ? 1.0 : 0.3)
                        .opacity(showAnimation ? 1.0 : 0)

                    // Score
                    Text(formattedScore)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    // Accuracy
                    Text(String(format: "%.2f%%", score.accuracy * 100))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    // Max combo
                    HStack(spacing: 4) {
                        Text("\(score.maxCombo)x")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("max combo")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)

                // Right: Hit distribution + Actions
                VStack(spacing: 16) {
                    // Hit counts
                    VStack(spacing: 8) {
                        HitCountRow(label: "300", count: score.count300, color: .cyan)
                        HitCountRow(label: "100", count: score.count100, color: .green)
                        HitCountRow(label: "50", count: score.count50, color: .yellow)
                        HitCountRow(label: "Miss", count: score.countMiss, color: .red)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.05))
                    )

                    // Mods used
                    if !score.mods.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(score.mods, id: \.self) { mod in
                                Text(mod)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.purple.opacity(0.4))
                                    )
                            }
                        }
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            audioManager.playSFX(.menuBack)
                            gameState.navigateToRoot()
                            gameState.navigateTo(.songSelect)
                        }) {
                            Label("Back", systemImage: "arrow.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        }

                        Button(action: {
                            audioManager.playSFX(.menuClick)
                            // Retry: navigate to gameplay again
                            gameState.navigateBack()
                        }) {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color(red: 0.953, green: 0.451, blue: 0.451)))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(30)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                showAnimation = true
            }
            audioManager.playSFX(.applause)
        }
    }

    private var formattedScore: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: score.score)) ?? "\(score.score)"
    }
}

struct HitCountRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Spacer()
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
