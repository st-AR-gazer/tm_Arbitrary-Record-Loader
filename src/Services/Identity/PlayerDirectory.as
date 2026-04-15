namespace PlayerDirectory {
    const int64 CACHE_TTL_SECONDS = 60 * 60 * 24 * 30 * 6;
    const uint SEARCH_LIMIT_DEFAULT = 20;
    const uint AGGREGATOR_BATCH_SIZE = 200;
    const uint AGGREGATOR_SYNC_MIN_INTERVAL_MS = 30000;

    const string AGGREGATOR_API_BASE = "https://aggregator.xjk.yt/api/v1";
    const string AGGREGATOR_BY_NAME_URL = AGGREGATOR_API_BASE + "/display-names/by-name";
    const string AggregatorIngestPluginUrl = AGGREGATOR_API_BASE + "/ingest/display-names/arl";
    const string CACHE_FILE_PATH = IO::FromStorageFolder("player_directory_cache.json");
    const string GHOSTS_PP_FILE_PATH = IO::FromStorageFolder("../ghosts-pp/player_names.jsons");

    const string PROJECT_KEY = "arl-player-directory";
    const string PROJECT_NAME = "Arbitrary Record Loader Player Directory";
    const string SOURCE_LABEL = "arl-player-directory";

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

    bool g_loaded = false;
    bool g_ready = false;
    bool g_dirty = false;
    bool g_syncInProgress = false;
    bool g_syncPending = false;
    bool g_importInProgress = false;
    bool g_persistInProgress = false;
    bool g_persistPending = false;
    uint g_lastSyncAt = 0;

    array<CacheEntry@> g_entries;
    dictionary g_entriesById;

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

    bool _IsEntryFresh(CacheEntry@ entry) {
        if (entry is null || entry.observedAt <= 0) return false;
        return Time::Stamp - entry.observedAt < CACHE_TTL_SECONDS;
    }

    CacheEntry@ _GetEntryByAccountId(const string &in rawAccountId) {
        string accountId = NormalizeAccountId(rawAccountId);
        if (accountId.Length == 0) return null;
        if (!g_entriesById.Exists(accountId)) return null;
        ref@ entryRef;
        g_entriesById.Get(accountId, @entryRef);
        return cast<CacheEntry@>(entryRef);
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

        Json::Value root = Json::Object();
        root["version"] = 1;
        root["savedAt"] = _NowIso();
        root["entries"] = Json::Array();

        for (uint i = 0; i < g_entries.Length; i++) {
            auto entry = g_entries[i];
            if (entry is null) continue;
            if (entry.accountId.Length == 0 || entry.displayName.Length == 0) continue;

            Json::Value row = Json::Object();
            row["accountId"] = entry.accountId;
            row["displayName"] = entry.displayName;
            row["observedAt"] = entry.observedAt;
            row["source"] = entry.source;
            root["entries"].Add(row);

            if (i % 250 == 249) yield();
        }

        try {
            _IO::File::WriteFile(CACHE_FILE_PATH, Json::Write(root));
        } catch {
            g_dirty = true;
            log("Failed to persist player directory cache: " + getExceptionInfo(), LogLevel::Warning, 140, "PlayerDirectory");
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
        if (accountId.Length == 0 || displayName.Length == 0) return null;

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
            if (displayName.Length > 0 && entry.displayName != displayName) {
                entry.displayName = displayName;
                changed = true;
            }
            if (observedAt > entry.observedAt) {
                entry.observedAt = observedAt;
                changed = true;
            }
            if (source.Length > 0 && entry.source != source) {
                entry.source = source;
                changed = true;
            }
        }

        if (changed) g_dirty = true;
        return entry;
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

    void _LoadCache() {
        g_entries.RemoveRange(0, g_entries.Length);
        auto keys = g_entriesById.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            g_entriesById.Delete(keys[i]);
        }

        if (!IO::FileExists(CACHE_FILE_PATH)) return;

        Json::Value root = Json::Parse(_IO::File::ReadFileToEnd(CACHE_FILE_PATH));
        if (root.GetType() != Json::Type::Object) return;

        auto entries = root["entries"];
        if (entries.GetType() != Json::Type::Array) return;

        for (uint i = 0; i < entries.Length; i++) {
            auto row = entries[i];
            if (row.GetType() != Json::Type::Object) continue;

            string accountId = string(row["accountId"]);
            string displayName = string(row["displayName"]);
            int64 observedAt = 0;
            try { observedAt = int64(row["observedAt"]); } catch {}
            string source = string(row["source"]);

            _UpsertEntry(accountId, displayName, observedAt, source);

            if (i % 50 == 49) yield();
        }

        g_dirty = false;
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
            log("Failed to import ghosts++ player cache: " + getExceptionInfo(), LogLevel::Warning, 192, "PlayerDirectory");
        }
    }

    void Coro_ImportGhostsPPCache() {
        g_importInProgress = true;
        _ImportGhostsPPCache();
        g_importInProgress = false;
        QueuePersistIfDirty();
    }

    void Coro_Init() {
        yield();
        _LoadCache();
        g_ready = true;

        if (!g_importInProgress) {
            startnew(CoroutineFunc(Coro_ImportGhostsPPCache));
        }

        QueueSyncFullCache(true);
    }

    void EnsureInit() {
        if (g_loaded) return;
        g_loaded = true;
        g_ready = false;
        startnew(CoroutineFunc(Coro_Init));
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
        return results;
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
        for (uint i = 0; i < exact.Length && merged.Length < limit; i++) merged.InsertLast(exact[i]);
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
        try { result.stale = bool(row["stale"]); } catch { result.stale = true; }
        try { result.missing = bool(row["missing"]); } catch { result.missing = result.displayName.Length == 0; }
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
        return results;
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
            log("Aggregator search failed for '" + query + "': " + err, LogLevel::Warning, 383, "PlayerDirectory");
            return results;
        }

        @results = _ParseAggregatorByNameResponse(payload, query, "aggregator");
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
            log("Player directory sync skipped: " + authErr, LogLevel::Warning, 435, "PlayerDirectory");
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
                log("Aggregator ingest failed: " + err, LogLevel::Warning, 434, "PlayerDirectory");
                break;
            }
        }

        g_syncInProgress = false;

        if (g_syncPending) {
            QueueSyncFullCache(true);
        }
    }
}
