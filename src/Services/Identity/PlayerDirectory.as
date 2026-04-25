namespace PlayerDirectory {
    const int64 CACHE_TTL_SECONDS = 60 * 60 * 24 * 30 * 6;
    const uint SEARCH_LIMIT_DEFAULT = 20;
    const uint AGGREGATOR_BATCH_SIZE = 200;
    const uint AGGREGATOR_SYNC_MIN_INTERVAL_MS = 30000;
    const uint AGGREGATOR_DISPLAY_NAME_RESOLVE_BATCH_SIZE = 500;
    const uint NADEO_DISPLAY_NAME_BATCH_SIZE = 50;
    const uint VALIDATION_NADEO_DELAY_MS = 5000;
    const uint GAME_PLAYER_INFO_SCAN_INTERVAL_MS = 10000;

    const string AGGREGATOR_API_BASE = "https://aggregator.xjk.yt/api/v1";
    const string AGGREGATOR_BY_NAME_URL = AGGREGATOR_API_BASE + "/display-names/by-name";
    const string AGGREGATOR_RESOLVE_URL = AGGREGATOR_API_BASE + "/display-names/resolve";
    const string AggregatorIngestPluginUrl = AGGREGATOR_API_BASE + "/ingest/display-names/arl";
    const string DB_PATH = IO::FromStorageFolder("arl.sqlite");
    const string LEGACY_CACHE_FILE_PATH = IO::FromStorageFolder("player_directory_cache.json");
    const string GHOSTS_PP_FILE_PATH = IO::FromStorageFolder("../ghosts-pp/player_names.jsons");

    const string PROJECT_KEY = "arl-player-directory";
    const string PROJECT_NAME = "Arbitrary Record Loader Player Directory";
    const string SOURCE_LABEL = "arl-player-directory";
    const uint RECENT_OBSERVED_LIMIT = 200;

    [Setting category="Player Directory" name="Log observed name matches" hidden]
    bool S_LogObservedMatches = true;

    class CacheEntry {
        string accountId;
        string displayName;
        int64 observedAt = 0;
        string source = "";
    }

    class LookupResult {
        string accountId;
        string displayName;
        string source = "";
        bool stale = true;
        bool missing = true;
    }

    class ObservedMatch {
        string accountId;
        string displayName;
        string source = "";
        string status = "";
        int64 observedAt = 0;
    }

    bool g_loaded = false;
    bool g_ready = false;
    bool g_dirty = false;
    bool g_syncInProgress = false;
    bool g_syncPending = false;
    bool g_importInProgress = false;
    bool g_persistInProgress = false;
    bool g_persistPending = false;
    bool g_validationInProgress = false;
    bool g_validationPendingAll = false;
    bool g_gamePlayerInfoImportInProgress = false;
    bool g_gamePlayerInfoMonitorStarted = false;
    uint g_lastGamePlayerInfoImportCount = 0;
    uint g_seenServerPlayerCount = 0;
    string g_validationStatus = "";
    string g_validationDetail = "";
    uint g_validationProcessed = 0;
    uint g_validationTotal = 0;
    uint g_validationInvalidPurged = 0;
    uint g_validationDuplicateKeys = 0;
    uint g_validationNadeoBatches = 0;
    uint g_validationNadeoAccounts = 0;
    uint g_lastSyncAt = 0;
    SQLite::Database@ g_Db = null;

    array<CacheEntry@> g_entries;
    dictionary g_entriesById;
    array<ObservedMatch@> g_recentObserved;
    dictionary g_pendingValidationKeys;
    dictionary g_seenServerPlayerIds;

    bool _IsHexChar(uint8 c) {
        return (c >= 48 && c <= 57) || (c >= 97 && c <= 102);
    }

    string NormalizeAccountId(const string &in raw) {
        string s = raw.Trim().ToLower();
        if (s.Length != 36) return "";
        if (s[8] != 0x2D || s[13] != 0x2D || s[18] != 0x2D || s[23] != 0x2D) return "";
        for (int i = 0; i < s.Length; i++) {
            if (i == 8 || i == 13 || i == 18 || i == 23) continue;
            if (!_IsHexChar(s[i])) return "";
        }
        return s;
    }

    string NormalizeDisplayNameKey(const string &in raw) {
        string s = Text::StripFormatCodes(raw).Trim().Replace("\t", " ").Replace("\r", " ").Replace("\n", " ");
        auto parts = s.Split(" ");
        string normalized = "";
        for (uint i = 0; i < parts.Length; i++) {
            string part = parts[i].Trim();
            if (part.Length == 0) continue;
            if (normalized.Length > 0) normalized += " ";
            normalized += part.ToLower();
        }
        return normalized;
    }

    string _NowIso() {
        return Time::FormatStringUTC("%Y-%m-%dT%H:%M:%SZ", Time::Stamp);
    }

    string _StampToIso(int64 stamp) {
        if (stamp <= 0) return "";
        return Time::FormatStringUTC("%Y-%m-%dT%H:%M:%SZ", stamp);
    }

    string _AggregatorUserAgent() {
        return "TM_Plugin:" + Meta::ExecutingPlugin().Name + " / component=PlayerDirectory / version=" + Meta::ExecutingPlugin().Version;
    }

    bool _GetOpenplanetAuthToken(string &out token, string &out err) {
        token = "";
        err = "";

        auto task = Auth::GetToken();
        while (!task.Finished()) { yield(); }

        if (!task.IsSuccess()) {
            err = task.Error();
            if (err.Length == 0) err = "Auth::GetToken failed.";
            return false;
        }

        token = task.Token();
        if (token.Length == 0) {
            err = "Auth::GetToken returned an empty token.";
            return false;
        }

        return true;
    }

    void _DbEnsureOpen() {
        if (g_Db !is null) return;

        string dbDir = Path::GetDirectoryName(DB_PATH);
        if (dbDir.Length > 0 && !IO::FolderExists(dbDir)) {
            IO::CreateFolder(dbDir, true);
        }

        @g_Db = SQLite::Database(DB_PATH);
        g_Db.Execute("PRAGMA journal_mode=WAL;");
        g_Db.Execute("PRAGMA synchronous=NORMAL;");
        g_Db.Execute(
            "CREATE TABLE IF NOT EXISTS player_directory_cache ("
            "  account_id TEXT PRIMARY KEY,"
            "  display_name TEXT NOT NULL,"
            "  observed_at INTEGER NOT NULL,"
            "  source TEXT NOT NULL DEFAULT ''"
            ");"
        );
    }

    bool _IsEntryFresh(CacheEntry@ entry) {
        if (entry is null || entry.observedAt <= 0) return false;
        return Time::Stamp - entry.observedAt < CACHE_TTL_SECONDS;
    }

    bool _ShouldSkipObservedDisplayName(const string &in rawDisplayName) {
        string normalized = NormalizeDisplayNameKey(rawDisplayName);
        if (normalized.Length == 0) return true;
        if (normalized.Contains("personal best")) return true;
        if (normalized == "pb" || normalized.StartsWith("pb ") || normalized.EndsWith(" pb") || normalized.Contains(" pb ")) return true;
        if (NormalizeAccountId(normalized).Length > 0) return true;

        if (normalized == "accountid" || normalized == "zoneid" || normalized == "groupuid") return true;
        if (normalized == "mapid" || normalized == "mapuid" || normalized == "seasonid") return true;
        if (normalized == "clubid" || normalized == "profileid" || normalized == "playerid") return true;
        if (normalized == "uid" || normalized == "id" || normalized == "login" || normalized == "webservicesuserid") return true;
        if (normalized == "playstation" || normalized == "playstation4" || normalized == "playstation5") return true;
        if (normalized == "xbox" || normalized == "xboxone" || normalized == "xboxseries") return true;
        if (normalized == "stadia" || normalized == "luna") return true;

        return false;
    }

    CacheEntry@ _GetEntryByAccountId(const string &in rawAccountId) {
        string accountId = NormalizeAccountId(rawAccountId);
        if (accountId.Length == 0) return null;
        if (!g_entriesById.Exists(accountId)) return null;
        ref@ entryRef;
        g_entriesById.Get(accountId, @entryRef);
        return cast<CacheEntry@>(entryRef);
    }

    void _RememberObservedMatch(const string &in accountId, const string &in displayName, const string &in source, const string &in status) {
        ObservedMatch@ match = ObservedMatch();
        match.accountId = accountId;
        match.displayName = displayName;
        match.source = source;
        match.status = status;
        match.observedAt = Time::Stamp;
        g_recentObserved.InsertAt(0, match);
        if (g_recentObserved.Length > RECENT_OBSERVED_LIMIT) {
            g_recentObserved.RemoveRange(RECENT_OBSERVED_LIMIT, g_recentObserved.Length - RECENT_OBSERVED_LIMIT);
        }
    }

    void QueuePersistIfDirty() {
        if (!g_dirty) return;
        if (g_persistInProgress) {
            g_persistPending = true;
            return;
        }

        g_persistInProgress = true;
        g_persistPending = false;
        startnew(CoroutineFunc(Coro_PersistIfDirty));
    }

    void Coro_PersistIfDirty() {
        yield();
        if (!g_dirty) {
            g_persistInProgress = false;
            return;
        }

        g_dirty = false;

        try {
            _DbEnsureOpen();
            g_Db.Execute("BEGIN IMMEDIATE TRANSACTION;");

            SQLite::Statement@ st = g_Db.Prepare(
                "INSERT OR REPLACE INTO player_directory_cache (account_id, display_name, observed_at, source) VALUES (?, ?, ?, ?);"
            );

            for (uint i = 0; i < g_entries.Length; i++) {
                auto entry = g_entries[i];
                if (entry is null) continue;
                if (entry.accountId.Length == 0 || entry.displayName.Length == 0) continue;

                st.Bind(1, entry.accountId);
                st.Bind(2, entry.displayName);
                st.Bind(3, entry.observedAt);
                st.Bind(4, entry.source);
                st.Execute();
                @st = g_Db.Prepare(
                    "INSERT OR REPLACE INTO player_directory_cache (account_id, display_name, observed_at, source) VALUES (?, ?, ?, ?);"
                );

                if (i % 250 == 249) yield();
            }

            g_Db.Execute("COMMIT;");
        } catch {
            try { g_Db.Execute("ROLLBACK;"); } catch {
                log("Failed to roll back player directory cache transaction: " + getExceptionInfo(), LogLevel::Warning, -1, "Coro_PersistIfDirty");
            }
            g_dirty = true;
            log("Failed to persist player directory cache: " + getExceptionInfo(), LogLevel::Warning, 262, "Coro_PersistIfDirty");
        }

        g_persistInProgress = false;
        if (g_dirty || g_persistPending) {
            g_persistPending = false;
            QueuePersistIfDirty();
        }
    }

    CacheEntry@ _UpsertEntry(const string &in rawAccountId, const string &in rawDisplayName, int64 observedAt = 0, const string &in source = "") {
        string accountId = NormalizeAccountId(rawAccountId);
        string displayName = Text::StripFormatCodes(rawDisplayName).Trim();
        if (accountId.Length == 0 || displayName.Length == 0 || _ShouldSkipObservedDisplayName(displayName)) return null;

        if (observedAt <= 0) observedAt = Time::Stamp;

        CacheEntry@ entry = _GetEntryByAccountId(accountId);
        bool changed = false;

        if (entry is null) {
            @entry = CacheEntry();
            entry.accountId = accountId;
            entry.displayName = displayName;
            entry.observedAt = observedAt;
            entry.source = source;
            g_entries.InsertLast(entry);
            g_entriesById.Set(accountId, @entry);
            changed = true;
        } else {
            bool canUpdateFromObservation = observedAt >= entry.observedAt;
            if (displayName.Length > 0 && entry.displayName != displayName && canUpdateFromObservation) {
                entry.displayName = displayName;
                changed = true;
            }
            if (observedAt > entry.observedAt) {
                entry.observedAt = observedAt;
                changed = true;
            }
            if (source.Length > 0 && entry.source != source && canUpdateFromObservation) {
                entry.source = source;
                changed = true;
            }
        }

        if (changed) g_dirty = true;
        return entry;
    }

    void _DeleteDbAccountId(const string &in rawAccountId) {
        string accountId = NormalizeAccountId(rawAccountId);
        if (accountId.Length == 0) return;
        try {
            _DbEnsureOpen();
            SQLite::Statement@ st = g_Db.Prepare("DELETE FROM player_directory_cache WHERE account_id = ?;");
            st.Bind(1, accountId);
            st.Execute();
        } catch {
            log("Failed to delete player directory row for " + accountId + ": " + getExceptionInfo(), LogLevel::Warning, 320, "_DeleteDbAccountId");
        }
    }

    void _DeleteEntry(const string &in rawAccountId, const string &in reason = "") {
        string accountId = NormalizeAccountId(rawAccountId);
        if (accountId.Length == 0) return;

        if (g_entriesById.Exists(accountId)) {
            g_entriesById.Delete(accountId);
        }

        for (int i = int(g_entries.Length) - 1; i >= 0; i--) {
            auto entry = g_entries[uint(i)];
            if (entry !is null && entry.accountId == accountId) {
                g_entries.RemoveAt(uint(i));
            }
        }

        _DeleteDbAccountId(accountId);
        g_dirty = true;

        if (reason.Length > 0) {
            log("Deleted player directory row: " + accountId + " (" + reason + ")", LogLevel::Info, 343, "_DeleteEntry");
        }
    }

    LookupResult@ _MakeMissingResult(const string &in rawAccountId = "") {
        LookupResult@ result = LookupResult();
        result.accountId = NormalizeAccountId(rawAccountId);
        result.displayName = "";
        result.source = "";
        result.stale = true;
        result.missing = true;
        return result;
    }

    LookupResult@ _MakeResultFromEntry(CacheEntry@ entry) {
        if (entry is null) return _MakeMissingResult();
        LookupResult@ result = LookupResult();
        result.accountId = entry.accountId;
        result.displayName = entry.displayName;
        result.source = entry.source;
        result.stale = !_IsEntryFresh(entry);
        result.missing = entry.displayName.Length == 0;
        return result;
    }

    bool IsReady() {
        return g_ready;
    }

    bool IsLoading() {
        return g_loaded && !g_ready;
    }

    void _ImportLegacyJsonCache() {
        if (!IO::FileExists(LEGACY_CACHE_FILE_PATH)) return;

        Json::Value root = Json::Parse(_IO::File::ReadFileToEnd(LEGACY_CACHE_FILE_PATH));
        if (root.GetType() != Json::Type::Object) return;

        auto entries = root["entries"];
        if (entries.GetType() != Json::Type::Array) return;

        for (uint i = 0; i < entries.Length; i++) {
            auto row = entries[i];
            if (row.GetType() != Json::Type::Object) continue;

            string accountId = string(row["accountId"]);
            string displayName = string(row["displayName"]);
            int64 observedAt = 0;
            try { observedAt = int64(row["observedAt"]); } catch {
                log("Failed to parse legacy player directory observedAt for accountId=" + accountId + ": " + getExceptionInfo(), LogLevel::Debug, -1, "_ImportLegacyJsonCache");
            }
            string source = string(row["source"]);

            _UpsertEntry(accountId, displayName, observedAt, source);
        }
    }

    bool _LoadCache() {
        g_entries.RemoveRange(0, g_entries.Length);
        auto keys = g_entriesById.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            g_entriesById.Delete(keys[i]);
        }

        _DbEnsureOpen();

        bool loadedFromDb = false;
        array<string> invalidDbAccountIds;
        SQLite::Statement@ st = g_Db.Prepare(
            "SELECT account_id, display_name, observed_at, source FROM player_directory_cache ORDER BY observed_at DESC;"
        );
        while (st.NextRow()) {
            loadedFromDb = true;
            string accountId = st.GetColumnString("account_id");
            string displayName = st.GetColumnString("display_name");
            if (_ShouldSkipObservedDisplayName(displayName)) {
                invalidDbAccountIds.InsertLast(accountId);
                continue;
            }
            _UpsertEntry(
                accountId,
                displayName,
                st.GetColumnInt64("observed_at"),
                st.GetColumnString("source")
            );
        }

        for (uint di = 0; di < invalidDbAccountIds.Length; di++) {
            _DeleteDbAccountId(invalidDbAccountIds[di]);
        }

        if (!loadedFromDb) {
            _ImportLegacyJsonCache();
        }

        bool importedLegacy = !loadedFromDb && g_entries.Length > 0;
        g_dirty = importedLegacy || invalidDbAccountIds.Length > 0;
        return importedLegacy;
    }

    void _ImportGhostsPPCache() {
        if (!IO::FileExists(GHOSTS_PP_FILE_PATH)) return;

        try {
            IO::File file(GHOSTS_PP_FILE_PATH, IO::FileMode::Read);
            string content = file.ReadToEnd();
            file.Close();

            auto lines = content.Split("\n");
            for (uint li = 0; li < lines.Length; li++) {
                string line = lines[li].Trim();
                if (line.Length == 0) continue;

                Json::Value entry = Json::Parse(line);
                if (entry.GetType() != Json::Type::Object) continue;
                if (!entry.HasKey("wsid") || !entry.HasKey("names")) continue;

                string wsid = NormalizeAccountId(string(entry["wsid"]));
                if (wsid.Length == 0) continue;

                auto names = entry["names"];
                if (names.GetType() != Json::Type::Object) continue;

                auto nameKeys = names.GetKeys();
                for (uint ni = 0; ni < nameKeys.Length; ni++) {
                    string displayName = Text::StripFormatCodes(nameKeys[ni]).Trim();
                    if (NormalizeDisplayNameKey(displayName) == "personal best" || displayName.Length == 0) continue;
                    _UpsertEntry(wsid, displayName, Time::Stamp, "ghosts++");
                }

                if (li % 50 == 49) yield();
            }
        } catch {
            log("Failed to import ghosts++ player cache: " + getExceptionInfo(), LogLevel::Warning, 475, "_ImportGhostsPPCache");
        }
    }

    void Coro_ImportGhostsPPCache() {
        g_importInProgress = true;
        _ImportGhostsPPCache();
        g_importInProgress = false;
        QueuePersistIfDirty();
    }

    int64 _ApproxGameCacheTimestamp() {
        auto app = GetApp();
        if (app is null) return Time::Stamp;

        try {
            uint initMs = app.TimeSinceInitMs;
            return Time::Stamp - int64(initMs / 1000);
        } catch {
            log("Failed to approximate game cache timestamp from app.TimeSinceInitMs: " + getExceptionInfo(), LogLevel::Debug, -1, "_ApproxGameCacheTimestamp");
        }

        return Time::Stamp;
    }

    uint ImportRuntimePlayerInfoCache() {
        EnsureInit();
        if (g_gamePlayerInfoImportInProgress) return 0;
        g_gamePlayerInfoImportInProgress = true;

        uint imported = 0;
        uint scanned = 0;
        try {
            auto app = cast<CTrackMania>(GetApp());
            if (app is null || app.Network is null) {
                g_gamePlayerInfoImportInProgress = false;
                return 0;
            }

            int64 observedAt = _ApproxGameCacheTimestamp();
            auto infos = app.Network.PlayerInfos;
            for (uint i = 0; i < infos.Length; i++) {
                auto info = cast<CGamePlayerInfo>(infos[i]);
                if (info is null) continue;

                string accountId = NormalizeAccountId(info.WebServicesUserId);
                string displayName = Text::StripFormatCodes(string(info.Name)).Trim();
                if (accountId.Length == 0 || _ShouldSkipObservedDisplayName(displayName)) continue;
                scanned++;
                if (g_seenServerPlayerIds.Exists(accountId)) continue;
                g_seenServerPlayerIds.Set(accountId, true);
                g_seenServerPlayerCount++;

                auto entry = _UpsertEntry(accountId, displayName, observedAt, "game-runtime-player-info");
                if (entry !is null) imported++;

                if (i % 50 == 49) yield();
            }

            if (imported > 0) {
                QueuePersistIfDirty();
                QueueSyncFullCache(true);
            }

            if (imported > 0) {
                log(
                    "Runtime player-info scan: added " + imported + " new player name(s), scanned " + scanned + " valid player info row(s), session seen total " + g_seenServerPlayerCount + ".",
                    LogLevel::Debug,
                    460,
                    "PlayerDirectory"
                );
            }
        } catch {
            log("Runtime player-info import failed: " + getExceptionInfo(), LogLevel::Warning, 546, "ImportRuntimePlayerInfoCache");
        }

        g_lastGamePlayerInfoImportCount = imported;
        g_gamePlayerInfoImportInProgress = false;
        return imported;
    }

    void Coro_ImportGamePlayerInfoCache() {
        ImportRuntimePlayerInfoCache();
    }

    void QueueImportGamePlayerInfoCache() {
        if (g_gamePlayerInfoImportInProgress) return;
        startnew(CoroutineFunc(Coro_ImportGamePlayerInfoCache));
    }

    bool IsImportingGamePlayerInfoCache() {
        return g_gamePlayerInfoImportInProgress;
    }

    uint GetLastGamePlayerInfoImportCount() {
        return g_lastGamePlayerInfoImportCount;
    }

    uint GetSeenServerPlayerCount() {
        return g_seenServerPlayerCount;
    }

    void Coro_MonitorRuntimePlayerInfoCache() {
        while (true) {
            sleep(GAME_PLAYER_INFO_SCAN_INTERVAL_MS);

            auto app = cast<CTrackMania>(GetApp());
            if (app is null || app.Network is null) continue;
            if (!_Game::IsPlayingMap()) continue;

            QueueImportGamePlayerInfoCache();
        }
    }

    void EnsureRuntimePlayerInfoMonitor() {
        if (g_gamePlayerInfoMonitorStarted) return;
        g_gamePlayerInfoMonitorStarted = true;
        startnew(CoroutineFunc(Coro_MonitorRuntimePlayerInfoCache));
    }

    void Coro_InitBackground() {
        if (!g_importInProgress) {
            startnew(CoroutineFunc(Coro_ImportGhostsPPCache));
        }

        QueueImportGamePlayerInfoCache();
        EnsureRuntimePlayerInfoMonitor();
        QueueSyncFullCache(true);
    }

    void EnsureInit() {
        if (g_loaded) return;
        g_loaded = true;
        g_ready = false;

        bool importedLegacy = _LoadCache();
        g_ready = true;

        if (importedLegacy) {
            QueuePersistIfDirty();
        }

        startnew(CoroutineFunc(Coro_InitBackground));
    }

    void ObserveAccountDisplayName(const string &in rawAccountId, const string &in rawDisplayName, const string &in source = "arl") {
        EnsureInit();
        string accountId = NormalizeAccountId(rawAccountId);
        string displayName = Text::StripFormatCodes(rawDisplayName).Trim();
        if (accountId.Length == 0 || _ShouldSkipObservedDisplayName(displayName)) return;

        auto existing = _GetEntryByAccountId(accountId);
        string status = existing is null ? "new" : (existing.displayName == displayName ? "seen" : "rename");
        _RememberObservedMatch(accountId, displayName, source, status);

        if (S_LogObservedMatches && status != "seen") {
            log("Observed player mapping: " + accountId + " <-> " + displayName, LogLevel::Debug, 629, "ObserveAccountDisplayName");
        }

        auto entry = _UpsertEntry(accountId, displayName, Time::Stamp, source);
        if (entry !is null) {
            if (_HasConflictingDisplayName(displayName, accountId)) {
                QueueValidateDisplayNameKey(NormalizeDisplayNameKey(displayName));
            }
            QueuePersistIfDirty();
            if (status != "seen") QueueSyncFullCache();
        }
    }

    bool _HasConflictingDisplayName(const string &in rawDisplayName, const string &in rawAccountId) {
        string key = NormalizeDisplayNameKey(rawDisplayName);
        string accountId = NormalizeAccountId(rawAccountId);
        if (key.Length == 0 || accountId.Length == 0) return false;

        for (uint i = 0; i < g_entries.Length; i++) {
            auto entry = g_entries[i];
            if (entry is null || entry.accountId == accountId) continue;
            if (NormalizeDisplayNameKey(entry.displayName) == key) return true;
        }
        return false;
    }

    array<CacheEntry@>@ _GetEntriesByDisplayNameKey(const string &in key) {
        array<CacheEntry@>@ results = array<CacheEntry@>();
        if (key.Length == 0) return results;

        for (uint i = 0; i < g_entries.Length; i++) {
            auto entry = g_entries[i];
            if (entry is null) continue;
            if (NormalizeDisplayNameKey(entry.displayName) == key) {
                results.InsertLast(entry);
            }
        }
        return results;
    }

    array<string>@ _GetDuplicateDisplayNameKeys() {
        array<string>@ duplicates = array<string>();
        dictionary firstAccountByName;
        dictionary duplicateSeen;

        for (uint i = 0; i < g_entries.Length; i++) {
            auto entry = g_entries[i];
            if (entry is null) continue;

            string key = NormalizeDisplayNameKey(entry.displayName);
            if (key.Length == 0) continue;

            if (firstAccountByName.Exists(key)) {
                if (!duplicateSeen.Exists(key)) {
                    duplicates.InsertLast(key);
                    duplicateSeen.Set(key, true);
                }
            } else {
                firstAccountByName.Set(key, entry.accountId);
            }
        }

        return duplicates;
    }

    uint _PurgeInvalidDisplayNames() {
        uint purged = 0;
        for (int i = int(g_entries.Length) - 1; i >= 0; i--) {
            auto entry = g_entries[uint(i)];
            if (entry is null) continue;
            if (_ShouldSkipObservedDisplayName(entry.displayName)) {
                _DeleteEntry(entry.accountId, "invalid display name '" + entry.displayName + "'");
                purged++;
            }
        }
        return purged;
    }

    void QueueValidateDisplayNameKey(const string &in rawKey) {
        string key = NormalizeDisplayNameKey(rawKey);
        if (key.Length == 0) return;

        g_pendingValidationKeys.Set(key, true);
        if (!g_validationInProgress) {
            startnew(CoroutineFunc(Coro_ValidateDisplayNameCache));
        }
    }

    void QueueValidateAllDisplayNames() {
        g_validationPendingAll = true;
        if (!g_validationInProgress) {
            startnew(CoroutineFunc(Coro_ValidateDisplayNameCache));
        }
    }

    void ValidateDisplayNameCacheNow() {
        EnsureInit();
        QueueValidateAllDisplayNames();
    }

    bool IsValidatingDisplayNames() {
        return g_validationInProgress;
    }

    string GetValidationStatus() {
        return g_validationStatus;
    }

    string GetValidationDetail() {
        return g_validationDetail;
    }

    uint GetValidationProcessed() {
        return g_validationProcessed;
    }

    uint GetValidationTotal() {
        return g_validationTotal;
    }

    uint GetValidationInvalidPurged() {
        return g_validationInvalidPurged;
    }

    uint GetValidationDuplicateKeys() {
        return g_validationDuplicateKeys;
    }

    void _SetValidationStatus(const string &in status, const string &in detail = "") {
        g_validationStatus = status;
        g_validationDetail = detail;
        string msg = status;
        if (detail.Length > 0) msg += " - " + detail;
        log("Display name validation: " + msg, LogLevel::Info, 762, "_SetValidationStatus");
    }

    uint _QueueDuplicateDisplayNameKeys() {
        auto duplicateKeys = _GetDuplicateDisplayNameKeys();
        for (uint i = 0; i < duplicateKeys.Length; i++) {
            g_pendingValidationKeys.Set(duplicateKeys[i], true);
        }
        return duplicateKeys.Length;
    }

    void Coro_ValidateDisplayNameCache() {
        if (g_validationInProgress) return;
        g_validationInProgress = true;
        g_validationProcessed = 0;
        g_validationTotal = 0;
        g_validationInvalidPurged = 0;
        g_validationDuplicateKeys = 0;
        g_validationNadeoBatches = 0;
        g_validationNadeoAccounts = 0;
        _SetValidationStatus("Starting", "Preparing display-name validation.");
        array<string> accountIdsNeedingNadeo;
        dictionary accountIdsNeedingNadeoSeen;

        while (true) {
            if (g_validationPendingAll) {
                g_validationPendingAll = false;
                _SetValidationStatus("Scanning", "Purging invalid rows and finding duplicate names.");
                g_validationInvalidPurged += _PurgeInvalidDisplayNames();
                g_validationDuplicateKeys = _QueueDuplicateDisplayNameKeys();
                _SetValidationStatus("Aggregator pass", "Duplicate groups: " + g_validationDuplicateKeys + ", invalid rows purged: " + g_validationInvalidPurged + ".");
            }

            auto keys = g_pendingValidationKeys.GetKeys();
            if (keys.Length == 0) break;
            g_validationTotal = Math::Max(g_validationTotal, g_validationProcessed + keys.Length);

            string key = keys[0];
            g_pendingValidationKeys.Delete(key);
            g_validationDetail = "Checking duplicate name '" + key + "' via aggregator (" + (g_validationProcessed + 1) + "/" + g_validationTotal + ").";
            auto unresolvedAccountIds = _ValidateDisplayNameKeyViaAggregator(key);
            for (uint ui = 0; ui < unresolvedAccountIds.Length; ui++) {
                _AppendUniqueAccountId(accountIdsNeedingNadeo, accountIdsNeedingNadeoSeen, unresolvedAccountIds[ui]);
            }
            g_validationProcessed++;
            yield();
        }

        if (accountIdsNeedingNadeo.Length > 0) {
            _SetValidationStatus("Nadeo fallback", "Accounts still unresolved after aggregator: " + accountIdsNeedingNadeo.Length + ".");
            _ValidateAccountIdsViaNadeo(accountIdsNeedingNadeo);
        }

        _DeleteAllUnresolvedDuplicateDisplayNameKeys();
        QueuePersistIfDirty();
        _SetValidationStatus(
            "Finished",
            "Checked " + g_validationProcessed + " duplicate groups, purged " + g_validationInvalidPurged + " invalid rows, refreshed " + g_validationNadeoAccounts + " account(s) in " + g_validationNadeoBatches + " Nadeo batch(es)."
        );
        g_validationInProgress = false;
    }

    array<string>@ _ValidateDisplayNameKeyViaAggregator(const string &in key) {
        array<string>@ unresolvedAccountIds = array<string>();
        auto entries = _GetEntriesByDisplayNameKey(key);
        if (entries.Length <= 1) return unresolvedAccountIds;

        array<string> accountIds;
        for (uint i = 0; i < entries.Length; i++) {
            if (entries[i] !is null && entries[i].accountId.Length > 0) {
                accountIds.InsertLast(entries[i].accountId);
            }
        }
        if (accountIds.Length == 0) return unresolvedAccountIds;

        g_validationDetail = "Aggregator batch lookup '" + key + "' for " + accountIds.Length + " account(s).";
        log("Display name validation: " + g_validationDetail, LogLevel::Info, 838, "Coro_ValidateDisplayNameCache");

        _ResolveAggregatorDisplayNameBatches(accountIds, unresolvedAccountIds);

        entries = _GetEntriesByDisplayNameKey(key);
        if (entries.Length <= 1) {
            unresolvedAccountIds.Resize(0);
        }
        return unresolvedAccountIds;
    }

    void _AppendUniqueAccountId(array<string>@ accountIds, dictionary &inout seenAccountIds, const string &in rawAccountId) {
        string accountId = NormalizeAccountId(rawAccountId);
        if (accountId.Length == 0 || seenAccountIds.Exists(accountId)) return;
        seenAccountIds.Set(accountId, true);
        accountIds.InsertLast(accountId);
    }

    void _ValidateAccountIdsViaNadeo(const array<string> &in accountIds) {
        array<string> batch;
        for (uint i = 0; i < accountIds.Length; i++) {
            batch.InsertLast(accountIds[i]);
            if (batch.Length >= NADEO_DISPLAY_NAME_BATCH_SIZE) {
                _ResolveNadeoDisplayNameBatch(batch);
                batch.Resize(0);
                if (i + 1 < accountIds.Length) sleep(VALIDATION_NADEO_DELAY_MS);
                yield();
            }
        }

        if (batch.Length > 0) {
            _ResolveNadeoDisplayNameBatch(batch);
        }
    }

    void _ResolveAggregatorDisplayNameBatches(const array<string> &in accountIds, array<string>@ unresolvedAccountIds) {
        if (unresolvedAccountIds is null) return;
        unresolvedAccountIds.Resize(0);

        array<string> batch;
        array<string> batchUnresolved;
        for (uint i = 0; i < accountIds.Length; i++) {
            batch.InsertLast(accountIds[i]);
            if (batch.Length >= AGGREGATOR_DISPLAY_NAME_RESOLVE_BATCH_SIZE) {
                if (!_ResolveAggregatorDisplayNameBatch(batch, batchUnresolved)) {
                    for (uint bi = 0; bi < batch.Length; bi++) unresolvedAccountIds.InsertLast(batch[bi]);
                } else {
                    for (uint ui = 0; ui < batchUnresolved.Length; ui++) unresolvedAccountIds.InsertLast(batchUnresolved[ui]);
                }
                batch.Resize(0);
                batchUnresolved.Resize(0);
                yield();
            }
        }

        if (batch.Length > 0) {
            if (!_ResolveAggregatorDisplayNameBatch(batch, batchUnresolved)) {
                for (uint bi = 0; bi < batch.Length; bi++) unresolvedAccountIds.InsertLast(batch[bi]);
            } else {
                for (uint ui = 0; ui < batchUnresolved.Length; ui++) unresolvedAccountIds.InsertLast(batchUnresolved[ui]);
            }
        }
    }

    bool _ResolveAggregatorDisplayNameBatch(const array<string> &in accountIds, array<string>@ unresolvedAccountIds) {
        if (unresolvedAccountIds is null) return false;
        unresolvedAccountIds.Resize(0);
        if (accountIds.Length == 0) return true;

        Json::Value body = Json::Object();
        body["accountIds"] = Json::Array();
        body["maxAgeSeconds"] = CACHE_TTL_SECONDS;
        for (uint i = 0; i < accountIds.Length; i++) {
            body["accountIds"].Add(accountIds[i]);
        }

        Json::Value@ payload;
        string err = "";
        if (!_PostAggregatorJson(AGGREGATOR_RESOLVE_URL, body, payload, err)) {
            log("Aggregator batch resolve failed: " + err, LogLevel::Warning, 917, "_ResolveAggregatorDisplayNameBatch");
            return false;
        }

        dictionary resolvedIds;
        auto results = _ParseAggregatorResponse(payload, "aggregator-validate");
        for (uint i = 0; i < results.Length; i++) {
            auto result = results[i];
            if (result is null || result.accountId.Length == 0) continue;
            if (!result.missing && !_ShouldSkipObservedDisplayName(result.displayName)) {
                _UpsertEntry(result.accountId, result.displayName, Time::Stamp, result.source.Length > 0 ? result.source : "aggregator-validate");
                resolvedIds.Set(result.accountId, true);
            }
        }

        auto missing = payload["missing"];
        if (missing.GetType() == Json::Type::Array) {
            for (uint i = 0; i < missing.Length; i++) {
                string accountId = NormalizeAccountId(string(missing[i]));
                if (accountId.Length > 0 && !resolvedIds.Exists(accountId)) {
                    unresolvedAccountIds.InsertLast(accountId);
                    resolvedIds.Set(accountId, true);
                }
            }
        }

        for (uint i = 0; i < accountIds.Length; i++) {
            if (!resolvedIds.Exists(accountIds[i])) {
                unresolvedAccountIds.InsertLast(accountIds[i]);
            }
        }

        return true;
    }

    void _DeleteAllUnresolvedDuplicateDisplayNameKeys() {
        auto keys = _GetDuplicateDisplayNameKeys();
        for (uint i = 0; i < keys.Length; i++) {
            _DeleteUnresolvedDuplicateDisplayNameKey(keys[i]);
        }
    }

    void _ResolveNadeoDisplayNameBatch(const array<string> &in accountIds) {
        if (accountIds.Length == 0) return;

        g_validationNadeoBatches++;
        g_validationNadeoAccounts += accountIds.Length;
        g_validationDetail = "Nadeo batch " + g_validationNadeoBatches + ": refreshing " + accountIds.Length + " account(s).";
        log("Display name validation: " + g_validationDetail, LogLevel::Info, 965, "_ResolveNadeoDisplayNameBatch");

        auto nameMap = NadeoServices::GetDisplayNamesAsync(accountIds);
        if (nameMap !is null) {
            for (uint ni = 0; ni < accountIds.Length; ni++) {
                string accountId = accountIds[ni];
                if (!nameMap.Exists(accountId)) continue;

                string displayName = Text::StripFormatCodes(string(nameMap[accountId])).Trim();
                if (_ShouldSkipObservedDisplayName(displayName)) {
                    _DeleteEntry(accountId, "Nadeo returned invalid display name during duplicate validation");
                } else {
                    _UpsertEntry(accountId, displayName, Time::Stamp, "nadeoservices-validate");
                }
            }
        }
    }

    void _DeleteUnresolvedDuplicateDisplayNameKey(const string &in key) {
        auto entries = _GetEntriesByDisplayNameKey(key);
        if (entries.Length <= 1) return;

        int keepIdx = 0;
        int64 newest = -1;
        for (uint i = 0; i < entries.Length; i++) {
            if (entries[i] !is null && entries[i].observedAt > newest) {
                newest = entries[i].observedAt;
                keepIdx = int(i);
            }
        }

        string keptAccountId = entries[uint(keepIdx)] !is null ? entries[uint(keepIdx)].accountId : "";
        for (uint i = 0; i < entries.Length; i++) {
            auto entry = entries[i];
            if (entry is null || entry.accountId == keptAccountId) continue;
            _DeleteEntry(entry.accountId, "unresolved duplicate display name '" + entry.displayName + "'");
        }
    }

    array<ObservedMatch@>@ GetRecentObservedMatches() {
        EnsureInit();
        return g_recentObserved;
    }

    void ClearRecentObservedMatches() {
        if (g_recentObserved.Length > 0) {
            g_recentObserved.RemoveRange(0, g_recentObserved.Length);
        }
    }

    uint GetEntryCount() {
        EnsureInit();
        return g_entries.Length;
    }

    string GetDatabasePath() {
        return DB_PATH;
    }

    bool IsPersisting() {
        return g_persistInProgress;
    }

    bool IsSyncing() {
        return g_syncInProgress;
    }

    LookupResult@ GetCachedByAccountId(const string &in rawAccountId) {
        EnsureInit();
        if (!g_ready) return _MakeMissingResult(rawAccountId);
        auto entry = _GetEntryByAccountId(rawAccountId);
        if (entry is null) return _MakeMissingResult(rawAccountId);
        return _MakeResultFromEntry(entry);
    }

    int _LookupSortCompare(LookupResult@ a, LookupResult@ b) {
        if (a is null && b is null) return 0;
        if (a is null) return 1;
        if (b is null) return -1;
        if (a.missing != b.missing) return a.missing ? 1 : -1;
        if (a.stale != b.stale) return a.stale ? 1 : -1;
        string an = NormalizeDisplayNameKey(a.displayName);
        string bn = NormalizeDisplayNameKey(b.displayName);
        if (an < bn) return -1;
        if (an > bn) return 1;
        if (a.accountId < b.accountId) return -1;
        if (a.accountId > b.accountId) return 1;
        return 0;
    }

    void _InsertSorted(array<LookupResult@>@ results, LookupResult@ result) {
        if (results is null || result is null) return;
        uint insertAt = results.Length;
        for (uint i = 0; i < results.Length; i++) {
            if (_LookupSortCompare(result, results[i]) < 0) {
                insertAt = i;
                break;
            }
        }
        results.InsertAt(insertAt, result);
    }

    bool _HasAccountId(const array<LookupResult@>@ results, const string &in accountId) {
        if (results is null) return false;
        for (uint i = 0; i < results.Length; i++) {
            if (results[i] !is null && results[i].accountId == accountId) return true;
        }
        return false;
    }

    array<LookupResult@>@ _CollapseDuplicateDisplayNames(const array<LookupResult@>@ results, uint limit = SEARCH_LIMIT_DEFAULT) {
        array<LookupResult@>@ collapsed = array<LookupResult@>();
        dictionary seenNames;
        if (results is null) return collapsed;

        for (uint i = 0; i < results.Length && collapsed.Length < limit; i++) {
            auto result = results[i];
            if (result is null) continue;

            string key = NormalizeDisplayNameKey(result.displayName);
            if (key.Length == 0) key = result.accountId;
            if (seenNames.Exists(key)) continue;

            seenNames.Set(key, true);
            collapsed.InsertLast(result);
        }

        return collapsed;
    }

    array<LookupResult@>@ FindExactLocal(const string &in rawDisplayName) {
        EnsureInit();
        array<LookupResult@>@ results = array<LookupResult@>();
        if (!g_ready) return results;
        string key = NormalizeDisplayNameKey(rawDisplayName);
        if (key.Length == 0) return results;

        for (uint i = 0; i < g_entries.Length; i++) {
            auto entry = g_entries[i];
            if (entry is null) continue;
            if (NormalizeDisplayNameKey(entry.displayName) != key) continue;
            _InsertSorted(results, _MakeResultFromEntry(entry));
        }
        return _CollapseDuplicateDisplayNames(results);
    }

    array<LookupResult@>@ SearchLocal(const string &in rawQuery, uint limit = SEARCH_LIMIT_DEFAULT) {
        EnsureInit();
        array<LookupResult@>@ exact = array<LookupResult@>();
        if (!g_ready) return exact;
        array<LookupResult@>@ prefix = array<LookupResult@>();
        array<LookupResult@>@ partial = array<LookupResult@>();
        string queryKey = NormalizeDisplayNameKey(rawQuery);
        if (queryKey.Length == 0) return exact;

        string queryLower = rawQuery.Trim().ToLower();

        for (uint i = 0; i < g_entries.Length; i++) {
            auto entry = g_entries[i];
            if (entry is null) continue;

            string key = NormalizeDisplayNameKey(entry.displayName);
            if (key.Length == 0) continue;

            LookupResult@ result = _MakeResultFromEntry(entry);

            if (key == queryKey) {
                _InsertSorted(exact, result);
            } else if (key.StartsWith(queryKey)) {
                _InsertSorted(prefix, result);
            } else if (key.Contains(queryKey) || entry.accountId.Contains(queryLower)) {
                _InsertSorted(partial, result);
            }
        }

        array<LookupResult@>@ merged = array<LookupResult@>();
        auto collapsedExact = _CollapseDuplicateDisplayNames(exact, limit);
        for (uint i = 0; i < collapsedExact.Length && merged.Length < limit; i++) merged.InsertLast(collapsedExact[i]);
        for (uint i = 0; i < prefix.Length && merged.Length < limit; i++) {
            if (!_HasAccountId(merged, prefix[i].accountId)) merged.InsertLast(prefix[i]);
        }
        for (uint i = 0; i < partial.Length && merged.Length < limit; i++) {
            if (!_HasAccountId(merged, partial[i].accountId)) merged.InsertLast(partial[i]);
        }
        return merged;
    }

    bool _FetchAggregatorJson(const string &in url, Json::Value@ &out payload, string &out err) {
        err = "";
        Net::HttpRequest@ req = Net::HttpRequest();
        req.Url = url;
        req.Method = Net::HttpMethod::Get;
        req.Headers["Accept"] = "application/json";
        req.Headers["User-Agent"] = _AggregatorUserAgent();
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            err = "Aggregator GET failed (" + req.ResponseCode() + ")";
            return false;
        }

        @payload = Json::Parse(req.String());
        if (payload.GetType() != Json::Type::Object) {
            err = "Failed to parse aggregator response.";
            return false;
        }
        return true;
    }

    bool _PostAggregatorJson(const string &in url, const Json::Value &in body, Json::Value@ &out payload, string &out err) {
        err = "";
        Net::HttpRequest@ req = Net::HttpRequest();
        req.Url = url;
        req.Method = Net::HttpMethod::Post;
        req.Body = Json::Write(body);
        req.Headers["Accept"] = "application/json";
        req.Headers["Content-Type"] = "application/json";
        req.Headers["User-Agent"] = _AggregatorUserAgent();
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() < 200 || req.ResponseCode() >= 300) {
            err = "Aggregator POST failed (" + req.ResponseCode() + ")";
            return false;
        }

        @payload = Json::Parse(req.String());
        if (payload.GetType() != Json::Type::Object) {
            err = "Failed to parse aggregator response.";
            return false;
        }
        return true;
    }

    LookupResult@ _RowToLookupResult(const Json::Value &in row) {
        LookupResult@ result = LookupResult();
        result.accountId = NormalizeAccountId(string(row["accountId"]));
        result.displayName = string(row["displayName"]);
        result.source = string(row["source"]);
        try { result.stale = bool(row["stale"]); } catch {
            log("Failed to parse lookup-result stale flag for accountId=" + result.accountId + ": " + getExceptionInfo(), LogLevel::Debug, -1, "_RowToLookupResult");
            result.stale = true;
        }
        try { result.missing = bool(row["missing"]); } catch {
            log("Failed to parse lookup-result missing flag for accountId=" + result.accountId + ": " + getExceptionInfo(), LogLevel::Debug, -1, "_RowToLookupResult");
            result.missing = result.displayName.Length == 0;
        }
        if (result.displayName.Length == 0) result.missing = true;
        return result;
    }

    void _MergeExternalResult(LookupResult@ result, bool fromAggregator, const string &in fallbackSource) {
        if (result is null || result.missing) return;

        string source = result.source.Length > 0 ? result.source : fallbackSource;
        auto existing = _GetEntryByAccountId(result.accountId);
        bool nameChanged = existing is null || existing.displayName != result.displayName;

        int64 observedAt = 1;
        if (!fromAggregator || !result.stale || nameChanged) {
            observedAt = Time::Stamp;
        } else if (existing !is null) {
            observedAt = existing.observedAt;
        }

        _UpsertEntry(result.accountId, result.displayName, observedAt, source);
    }

    array<LookupResult@>@ _ParseAggregatorResponse(const Json::Value &in payload, const string &in fallbackSource) {
        array<LookupResult@>@ results = array<LookupResult@>();

        auto names = payload["names"];
        if (names.GetType() != Json::Type::Array) return results;

        for (uint i = 0; i < names.Length; i++) {
            auto row = names[i];
            if (row.GetType() != Json::Type::Object) continue;

            LookupResult@ result = _RowToLookupResult(row);
            if (result.accountId.Length == 0) continue;
            results.InsertLast(result);
            _MergeExternalResult(result, true, fallbackSource);
        }

        QueuePersistIfDirty();
        return results;
    }

    array<LookupResult@>@ _ParseAggregatorByNameResponse(const Json::Value &in payload, const string &in requestedName, const string &in fallbackSource) {
        array<LookupResult@>@ results = array<LookupResult@>();

        auto queries = payload["queries"];
        if (queries.GetType() != Json::Type::Array) return results;

        string normalizedRequested = NormalizeDisplayNameKey(requestedName);
        for (uint i = 0; i < queries.Length; i++) {
            auto query = queries[i];
            if (query.GetType() != Json::Type::Object) continue;

            string normalizedQuery = NormalizeDisplayNameKey(string(query["displayName"]));
            if (normalizedQuery != normalizedRequested) continue;

            auto matches = query["matches"];
            if (matches.GetType() != Json::Type::Array) continue;

            for (uint j = 0; j < matches.Length; j++) {
                auto row = matches[j];
                if (row.GetType() != Json::Type::Object) continue;

                LookupResult@ result = _RowToLookupResult(row);
                if (result.accountId.Length == 0) continue;
                results.InsertLast(result);
                _MergeExternalResult(result, true, fallbackSource);
            }
        }

        QueuePersistIfDirty();
        return _CollapseDuplicateDisplayNames(results);
    }

    LookupResult@ _TryResolveViaNadeoServices(const string &in accountId) {
        array<string> ids = {accountId};
        auto nameMap = NadeoServices::GetDisplayNamesAsync(ids);
        if (nameMap is null || !nameMap.Exists(accountId)) return null;

        string displayName = string(nameMap[accountId]);
        if (_ShouldSkipObservedDisplayName(displayName)) return null;

        ObserveAccountDisplayName(accountId, displayName, "nadeoservices");
        auto entry = _GetEntryByAccountId(accountId);
        if (entry !is null) return _MakeResultFromEntry(entry);

        LookupResult@ result = LookupResult();
        result.accountId = accountId;
        result.displayName = displayName;
        result.source = "nadeoservices";
        result.stale = false;
        result.missing = displayName.Length == 0;
        return result.missing ? null : result;
    }

    LookupResult@ ResolveAccountIdToName(const string &in rawAccountId) {
        EnsureInit();
        string accountId = NormalizeAccountId(rawAccountId);
        if (accountId.Length == 0) return _MakeMissingResult(rawAccountId);

        auto cached = _GetEntryByAccountId(accountId);
        if (cached !is null && _IsEntryFresh(cached)) {
            return _MakeResultFromEntry(cached);
        }

        Json::Value@ payload;
        string err = "";
        string url = AGGREGATOR_API_BASE + "/display-names?accountId[]=" + Net::UrlEncode(accountId) + "&max_age_seconds=" + CACHE_TTL_SECONDS + "&limit=1";
        if (_FetchAggregatorJson(url, payload, err)) {
            auto results = _ParseAggregatorResponse(payload, "aggregator");
            if (results.Length > 0 && !results[0].missing) {
                return results[0];
            }
        }

        auto nadeoResult = _TryResolveViaNadeoServices(accountId);
        if (nadeoResult !is null && !nadeoResult.missing) {
            return nadeoResult;
        }

        if (cached !is null) {
            LookupResult@ fallback = _MakeResultFromEntry(cached);
            fallback.stale = true;
            return fallback;
        }

        return _MakeMissingResult(accountId);
    }

    array<LookupResult@>@ SearchAggregator(const string &in rawQuery, uint limit = SEARCH_LIMIT_DEFAULT) {
        EnsureInit();
        array<LookupResult@>@ results = array<LookupResult@>();
        string query = rawQuery.Trim();
        if (query.Length == 0) return results;

        Json::Value@ payload;
        string err = "";
        string url = AGGREGATOR_BY_NAME_URL + "?displayName[]=" + Net::UrlEncode(query) + "&max_age_seconds=" + CACHE_TTL_SECONDS;
        if (!_FetchAggregatorJson(url, payload, err)) {
            log("Aggregator search failed for '" + query + "': " + err, LogLevel::Warning, 1345, "_MergeExternalResult");
            return results;
        }

        @results = _ParseAggregatorByNameResponse(payload, query, "aggregator");
        return results;
    }

    array<LookupResult@>@ SearchDisplayNames(const string &in rawQuery, uint limit = SEARCH_LIMIT_DEFAULT, bool includeAggregator = true) {
        EnsureInit();
        string query = rawQuery.Trim();
        array<LookupResult@>@ results = array<LookupResult@>();
        if (query.Length == 0) return results;

        if (includeAggregator) {
            SearchAggregator(query, limit);
        }

        @results = SearchLocal(query, limit);
        return results;
    }

    void QueueSyncFullCache(bool force = false) {
        if (!g_loaded) return;
        if (g_syncInProgress) {
            g_syncPending = true;
            return;
        }
        if (!force && Time::Now - g_lastSyncAt < AGGREGATOR_SYNC_MIN_INTERVAL_MS) {
            g_syncPending = true;
            return;
        }

        g_syncPending = false;
        g_syncInProgress = true;
        g_lastSyncAt = Time::Now;
        startnew(Coro_SyncFullCacheToAggregator);
    }

    void Coro_SyncFullCacheToAggregator() {
        EnsureInit();

        string opToken = "";
        string authErr = "";
        if (!_GetOpenplanetAuthToken(opToken, authErr)) {
            log("Player directory sync skipped: " + authErr, LogLevel::Warning, 1390, "Coro_SyncFullCacheToAggregator");
            g_syncInProgress = false;
            return;
        }

        array<CacheEntry@> snapshot;
        for (uint i = 0; i < g_entries.Length; i++) {
            auto entry = g_entries[i];
            if (entry is null) continue;
            if (entry.accountId.Length == 0 || entry.displayName.Length == 0) continue;
            if (entry.observedAt <= 1) continue;
            snapshot.InsertLast(entry);
        }

        for (uint start = 0; start < snapshot.Length; start += AGGREGATOR_BATCH_SIZE) {
            Json::Value body = Json::Object();
            body["opToken"] = opToken;
            body["projectKey"] = PROJECT_KEY;
            body["projectName"] = PROJECT_NAME;
            body["sourceLabel"] = SOURCE_LABEL;
            body["observedAt"] = _NowIso();
            body["pluginVersion"] = Meta::ExecutingPlugin().Version;
            body["names"] = Json::Array();

            uint end = start + AGGREGATOR_BATCH_SIZE;
            if (end > snapshot.Length) end = snapshot.Length;
            for (uint i = start; i < end; i++) {
                auto entry = snapshot[i];
                if (entry is null) continue;

                Json::Value row = Json::Object();
                row["accountId"] = entry.accountId;
                row["displayName"] = entry.displayName;
                row["source"] = entry.source.Length > 0 ? entry.source : SOURCE_LABEL;
                string observedAtIso = _StampToIso(entry.observedAt);
                if (observedAtIso.Length > 0) row["observedAt"] = observedAtIso;
                body["names"].Add(row);
            }

            Json::Value@ payload;
            string err = "";
            if (!_PostAggregatorJson(AggregatorIngestPluginUrl, body, payload, err)) {
                log("Aggregator ingest failed: " + err, LogLevel::Warning, 1432, "Coro_SyncFullCacheToAggregator");
                break;
            }
        }

        g_syncInProgress = false;

        if (g_syncPending) {
            QueueSyncFullCache(true);
        }
    }
}
