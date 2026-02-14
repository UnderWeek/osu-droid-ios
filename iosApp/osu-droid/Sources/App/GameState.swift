import SwiftUI

/// Global game state observable across all views.
final class GameState: ObservableObject {
    static let shared = GameState()

    // MARK: - Navigation

    @Published var navigationPath = NavigationPath()

    // MARK: - User

    @Published var username: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var avatarURL: String?

    // MARK: - Beatmaps

    @Published var beatmapLibrary: [BeatmapSetInfo] = []
    @Published var selectedBeatmapSet: BeatmapSetInfo?
    @Published var selectedDifficulty: BeatmapInfo?

    // MARK: - Mods

    @Published var activeMods: Set<GameMod> = []

    // MARK: - Config

    @Published var config = GameConfig()

    // MARK: - Navigation Helpers

    func navigateTo(_ screen: AppScreen) {
        navigationPath.append(screen)
    }

    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func navigateToRoot() {
        navigationPath = NavigationPath()
    }

    // MARK: - Library Management

    func refreshBeatmapLibrary() {
        Task {
            let sets = await StorageManager.shared.loadBeatmapLibrary()
            await MainActor.run {
                self.beatmapLibrary = sets
            }
        }
    }

    private init() {}
}

// MARK: - Data Models

struct BeatmapSetInfo: Identifiable, Hashable {
    let id: String // folder name or beatmapset ID
    let title: String
    let artist: String
    let creator: String
    let difficulties: [BeatmapInfo]
    let directoryPath: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BeatmapSetInfo, rhs: BeatmapSetInfo) -> Bool { lhs.id == rhs.id }
}

struct BeatmapInfo: Identifiable, Hashable {
    let id: String // md5 hash
    let version: String // difficulty name
    let filePath: String
    let starRating: Double
    let cs: Float
    let ar: Float
    let od: Float
    let hp: Float
    let bpm: Double
    let lengthMs: Int
    let maxCombo: Int
    let circleCount: Int
    let sliderCount: Int
    let spinnerCount: Int

    var lengthFormatted: String {
        let seconds = lengthMs / 1000
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct GameScore: Hashable, Identifiable {
    let id = UUID()
    let beatmapId: String
    let score: Int
    let accuracy: Double
    let maxCombo: Int
    let count300: Int
    let count100: Int
    let count50: Int
    let countMiss: Int
    let mods: [String]
    let grade: ScoreGrade
    let date: Date

    var totalHits: Int { count300 + count100 + count50 + countMiss }
}

enum ScoreGrade: String, Hashable {
    case ss = "SS"
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var color: Color {
        switch self {
        case .ss: return .yellow
        case .s: return .yellow
        case .a: return .green
        case .b: return .blue
        case .c: return .purple
        case .d: return .red
        }
    }
}

enum GameMod: String, CaseIterable, Hashable {
    case easy = "EZ"
    case noFail = "NF"
    case halfTime = "HT"
    case hardRock = "HR"
    case suddenDeath = "SD"
    case perfect = "PF"
    case doubleTime = "DT"
    case nightCore = "NC"
    case hidden = "HD"
    case flashlight = "FL"
    case relax = "RX"
    case autopilot = "AP"
    case autoplay = "AT"
    case smallCircle = "SC"
    case precise = "PR"
    case reallyEasy = "RE"
    case scoreV2 = "V2"

    var name: String {
        switch self {
        case .easy: return "Easy"
        case .noFail: return "No Fail"
        case .halfTime: return "Half Time"
        case .hardRock: return "Hard Rock"
        case .suddenDeath: return "Sudden Death"
        case .perfect: return "Perfect"
        case .doubleTime: return "Double Time"
        case .nightCore: return "Nightcore"
        case .hidden: return "Hidden"
        case .flashlight: return "Flashlight"
        case .relax: return "Relax"
        case .autopilot: return "Autopilot"
        case .autoplay: return "Autoplay"
        case .smallCircle: return "Small Circle"
        case .precise: return "Precise"
        case .reallyEasy: return "Really Easy"
        case .scoreV2: return "Score V2"
        }
    }

    var category: ModCategory {
        switch self {
        case .easy, .noFail, .halfTime: return .difficultyReduction
        case .hardRock, .suddenDeath, .perfect, .doubleTime, .nightCore: return .difficultyIncrease
        case .hidden, .flashlight: return .visual
        case .relax, .autopilot, .autoplay: return .automation
        case .smallCircle, .precise, .reallyEasy, .scoreV2: return .special
        }
    }

    var scoreMultiplier: Float {
        switch self {
        case .easy: return 0.5
        case .noFail: return 0.5
        case .halfTime: return 0.3
        case .hardRock: return 1.06
        case .suddenDeath: return 1.0
        case .perfect: return 1.0
        case .doubleTime: return 1.12
        case .nightCore: return 1.12
        case .hidden: return 1.06
        case .flashlight: return 1.12
        case .relax: return 0.001
        case .autopilot: return 0.001
        case .autoplay: return 1.0
        case .smallCircle: return 1.06
        case .precise: return 1.06
        case .reallyEasy: return 0.5
        case .scoreV2: return 1.0
        }
    }
}

enum ModCategory: String, CaseIterable {
    case difficultyReduction = "Difficulty Reduction"
    case difficultyIncrease = "Difficulty Increase"
    case visual = "Visual"
    case automation = "Automation"
    case special = "Special"
}

struct GameConfig: Codable {
    // Graphics
    var showFPS: Bool = false
    var backgroundBrightness: Float = 0.7
    var useStoryboard: Bool = false
    var snakingSliders: Bool = true

    // Gameplay
    var cursorSize: Float = 1.0
    var showCursorTrail: Bool = true
    var audioOffset: Int = 0
    var showHitErrorMeter: Bool = true
    var showScoreBoard: Bool = true

    // Audio
    var musicVolume: Float = 0.8
    var effectVolume: Float = 0.8
    var hitSoundVolume: Float = 0.8

    // Input
    var touchAreaScale: Float = 1.0

    // Online
    var serverURL: String = "https://osudroid.moe"
    var onlineUsername: String = ""
}
