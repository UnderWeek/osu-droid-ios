import SwiftUI
import SpriteKit

@main
struct OsuDroidApp: App {
    @StateObject private var gameState = GameState.shared
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var storageManager = StorageManager.shared
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var skinManager = SkinManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameState)
                .environmentObject(audioManager)
                .environmentObject(storageManager)
                .environmentObject(networkManager)
                .environmentObject(skinManager)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}

/// Root content view handling navigation between screens.
struct ContentView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        NavigationStack(path: $gameState.navigationPath) {
            MainMenuView()
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .songSelect:
                        SongSelectView()
                    case .settings:
                        SettingsView()
                    case .multiplayer:
                        MultiplayerLobbyView()
                    case .gameplay(let beatmap, let mods):
                        GameplayView(beatmapPath: beatmap, mods: mods)
                    case .results(let score):
                        ResultsView(score: score)
                    case .multiplayerRoom(let roomId):
                        MultiplayerRoomView(roomId: roomId)
                    }
                }
        }
    }
}

/// All navigable screens in the app.
enum AppScreen: Hashable {
    case songSelect
    case settings
    case multiplayer
    case gameplay(beatmap: String, mods: [String])
    case results(score: GameScore)
    case multiplayerRoom(roomId: String)
}
