namespace Services {
namespace Storage {
namespace FileStore {
    const string DB_PATH = IO::FromStorageFolder("arl.sqlite");
    const string INGEST_DIRECTORY = IO::FromStorageFolder("ingest/");
    const string KIND_GPS_GHOST = "gps_ghost";
    const string KIND_REMOTE_GHOST = "remote_ghost";
    const string KIND_URL_FILE = "url_file";
    const string KIND_SAVED_REPLAY = "saved_replay";
    const string KIND_VALIDATION_REPLAY = "validation_replay";

    SQLite::Database@ g_Db = null;
    bool g_DbReady = false;
    dictionary g_RecordById;
    dictionary g_RecordByFileName;
    dictionary g_RecordByStoredPath;

    class StoredFileRecord {
        string fileId;
        string kind;
        int sourceKind = 0;
        string fileName;
        string storedPath;
        string originalFileName;
        string backendFileName;
        string sourceRef;
        string mapUid;
        string accountId;
        int clipIndex = -1;
        int trackIndex = -1;
        int blockIndex = -1;
        int derivedRaceTimeMs = -1;
        string clipName;
        string trackName;
        string sourcePath;
        bool useGhostLayer = true;
        int64 sizeBytes = 0;
        int64 createdAt = 0;
        int64 updatedAt = 0;
    }

    class SavedReplayRecord {
        string savedId;
        string fileId;
        string nickname;
        int time = -1;
        int score = 0;
        string source;
        string sourceRef;
        string mapUid;
        string accountId;
        string savedAt;
        int64 createdAt = 0;
    }

    void EnsureOpen() {
        if (g_DbReady && g_Db !is null) return;

        string dbDir = Path::GetDirectoryName(DB_PATH);
        if (dbDir.Length > 0 && !IO::FolderExists(dbDir)) {
            IO::CreateFolder(dbDir, true);
        }
        if (!IO::FolderExists(Server::storedFilesDirectory)) {
            IO::CreateFolder(Server::storedFilesDirectory, true);
        }
        if (!IO::FolderExists(INGEST_DIRECTORY)) {
            IO::CreateFolder(INGEST_DIRECTORY, true);
        }

        @g_Db = SQLite::Database(DB_PATH);
        g_Db.Execute("PRAGMA journal_mode=WAL;");
        g_Db.Execute("PRAGMA synchronous=NORMAL;");
        g_Db.Execute(
            "CREATE TABLE IF NOT EXISTS stored_files ("
            "  file_id TEXT PRIMARY KEY,"
            "  kind TEXT NOT NULL,"
            "  source_kind INTEGER NOT NULL DEFAULT 0,"
            "  file_name TEXT NOT NULL,"
            "  stored_path TEXT NOT NULL,"
            "  original_file_name TEXT,"
            "  backend_file_name TEXT,"
            "  source_ref TEXT,"
            "  map_uid TEXT,"
            "  account_id TEXT,"
            "  clip_index INTEGER,"
            "  track_index INTEGER,"
            "  block_index INTEGER,"
            "  derived_race_time_ms INTEGER,"
            "  clip_name TEXT,"
            "  track_name TEXT,"
            "  source_path TEXT,"
            "  use_ghost_layer INTEGER NOT NULL DEFAULT 1,"
            "  size_bytes INTEGER NOT NULL DEFAULT 0,"
            "  created_at INTEGER NOT NULL,"
            "  updated_at INTEGER NOT NULL"
            ");"
        );
        g_Db.Execute("CREATE INDEX IF NOT EXISTS idx_stored_files_kind_map_track ON stored_files(kind, map_uid, clip_index, track_index, block_index, updated_at DESC);");
        g_Db.Execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_stored_files_file_name ON stored_files(file_name);");
        g_Db.Execute(
            "CREATE TABLE IF NOT EXISTS gps_inspect_cache ("
            "  map_uid TEXT PRIMARY KEY,"
            "  manifest_json TEXT NOT NULL,"
            "  updated_at INTEGER NOT NULL"
            ");"
        );
        g_Db.Execute(
            "CREATE TABLE IF NOT EXISTS saved_replays ("
            "  saved_id TEXT PRIMARY KEY,"
            "  file_id TEXT NOT NULL,"
            "  nickname TEXT,"
            "  time INTEGER NOT NULL DEFAULT -1,"
            "  score INTEGER NOT NULL DEFAULT 0,"
            "  source TEXT,"
            "  source_ref TEXT,"
            "  map_uid TEXT,"
            "  account_id TEXT,"
            "  saved_at TEXT,"
            "  created_at INTEGER NOT NULL"
            ");"
        );
        HydrateCache();
        g_DbReady = true;
    }

    void HydrateCache() {
        auto keys = g_RecordById.GetKeys();
        for (uint i = 0; i < keys.Length; i++) g_RecordById.Delete(keys[i]);
        keys = g_RecordByFileName.GetKeys();
        for (uint i = 0; i < keys.Length; i++) g_RecordByFileName.Delete(keys[i]);
        keys = g_RecordByStoredPath.GetKeys();
        for (uint i = 0; i < keys.Length; i++) g_RecordByStoredPath.Delete(keys[i]);

        SQLite::Statement@ st = g_Db.Prepare("SELECT * FROM stored_files;");
        while (st.NextRow()) {
            CacheRecord(ReadRecord(st));
        }
    }

    void CacheRecord(StoredFileRecord@ record) {
        if (record is null) return;
        if (record.fileId.Length > 0) g_RecordById.Set(record.fileId, @record);
        if (record.fileName.Length > 0) g_RecordByFileName.Set(record.fileName, @record);
        if (record.storedPath.Length > 0) g_RecordByStoredPath.Set(record.storedPath, @record);
    }

    void RemoveRecordFromCache(StoredFileRecord@ record) {
        if (record is null) return;
        if (record.fileId.Length > 0) g_RecordById.Delete(record.fileId);
        if (record.fileName.Length > 0) g_RecordByFileName.Delete(record.fileName);
        if (record.storedPath.Length > 0) g_RecordByStoredPath.Delete(record.storedPath);
    }

    StoredFileRecord@ GetCachedRecordById(const string &in fileId) {
        if (fileId.Length == 0 || !g_RecordById.Exists(fileId)) return null;
        ref@ r;
        g_RecordById.Get(fileId, @r);
        return cast<StoredFileRecord@>(r);
    }

    StoredFileRecord@ GetCachedRecordByFileName(const string &in fileName) {
        if (fileName.Length == 0 || !g_RecordByFileName.Exists(fileName)) return null;
        ref@ r;
        g_RecordByFileName.Get(fileName, @r);
        return cast<StoredFileRecord@>(r);
    }

    StoredFileRecord@ GetCachedRecordByStoredPath(const string &in storedPath) {
        if (storedPath.Length == 0 || !g_RecordByStoredPath.Exists(storedPath)) return null;
        ref@ r;
        g_RecordByStoredPath.Get(storedPath, @r);
        return cast<StoredFileRecord@>(r);
    }

    string NormalizeKind(const string &in kind) {
        string normalized = kind.Trim().ToLower();
        if (normalized.Length == 0) return "misc";
        return normalized;
    }

    string BuildFileId(const string &in kind, const string &in identity) {
        return Crypto::Sha1(NormalizeKind(kind) + "|" + identity).ToLower();
    }

    string TryGetManagedFileIdFromName(const string &in name) {
        string trimmed = Path::GetFileName(name.Trim());
        if (!trimmed.StartsWith("ARL_")) return "";
        int dot = trimmed.IndexOf(".");
        if (dot <= 4) return "";
        string fileId = trimmed.SubStr(4, dot - 4).ToLower();
        if (fileId.Length == 0) return "";
        return fileId;
    }

    StoredFileRecord@ ResolveManagedRecord(const string &in keyOrName) {
        string trimmed = keyOrName.Trim();
        if (trimmed.Length == 0) return null;

        auto record = GetByFileId(trimmed);
        if (record !is null) return record;

        string managedId = TryGetManagedFileIdFromName(trimmed);
        if (managedId.Length > 0) {
            @record = GetByFileId(managedId);
            if (record !is null) return record;
        }

        return GetByFileName(Path::GetFileName(trimmed));
    }

    string InferManagedExtension(const string &in fileName, const string &in fallback = ".bin") {
        string trimmed = fileName.Trim();
        string lower = trimmed.ToLower();
        if (lower.EndsWith(".ghost.gbx")) return ".Ghost.Gbx";
        if (lower.EndsWith(".replay.gbx")) return ".Replay.Gbx";

        string ext = Path::GetExtension(trimmed);
        if (ext.Length == 0) ext = fallback;
        if (!ext.StartsWith(".")) ext = "." + ext;
        return ext;
    }

    string BuildStoredFilePath(const string &in kind, const string &in fileId, const string &in extension = ".bin") {
        EnsureOpen();

        string safeExt = extension.Length > 0 ? extension : ".bin";
        if (!safeExt.StartsWith(".")) safeExt = "." + safeExt;
        if (!IO::FolderExists(Server::storedFilesDirectory)) {
            IO::CreateFolder(Server::storedFilesDirectory, true);
        }
        return Path::Join(Server::storedFilesDirectory, "ARL_" + fileId.ToLower() + safeExt);
    }

    void Upsert(StoredFileRecord@ record) {
        if (record is null) return;
        EnsureOpen();

        if (record.fileId.Length == 0 || record.storedPath.Length == 0) {
            throw("Stored file record requires fileId and storedPath.");
        }

        record.kind = NormalizeKind(record.kind);
        if (record.fileName.Length == 0) record.fileName = Path::GetFileName(record.storedPath);
        if (record.fileName.Length == 0) record.fileName = record.fileId;
        if (record.sizeBytes <= 0 && IO::FileExists(record.storedPath)) {
            record.sizeBytes = int64(IO::FileSize(record.storedPath));
        }

        int64 now = Time::Stamp;
        if (record.createdAt <= 0) record.createdAt = now;
        if (record.updatedAt <= 0) record.updatedAt = now;

        auto existing = GetCachedRecordById(record.fileId);
        if (existing !is null) {
            RemoveRecordFromCache(existing);
        }

        SQLite::Statement@ st = g_Db.Prepare(
            "INSERT OR REPLACE INTO stored_files ("
            "  file_id, kind, source_kind, file_name, stored_path, original_file_name, backend_file_name, source_ref, map_uid, account_id,"
            "  clip_index, track_index, block_index, derived_race_time_ms, clip_name, track_name, source_path, use_ghost_layer, size_bytes, created_at, updated_at"
            ") VALUES ("
            "  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,"
            "  ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"
            ");"
        );
        st.Bind(1, record.fileId);
        st.Bind(2, record.kind);
        st.Bind(3, int64(record.sourceKind));
        st.Bind(4, record.fileName);
        st.Bind(5, record.storedPath);
        st.Bind(6, record.originalFileName);
        st.Bind(7, record.backendFileName);
        st.Bind(8, record.sourceRef);
        st.Bind(9, record.mapUid);
        st.Bind(10, record.accountId);
        st.Bind(11, int64(record.clipIndex));
        st.Bind(12, int64(record.trackIndex));
        st.Bind(13, int64(record.blockIndex));
        st.Bind(14, int64(record.derivedRaceTimeMs));
        st.Bind(15, record.clipName);
        st.Bind(16, record.trackName);
        st.Bind(17, record.sourcePath);
        st.Bind(18, int64(record.useGhostLayer ? 1 : 0));
        st.Bind(19, record.sizeBytes);
        st.Bind(20, record.createdAt);
        st.Bind(21, record.updatedAt);
        st.Execute();
        CacheRecord(record);
    }

    StoredFileRecord@ GetByFileId(const string &in fileId) {
        if (fileId.Trim().Length == 0) return null;
        EnsureOpen();

        auto cached = GetCachedRecordById(fileId.Trim().ToLower());
        if (cached !is null) return cached;

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files WHERE file_id = ? LIMIT 1;"
        );
        st.Bind(1, fileId.Trim().ToLower());
        if (!st.NextRow()) return null;
        auto record = ReadRecord(st);
        CacheRecord(record);
        return record;
    }

    StoredFileRecord@ GetByFileName(const string &in fileName) {
        if (fileName.Trim().Length == 0) return null;
        EnsureOpen();

        auto cached = GetCachedRecordByFileName(fileName.Trim());
        if (cached !is null) return cached;

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files WHERE file_name = ? LIMIT 1;"
        );
        st.Bind(1, fileName.Trim());
        if (!st.NextRow()) return null;
        auto record = ReadRecord(st);
        CacheRecord(record);
        return record;
    }

    StoredFileRecord@ GetByStoredPath(const string &in storedPath) {
        if (storedPath.Trim().Length == 0) return null;
        EnsureOpen();

        auto cached = GetCachedRecordByStoredPath(storedPath.Trim());
        if (cached !is null) return cached;

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files WHERE stored_path = ? LIMIT 1;"
        );
        st.Bind(1, storedPath.Trim());
        if (st.NextRow()) {
            auto record = ReadRecord(st);
            CacheRecord(record);
            return record;
        }

        return ResolveManagedRecord(Path::GetFileName(storedPath));
    }

    StoredFileRecord@ FindGpsGhost(const string &in mapUid, uint clipIndex, uint trackIndex, int blockIndex) {
        if (mapUid.Trim().Length == 0 || blockIndex < 0) return null;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files "
            "WHERE kind = ? AND map_uid = ? AND clip_index = ? AND track_index = ? AND block_index = ? "
            "ORDER BY updated_at DESC LIMIT 1;"
        );
        st.Bind(1, KIND_GPS_GHOST);
        st.Bind(2, mapUid);
        st.Bind(3, int64(clipIndex));
        st.Bind(4, int64(trackIndex));
        st.Bind(5, int64(blockIndex));
        if (!st.NextRow()) return null;
        auto record = ReadRecord(st);
        CacheRecord(record);
        return record;
    }

    StoredFileRecord@ FindByKindAndSourceRef(const string &in kind, const string &in sourceRef) {
        if (kind.Trim().Length == 0 || sourceRef.Trim().Length == 0) return null;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files WHERE kind = ? AND source_ref = ? LIMIT 1;"
        );
        st.Bind(1, NormalizeKind(kind));
        st.Bind(2, sourceRef);
        if (!st.NextRow()) return null;
        auto record = ReadRecord(st);
        CacheRecord(record);
        return record;
    }

    StoredFileRecord@ FindLatestByKindAndMapUid(const string &in kind, const string &in mapUid) {
        if (kind.Trim().Length == 0 || mapUid.Trim().Length == 0) return null;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files WHERE kind = ? AND map_uid = ? ORDER BY updated_at DESC LIMIT 1;"
        );
        st.Bind(1, NormalizeKind(kind));
        st.Bind(2, mapUid);
        if (!st.NextRow()) return null;
        auto record = ReadRecord(st);
        CacheRecord(record);
        return record;
    }

    StoredFileRecord@ FindRemoteGhost(const string &in mapUid, const string &in accountId, int expectedTimeMs) {
        if (mapUid.Trim().Length == 0 || accountId.Trim().Length == 0 || expectedTimeMs <= 0) return null;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files "
            "WHERE kind = ? AND map_uid = ? AND account_id = ? "
            "ORDER BY updated_at DESC;"
        );
        st.Bind(1, KIND_REMOTE_GHOST);
        st.Bind(2, mapUid.Trim());
        st.Bind(3, accountId.Trim());

        while (st.NextRow()) {
            auto record = ReadRecord(st);
            CacheRecord(record);
            if (LoadedRecords::TryParseExpectedRaceTimeMs(record.sourceRef) == expectedTimeMs) {
                return record;
            }
        }

        return null;
    }

    StoredFileRecord@ FindRemoteGhostByStorageObjectUuid(const string &in mapUid, const string &in accountId, const string &in storageObjectUuid) {
        string normalizedUuid = storageObjectUuid.Trim().ToLower();
        if (mapUid.Trim().Length == 0 || accountId.Trim().Length == 0 || normalizedUuid.Length == 0) return null;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM stored_files "
            "WHERE kind = ? AND map_uid = ? AND account_id = ? "
            "ORDER BY updated_at DESC;"
        );
        st.Bind(1, KIND_REMOTE_GHOST);
        st.Bind(2, mapUid.Trim());
        st.Bind(3, accountId.Trim());

        while (st.NextRow()) {
            auto record = ReadRecord(st);
            CacheRecord(record);
            if (LoadedRecords::TryParseStorageObjectUuid(record.sourceRef) == normalizedUuid) {
                return record;
            }
        }

        return null;
    }

    string GetStoredFileExtension(StoredFileRecord@ record) {
        if (record is null) return ".bin";

        string ext = InferManagedExtension(record.fileName, "");
        if (ext.Length == 0 || ext == ".") ext = InferManagedExtension(record.storedPath, ".bin");
        return ext;
    }

    string GetCanonicalStoredPath(StoredFileRecord@ record) {
        if (record is null) return "";
        return BuildStoredFilePath(record.kind, record.fileId, GetStoredFileExtension(record));
    }

    bool StageForGame(const string &in fileId, const string &in stagingDirectory, string &out stagedPath, string &out err) {
        stagedPath = "";
        err = "";
        StoredFileRecord@ record = GetByFileId(fileId);
        if (record is null) {
            err = "Stored file metadata not found for id: " + fileId;
            return false;
        }
        if (!IO::FileExists(record.storedPath)) {
            err = "Stored file is missing: " + record.storedPath;
            return false;
        }

        if (!IO::FolderExists(stagingDirectory)) {
            IO::CreateFolder(stagingDirectory, true);
        }

        stagedPath = Path::Join(stagingDirectory, record.fileName);
        if (record.storedPath == stagedPath) return true;

        if (IO::FileExists(stagedPath)) {
            try { IO::Delete(stagedPath); } catch {
                log("Failed to delete existing staged file before overwrite: " + stagedPath + " " + getExceptionInfo(), LogLevel::Warning, -1, "StageForGame");
            }
        }

        try {
            IO::Move(record.storedPath, stagedPath);
        } catch {
            err = "Failed to move stored file into the game-owned staging directory.";
            log(err + " " + record.storedPath + " -> " + stagedPath + " " + getExceptionInfo(), LogLevel::Warning, -1, "StageForGame");
            return false;
        }

        if (!IO::FileExists(stagedPath)) {
            err = "Staged file missing after move: " + stagedPath;
            return false;
        }

        RemoveRecordFromCache(record);
        record.storedPath = stagedPath;
        Upsert(record);
        return true;
    }

    bool RestoreFromGameStage(const string &in fileId, string &out err) {
        err = "";
        StoredFileRecord@ record = GetByFileId(fileId);
        if (record is null) {
            err = "Stored file metadata not found for id: " + fileId;
            return false;
        }

        string canonicalPath = GetCanonicalStoredPath(record);
        if (canonicalPath.Length == 0) {
            err = "Canonical path could not be determined for file id: " + fileId;
            return false;
        }

        if (record.storedPath == canonicalPath) return true;
        if (!IO::FileExists(record.storedPath)) {
            err = "Staged file missing while restoring: " + record.storedPath;
            return false;
        }

        string canonicalDir = Path::GetDirectoryName(canonicalPath);
        if (canonicalDir.Length > 0 && !IO::FolderExists(canonicalDir)) {
            IO::CreateFolder(canonicalDir, true);
        }
        if (IO::FileExists(canonicalPath)) {
            try { IO::Delete(canonicalPath); } catch {
                log("Failed to delete existing canonical file before restore: " + canonicalPath + " " + getExceptionInfo(), LogLevel::Warning, -1, "RestoreFromGameStage");
            }
        }

        try {
            IO::Move(record.storedPath, canonicalPath);
        } catch {
            err = "Failed to restore staged file back into canonical storage.";
            log(err + " " + record.storedPath + " -> " + canonicalPath + " " + getExceptionInfo(), LogLevel::Warning, -1, "RestoreFromGameStage");
            return false;
        }

        if (!IO::FileExists(canonicalPath)) {
            err = "Canonical file missing after restore: " + canonicalPath;
            return false;
        }

        RemoveRecordFromCache(record);
        record.storedPath = canonicalPath;
        Upsert(record);
        return true;
    }

    bool DeleteStoredFile(const string &in fileId, string &out err) {
        err = "";
        StoredFileRecord@ record = GetByFileId(fileId);
        if (record is null) return true;

        if (IO::FileExists(record.storedPath)) {
            try {
                IO::Delete(record.storedPath);
            } catch {
                err = "Failed to delete stored file: " + record.storedPath;
                log(err + " " + getExceptionInfo(), LogLevel::Warning, -1, "DeleteStoredFile");
                return false;
            }
        }

        RemoveRecordFromCache(record);
        SQLite::Statement@ st = g_Db.Prepare("DELETE FROM stored_files WHERE file_id = ?;");
        st.Bind(1, fileId);
        st.Execute();
        return true;
    }

    bool IngestExternalFileCopy(const string &in sourcePath, const string &in kind, const string &in fileId, const string &in extension, string &out storedPath, string &out err) {
        storedPath = "";
        err = "";
        if (!IO::FileExists(sourcePath)) {
            err = "Source file does not exist: " + sourcePath;
            return false;
        }

        EnsureOpen();
        if (!IO::FolderExists(INGEST_DIRECTORY)) {
            IO::CreateFolder(INGEST_DIRECTORY, true);
        }

        string tempPath = Path::Join(INGEST_DIRECTORY, "ARL_ingest_" + fileId + extension);
        storedPath = BuildStoredFilePath(kind, fileId, extension);

        if (IO::FileExists(tempPath)) {
            try { IO::Delete(tempPath); } catch {
                log("Failed to delete existing ARL ingest temp file before overwrite: " + tempPath + " " + getExceptionInfo(), LogLevel::Warning, -1, "IngestExternalFileCopy");
            }
        }
        if (IO::FileExists(storedPath)) {
            try { IO::Delete(storedPath); } catch {
                log("Failed to delete existing stored file before ingest overwrite: " + storedPath + " " + getExceptionInfo(), LogLevel::Warning, -1, "IngestExternalFileCopy");
            }
        }

        _IO::File::CopyFileTo(sourcePath, tempPath);
        if (!IO::FileExists(tempPath)) {
            err = "Failed to copy external file into ARL temp storage.";
            return false;
        }

        string storedDir = Path::GetDirectoryName(storedPath);
        if (storedDir.Length > 0 && !IO::FolderExists(storedDir)) {
            IO::CreateFolder(storedDir, true);
        }

        try {
            IO::Move(tempPath, storedPath);
        } catch {
            err = "Failed to move ARL temp file into canonical storage.";
            log(err + " " + tempPath + " -> " + storedPath + " " + getExceptionInfo(), LogLevel::Warning, -1, "IngestExternalFileCopy");
            return false;
        }

        if (!IO::FileExists(storedPath)) {
            err = "Canonical stored file missing after ingest: " + storedPath;
            return false;
        }

        return true;
    }

    void UpsertSavedReplay(SavedReplayRecord@ record) {
        if (record is null || record.savedId.Length == 0 || record.fileId.Length == 0) return;
        EnsureOpen();
        if (record.createdAt <= 0) record.createdAt = Time::Stamp;

        SQLite::Statement@ st = g_Db.Prepare(
            "INSERT OR REPLACE INTO saved_replays (saved_id, file_id, nickname, time, score, source, source_ref, map_uid, account_id, saved_at, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        );
        st.Bind(1, record.savedId);
        st.Bind(2, record.fileId);
        st.Bind(3, record.nickname);
        st.Bind(4, int64(record.time));
        st.Bind(5, int64(record.score));
        st.Bind(6, record.source);
        st.Bind(7, record.sourceRef);
        st.Bind(8, record.mapUid);
        st.Bind(9, record.accountId);
        st.Bind(10, record.savedAt);
        st.Bind(11, record.createdAt);
        st.Execute();
    }

    array<SavedReplayRecord@>@ GetSavedReplays() {
        EnsureOpen();
        array<SavedReplayRecord@>@ rows = array<SavedReplayRecord@>();
        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT * FROM saved_replays ORDER BY created_at DESC;"
        );
        while (st.NextRow()) {
            SavedReplayRecord@ row = SavedReplayRecord();
            row.savedId = st.GetColumnString("saved_id");
            row.fileId = st.GetColumnString("file_id");
            row.nickname = st.GetColumnString("nickname");
            row.time = st.GetColumnInt("time");
            row.score = st.GetColumnInt("score");
            row.source = st.GetColumnString("source");
            row.sourceRef = st.GetColumnString("source_ref");
            row.mapUid = st.GetColumnString("map_uid");
            row.accountId = st.GetColumnString("account_id");
            row.savedAt = st.GetColumnString("saved_at");
            row.createdAt = st.GetColumnInt64("created_at");
            rows.InsertLast(row);
        }
        return rows;
    }

    bool DeleteSavedReplay(const string &in savedId, string &out fileId, string &out err) {
        fileId = "";
        err = "";
        if (savedId.Trim().Length == 0) return false;
        EnsureOpen();

        SQLite::Statement@ stSel = g_Db.Prepare("SELECT file_id FROM saved_replays WHERE saved_id = ? LIMIT 1;");
        stSel.Bind(1, savedId);
        if (stSel.NextRow()) fileId = stSel.GetColumnString("file_id");

        SQLite::Statement@ stDel = g_Db.Prepare("DELETE FROM saved_replays WHERE saved_id = ?;");
        stDel.Bind(1, savedId);
        stDel.Execute();
        return true;
    }

    void UpsertGpsInspectManifest(const string &in mapUid, const string &in manifestJson) {
        if (mapUid.Trim().Length == 0 || manifestJson.Trim().Length == 0) return;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "INSERT OR REPLACE INTO gps_inspect_cache (map_uid, manifest_json, updated_at) VALUES (?, ?, ?);"
        );
        st.Bind(1, mapUid);
        st.Bind(2, manifestJson);
        st.Bind(3, int64(Time::Stamp));
        st.Execute();
    }

    void DeleteGpsInspectManifest(const string &in mapUid) {
        if (mapUid.Trim().Length == 0) return;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "DELETE FROM gps_inspect_cache WHERE map_uid = ?;"
        );
        st.Bind(1, mapUid);
        st.Execute();
    }

    string GetGpsInspectManifest(const string &in mapUid) {
        if (mapUid.Trim().Length == 0) return "";
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT manifest_json FROM gps_inspect_cache WHERE map_uid = ? LIMIT 1;"
        );
        st.Bind(1, mapUid);
        if (!st.NextRow()) return "";
        return st.GetColumnString("manifest_json");
    }

    bool HasGpsInspectManifest(const string &in mapUid) {
        return GetGpsInspectManifest(mapUid).Length > 0;
    }

    int64 GetGpsInspectUpdatedAt(const string &in mapUid) {
        if (mapUid.Trim().Length == 0) return 0;
        EnsureOpen();

        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT updated_at FROM gps_inspect_cache WHERE map_uid = ? LIMIT 1;"
        );
        st.Bind(1, mapUid);
        if (!st.NextRow()) return 0;
        return st.GetColumnInt64("updated_at");
    }

    StoredFileRecord@ ReadRecord(SQLite::Statement@ st) {
        StoredFileRecord@ record = StoredFileRecord();
        record.fileId = st.GetColumnString("file_id");
        record.kind = st.GetColumnString("kind");
        record.sourceKind = st.GetColumnInt("source_kind");
        record.fileName = st.GetColumnString("file_name");
        record.storedPath = st.GetColumnString("stored_path");
        record.originalFileName = st.GetColumnString("original_file_name");
        record.backendFileName = st.GetColumnString("backend_file_name");
        record.sourceRef = st.GetColumnString("source_ref");
        record.mapUid = st.GetColumnString("map_uid");
        record.accountId = st.GetColumnString("account_id");
        record.clipIndex = st.GetColumnInt("clip_index");
        record.trackIndex = st.GetColumnInt("track_index");
        record.blockIndex = st.GetColumnInt("block_index");
        record.derivedRaceTimeMs = st.GetColumnInt("derived_race_time_ms");
        record.clipName = st.GetColumnString("clip_name");
        record.trackName = st.GetColumnString("track_name");
        record.sourcePath = st.GetColumnString("source_path");
        record.useGhostLayer = st.GetColumnInt("use_ghost_layer") != 0;
        record.sizeBytes = st.GetColumnInt64("size_bytes");
        record.createdAt = st.GetColumnInt64("created_at");
        record.updatedAt = st.GetColumnInt64("updated_at");
        return record;
    }
}
}
}
