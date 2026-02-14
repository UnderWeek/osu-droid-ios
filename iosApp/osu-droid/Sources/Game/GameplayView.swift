import SwiftUI
import SpriteKit

/// SwiftUI wrapper for the SpriteKit gameplay scene.
struct GameplayView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager

    let beatmapPath: String
    let mods: [String]

    @State private var gameScene: GameScene?
    @State private var showPauseMenu = false
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let scene = gameScene {
                SpriteView(scene: scene, transition: nil, isPaused: showPauseMenu, preferredFramesPerSecond: 120)
                    .ignoresSafeArea()
            }

            // Loading overlay
            if isLoading {
                LoadingOverlay(beatmapPath: beatmapPath)
            }

            // Pause menu
            if showPauseMenu {
                PauseMenuOverlay(
                    onResume: {
                        showPauseMenu = false
                        gameScene?.resumeGame()
                        audioManager.resumeGameplayAudio()
                    },
                    onRetry: {
                        showPauseMenu = false
                        restartGame()
                    },
                    onQuit: {
                        audioManager.stopGameplayAudio()
                        gameState.navigateBack()
                    }
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear { loadAndStart() }
        .onDisappear { audioManager.stopGameplayAudio() }
    }

    private func loadAndStart() {
        Task {
            // Parse beatmap
            guard let parsed = await BeatmapLoader.parse(filePath: beatmapPath) else {
                await MainActor.run {
                    gameState.navigateBack()
                }
                return
            }

            await MainActor.run {
                let scene = GameScene(size: UIScreen.main.bounds.size)
                scene.scaleMode = .resizeFill
                scene.activeMods = mods
                scene.loadBeatmap(parsed)
                scene.gameDelegate = GameplayCoordinator.shared

                GameplayCoordinator.shared.configure(
                    gameState: gameState,
                    audioManager: audioManager,
                    scene: scene,
                    beatmap: parsed,
                    onPause: { showPauseMenu = true }
                )

                self.gameScene = scene
                isLoading = false

                // Start after a short delay for scene setup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scene.startGame()
                    audioManager.startGameplayAudio(filePath: parsed.audioFilePath)
                }
            }
        }
    }

    private func restartGame() {
        isLoading = true
        audioManager.stopGameplayAudio()
        loadAndStart()
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let beatmapPath: String

    @State private var dots = ""
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.953, green: 0.451, blue: 0.451)))
                    .scaleEffect(1.5)

                Text("Loading\(dots)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onReceive(timer) { _ in
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }
}

// MARK: - Pause Menu

struct PauseMenuOverlay: View {
    let onResume: () -> Void
    let onRetry: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Paused")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer().frame(height: 20)

                PauseButton(title: "Continue", color: Color.green.opacity(0.6), action: onResume)
                PauseButton(title: "Retry", color: Color.orange.opacity(0.6), action: onRetry)
                PauseButton(title: "Quit", color: Color(red: 0.953, green: 0.451, blue: 0.451), action: onQuit)
            }
        }
    }
}

struct PauseButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 200, height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(color))
        }
    }
}

// MARK: - Gameplay Coordinator

/// Bridges between GameScene delegate callbacks and SwiftUI state.
final class GameplayCoordinator: GameSceneDelegate {
    static let shared = GameplayCoordinator()

    private var gameState: GameState?
    private var audioManager: AudioManager?
    private var scene: GameScene?
    private var beatmap: ParsedBeatmap?
    private var onPause: (() -> Void)?

    func configure(gameState: GameState, audioManager: AudioManager,
                   scene: GameScene, beatmap: ParsedBeatmap, onPause: @escaping () -> Void) {
        self.gameState = gameState
        self.audioManager = audioManager
        self.scene = scene
        self.beatmap = beatmap
        self.onPause = onPause
    }

    func gameDidStart() {}

    func gameDidPause() {
        audioManager?.pauseGameplayAudio()
        onPause?()
    }

    func gameDidResume() {
        audioManager?.resumeGameplayAudio()
    }

    func gameDidFail() {
        audioManager?.stopGameplayAudio()
        // Navigate to results with fail
    }

    func gameDidEnd(score: GameScore) {
        audioManager?.stopGameplayAudio()
        Task { @MainActor in
            // Save score
            StorageManager.shared.saveScore(score)
            // Navigate to results
            gameState?.navigateTo(.results(score: score))
        }
    }

    func requestAudioStart() {
        guard let beatmap = beatmap else { return }
        audioManager?.startGameplayAudio(filePath: beatmap.audioFilePath)
    }

    func requestHitSound(sampleSet: Int, addition: Int) {
        let sfx: SFXType
        switch addition {
        case 2: sfx = .hitWhistle
        case 4: sfx = .hitFinish
        case 8: sfx = .hitClap
        default: sfx = .hitNormal
        }
        audioManager?.playSFX(sfx)
    }
}
