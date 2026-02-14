import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Back button column
                VStack {
                    Button(action: {
                        audioManager.playSFX(.menuBack)
                        gameState.navigateBack()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    Spacer()
                }
                .frame(width: 100)

                // Settings content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Settings")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        // Graphics
                        SettingsSection(title: "Graphics", icon: "display") {
                            SettingsToggle(title: "Show FPS", isOn: $gameState.config.showFPS)
                            SettingsSlider(title: "Background Brightness", value: $gameState.config.backgroundBrightness, range: 0...1)
                            SettingsToggle(title: "Snaking Sliders", isOn: $gameState.config.snakingSliders)
                            SettingsToggle(title: "Storyboard", isOn: $gameState.config.useStoryboard)
                        }

                        // Gameplay
                        SettingsSection(title: "Gameplay", icon: "gamecontroller") {
                            SettingsSlider(title: "Cursor Size", value: $gameState.config.cursorSize, range: 0.5...2.0)
                            SettingsToggle(title: "Cursor Trail", isOn: $gameState.config.showCursorTrail)
                            SettingsToggle(title: "Hit Error Meter", isOn: $gameState.config.showHitErrorMeter)
                            SettingsToggle(title: "Scoreboard", isOn: $gameState.config.showScoreBoard)
                            SettingsSlider(title: "Touch Area Scale", value: $gameState.config.touchAreaScale, range: 0.5...2.0)
                        }

                        // Audio
                        SettingsSection(title: "Audio", icon: "speaker.wave.3") {
                            SettingsSlider(title: "Music Volume", value: $gameState.config.musicVolume, range: 0...1)
                            SettingsSlider(title: "Effect Volume", value: $gameState.config.effectVolume, range: 0...1)
                            SettingsSlider(title: "Hitsound Volume", value: $gameState.config.hitSoundVolume, range: 0...1)
                            SettingsIntField(title: "Audio Offset (ms)", value: $gameState.config.audioOffset, range: -200...200)
                        }

                        // Online
                        SettingsSection(title: "Online", icon: "globe") {
                            SettingsTextField(title: "Username", text: $gameState.config.onlineUsername)
                            SettingsTextField(title: "Server URL", text: $gameState.config.serverURL)
                        }

                        // Storage
                        SettingsSection(title: "Storage", icon: "folder") {
                            SettingsInfoRow(title: "Beatmaps", value: "\(gameState.beatmapLibrary.count) sets")
                            SettingsInfoRow(title: "Storage Path", value: "My iPhone/osu-droid")
                            SettingsButton(title: "Clear Beatmap Cache", color: .orange) {
                                StorageManager.shared.clearBeatmapCache()
                                gameState.refreshBeatmapLibrary()
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.953, green: 0.451, blue: 0.451))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
}

struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .tint(Color(red: 0.953, green: 0.451, blue: 0.451))
        .padding(.vertical, 4)
    }
}

struct SettingsSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.953, green: 0.451, blue: 0.451))
        }
        .padding(.vertical, 4)
    }
}

struct SettingsIntField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            HStack(spacing: 8) {
                Button(action: { if value > range.lowerBound { value -= 1 } }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.white.opacity(0.5))
                }
                Text("\(value)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 40)
                Button(action: { if value < range.upperBound { value += 1 } }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            TextField("", text: $text)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .frame(maxWidth: 200)
        }
        .padding(.vertical, 4)
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}

struct SettingsButton: View {
    let title: String
    var color: Color = .red
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.1))
                )
        }
        .padding(.vertical, 4)
    }
}
