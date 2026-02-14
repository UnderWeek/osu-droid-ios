# Plan: osu-droid iOS Port via Kotlin Multiplatform

## Architecture Overview

```
osu-droid/
├── shared/                          # KMP Shared Module (commonMain + targets)
│   ├── src/commonMain/kotlin/
│   │   ├── com/rian/osu/            # ~159 pure Kotlin files (beatmap, difficulty, mods, math)
│   │   └── com/rian/util/
│   ├── src/androidMain/kotlin/      # Android expect/actual implementations
│   └── src/iosMain/kotlin/          # iOS expect/actual implementations
├── android/                         # Existing Android app (refactored)
│   ├── src/                         # Android-specific code (AndEngine, UI, audio)
│   └── build.gradle.kts
├── iosApp/                          # New iOS App (Swift)
│   ├── osu-droid.xcodeproj
│   ├── Sources/
│   │   ├── App/                     # SwiftUI App entry point
│   │   ├── Screens/                 # SwiftUI screens (menu, settings, song select)
│   │   ├── Game/                    # SpriteKit gameplay engine
│   │   │   ├── GameScene.swift      # Main SpriteKit gameplay scene
│   │   │   ├── HitCircleNode.swift  # Hit circle rendering
│   │   │   ├── SliderNode.swift     # Slider rendering
│   │   │   ├── SpinnerNode.swift    # Spinner rendering
│   │   │   ├── CursorNode.swift     # Cursor trail
│   │   │   └── HUDOverlay.swift     # Score, combo, HP bar
│   │   ├── Audio/                   # AVAudioEngine audio system
│   │   ├── Storage/                 # SQLite + UserDefaults
│   │   ├── Network/                 # URLSession + SocketIO
│   │   └── Skin/                    # Skin system
│   ├── Resources/                   # Assets (copied from assets/)
│   └── Info.plist
├── build.gradle.kts                 # Root build (KMP configuration)
└── settings.gradle.kts
```

## Step-by-step Implementation Plan

---

### Step 1: Restructure project for KMP shared module

**What:** Create KMP Gradle configuration and `shared/` module. Move the 159 pure-Kotlin
files from `src/com/rian/` into `shared/src/commonMain/kotlin/`. Keep the 33 files with
Android dependencies in `shared/` too, but introduce `expect`/`actual` abstractions for:

- `android.util.Log` → `expect fun platformLog(tag: String, msg: String)`
- `android.graphics.Color` → `expect class PlatformColor` (only used in ComboColor)
- `ru.nsu.ccfit.zuev.osu.ToastLogger` → `expect object PlatformLogger`
- `ru.nsu.ccfit.zuev.osu.helper.StringTable` → `expect object PlatformStrings`
- `ru.nsu.ccfit.zuev.osu.helper.FileUtils` → already uses java.io.File (JVM-shared)
- `com.reco1l.toolkt.*` → inline the 2-3 used extension functions

**Files to move (commonMain):**
- `com/rian/osu/beatmap/` — all 50+ files (parser, hitobjects, timings, sections)
- `com/rian/osu/difficulty/` — all 35+ files (calculator, skills, evaluators, attributes)
- `com/rian/osu/mods/` — all 40+ files
- `com/rian/osu/math/` — all 10 files
- `com/rian/osu/gameplay/` — 3 files
- `com/rian/osu/replay/` — 7 files (need abstraction for StatisticV2 dependency)
- `com/rian/osu/utils/` — 7 files
- `com/rian/osu/GameMode.kt`
- `com/rian/util/Strings.kt`

**Android app** keeps working as-is — just depends on `shared` module instead of
having these files inline.

**New Gradle files:**
- `shared/build.gradle.kts` — KMP plugin with `androidTarget()` + `iosArm64()` + `iosSimulatorArm64()`
- Update root `settings.gradle.kts` to include `:shared`
- Update root `build.gradle.kts` for KMP plugin

---

### Step 2: Create iOS Xcode project skeleton

**What:** Generate the Xcode project for the iOS app with:

- SwiftUI App lifecycle (`@main struct OsuDroidApp`)
- SpriteKit view embedded via `SpriteView` for gameplay
- KMP framework integration via SPM/CocoaPods
- Target: iOS 16+ (SpriteKit + SwiftUI maturity)
- Landscape-only orientation
- Document storage: `My iPhone/osu-droid` (via `Info.plist` `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`)

**Key files:**
- `iosApp/osu-droid/OsuDroidApp.swift`
- `iosApp/osu-droid/Info.plist` (UIFileSharingEnabled, landscape lock, document types for .osz/.odr)
- `iosApp/osu-droid/ContentView.swift` (navigation root)

---

### Step 3: iOS Audio System

**What:** Implement audio playback using AVAudioEngine (or BASS iOS SDK if available).

- `AudioManager.swift` — singleton managing background music + hit sounds
- Music playback: `AVAudioPlayerNode` for .mp3/.ogg (via AVFoundation)
- SFX playback: preloaded `AVAudioPCMBuffer` for low-latency hit sounds
- Rate adjustment for speed mods (DT/HT/NC): `AVAudioUnitTimePitch`
- Hitsound system: hitnormal, hitclap, hitwhistle, hitfinish + drum/soft variants

**iOS actual implementations:**
- `PlatformAudio` expect/actual for shared module integration

---

### Step 4: iOS Storage System

**What:** Local persistence for beatmaps, scores, settings.

- **Beatmap storage:** Files in app's Documents directory (`My iPhone/osu-droid/Songs/`)
- **Database:** SQLite via GRDB.swift (or SQLite.swift)
  - Tables: beatmaps, scores, collections, mod_presets
  - Mirror Room DB schema from Android
- **Settings:** `UserDefaults` for game configuration
- **File import:** Handle .osz files via document types + Files app integration

---

### Step 5: iOS Game Rendering (SpriteKit)

**What:** Port the gameplay rendering from AndEngine to SpriteKit.

**GameScene.swift** — main SpriteKit scene:
- Coordinate system: match osu! playfield (512x384 logical units) scaled to screen
- Game loop: `update(_:)` at 60/120fps for timing-critical gameplay
- Touch input: `touchesBegan`/`touchesMoved`/`touchesEnded` for tap detection

**Hit Objects:**
- `HitCircleNode`: SKSpriteNode + approach circle (SKShapeNode shrinking animation)
  - Fade in/out timing from beatmap data
  - Number overlay (combo number)
  - Hit judgement animation (300/100/50/miss)
- `SliderNode`: SKShapeNode for slider path (bezier/catmull curves from SliderPath)
  - Slider ball animation following path
  - Slider ticks + reverse arrows
  - Slider body rendering via `CGPath` from control points
- `SpinnerNode`: Centered rotating sprite
  - RPM tracking, spin-to-clear mechanic
  - Progress visualization
- `CursorNode`: Player cursor with trail (SKEmitterNode or trail sprites)

**HUD (SKNode overlay or SwiftUI overlay):**
- Score counter, combo counter, accuracy
- HP bar, progress bar
- Hit error meter

---

### Step 6: iOS Menu System (SwiftUI)

**What:** Implement all game menus in SwiftUI.

**Screens:**
- `MainMenuView` — logo, play/multiplayer/settings/exit buttons
- `SongSelectView` — beatmap list with search, difficulty info, mod selection
  - Beatmap card with title, artist, creator, star rating, duration
  - Difficulty selector
  - Preview audio playback
- `ModMenuView` — grid of mod toggles matching Android mod menu
- `SettingsView` — graphics, audio, gameplay, skin, online settings
- `ResultsView` — score, accuracy, combo, hit distribution, grade
- `MultiplayerLobbyView` — room list, create room
- `MultiplayerRoomView` — player list, chat, beatmap info, ready/start

**Navigation:** NavigationStack with programmatic navigation

---

### Step 7: iOS Skin System

**What:** Load and apply osu! skins.

- Parse `skin.ini` files (reuse shared IniReader logic)
- Load textures from skin directories into SpriteKit texture atlas
- Fallback to default assets
- Support beatmap-specific skins
- Skin directory: `My iPhone/osu-droid/Skins/`

---

### Step 8: iOS Networking & Multiplayer

**What:** Online features and multiplayer.

- **HTTP:** URLSession for API calls (score submission, beatmap listing)
- **Socket.IO:** SocketIO-swift library for real-time multiplayer
  - Lobby API: room list, search, create
  - Room API: player management, chat, match flow
- **Firebase:** Firebase iOS SDK for Crashlytics + Analytics
- **Beatmap download:** Background URLSession download tasks

---

### Step 9: Beatmap Import & File Handling

**What:** Handle .osz and .odr files on iOS.

- Register UTI/document types for .osz (beatmap) and .odr (replay)
- Import from Files app, Safari downloads, AirDrop
- Extract .osz (ZIP) to Songs directory using ZIPFoundation
- Parse extracted .osu files using shared KMP beatmap parser
- Index into local SQLite database

---

### Step 10: Testing & Polish

**What:** Ensure feature parity and gameplay accuracy.

- Unit tests for shared KMP module (difficulty calculation, beatmap parsing)
- Gameplay accuracy testing against known beatmaps
- Touch input latency optimization
- Audio-visual sync calibration (offset settings)
- Memory profiling for texture management
- Battery optimization for long play sessions

---

## Dependencies (iOS)

| Library | Purpose | Integration |
|---------|---------|-------------|
| shared (KMP) | Beatmap parsing, difficulty calc, mods | SPM/CocoaPods framework |
| GRDB.swift | SQLite database | SPM |
| SocketIO-swift | Multiplayer | SPM |
| ZIPFoundation | .osz extraction | SPM |
| Firebase iOS SDK | Analytics, Crashlytics | SPM |

## Storage Layout (My iPhone/osu-droid)

```
osu-droid/
├── Songs/           # Beatmap directories (extracted .osz)
│   ├── 12345 Artist - Title/
│   │   ├── audio.mp3
│   │   ├── bg.jpg
│   │   ├── Easy.osu
│   │   └── Hard.osu
│   └── ...
├── Skins/           # Custom skins
│   ├── default/
│   └── custom-skin/
├── Replays/         # .odr replay files
├── Export/          # Exported replays/scores
└── osu-droid.db     # SQLite database
```
