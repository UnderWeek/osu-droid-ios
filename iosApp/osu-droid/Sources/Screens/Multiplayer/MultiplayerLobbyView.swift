import SwiftUI

struct MultiplayerLobbyView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var networkManager: NetworkManager

    @State private var rooms: [MultiplayerRoom] = []
    @State private var searchText = ""
    @State private var showCreateRoom = false
    @State private var isRefreshing = false

    var filteredRooms: [MultiplayerRoom] {
        searchText.isEmpty ? rooms : rooms.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
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

                    Spacer()

                    Text("Multiplayer Lobby")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showCreateRoom = true }) {
                        Label("Create Room", systemImage: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(red: 0.953, green: 0.451, blue: 0.451)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Search rooms...", text: $searchText)
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)

                    Button(action: { refreshRooms() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white.opacity(0.5))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                .padding(.horizontal, 20)

                // Room list
                if filteredRooms.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No rooms available")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Create a room or refresh the list")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredRooms) { room in
                                RoomCard(room: room) {
                                    audioManager.playSFX(.menuClick)
                                    gameState.navigateTo(.multiplayerRoom(roomId: room.id))
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }

            // Create room sheet
            if showCreateRoom {
                CreateRoomSheet(isPresented: $showCreateRoom)
            }
        }
        .navigationBarHidden(true)
        .onAppear { refreshRooms() }
    }

    private func refreshRooms() {
        isRefreshing = true
        Task {
            let fetched = await networkManager.fetchRooms()
            await MainActor.run {
                rooms = fetched
                isRefreshing = false
            }
        }
    }
}

// MARK: - Data Models

struct MultiplayerRoom: Identifiable {
    let id: String
    let name: String
    let host: String
    let playerCount: Int
    let maxPlayers: Int
    let isLocked: Bool
    let beatmapTitle: String?
    let status: RoomStatus
}

enum RoomStatus: String {
    case waiting = "Waiting"
    case playing = "Playing"
}

// MARK: - Room Card

struct RoomCard: View {
    let room: MultiplayerRoom
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Lock icon
                if room.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Host: \(room.host)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    if let beatmap = room.beatmapTitle {
                        Text(beatmap)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(room.playerCount)/\(room.maxPlayers)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(room.status.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(room.status == .playing ? .orange : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                (room.status == .playing ? Color.orange : Color.green).opacity(0.2)
                            )
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Room Sheet

struct CreateRoomSheet: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var networkManager: NetworkManager
    @Binding var isPresented: Bool

    @State private var roomName = ""
    @State private var maxPlayers = 8
    @State private var password = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                Text("Create Room")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    TextField("Room Name", text: $roomName)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))

                    HStack {
                        Text("Max Players")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Picker("", selection: $maxPlayers) {
                            ForEach([2, 4, 8, 16], id: \.self) { n in
                                Text("\(n)").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    SecureField("Password (optional)", text: $password)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                }

                HStack(spacing: 12) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(.white.opacity(0.6))

                    Button("Create") {
                        Task {
                            if let roomId = await networkManager.createRoom(
                                name: roomName,
                                maxPlayers: maxPlayers,
                                password: password.isEmpty ? nil : password
                            ) {
                                await MainActor.run {
                                    isPresented = false
                                    gameState.navigateTo(.multiplayerRoom(roomId: roomId))
                                }
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(red: 0.953, green: 0.451, blue: 0.451)))
                    .disabled(roomName.isEmpty)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
            )
            .frame(width: 400)
        }
    }
}
