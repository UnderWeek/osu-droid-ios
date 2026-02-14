import SwiftUI
import UniformTypeIdentifiers

/// Handles .osz and .odr file imports from other apps, Files, AirDrop, etc.
struct OsuFileImporter: ViewModifier {
    @EnvironmentObject var gameState: GameState
    @State private var showImportProgress = false
    @State private var importProgress: Double = 0
    @State private var importMessage = ""

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                handleIncomingFile(url)
            }
            .overlay {
                if showImportProgress {
                    importOverlay
                }
            }
    }

    private func handleIncomingFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "osz":
            importBeatmap(from: url)
        case "odr":
            importReplay(from: url)
        default:
            print("[FileHandler] Unknown file type: \(ext)")
        }
    }

    private func importBeatmap(from url: URL) {
        showImportProgress = true
        importMessage = "Importing beatmap..."

        Task {
            // Ensure we have access to the file
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let success = await BeatmapImporter.shared.importOSZ(from: url)

            await MainActor.run {
                showImportProgress = false
                if success {
                    gameState.refreshBeatmapLibrary()
                }
            }
        }
    }

    private func importReplay(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let dest = "\(StorageManager.shared.replaysDirectory)/\(url.lastPathComponent)"
        try? fm.copyItem(at: url, to: URL(fileURLWithPath: dest))
    }

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text(importMessage)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.12, green: 0.12, blue: 0.18)))
        }
    }
}

extension View {
    func osuFileImporter() -> some View {
        modifier(OsuFileImporter())
    }
}

// MARK: - UTI Definitions

extension UTType {
    static var osuBeatmap: UTType {
        UTType(exportedAs: "com.osu.beatmap.osz", conformingTo: .zip)
    }

    static var osuDroidReplay: UTType {
        UTType(exportedAs: "com.osudroid.replay.odr")
    }
}
