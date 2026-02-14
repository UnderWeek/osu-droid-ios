import SwiftUI

struct SongSelectView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager

    @State private var searchText = ""
    @State private var sortMode: SortMode = .title
    @State private var showModMenu = false
    @State private var selectedSetIndex: Int? = nil

    private var filteredSets: [BeatmapSetInfo] {
        let sets = gameState.beatmapLibrary
        let filtered = searchText.isEmpty ? sets : sets.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText) ||
            $0.creator.localizedCaseInsensitiveContains(searchText)
        }

        switch sortMode {
        case .title: return filtered.sorted { $0.title < $1.title }
        case .artist: return filtered.sorted { $0.artist < $1.artist }
        case .creator: return filtered.sorted { $0.creator < $1.creator }
        case .difficulty: return filtered.sorted {
            ($0.difficulties.first?.starRating ?? 0) < ($1.difficulties.first?.starRating ?? 0)
        }
        case .recent: return filtered
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Left panel: Beatmap info
                leftPanel
                    .frame(width: UIScreen.main.bounds.width * 0.4)

                // Right panel: Beatmap list
                rightPanel
            }

            // Mod menu overlay
            if showModMenu {
                ModMenuView(isPresented: $showModMenu)
                    .transition(.move(edge: .bottom))
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Left Panel (Beatmap Info)

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Back button
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

            if let set = gameState.selectedBeatmapSet, let diff = gameState.selectedDifficulty {
                // Background image area
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .overlay(
                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text(set.artist)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Mapped by \(set.creator)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    )

                // Difficulty selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(set.difficulties) { diff in
                            DifficultyChip(
                                difficulty: diff,
                                isSelected: gameState.selectedDifficulty?.id == diff.id
                            ) {
                                gameState.selectedDifficulty = diff
                            }
                        }
                    }
                }

                // Difficulty stats
                DifficultyStatsView(difficulty: diff)

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation { showModMenu = true }
                    }) {
                        Label("Mods", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.purple.opacity(0.6)))
                    }

                    if !gameState.activeMods.isEmpty {
                        Text("\(gameState.activeMods.count) mod(s)")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }

                    Spacer()

                    Button(action: {
                        startGame()
                    }) {
                        Label("Play", systemImage: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color(red: 0.953, green: 0.451, blue: 0.451)))
                    }
                }
            } else {
                Spacer()
                Text("Select a beatmap")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(20)
    }

    // MARK: - Right Panel (Beatmap List)

    private var rightPanel: some View {
        VStack(spacing: 0) {
            // Search bar + sort
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Search...", text: $searchText)
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )

                Menu {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) { sortMode = mode }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortMode.rawValue)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Beatmap list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredSets.enumerated()), id: \.element.id) { index, set in
                        BeatmapSetCard(set: set, isSelected: gameState.selectedBeatmapSet?.id == set.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    gameState.selectedBeatmapSet = set
                                    gameState.selectedDifficulty = set.difficulties.first
                                    audioManager.playSFX(.menuClick)
                                    // Preview audio
                                    audioManager.previewBeatmap(directoryPath: set.directoryPath)
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func startGame() {
        guard let diff = gameState.selectedDifficulty else { return }
        audioManager.playSFX(.menuClick)
        let modStrings = gameState.activeMods.map(\.rawValue)
        gameState.navigateTo(.gameplay(beatmap: diff.filePath, mods: modStrings))
    }
}

// MARK: - Supporting Views

struct BeatmapSetCard: View {
    let set: BeatmapSetInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(set.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(set.artist) // \(set.creator)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            // Star ratings
            VStack(alignment: .trailing, spacing: 2) {
                if let maxStar = set.difficulties.map(\.starRating).max() {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.2f", maxStar))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(starColor(for: maxStar))
                }
                Text("\(set.difficulties.count) diff(s)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(red: 0.953, green: 0.451, blue: 0.451).opacity(0.3) : Color.white.opacity(0.05))
        )
    }

    private func starColor(for rating: Double) -> Color {
        switch rating {
        case ..<2: return .green
        case 2..<4: return .blue
        case 4..<5.5: return .yellow
        case 5.5..<7: return .orange
        case 7..<8: return .red
        default: return .purple
        }
    }
}

struct DifficultyChip: View {
    let difficulty: BeatmapInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(diffColor)
                    .frame(width: 8, height: 8)
                Text(difficulty.version)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? diffColor.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? diffColor : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var diffColor: Color {
        switch difficulty.starRating {
        case ..<2: return .green
        case 2..<4: return .blue
        case 4..<5.5: return .yellow
        case 5.5..<7: return .orange
        case 7..<8: return .red
        default: return .purple
        }
    }
}

struct DifficultyStatsView: View {
    let difficulty: BeatmapInfo

    var body: some View {
        VStack(spacing: 8) {
            StatRow(label: "Star Rating", value: String(format: "%.2f", difficulty.starRating), color: .yellow)
            StatRow(label: "CS", value: String(format: "%.1f", difficulty.cs))
            StatRow(label: "AR", value: String(format: "%.1f", difficulty.ar))
            StatRow(label: "OD", value: String(format: "%.1f", difficulty.od))
            StatRow(label: "HP", value: String(format: "%.1f", difficulty.hp))
            StatRow(label: "BPM", value: String(format: "%.0f", difficulty.bpm))
            StatRow(label: "Length", value: difficulty.lengthFormatted)
            StatRow(label: "Objects", value: "\(difficulty.circleCount + difficulty.sliderCount + difficulty.spinnerCount)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

enum SortMode: String, CaseIterable {
    case title = "Title"
    case artist = "Artist"
    case creator = "Creator"
    case difficulty = "Difficulty"
    case recent = "Recent"
}

#Preview {
    SongSelectView()
        .environmentObject(GameState.shared)
        .environmentObject(AudioManager.shared)
}
