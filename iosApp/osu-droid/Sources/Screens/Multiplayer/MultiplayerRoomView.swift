import SwiftUI

struct MultiplayerRoomView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var networkManager: NetworkManager

    let roomId: String

    @State private var players: [RoomPlayer] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput = ""
    @State private var currentBeatmap: String = "No beatmap selected"
    @State private var isHost = false
    @State private var isReady = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Left: Players + Beatmap info
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Button(action: {
                            networkManager.leaveRoom()
                            audioManager.playSFX(.menuBack)
                            gameState.navigateBack()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Leave")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.953, green: 0.451, blue: 0.451))
                        }

                        Spacer()

                        Text("Room")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()
                    }

                    // Beatmap card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Beatmap")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        Text(currentBeatmap)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        if isHost {
                            Button("Change Beatmap") {
                                audioManager.playSFX(.menuClick)
                                // Navigate to song select in multiplayer mode
                            }
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.953, green: 0.451, blue: 0.451))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))

                    // Player list
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(players) { player in
                                PlayerRow(player: player)
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            isReady.toggle()
                            networkManager.setReady(isReady)
                            audioManager.playSFX(.menuClick)
                        }) {
                            Text(isReady ? "Not Ready" : "Ready")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isReady ? Color.gray.opacity(0.4) : Color.green.opacity(0.6))
                                )
                        }

                        if isHost {
                            Button(action: {
                                networkManager.startMatch()
                                audioManager.playSFX(.menuClick)
                            }) {
                                Text("Start")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.953, green: 0.451, blue: 0.451))
                                    )
                            }
                        }
                    }
                }
                .padding(16)
                .frame(width: UIScreen.main.bounds.width * 0.45)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)

                // Right: Chat
                VStack(spacing: 0) {
                    Text("Chat")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.03))

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(chatMessages) { msg in
                                    ChatBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(8)
                        }
                        .onChange(of: chatMessages.count) {
                            if let last = chatMessages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }

                    // Chat input
                    HStack(spacing: 8) {
                        TextField("Type a message...", text: $chatInput)
                            .foregroundColor(.white)
                            .textFieldStyle(.plain)
                            .onSubmit { sendChat() }

                        Button(action: sendChat) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(chatInput.isEmpty ? .white.opacity(0.3) : Color(red: 0.953, green: 0.451, blue: 0.451))
                        }
                        .disabled(chatInput.isEmpty)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { joinRoom() }
    }

    private func joinRoom() {
        networkManager.joinRoom(roomId: roomId) { updatedPlayers, messages, beatmap, host in
            players = updatedPlayers
            chatMessages = messages
            currentBeatmap = beatmap
            isHost = host
        }
    }

    private func sendChat() {
        guard !chatInput.isEmpty else { return }
        networkManager.sendChatMessage(chatInput)
        chatInput = ""
    }
}

// MARK: - Supporting Types

struct RoomPlayer: Identifiable {
    let id: String
    let name: String
    let isHost: Bool
    let isReady: Bool
    let mods: [String]
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let text: String
    let timestamp: Date
    let isSystem: Bool
}

// MARK: - Player Row

struct PlayerRow: View {
    let player: RoomPlayer

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(player.isReady ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(player.name)
                .font(.system(size: 14))
                .foregroundColor(.white)

            if player.isHost {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }

            Spacer()

            if !player.mods.isEmpty {
                HStack(spacing: 2) {
                    ForEach(player.mods, id: \.self) { mod in
                        Text(mod)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            Text(player.isReady ? "Ready" : "Not ready")
                .font(.system(size: 11))
                .foregroundColor(player.isReady ? .green : .white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.isSystem {
            Text(message.text)
                .font(.system(size: 11))
                .foregroundColor(.yellow.opacity(0.6))
                .italic()
        } else {
            HStack(alignment: .top, spacing: 6) {
                Text("\(message.sender):")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.953, green: 0.451, blue: 0.451))
                Text(message.text)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
