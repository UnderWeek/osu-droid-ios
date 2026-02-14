import AVFoundation
import SwiftUI

/// Manages all audio playback: background music, gameplay audio, and sound effects.
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    // MARK: - Published State

    @Published var isPlaying = false
    @Published var currentTrackTitle = "No music"
    @Published var currentTime: TimeInterval = 0
    @Published var trackDuration: TimeInterval = 0

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private var musicPlayer: AVAudioPlayerNode?
    private var musicFile: AVAudioFile?
    private var timePitch: AVAudioUnitTimePitch?

    /// Dedicated player for gameplay music (separate from menu music).
    private var gameplayPlayer: AVAudioPlayer?

    /// Pre-loaded SFX buffers for low-latency playback.
    private var sfxBuffers: [SFXType: AVAudioPCMBuffer] = [:]
    private var sfxPlayers: [AVAudioPlayerNode] = []
    private let maxSFXPlayers = 8

    // MARK: - Menu music state

    private var menuMusicPlayer: AVAudioPlayer?
    private var musicPlaylist: [String] = []
    private var currentTrackIndex = 0

    // MARK: - Init

    private init() {
        setupAudioSession()
        setupSFXPlayers()
        preloadSFX()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            try session.setActive(true)
        } catch {
            print("[AudioManager] Failed to setup audio session: \(error)")
        }
    }

    private func setupSFXPlayers() {
        for _ in 0..<maxSFXPlayers {
            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: nil)
            sfxPlayers.append(player)
        }

        do {
            try audioEngine.start()
        } catch {
            print("[AudioManager] Failed to start audio engine: \(error)")
        }
    }

    private func preloadSFX() {
        for sfxType in SFXType.allCases {
            if let url = Bundle.main.url(forResource: sfxType.filename, withExtension: "ogg", subdirectory: "SFX") ??
                         Bundle.main.url(forResource: sfxType.filename, withExtension: "wav", subdirectory: "SFX") {
                do {
                    let file = try AVAudioFile(forReading: url)
                    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                  frameCapacity: AVAudioFrameCount(file.length))!
                    try file.read(into: buffer)
                    sfxBuffers[sfxType] = buffer
                } catch {
                    print("[AudioManager] Failed to preload SFX \(sfxType.filename): \(error)")
                }
            }
        }
    }

    // MARK: - Menu Music

    func playMenuMusic() {
        // Build playlist from available beatmaps
        let songsDir = StorageManager.shared.songsDirectory
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: songsDir) else { return }

        musicPlaylist = contents.compactMap { dir in
            let path = "\(songsDir)/\(dir)"
            guard let files = try? fm.contentsOfDirectory(atPath: path) else { return nil }
            return files.first(where: { $0.hasSuffix(".mp3") || $0.hasSuffix(".ogg") })
                .map { "\(path)/\($0)" }
        }

        guard !musicPlaylist.isEmpty else { return }
        musicPlaylist.shuffle()
        playTrack(at: 0)
    }

    private func playTrack(at index: Int) {
        guard index < musicPlaylist.count else { return }
        currentTrackIndex = index
        let path = musicPlaylist[index]

        do {
            menuMusicPlayer?.stop()
            menuMusicPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            menuMusicPlayer?.volume = GameState.shared.config.musicVolume
            menuMusicPlayer?.play()
            isPlaying = true
            currentTrackTitle = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            trackDuration = menuMusicPlayer?.duration ?? 0
        } catch {
            print("[AudioManager] Failed to play track: \(error)")
            nextTrack()
        }
    }

    func nextTrack() {
        currentTrackIndex = (currentTrackIndex + 1) % max(musicPlaylist.count, 1)
        playTrack(at: currentTrackIndex)
    }

    func previousTrack() {
        currentTrackIndex = (currentTrackIndex - 1 + musicPlaylist.count) % max(musicPlaylist.count, 1)
        playTrack(at: currentTrackIndex)
    }

    func togglePlayPause() {
        if isPlaying {
            menuMusicPlayer?.pause()
        } else {
            menuMusicPlayer?.play()
        }
        isPlaying.toggle()
    }

    func previewBeatmap(directoryPath: String) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directoryPath) else { return }

        if let audioFile = files.first(where: { $0.hasSuffix(".mp3") || $0.hasSuffix(".ogg") || $0.hasSuffix(".wav") }) {
            let path = "\(directoryPath)/\(audioFile)"
            do {
                menuMusicPlayer?.stop()
                menuMusicPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                menuMusicPlayer?.volume = GameState.shared.config.musicVolume
                menuMusicPlayer?.currentTime = max(0, (menuMusicPlayer?.duration ?? 0) * 0.4) // Start at 40%
                menuMusicPlayer?.play()
                isPlaying = true
                currentTrackTitle = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            } catch {
                print("[AudioManager] Failed to preview: \(error)")
            }
        }
    }

    // MARK: - Gameplay Audio

    func startGameplayAudio(filePath: String) {
        menuMusicPlayer?.stop()

        do {
            gameplayPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: filePath))
            gameplayPlayer?.volume = GameState.shared.config.musicVolume
            gameplayPlayer?.prepareToPlay()
            gameplayPlayer?.play()
            isPlaying = true
        } catch {
            print("[AudioManager] Failed to start gameplay audio: \(error)")
        }
    }

    func pauseGameplayAudio() {
        gameplayPlayer?.pause()
    }

    func resumeGameplayAudio() {
        gameplayPlayer?.play()
    }

    func stopGameplayAudio() {
        gameplayPlayer?.stop()
        gameplayPlayer = nil
    }

    /// Current gameplay audio position in milliseconds.
    var gameplayTimeMs: Double {
        (gameplayPlayer?.currentTime ?? 0) * 1000.0
    }

    // MARK: - Sound Effects

    private var nextSFXPlayerIndex = 0

    func playSFX(_ type: SFXType) {
        guard let buffer = sfxBuffers[type] else { return }

        let player = sfxPlayers[nextSFXPlayerIndex]
        nextSFXPlayerIndex = (nextSFXPlayerIndex + 1) % maxSFXPlayers

        player.stop()
        player.volume = GameState.shared.config.hitSoundVolume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    // MARK: - Volume Control

    func updateVolumes() {
        menuMusicPlayer?.volume = GameState.shared.config.musicVolume
        gameplayPlayer?.volume = GameState.shared.config.musicVolume
        for player in sfxPlayers {
            player.volume = GameState.shared.config.hitSoundVolume
        }
    }
}

// MARK: - SFX Types

enum SFXType: String, CaseIterable {
    case hitNormal = "hitnormal"
    case hitWhistle = "hitwhistle"
    case hitFinish = "hitfinish"
    case hitClap = "hitclap"
    case sliderSlide = "sliderslide"
    case sliderTick = "slidertick"
    case spinnerSpin = "spinnerspin"
    case spinnerBonus = "spinnerbonus"
    case comboBreak = "combobreak"
    case menuClick = "menuclick"
    case menuBack = "menuback"
    case menuHit = "menuhit"
    case sectionPass = "sectionpass"
    case sectionFail = "sectionfail"
    case applause = "applause"

    var filename: String { rawValue }
}
