import Foundation
import SwiftUI

/// Manages all network operations: HTTP API, Socket.IO multiplayer, beatmap downloading.
final class NetworkManager: ObservableObject {
    static let shared = NetworkManager()

    // MARK: - Published State

    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected

    // MARK: - Configuration

    private var serverURL: String { GameState.shared.config.serverURL }
    private let session = URLSession.shared

    // MARK: - Socket.IO (placeholder — requires SocketIO-swift package)

    // In production, integrate with SocketIO-swift via SPM
    // private var socket: SocketIOClient?
    // private var manager: SocketManager?

    private init() {}

    // MARK: - HTTP API

    /// Generic GET request.
    func get<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = URL(string: "\(serverURL)\(endpoint)")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Generic POST request.
    func post<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        let url = URL(string: "\(serverURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Score Submission

    func submitScore(_ score: GameScore) async -> Bool {
        // TODO: Implement score submission API
        print("[NetworkManager] Score submission: \(score.score)")
        return true
    }

    // MARK: - Beatmap Download

    func downloadBeatmap(beatmapSetId: String, progressHandler: @escaping (Double) -> Void) async -> String? {
        let downloadURL = "\(serverURL)/api/beatmap/\(beatmapSetId)/download"
        guard let url = URL(string: downloadURL) else { return nil }

        do {
            let (tempURL, response) = try await session.download(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Move to Songs directory
            let destPath = "\(StorageManager.shared.songsDirectory)/\(beatmapSetId).osz"
            try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destPath))
            return destPath
        } catch {
            print("[NetworkManager] Download failed: \(error)")
            return nil
        }
    }

    // MARK: - Multiplayer

    func fetchRooms() async -> [MultiplayerRoom] {
        // TODO: Implement Socket.IO room fetching
        // Placeholder - returns empty for now
        return []
    }

    func createRoom(name: String, maxPlayers: Int, password: String?) async -> String? {
        // TODO: Implement Socket.IO room creation
        print("[NetworkManager] Creating room: \(name)")
        return UUID().uuidString // Placeholder
    }

    func joinRoom(roomId: String, completion: @escaping ([RoomPlayer], [ChatMessage], String, Bool) -> Void) {
        // TODO: Implement Socket.IO room joining
        print("[NetworkManager] Joining room: \(roomId)")
    }

    func leaveRoom() {
        // TODO: Implement Socket.IO room leaving
        print("[NetworkManager] Leaving room")
    }

    func sendChatMessage(_ message: String) {
        // TODO: Implement Socket.IO chat
        print("[NetworkManager] Chat: \(message)")
    }

    func setReady(_ ready: Bool) {
        // TODO: Implement Socket.IO ready state
        print("[NetworkManager] Ready: \(ready)")
    }

    func startMatch() {
        // TODO: Implement Socket.IO match start
        print("[NetworkManager] Starting match")
    }

    // MARK: - Connection

    func connect() {
        // TODO: Initialize Socket.IO connection
        connectionStatus = .connecting
        // Simulate connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.connectionStatus = .connected
            self.isConnected = true
        }
    }

    func disconnect() {
        connectionStatus = .disconnected
        isConnected = false
    }
}

// MARK: - Types

enum ConnectionStatus {
    case disconnected, connecting, connected

    var text: String {
        switch self {
        case .disconnected: return "Offline"
        case .connecting: return "Connecting..."
        case .connected: return "Online"
        }
    }
}

enum NetworkError: Error {
    case serverError
    case decodingError
    case noConnection
}
