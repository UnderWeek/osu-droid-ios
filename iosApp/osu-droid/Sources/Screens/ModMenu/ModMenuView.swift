import SwiftUI

struct ModMenuView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Mods")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        // Score multiplier
                        let multiplier = calculateScoreMultiplier()
                        Text(String(format: "%.2fx", multiplier))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(multiplier > 1.0 ? .green : multiplier < 1.0 ? .red : .white)

                        Spacer()

                        Button("Reset") {
                            gameState.activeMods.removeAll()
                            audioManager.playSFX(.menuClick)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))

                        Button(action: {
                            withAnimation { isPresented = false }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Mod categories
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(ModCategory.allCases, id: \.self) { category in
                                ModCategorySection(category: category)
                            }
                        }
                    }
                    .frame(maxHeight: 300)

                    // Close button
                    Button(action: {
                        withAnimation { isPresented = false }
                        audioManager.playSFX(.menuBack)
                    }) {
                        Text("Close")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.953, green: 0.451, blue: 0.451))
                            )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
        }
    }

    private func calculateScoreMultiplier() -> Float {
        var multiplier: Float = 1.0
        for mod in gameState.activeMods {
            multiplier *= mod.scoreMultiplier
        }
        return multiplier
    }
}

struct ModCategorySection: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager
    let category: ModCategory

    private var modsInCategory: [GameMod] {
        GameMod.allCases.filter { $0.category == category }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(categoryColor)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(modsInCategory, id: \.self) { mod in
                    ModToggleButton(mod: mod, isActive: gameState.activeMods.contains(mod)) {
                        toggleMod(mod)
                        audioManager.playSFX(.menuClick)
                    }
                }
            }
        }
    }

    private var categoryColor: Color {
        switch category {
        case .difficultyReduction: return .green
        case .difficultyIncrease: return .red
        case .visual: return .blue
        case .automation: return .purple
        case .special: return .yellow
        }
    }

    private func toggleMod(_ mod: GameMod) {
        if gameState.activeMods.contains(mod) {
            gameState.activeMods.remove(mod)
        } else {
            // Handle incompatibilities
            resolveIncompatibilities(for: mod)
            gameState.activeMods.insert(mod)
        }
    }

    private func resolveIncompatibilities(for mod: GameMod) {
        switch mod {
        case .easy: gameState.activeMods.remove(.hardRock)
        case .hardRock: gameState.activeMods.remove(.easy); gameState.activeMods.remove(.reallyEasy)
        case .halfTime: gameState.activeMods.remove(.doubleTime); gameState.activeMods.remove(.nightCore)
        case .doubleTime: gameState.activeMods.remove(.halfTime); gameState.activeMods.remove(.nightCore)
        case .nightCore: gameState.activeMods.remove(.halfTime); gameState.activeMods.remove(.doubleTime)
        case .suddenDeath: gameState.activeMods.remove(.noFail); gameState.activeMods.remove(.perfect)
        case .perfect: gameState.activeMods.remove(.noFail); gameState.activeMods.remove(.suddenDeath)
        case .noFail: gameState.activeMods.remove(.suddenDeath); gameState.activeMods.remove(.perfect)
        case .relax: gameState.activeMods.remove(.autopilot); gameState.activeMods.remove(.autoplay)
        case .autopilot: gameState.activeMods.remove(.relax); gameState.activeMods.remove(.autoplay)
        case .autoplay: gameState.activeMods.remove(.relax); gameState.activeMods.remove(.autopilot)
        case .reallyEasy: gameState.activeMods.remove(.hardRock)
        default: break
        }
    }
}

struct ModToggleButton: View {
    let mod: GameMod
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mod.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isActive ? .white : .white.opacity(0.5))
                Text(mod.name)
                    .font(.system(size: 8))
                    .foregroundColor(isActive ? .white.opacity(0.8) : .white.opacity(0.3))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? modColor.opacity(0.6) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isActive ? modColor : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var modColor: Color {
        switch mod.category {
        case .difficultyReduction: return .green
        case .difficultyIncrease: return .red
        case .visual: return .blue
        case .automation: return .purple
        case .special: return .yellow
        }
    }
}
