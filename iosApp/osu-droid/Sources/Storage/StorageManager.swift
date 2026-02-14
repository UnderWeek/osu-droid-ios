import Foundation
import SwiftUI
import SQLite3

/// Manages file storage, database, and settings persistence.
final class StorageManager: ObservableObject {
    static let shared = StorageManager()

    // MARK: - Directories

    /// Root directory: Documents/osu-droid (visible in Files app as "My iPhone/osu-droid")
    var rootDirectory: String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return docs
    }

    var songsDirectory: String { "\(rootDirectory)/Songs" }
    var skinsDirectory: String { "\(rootDirectory)/Skins" }
    var replaysDirectory: String { "\(rootDirectory)/Replays" }
    var exportDirectory: String { "\(rootDirectory)/Export" }
    var databasePath: String { "\(rootDirectory)/osu-droid.db" }

    // MARK: - Database

    private var db: OpaquePointer?

    // MARK: - Init

    private init() {
        createDirectories()
        openDatabase()
        createTables()
    }

    private func createDirectories() {
        let fm = FileManager.default
        for dir in [songsDirectory, skinsDirectory, replaysDirectory, exportDirectory] {
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Database Operations

    private func openDatabase() {
        if sqlite3_open(databasePath, &db) != SQLITE_OK {
            print("[StorageManager] Failed to open database at \(databasePath)")
        }
    }

    private func createTables() {
        let createBeatmaps = """
        CREATE TABLE IF NOT EXISTS beatmaps (
            id TEXT PRIMARY KEY,
            set_id TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            creator TEXT NOT NULL,
            version TEXT NOT NULL,
            file_path TEXT NOT NULL,
            directory_path TEXT NOT NULL,
            md5 TEXT NOT NULL,
            star_rating REAL DEFAULT 0,
            cs REAL DEFAULT 0,
            ar REAL DEFAULT 0,
            od REAL DEFAULT 0,
            hp REAL DEFAULT 0,
            bpm REAL DEFAULT 0,
            length_ms INTEGER DEFAULT 0,
            max_combo INTEGER DEFAULT 0,
            circle_count INTEGER DEFAULT 0,
            slider_count INTEGER DEFAULT 0,
            spinner_count INTEGER DEFAULT 0,
            last_updated INTEGER DEFAULT 0
        );
        """

        let createScores = """
        CREATE TABLE IF NOT EXISTS scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            beatmap_id TEXT NOT NULL,
            score INTEGER NOT NULL,
            accuracy REAL NOT NULL,
            max_combo INTEGER NOT NULL,
            count_300 INTEGER NOT NULL,
            count_100 INTEGER NOT NULL,
            count_50 INTEGER NOT NULL,
            count_miss INTEGER NOT NULL,
            mods TEXT NOT NULL,
            grade TEXT NOT NULL,
            date INTEGER NOT NULL,
            FOREIGN KEY (beatmap_id) REFERENCES beatmaps(id)
        );
        """

        let createCollections = """
        CREATE TABLE IF NOT EXISTS collections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );
        """

        let createCollectionBeatmaps = """
        CREATE TABLE IF NOT EXISTS collection_beatmaps (
            collection_id INTEGER NOT NULL,
            beatmap_id TEXT NOT NULL,
            PRIMARY KEY (collection_id, beatmap_id),
            FOREIGN KEY (collection_id) REFERENCES collections(id),
            FOREIGN KEY (beatmap_id) REFERENCES beatmaps(id)
        );
        """

        let createModPresets = """
        CREATE TABLE IF NOT EXISTS mod_presets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            mods TEXT NOT NULL
        );
        """

        for sql in [createBeatmaps, createScores, createCollections, createCollectionBeatmaps, createModPresets] {
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
                let error = errMsg.map { String(cString: $0) } ?? "unknown"
                print("[StorageManager] SQL error: \(error)")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Beatmap Library

    func loadBeatmapLibrary() async -> [BeatmapSetInfo] {
        var sets: [String: BeatmapSetInfo] = [:]

        let sql = "SELECT * FROM beatmaps ORDER BY title"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let setId = String(cString: sqlite3_column_text(stmt, 1))
            let title = String(cString: sqlite3_column_text(stmt, 2))
            let artist = String(cString: sqlite3_column_text(stmt, 3))
            let creator = String(cString: sqlite3_column_text(stmt, 4))
            let version = String(cString: sqlite3_column_text(stmt, 5))
            let filePath = String(cString: sqlite3_column_text(stmt, 6))
            let dirPath = String(cString: sqlite3_column_text(stmt, 7))
            let md5 = String(cString: sqlite3_column_text(stmt, 8))
            let starRating = sqlite3_column_double(stmt, 9)
            let cs = Float(sqlite3_column_double(stmt, 10))
            let ar = Float(sqlite3_column_double(stmt, 11))
            let od = Float(sqlite3_column_double(stmt, 12))
            let hp = Float(sqlite3_column_double(stmt, 13))
            let bpm = sqlite3_column_double(stmt, 14)
            let lengthMs = Int(sqlite3_column_int(stmt, 15))
            let maxCombo = Int(sqlite3_column_int(stmt, 16))
            let circleCount = Int(sqlite3_column_int(stmt, 17))
            let sliderCount = Int(sqlite3_column_int(stmt, 18))
            let spinnerCount = Int(sqlite3_column_int(stmt, 19))

            let diff = BeatmapInfo(
                id: id, version: version, filePath: filePath,
                starRating: starRating, cs: cs, ar: ar, od: od, hp: hp, bpm: bpm,
                lengthMs: lengthMs, maxCombo: maxCombo,
                circleCount: circleCount, sliderCount: sliderCount, spinnerCount: spinnerCount
            )

            if var existing = sets[setId] {
                var diffs = existing.difficulties
                diffs.append(diff)
                sets[setId] = BeatmapSetInfo(
                    id: setId, title: title, artist: artist, creator: creator,
                    difficulties: diffs.sorted { $0.starRating < $1.starRating },
                    directoryPath: dirPath
                )
            } else {
                sets[setId] = BeatmapSetInfo(
                    id: setId, title: title, artist: artist, creator: creator,
                    difficulties: [diff], directoryPath: dirPath
                )
            }
        }

        sqlite3_finalize(stmt)
        return Array(sets.values).sorted { $0.title < $1.title }
    }

    // MARK: - Save Beatmap

    func saveBeatmap(_ info: BeatmapInfo, setId: String, title: String, artist: String,
                     creator: String, directoryPath: String) {
        let sql = """
        INSERT OR REPLACE INTO beatmaps
        (id, set_id, title, artist, creator, version, file_path, directory_path, md5,
         star_rating, cs, ar, od, hp, bpm, length_ms, max_combo,
         circle_count, slider_count, spinner_count, last_updated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }

        sqlite3_bind_text(stmt, 1, (info.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (setId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (artist as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5, (creator as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (info.version as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 7, (info.filePath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 8, (directoryPath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 9, (info.id as NSString).utf8String, -1, nil) // md5
        sqlite3_bind_double(stmt, 10, info.starRating)
        sqlite3_bind_double(stmt, 11, Double(info.cs))
        sqlite3_bind_double(stmt, 12, Double(info.ar))
        sqlite3_bind_double(stmt, 13, Double(info.od))
        sqlite3_bind_double(stmt, 14, Double(info.hp))
        sqlite3_bind_double(stmt, 15, info.bpm)
        sqlite3_bind_int(stmt, 16, Int32(info.lengthMs))
        sqlite3_bind_int(stmt, 17, Int32(info.maxCombo))
        sqlite3_bind_int(stmt, 18, Int32(info.circleCount))
        sqlite3_bind_int(stmt, 19, Int32(info.sliderCount))
        sqlite3_bind_int(stmt, 20, Int32(info.spinnerCount))
        sqlite3_bind_int64(stmt, 21, Int64(Date().timeIntervalSince1970))

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // MARK: - Save Score

    func saveScore(_ score: GameScore) {
        let sql = """
        INSERT INTO scores (beatmap_id, score, accuracy, max_combo,
        count_300, count_100, count_50, count_miss, mods, grade, date)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }

        sqlite3_bind_text(stmt, 1, (score.beatmapId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(score.score))
        sqlite3_bind_double(stmt, 3, score.accuracy)
        sqlite3_bind_int(stmt, 4, Int32(score.maxCombo))
        sqlite3_bind_int(stmt, 5, Int32(score.count300))
        sqlite3_bind_int(stmt, 6, Int32(score.count100))
        sqlite3_bind_int(stmt, 7, Int32(score.count50))
        sqlite3_bind_int(stmt, 8, Int32(score.countMiss))
        sqlite3_bind_text(stmt, 9, (score.mods.joined(separator: ",") as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 10, (score.grade.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 11, Int64(score.date.timeIntervalSince1970))

        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // MARK: - Scores Query

    func getScores(for beatmapId: String) -> [GameScore] {
        let sql = "SELECT * FROM scores WHERE beatmap_id = ? ORDER BY score DESC LIMIT 50"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        sqlite3_bind_text(stmt, 1, (beatmapId as NSString).utf8String, -1, nil)

        var scores: [GameScore] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let modsStr = String(cString: sqlite3_column_text(stmt, 9))
            let gradeStr = String(cString: sqlite3_column_text(stmt, 10))

            scores.append(GameScore(
                beatmapId: beatmapId,
                score: Int(sqlite3_column_int(stmt, 2)),
                accuracy: sqlite3_column_double(stmt, 3),
                maxCombo: Int(sqlite3_column_int(stmt, 4)),
                count300: Int(sqlite3_column_int(stmt, 5)),
                count100: Int(sqlite3_column_int(stmt, 6)),
                count50: Int(sqlite3_column_int(stmt, 7)),
                countMiss: Int(sqlite3_column_int(stmt, 8)),
                mods: modsStr.split(separator: ",").map(String.init),
                grade: ScoreGrade(rawValue: gradeStr) ?? .d,
                date: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 11)))
            ))
        }

        sqlite3_finalize(stmt)
        return scores
    }

    // MARK: - Cache

    func clearBeatmapCache() {
        sqlite3_exec(db, "DELETE FROM beatmaps", nil, nil, nil)
    }

    // MARK: - Cleanup

    deinit {
        sqlite3_close(db)
    }
}
