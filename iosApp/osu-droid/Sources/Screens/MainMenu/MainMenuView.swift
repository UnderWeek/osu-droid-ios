import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager
    @State private var logoScale: CGFloat = 1.0
    @State private var showButtons = false
    @State private var isLogoAnimating = false

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.118, green: 0.118, blue: 0.180)
                .ignoresSafeArea()

            // Triangles background animation
            TrianglesBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        isLogoAnimating.toggle()
                        logoScale = isLogoAnimating ? 1.1 : 1.0
                        showButtons.toggle()
                    }
                    audioManager.playSFX(.menuHit)
                }) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .scaleEffect(logoScale)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 30)

                // Menu buttons
                if showButtons {
                    VStack(spacing: 12) {
                        MainMenuButton(title: "Play", icon: "play.fill") {
                            audioManager.playSFX(.menuClick)
                            gameState.navigateTo(.songSelect)
                        }

                        MainMenuButton(title: "Multiplayer", icon: "person.2.fill") {
                            audioManager.playSFX(.menuClick)
                            gameState.navigateTo(.multiplayer)
                        }

                        MainMenuButton(title: "Settings", icon: "gearshape.fill") {
                            audioManager.playSFX(.menuClick)
                            gameState.navigateTo(.settings)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }

            // Online panel (top-right)
            VStack {
                HStack {
                    Spacer()
                    OnlinePanel()
                }
                Spacer()
            }
            .padding()

            // Music player (bottom)
            VStack {
                Spacer()
                MusicPlayerBar()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            gameState.refreshBeatmapLibrary()
            audioManager.playMenuMusic()
        }
    }
}

// MARK: - Components

struct MainMenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(width: 220, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.953, green: 0.451, blue: 0.451).opacity(isPressed ? 0.9 : 0.8))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct OnlinePanel: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(gameState.isLoggedIn ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(gameState.isLoggedIn ? gameState.username : "Offline")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }
}

struct MusicPlayerBar: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { audioManager.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .foregroundColor(.white.opacity(0.7))
            }

            Button(action: { audioManager.togglePlayPause() }) {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }

            Button(action: { audioManager.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(audioManager.currentTrackTitle)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.5))
    }
}

struct TrianglesBackground: View {
    @State private var triangles: [TriangleData] = (0..<20).map { _ in TriangleData.random() }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for triangle in triangles {
                    let path = triangle.path(in: size, time: timeline.date.timeIntervalSinceReferenceDate)
                    context.fill(path, with: .color(triangle.color))
                }
            }
        }
    }
}

struct TriangleData {
    let x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let speed: CGFloat
    let color: Color
    let rotation: Double

    func path(in containerSize: CGSize, time: TimeInterval) -> Path {
        let yPos = containerSize.height - ((CGFloat(time) * speed * 20).truncatingRemainder(dividingBy: containerSize.height + size * 2) - size)
        let xPos = x * containerSize.width

        var path = Path()
        let half = size / 2
        path.move(to: CGPoint(x: xPos, y: yPos - half))
        path.addLine(to: CGPoint(x: xPos - half, y: yPos + half))
        path.addLine(to: CGPoint(x: xPos + half, y: yPos + half))
        path.closeSubpath()
        return path
    }

    static func random() -> TriangleData {
        TriangleData(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            size: CGFloat.random(in: 20...80),
            speed: CGFloat.random(in: 0.5...2.0),
            color: Color(
                red: Double.random(in: 0.1...0.2),
                green: Double.random(in: 0.1...0.2),
                blue: Double.random(in: 0.15...0.3)
            ).opacity(Double.random(in: 0.3...0.6)),
            rotation: Double.random(in: 0...360)
        )
    }
}

#Preview {
    MainMenuView()
        .environmentObject(GameState.shared)
        .environmentObject(AudioManager.shared)
}
