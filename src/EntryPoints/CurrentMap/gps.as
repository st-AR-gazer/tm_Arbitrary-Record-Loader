namespace EntryPoints {
namespace CurrentMap {
namespace GPS {
    class HttpResponseData {
        int statusCode = 0;
        dictionary headersLower;
        MemoryBuffer@ body = MemoryBuffer();

        string Header(const string &in key) {
            string lower = key.ToLower();
            if (!headersLower.Exists(lower)) return "";
            return string(headersLower[lower]);
        }

        string String() {
            return MemoryBufferToString(body);
        }

        bool SaveToFile(const string &in path) {
            string dir = Path::GetDirectoryName(path);
            if (dir.Length > 0 && !IO::FolderExists(dir)) {
                IO::CreateFolder(dir, true);
            }

            IO::File file(path, IO::FileMode::Write);
            body.Seek(0);
            file.Write(body);
            file.Close();
            return IO::FileExists(path) && IO::FileSize(path) > 0;
        }
    }

    class TransferProgressState {
        uint lastStatusTick = 0;
        uint lastLogTick = 0;
    }

    const uint64 SOCKET_WRITE_CHUNK_BYTES = 4096;
    const uint SOCKET_WRITE_STALL_TIMEOUT_MS = 15000;

    [Setting category="Current Map - GPS" name="Clip-To-Ghost Base URL"]
    string S_ClipToGhostBaseUrl = "https://tools.xjk.yt/Clip-To-Ghost";

    [Setting category="Current Map - GPS" name="Template mode"]
    string S_ClipToGhostTemplateMode = "shipped";

    [Setting category="Current Map - GPS" name="Force refresh GPS ghosts"]
    bool S_ForceRefreshGpsGhosts = false;

    [Setting category="Current Map - GPS" name="Force refresh GPS inspection"]
    bool S_ForceRefreshGpsInspect = false;

    class GhostTrackInfo {
        uint clipIndex = 0;
        uint trackIndex = 0;
        int blockIndex = -1;
        string clipName;
        string trackName;
        string sourcePath;
        uint blockCount = 0;
        uint entListCount = 0;
        uint totalSamples = 0;
        uint totalSamples2 = 0;
        int derivedRaceTimeMs = -1;
        bool looksLikeGps = false;
        bool fromInspect = false;

        GhostTrackInfo() {}

        GhostTrackInfo(uint clipIndex, uint trackIndex, const string &in clipName, const string &in trackName, uint blockCount, bool looksLikeGps) {
            this.clipIndex = clipIndex;
            this.trackIndex = trackIndex;
            this.clipName = clipName;
            this.trackName = trackName;
            this.blockCount = blockCount;
            this.looksLikeGps = looksLikeGps;
        }
    }

    string g_CachedMapUid = "";
    array<GhostTrackInfo@> g_LocalTracks;
    array<GhostTrackInfo@> g_CachedTracks;
    bool g_InspectingTracks = false;
    bool g_InspectionStarted = false;
    bool g_LoadingGpsGhost = false;
    string g_LastGpsStatus = "";
    uint g_LastGpsStatusTime = 0;
    GhostTrackInfo@ g_PendingTrack = null;
    string g_CachedUploadMapUid = "";
    string g_CachedUploadSourcePath = "";
    string g_CachedUploadId = "";

    void OnMapLoad() {
        g_CachedMapUid = "";
        g_LocalTracks.RemoveRange(0, g_LocalTracks.Length);
        g_CachedTracks.RemoveRange(0, g_CachedTracks.Length);
        g_InspectingTracks = false;
        g_InspectionStarted = false;
        g_LoadingGpsGhost = false;
        g_LastGpsStatus = "";
        g_LastGpsStatusTime = 0;
        @g_PendingTrack = null;
        g_CachedUploadMapUid = "";
        g_CachedUploadSourcePath = "";
        g_CachedUploadId = "";
    }

    array<GhostTrackInfo@>@ GetGhostTracks() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) {
            g_CachedMapUid = "";
            g_LocalTracks.RemoveRange(0, g_LocalTracks.Length);
            g_CachedTracks.RemoveRange(0, g_CachedTracks.Length);
            return g_CachedTracks;
        }

        if (g_CachedMapUid != mapUid) {
            ResetStateForMap(mapUid);
            PopulateLocalTracks();
            LoadCachedManifest();
        }

        return g_CachedTracks;
    }

    bool HasGhostTracks() {
        return GetGhostTracks().Length > 0;
    }

    bool IsLoading() {
        return g_LoadingGpsGhost;
    }

    bool IsInspecting() {
        return g_InspectingTracks;
    }

    string GetLastStatus() {
        if (g_LastGpsStatus.Length == 0) return "";
        if (Time::Now - g_LastGpsStatusTime > 15000 && !g_LoadingGpsGhost && !g_InspectingTracks) return "";
        return g_LastGpsStatus;
    }

    void RefreshInspection() {
        Services::Storage::FileStore::DeleteGpsInspectManifest(CurrentMap::GetMapUid());

        g_InspectionStarted = false;
        g_CachedUploadMapUid = "";
        g_CachedUploadSourcePath = "";
        g_CachedUploadId = "";
        g_CachedTracks = CloneTrackArray(g_LocalTracks);
        StartInspectionIfNeeded(true);
    }

    void CopyGhostApiUrl(GhostTrackInfo@ track) {
        IO::SetClipboard(GetExportEndpointUrl());
        NotifyInfo("Copied Clip-To-Ghost export endpoint.");
    }

    void OpenCacheFolder() {
        _IO::OpenFolder(Server::storedFilesDirectory);
    }

    bool HasCachedGhost(GhostTrackInfo@ track) {
        if (track is null) return false;
        return CanReuseCachedGhost(track, FindStoredGpsGhostRecord(track));
    }

    void LoadGhostTrack(GhostTrackInfo@ track, bool forceRefresh = false) {
        if (track is null) return;
        if (g_LoadingGpsGhost) {
            NotifyWarning("A GPS ghost download is already running.");
            return;
        }

        g_LoadingGpsGhost = true;
        SetStatus(Icons::Refresh + " Uploading current map to Clip-To-Ghost...");
        @g_PendingTrack = track;
        startnew(CoroutineFuncUserdataBool(Coro_LoadGhostTrack), forceRefresh);
    }

    void Coro_LoadGhostTrack(bool forceRefresh) {
        auto track = g_PendingTrack;
        @g_PendingTrack = null;
        string err;
        try {
            if (track !is null) {
                auto exportTrack = ResolveTrackForExport(track, forceRefresh);
                if (exportTrack !is null) {
                    auto storedRecord = FindStoredGpsGhostRecord(exportTrack);
                    string cachedPath = storedRecord !is null ? storedRecord.storedPath : GetManagedGpsGhostPath(exportTrack);
                    if (!forceRefresh && !S_ForceRefreshGpsGhosts && CanReuseCachedGhost(exportTrack, storedRecord)) {
                        EnqueueCachedGhost(exportTrack, cachedPath);
                        SetStatus(Icons::Check + " Loaded GPS ghost from cache.");
                    } else {
                        string exportedPath;
                        if (!ExportGhostTrack(exportTrack, cachedPath, exportedPath, err, forceRefresh || S_ForceRefreshGpsGhosts)) {
                            NotifyWarning(err);
                            SetStatus(Icons::Times + " " + err);
                        } else {
                            EnqueueCachedGhost(exportTrack, exportedPath);
                            SetStatus(Icons::Check + " Downloaded and loaded GPS ghost.");
                        }
                    }
                }
            }
        } catch {
            err = "Unexpected error while loading the GPS ghost.";
            NotifyWarning(err);
            SetStatus(Icons::Times + " " + err);
        }
        g_LoadingGpsGhost = false;
    }

    void ResetStateForMap(const string &in mapUid) {
        g_CachedMapUid = mapUid;
        g_LocalTracks.RemoveRange(0, g_LocalTracks.Length);
        g_CachedTracks.RemoveRange(0, g_CachedTracks.Length);
        g_InspectingTracks = false;
        g_InspectionStarted = false;
        @g_PendingTrack = null;
        g_CachedUploadMapUid = "";
        g_CachedUploadSourcePath = "";
        g_CachedUploadId = "";
    }

    void PopulateLocalTracks() {
        auto root = GetApp().RootMap;
        if (root is null || root.ClipGroupInGame is null) return;

        for (uint ci = 0; ci < root.ClipGroupInGame.Clips.Length; ci++) {
            auto clip = root.ClipGroupInGame.Clips[ci];
            if (clip is null) continue;

            string clipName = clip.Name;

            for (uint ti = 0; ti < clip.Tracks.Length; ti++) {
                auto track = clip.Tracks[ti];
                if (track is null) continue;

                string trackName = track.Name;
                string lowerTrackName = trackName.ToLower();
                string lowerClipName = clipName.ToLower();
                bool looksLikeGhost = trackName.StartsWith("Ghost:");
                bool looksLikeGps = lowerTrackName.Contains("gps") || lowerClipName.Contains("gps");
                if (!looksLikeGhost && !looksLikeGps) continue;

                g_LocalTracks.InsertLast(GhostTrackInfo(ci, ti, clipName, trackName, track.Blocks.Length, looksLikeGps));
            }
        }

        g_CachedTracks = CloneTrackArray(g_LocalTracks);
    }

    void StartInspectionIfNeeded(bool forceRefresh = false) {
        if (g_InspectingTracks || g_InspectionStarted) return;

        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return;

        if (!forceRefresh && !S_ForceRefreshGpsInspect && Services::Storage::FileStore::HasGpsInspectManifest(mapUid)) {
            return;
        }

        g_InspectionStarted = true;
        g_InspectingTracks = true;
        SetStatus(Icons::Search + " Uploading current map for GPS inspection...");
        startnew(CoroutineFunc(Coro_InspectCurrentMap));
    }

    void Coro_InspectCurrentMap() {
        string err;
        if (!RefreshCandidatesFromCurrentMap(err, S_ForceRefreshGpsInspect)) {
            SetStatus(Icons::Times + " " + err);
            g_InspectingTracks = false;
            return;
        }

        SetStatus(Icons::Check + " Loaded GPS candidates from Clip-To-Ghost.");
        g_InspectingTracks = false;
    }

    void LoadCachedManifest() {
        string raw = Services::Storage::FileStore::GetGpsInspectManifest(CurrentMap::GetMapUid());
        if (S_ForceRefreshGpsInspect) return;
        if (raw.Length == 0) return;

        Json::Value manifest = Json::Parse(raw);
        if (manifest.GetType() != Json::Type::Object) return;

        ApplyManifest(manifest);
    }

    bool ApplyManifest(const Json::Value &in manifest) {
        if (manifest.GetType() != Json::Type::Object || !manifest.HasKey("entries")) return false;

        auto entries = manifest["entries"];
        if (entries.GetType() != Json::Type::Array || entries.Length == 0) return false;

        array<GhostTrackInfo@> inspectedTracks;
        for (uint i = 0; i < entries.Length; i++) {
            auto entry = entries[i];
            if (entry.GetType() != Json::Type::Object) continue;

            auto track = BuildTrackFromManifestEntry(entry);
            if (track is null) continue;
            inspectedTracks.InsertLast(track);
        }

        if (inspectedTracks.Length == 0) return false;

        g_CachedTracks = inspectedTracks;
        return true;
    }

    GhostTrackInfo@ BuildTrackFromManifestEntry(const Json::Value &in entry) {
        GhostTrackInfo@ track = GhostTrackInfo();
        track.clipIndex = GetJsonUInt(entry, "clipIndex");
        track.trackIndex = GetJsonUInt(entry, "trackIndex");
        track.blockIndex = GetJsonInt(entry, "blockIndex", -1);
        track.sourcePath = GetJsonString(entry, "sourcePath");
        track.entListCount = GetJsonUInt(entry, "entListCount");
        track.totalSamples = GetJsonUInt(entry, "totalSamples");
        track.totalSamples2 = GetJsonUInt(entry, "totalSamples2");
        track.derivedRaceTimeMs = GetJsonInt(entry, "derivedRaceTimeMs", -1);
        track.fromInspect = true;

        auto local = FindLocalTrack(g_LocalTracks, track.clipIndex, track.trackIndex);
        if (local !is null) {
            track.clipName = local.clipName;
            track.trackName = local.trackName;
            track.blockCount = local.blockCount;
            track.looksLikeGps = local.looksLikeGps;
        } else {
            track.clipName = "Clip " + track.clipIndex;
            track.trackName = "Track " + track.trackIndex;
            track.looksLikeGps = true;
        }

        return track;
    }

    GhostTrackInfo@ ResolveTrackForExport(GhostTrackInfo@ track, bool forceRefreshInspect) {
        if (track is null) return null;
        if (track.fromInspect && track.blockIndex >= 0) return track;

        array<GhostTrackInfo@> matches = FindCandidateMatches(track);
        if (matches.Length == 0 || forceRefreshInspect || S_ForceRefreshGpsInspect) {
            string err;
            if (!RefreshCandidatesFromCurrentMap(err, forceRefreshInspect || S_ForceRefreshGpsInspect)) {
                NotifyWarning(err);
                SetStatus(Icons::Times + " " + err);
                return null;
            }
            matches = FindCandidateMatches(track);
        }

        if (matches.Length == 0) {
            string err = "Clip-To-Ghost found no GPS RecordData candidate for this clip/track.";
            NotifyWarning(err);
            SetStatus(Icons::Times + " " + err);
            return null;
        }

        if (matches.Length > 1) {
            MergeMatchesIntoCache(track, matches);
            string err = "Multiple GPS blocks were found for this track. Pick a specific block and try again.";
            NotifyWarning(err);
            SetStatus(Icons::Times + " " + err);
            return null;
        }

        MergeMatchesIntoCache(track, matches);
        return matches[0];
    }

    bool RefreshCandidatesFromCurrentMap(string &out err, bool forceMapUpload = false) {
        Json::Value@ manifest = InspectCurrentMap(null, err, forceMapUpload);
        if (manifest is null) {
            return false;
        }

        if (!ApplyManifest(manifest)) {
            err = "Clip-To-Ghost found no GPS candidates on this map.";
            return false;
        }

        Services::Storage::FileStore::UpsertGpsInspectManifest(CurrentMap::GetMapUid(), Json::Write(manifest, true));
        return true;
    }

    array<GhostTrackInfo@> FindCandidateMatches(GhostTrackInfo@ selectedTrack) {
        array<GhostTrackInfo@> matches;
        if (selectedTrack is null) return matches;

        for (uint i = 0; i < g_CachedTracks.Length; i++) {
            auto track = g_CachedTracks[i];
            if (track is null || !track.fromInspect) continue;
            if (track.clipIndex != selectedTrack.clipIndex) continue;
            if (track.trackIndex != selectedTrack.trackIndex) continue;
            matches.InsertLast(track);
        }

        return matches;
    }

    void MergeMatchesIntoCache(GhostTrackInfo@ originalTrack, const array<GhostTrackInfo@> &in matches) {
        if (originalTrack is null || matches.Length == 0) return;

        array<GhostTrackInfo@> updated;
        bool inserted = false;

        for (uint i = 0; i < g_CachedTracks.Length; i++) {
            auto existing = g_CachedTracks[i];
            if (existing is null) continue;

            bool sameTrack = existing.clipIndex == originalTrack.clipIndex && existing.trackIndex == originalTrack.trackIndex;
            if (sameTrack) {
                if (!inserted) {
                    for (uint j = 0; j < matches.Length; j++) {
                        updated.InsertLast(matches[j]);
                    }
                    inserted = true;
                }
                continue;
            }

            updated.InsertLast(existing);
        }

        if (!inserted) {
            for (uint j = 0; j < matches.Length; j++) {
                updated.InsertLast(matches[j]);
            }
        }

        g_CachedTracks = updated;
    }

    Json::Value@ InspectCurrentMap(GhostTrackInfo@ filterTrack, string &out err, bool forceMapUpload = false) {
        string uploadId;
        if (!EnsureCurrentMapUploaded(uploadId, err, forceMapUpload)) {
            return null;
        }

        Net::HttpRequest@ req = null;
        if (!SendInspectJsonRequest(uploadId, filterTrack, req, err)) {
            return null;
        }

        if (req.ResponseCode() != 200) {
            err = BuildHttpError("Clip-To-Ghost inspection failed", req);
            return null;
        }

        Json::Value@ response = req.Json();
        if (response is null || response.GetType() != Json::Type::Object) {
            err = "Clip-To-Ghost inspection returned an unexpected response.";
            return null;
        }

        if (response.HasKey("error")) {
            err = string(response["error"]);
            return null;
        }

        if (!response.HasKey("manifest") || response["manifest"].GetType() != Json::Type::Object) {
            err = "Clip-To-Ghost inspection returned an unexpected response.";
            return null;
        }

        Json::Value@ manifest = Json::Parse(Json::Write(response["manifest"]));
        if (manifest is null || manifest.GetType() != Json::Type::Object) {
            err = "Clip-To-Ghost inspection returned an unexpected response.";
            return null;
        }
        return manifest;
    }

    bool ExportGhostTrack(GhostTrackInfo@ track, const string &in defaultOutputPath, string &out outputPath, string &out err, bool forceMapUpload = false) {
        outputPath = "";
        err = "";

        if (track is null) {
            err = "No GPS track was selected.";
            return false;
        }

        string templateMode = NormalizeTemplateMode();
        if (templateMode == "custom") {
            err = "Clip-To-Ghost template mode 'custom' requires a template ghost file upload, which is not supported by this plugin. Use 'shipped' or 'blank'.";
            return false;
        }

        string uploadId;
        if (!EnsureCurrentMapUploaded(uploadId, err, forceMapUpload)) {
            return false;
        }

        Net::HttpRequest@ req = null;
        if (!SendExportJsonRequest(uploadId, track, templateMode, req, err)) {
            return false;
        }

        if (req.ResponseCode() != 200) {
            err = BuildHttpError("Clip-To-Ghost export failed", req);
            return false;
        }

        string contentType = req.ResponseHeader("Content-Type").ToLower();
        if (contentType.Contains("application/json")) {
            Json::Value@ response = req.Json();
            if (response !is null && response.GetType() == Json::Type::Object && response.HasKey("error")) {
                err = string(response["error"]);
            } else {
                err = "Clip-To-Ghost export returned JSON instead of a ghost file.";
            }
            return false;
        }

        if (contentType.Contains("application/zip")) {
            err = "Clip-To-Ghost returned a zip archive. Pick a specific GPS block and try again.";
            return false;
        }

        string backendFileName = TryParseContentDispositionFileName(req.ResponseHeader("Content-Disposition"));
        string fileId = BuildGpsStoredFileId(track, templateMode);
        outputPath = Services::Storage::FileStore::BuildStoredFilePath(Services::Storage::FileStore::KIND_GPS_GHOST, fileId, ".Ghost.Gbx");

        string outputDir = Path::GetDirectoryName(outputPath);
        if (outputDir.Length > 0 && !IO::FolderExists(outputDir)) {
            IO::CreateFolder(outputDir, true);
        }

        if (IO::FileExists(outputPath)) {
            try { IO::Delete(outputPath); } catch {}
        }

        try {
            req.SaveToFile(outputPath);
        } catch {
            err = "Failed to save exported GPS ghost to disk: " + outputPath;
            return false;
        }
        if (!IO::FileExists(outputPath) || IO::FileSize(outputPath) == 0) {
            err = "Exported GPS ghost file is missing or empty.";
            return false;
        }

        RegisterGpsStoredGhost(fileId, track, outputPath, backendFileName);
        return true;
    }

    void EnqueueCachedGhost(GhostTrackInfo@ track, const string &in path) {
        Domain::LoadRequest@ loadReq = Domain::LoadRequest();
        loadReq.selectorKind = Domain::SelectorKind::LocalFile;
        loadReq.context = Domain::LoadContext::LocalFile;
        loadReq.filePath = path;
        loadReq.mapUid = CurrentMap::GetMapUid();
        loadReq.useGhostLayer = GhostLoader::S_UseGhostLayer;
        loadReq.cacheFile = true;
        loadReq.forceRefresh = false;
        loadReq.sourceKind = LoadedRecords::SourceKind::Replay;
        loadReq.sourceRef = BuildGpsSourceRef(track);
        Services::LoadQueue::Enqueue(loadReq);
    }

    string DescribeTrack(GhostTrackInfo@ track) {
        if (track is null) return "track";

        string desc = track.trackName.Length > 0 ? track.trackName : ("Track " + track.trackIndex);
        if (track.blockIndex >= 0) desc += " | block " + track.blockIndex;
        return desc;
    }

    GhostTrackInfo@ FindLocalTrack(const array<GhostTrackInfo@> &in tracks, uint clipIndex, uint trackIndex) {
        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            if (track is null) continue;
            if (track.clipIndex == clipIndex && track.trackIndex == trackIndex) return track;
        }
        return null;
    }

    array<GhostTrackInfo@> CloneTrackArray(const array<GhostTrackInfo@> &in src) {
        array<GhostTrackInfo@> dst;
        for (uint i = 0; i < src.Length; i++) {
            auto track = src[i];
            if (track is null) continue;
            dst.InsertLast(CloneTrack(track));
        }
        return dst;
    }

    GhostTrackInfo@ CloneTrack(GhostTrackInfo@ src) {
        if (src is null) return null;

        GhostTrackInfo@ dst = GhostTrackInfo();
        dst.clipIndex = src.clipIndex;
        dst.trackIndex = src.trackIndex;
        dst.blockIndex = src.blockIndex;
        dst.clipName = src.clipName;
        dst.trackName = src.trackName;
        dst.sourcePath = src.sourcePath;
        dst.blockCount = src.blockCount;
        dst.entListCount = src.entListCount;
        dst.totalSamples = src.totalSamples;
        dst.totalSamples2 = src.totalSamples2;
        dst.derivedRaceTimeMs = src.derivedRaceTimeMs;
        dst.looksLikeGps = src.looksLikeGps;
        dst.fromInspect = src.fromInspect;
        return dst;
    }

    string GetCachedMapPath() {
        string cacheDir = IO::FromStorageFolder("cache/");
        if (!IO::FolderExists(cacheDir)) {
            IO::CreateFolder(cacheDir, true);
        }

        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) mapUid = "current";
        return Path::Join(cacheDir, "ARL_map_" + Path::SanitizeFileName(mapUid) + ".Map.Gbx");
    }

    string TryParseContentDispositionFileName(const string &in contentDisposition) {
        if (contentDisposition.Trim().Length == 0) return "";
        string cdLower = contentDisposition.ToLower();
        int idx = cdLower.IndexOf("filename=");
        if (idx < 0) return "";

        string tail = contentDisposition.SubStr(idx + 9).Trim();
        if (tail.StartsWith("\"")) {
            int endQ = tail.SubStr(1).IndexOf("\"");
            if (endQ >= 0) tail = tail.SubStr(1, endQ);
            else tail = tail.Replace("\"", "");
        } else {
            int semi = tail.IndexOf(";");
            if (semi >= 0) tail = tail.SubStr(0, semi);
        }
        return tail.Trim();
    }

    Services::Storage::FileStore::StoredFileRecord@ FindStoredGpsGhostRecord(GhostTrackInfo@ track) {
        if (track is null || track.blockIndex < 0) return null;
        auto record = Services::Storage::FileStore::FindGpsGhost(CurrentMap::GetMapUid(), track.clipIndex, track.trackIndex, track.blockIndex);
        if (record is null) return null;
        if (!IO::FileExists(record.storedPath) || IO::FileSize(record.storedPath) == 0) return null;
        return record;
    }

    string GetManagedGpsGhostPath(GhostTrackInfo@ track) {
        string fileId = BuildGpsStoredFileId(track, NormalizeTemplateMode());
        return Services::Storage::FileStore::BuildStoredFilePath(Services::Storage::FileStore::KIND_GPS_GHOST, fileId, ".Ghost.Gbx");
    }

    bool CanReuseCachedGhost(GhostTrackInfo@ track, Services::Storage::FileStore::StoredFileRecord@ record) {
        if (record is null) return false;
        if (!IO::FileExists(record.storedPath) || IO::FileSize(record.storedPath) == 0) return false;
        if (track is null || !track.fromInspect || track.blockIndex < 0) return true;

        int64 inspectUpdatedAt = Services::Storage::FileStore::GetGpsInspectUpdatedAt(CurrentMap::GetMapUid());
        if (inspectUpdatedAt <= 0) return true;
        return record.updatedAt >= inspectUpdatedAt;
    }

    string BuildGpsStoredFileId(GhostTrackInfo@ track, const string &in templateMode) {
        if (track is null) return Services::Storage::FileStore::BuildFileId(Services::Storage::FileStore::KIND_GPS_GHOST, CurrentMap::GetMapUid() + "|track");

        string identity = CurrentMap::GetMapUid()
            + "|" + track.clipIndex
            + "|" + track.trackIndex
            + "|" + track.blockIndex
            + "|" + templateMode.Trim().ToLower();
        return Services::Storage::FileStore::BuildFileId(Services::Storage::FileStore::KIND_GPS_GHOST, identity);
    }

    string BuildGpsSourceRef(GhostTrackInfo@ track) {
        string sourceRef = "GPS | " + CurrentMap::GetMapUid() + " | " + DescribeTrack(track);
        if (track !is null && track.derivedRaceTimeMs >= 0) {
            sourceRef += " | rt=" + track.derivedRaceTimeMs;
        }
        return sourceRef;
    }

    void RegisterGpsStoredGhost(const string &in fileId, GhostTrackInfo@ track, const string &in storedPath, const string &in backendFileName) {
        Services::Storage::FileStore::StoredFileRecord@ record = Services::Storage::FileStore::StoredFileRecord();
        record.fileId = fileId;
        record.kind = Services::Storage::FileStore::KIND_GPS_GHOST;
        record.sourceKind = int(LoadedRecords::SourceKind::Replay);
        record.fileName = Path::GetFileName(storedPath);
        record.storedPath = storedPath;
        record.originalFileName = backendFileName.Length > 0 ? Path::GetFileName(backendFileName) : Path::GetFileName(storedPath);
        record.backendFileName = backendFileName;
        record.sourceRef = BuildGpsSourceRef(track);
        record.mapUid = CurrentMap::GetMapUid();
        record.clipIndex = track is null ? -1 : int(track.clipIndex);
        record.trackIndex = track is null ? -1 : int(track.trackIndex);
        record.blockIndex = track is null ? -1 : track.blockIndex;
        record.derivedRaceTimeMs = track is null ? -1 : track.derivedRaceTimeMs;
        record.clipName = track is null ? "" : track.clipName;
        record.trackName = track is null ? "" : track.trackName;
        record.sourcePath = track is null ? "" : track.sourcePath;
        record.useGhostLayer = GhostLoader::S_UseGhostLayer;
        Services::Storage::FileStore::Upsert(record);
    }

    string NormalizeBaseUrl() {
        string url = S_ClipToGhostBaseUrl.Trim();
        while (url.EndsWith("/")) {
            url = url.SubStr(0, url.Length - 1);
        }
        return url;
    }

    string GetInspectEndpointUrl() {
        return NormalizeBaseUrl() + "/api/inspect";
    }

    string GetExportEndpointUrl() {
        return NormalizeBaseUrl() + "/api/export";
    }

    string GetUploadMapEndpointUrl() {
        return NormalizeBaseUrl() + "/api/upload-map";
    }

    string NormalizeTemplateMode() {
        string mode = S_ClipToGhostTemplateMode.Trim().ToLower();
        if (mode == "blank") return "blank";
        if (mode == "custom") return "custom";
        return "shipped";
    }

    bool EnsureCurrentMapUploaded(string &out uploadId, string &out err, bool forceRefresh = false) {
        uploadId = "";
        err = "";

        string mapPath;
        if (!EnsureCurrentMapUploadSource(mapPath, err, forceRefresh)) {
            return false;
        }

        string mapUid = CurrentMap::GetMapUid();
        if (!forceRefresh && g_CachedUploadId.Length > 0 && g_CachedUploadMapUid == mapUid && g_CachedUploadSourcePath == mapPath) {
            uploadId = g_CachedUploadId;
            return true;
        }

        string mapFileName = BuildMapUploadFileName(mapPath);
        if (!UploadCurrentMapFile(mapPath, mapFileName, uploadId, err)) {
            return false;
        }

        g_CachedUploadMapUid = mapUid;
        g_CachedUploadSourcePath = mapPath;
        g_CachedUploadId = uploadId;
        return true;
    }

    void ApplyTrackSelection(Json::Value &inout payload, GhostTrackInfo@ track) {
        if (track is null) return;
        payload["clipIndex"] = track.clipIndex;
        payload["trackIndex"] = track.trackIndex;
        if (track.blockIndex >= 0) {
            payload["blockIndex"] = track.blockIndex;
        }
    }

    bool ResolveCurrentMapFilePath(string &out mapPath, string &out err) {
        mapPath = "";
        err = "";

        auto rootMap = GetApp().RootMap;
        if (rootMap is null) {
            err = "No current map is loaded.";
            return false;
        }

        auto fid = GetFidFromNod(rootMap);
        if (fid is null) {
            err = "Could not resolve the current map fid.";
            return false;
        }

        mapPath = string(fid.FullFileName);
        if (mapPath.Trim().Length == 0) {
            mapPath = Fids::GetFullPath(fid);
        }

        if ((mapPath.Trim().Length == 0 || !IO::FileExists(mapPath)) && !Fids::Extract(fid)) {
            err = "Could not extract the current map from Trackmania cache.";
            return false;
        }

        if (mapPath.Trim().Length == 0 || !IO::FileExists(mapPath)) {
            string extractedPath = Fids::GetFullPath(fid);
            if (extractedPath.Length > 0) {
                mapPath = extractedPath;
            } else {
                mapPath = string(fid.FullFileName);
            }
        }

        if (mapPath.Trim().Length == 0 || !IO::FileExists(mapPath)) {
            err = "Current map file is not available on disk.";
            return false;
        }

        return true;
    }

    bool EnsureCurrentMapUploadSource(string &out mapPath, string &out err, bool forceRefresh = false) {
        mapPath = "";
        err = "";

        string sourcePath;
        if (!ResolveCurrentMapFilePath(sourcePath, err)) {
            return false;
        }

        string cachedPath = GetCachedMapPath();
        if (!forceRefresh && IO::FileExists(cachedPath) && IO::FileSize(cachedPath) > 0) {
            mapPath = cachedPath;
            return true;
        }

        if (!CopyBinaryFile(sourcePath, cachedPath, err)) {
            return false;
        }

        mapPath = cachedPath;
        return true;
    }

    bool CopyBinaryFile(const string &in sourcePath, const string &in destinationPath, string &out err) {
        err = "";

        if (!IO::FileExists(sourcePath)) {
            err = "Source map file does not exist: " + sourcePath;
            return false;
        }

        string destinationDir = Path::GetDirectoryName(destinationPath);
        if (destinationDir.Length > 0 && !IO::FolderExists(destinationDir)) {
            IO::CreateFolder(destinationDir, true);
        }

        IO::File src(sourcePath, IO::FileMode::Read);
        uint64 size = src.Size();
        auto buf = src.Read(size);
        src.Close();

        if (buf is null || buf.GetSize() == 0) {
            err = "Source map file is empty.";
            return false;
        }

        if (IO::FileExists(destinationPath)) {
            try { IO::Delete(destinationPath); } catch {}
        }

        IO::File dst(destinationPath, IO::FileMode::Write);
        dst.Write(buf);
        dst.Close();

        if (!IO::FileExists(destinationPath) || IO::FileSize(destinationPath) == 0) {
            err = "Failed to stage map file for upload.";
            return false;
        }

        return true;
    }

    string BuildMapUploadFileName(const string &in mapPath) {
        string safeMapName = CurrentMap::GetMapUid();
        if (safeMapName.Length > 0) {
            safeMapName = "map_" + Path::SanitizeFileName(safeMapName);
        }
        if (safeMapName.Length == 0) safeMapName = "map";

        string lower = safeMapName.ToLower();
        if (!lower.EndsWith(".map.gbx") && !lower.EndsWith(".gbx")) {
            safeMapName += ".Map.Gbx";
        }

        return safeMapName;
    }

    bool UploadCurrentMapFile(const string &in mapPath, const string &in mapFileName, string &out uploadId, string &out err) {
        uploadId = "";
        err = "";

        if (!IO::FileExists(mapPath)) {
            err = "Map file does not exist: " + mapPath;
            return false;
        }

        string url = GetUploadMapEndpointUrl() + "?mapFileName=" + Net::UrlEncode(mapFileName);
        HttpResponseData@ req = null;
        if (!SendRawFileRequest(url, "CurrentMap GPS upload", "application/json", mapPath, req, err)) {
            return false;
        }

        if (req.statusCode != 200) {
            err = BuildHttpError("Clip-To-Ghost map upload failed", req);
            return false;
        }

        Json::Value response = Json::Parse(req.String());
        if (response.GetType() != Json::Type::Object || !response.HasKey("uploadId")) {
            err = "Clip-To-Ghost map upload returned an unexpected response.";
            return false;
        }

        uploadId = string(response["uploadId"]);
        if (uploadId.Trim().Length == 0) {
            err = "Clip-To-Ghost map upload returned an empty upload id.";
            return false;
        }

        return true;
    }

    CNetScriptHttpManager@ ResolveScriptHttpManager() {
        auto appHttp = cast<CGameManiaApp>(GetApp());
        if (appHttp !is null && appHttp.Http !is null) return appHttp.Http;

        auto playgroundHttp = cast<CGamePlaygroundScript>(GetApp().PlaygroundScript);
        if (playgroundHttp !is null && playgroundHttp.Http !is null) return playgroundHttp.Http;

        auto editorHttp = cast<CGameEditorPluginMap>(GetApp().Editor);
        if (editorHttp !is null && editorHttp.Http !is null) return editorHttp.Http;

        return null;
    }

    bool SendJsonRequest(const string &in url, const Json::Value &in payload, const string &in throttleLabel, const string &in acceptHeader, Net::HttpRequest@ &out req, string &out err) {
        err = "";
        @req = Net::HttpRequest();
        req.Url = url;
        req.Method = Net::HttpMethod::Post;
        req.Body = Json::Write(payload);
        req.Headers["Accept"] = acceptHeader;
        req.Headers["Content-Type"] = "application/json";
        req.Headers["User-Agent"] = BuildUserAgent();

        RequestThrottle::WaitForSlot(throttleLabel);
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() == 0 && req.Error().Length > 0) {
            err = req.Error();
            return false;
        }

        return true;
    }

    bool SendRawFileRequest(const string &in url, const string &in throttleLabel, const string &in acceptHeader, const string &in filePath, HttpResponseData@ &out req, string &out err) {
        err = "";
        if (!IO::FileExists(filePath)) {
            err = "Upload file does not exist: " + filePath;
            return false;
        }

        string scheme, host, path;
        uint16 port = 0;
        if (!TryParseHttpUrl(url, scheme, host, port, path, err)) {
            return false;
        }

        uint64 fileSize = IO::FileSize(filePath);
        SetStatus(Icons::Refresh + " Connecting to Clip-To-Ghost...");
        log("Connecting to Clip-To-Ghost: " + host + ":" + port + " for " + throttleLabel, LogLevel::Info, -1, "CurrentMap::GPS");

        string headers =
            "POST " + path + " HTTP/1.1\r\n" +
            "Host: " + host + "\r\n" +
            "User-Agent: " + BuildUserAgent() + "\r\n" +
            "Accept: " + acceptHeader + "\r\n" +
            "Content-Type: application/octet-stream\r\n" +
            "Content-Length: " + fileSize + "\r\n" +
            "Connection: close\r\n\r\n";

        RequestThrottle::WaitForSlot(throttleLabel);
        if (scheme == "https") {
            auto sock = Net::Socket();
            if (!sock.Connect(host, port, true)) {
                err = "Failed to connect secure socket to " + host + ":" + port;
                return false;
            }
            if (!WaitForSocketConnected(sock, 10000, err)) return false;
            if (!WriteAll(sock, headers, filePath, err)) return false;
            return ReadHttpResponse(sock, req, err);
        }

        auto sock = Net::Socket();
        if (!sock.Connect(host, port)) {
            err = "Failed to connect socket to " + host + ":" + port;
            return false;
        }
        if (!WaitForSocketConnected(sock, 10000, err)) return false;
        if (!WriteAll(sock, headers, filePath, err)) return false;
        return ReadHttpResponse(sock, req, err);
    }

    bool SendInspectJsonRequest(const string &in uploadId, GhostTrackInfo@ filterTrack, Net::HttpRequest@ &out req, string &out err) {
        Json::Value payload = Json::Object();
        payload["uploadId"] = uploadId;
        ApplyTrackSelection(payload, filterTrack);
        return SendJsonRequest(GetInspectEndpointUrl(), payload, "CurrentMap GPS inspect", "application/json", req, err);
    }

    bool SendExportJsonRequest(const string &in uploadId, GhostTrackInfo@ track, const string &in templateMode, Net::HttpRequest@ &out req, string &out err) {
        Json::Value payload = Json::Object();
        payload["uploadId"] = uploadId;
        payload["templateMode"] = templateMode;
        payload["includeManifest"] = false;
        ApplyTrackSelection(payload, track);
        return SendJsonRequest(GetExportEndpointUrl(), payload, "CurrentMap GPS export", "application/octet-stream, application/zip, application/json", req, err);
    }

    bool SendInspectMultipartRequest(const string &in mapPath, GhostTrackInfo@ filterTrack, HttpResponseData@ &out req, string &out err) {
        string boundary = NextMultipartBoundary();
        auto body = BuildInspectMultipartBody(mapPath, filterTrack, boundary, err);
        if (body is null) return false;
        return SendMultipartRequest(GetInspectEndpointUrl(), "CurrentMap GPS inspect", "application/json", boundary, body, req, err);
    }

    bool SendExportMultipartRequest(const string &in mapPath, GhostTrackInfo@ track, const string &in templateMode, HttpResponseData@ &out req, string &out err) {
        string boundary = NextMultipartBoundary();
        auto body = BuildExportMultipartBody(mapPath, track, templateMode, boundary, err);
        if (body is null) return false;
        return SendMultipartRequest(GetExportEndpointUrl(), "CurrentMap GPS export", "application/octet-stream, application/zip, application/json", boundary, body, req, err);
    }

    bool SendMultipartRequest(const string &in url, const string &in throttleLabel, const string &in acceptHeader, const string &in boundary, MemoryBuffer@ body, HttpResponseData@ &out req, string &out err) {
        err = "";
        if (body is null) {
            err = "Multipart request body is null.";
            return false;
        }

        string scheme, host, path;
        uint16 port = 0;
        if (!TryParseHttpUrl(url, scheme, host, port, path, err)) {
            return false;
        }

        SetStatus(Icons::Refresh + " Connecting to Clip-To-Ghost...");
        log("Connecting to Clip-To-Ghost: " + host + ":" + port + " for " + throttleLabel, LogLevel::Info, -1, "CurrentMap::GPS");

        string headers =
            "POST " + path + " HTTP/1.1\r\n" +
            "Host: " + host + "\r\n" +
            "User-Agent: " + BuildUserAgent() + "\r\n" +
            "Accept: " + acceptHeader + "\r\n" +
            "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n" +
            "Content-Length: " + body.GetSize() + "\r\n" +
            "Connection: close\r\n\r\n";

        RequestThrottle::WaitForSlot(throttleLabel);
        if (scheme == "https") {
            auto sock = Net::Socket();
            if (!sock.Connect(host, port, true)) {
                err = "Failed to connect secure socket to " + host + ":" + port;
                return false;
            }
            if (!WaitForSocketConnected(sock, 10000, err)) return false;
            if (!WriteAll(sock, headers, body, err)) return false;
            return ReadHttpResponse(sock, req, err);
        }

        auto sock = Net::Socket();
        if (!sock.Connect(host, port)) {
            err = "Failed to connect socket to " + host + ":" + port;
            return false;
        }
        if (!WaitForSocketConnected(sock, 10000, err)) return false;
        if (!WriteAll(sock, headers, body, err)) return false;
        return ReadHttpResponse(sock, req, err);
    }

    MemoryBuffer@ BuildInspectMultipartBody(const string &in mapPath, GhostTrackInfo@ filterTrack, const string &in boundary, string &out err) {
        err = "";
        auto body = MemoryBuffer();
        if (!AppendMultipartFile(body, boundary, "map", mapPath, BuildMapUploadFileName(mapPath), err)) return null;
        AppendTrackSelectionFields(body, boundary, filterTrack);
        AppendMultipartEnd(body, boundary);
        return body;
    }

    MemoryBuffer@ BuildExportMultipartBody(const string &in mapPath, GhostTrackInfo@ track, const string &in templateMode, const string &in boundary, string &out err) {
        err = "";
        auto body = MemoryBuffer();
        if (!AppendMultipartFile(body, boundary, "map", mapPath, BuildMapUploadFileName(mapPath), err)) return null;
        AppendMultipartField(body, boundary, "templateMode", templateMode);
        AppendMultipartField(body, boundary, "includeManifest", "false");
        AppendTrackSelectionFields(body, boundary, track);
        AppendMultipartEnd(body, boundary);
        return body;
    }

    void AppendTrackSelectionFields(MemoryBuffer &inout body, const string &in boundary, GhostTrackInfo@ track) {
        if (track is null) return;
        AppendMultipartField(body, boundary, "clipIndex", "" + track.clipIndex);
        AppendMultipartField(body, boundary, "trackIndex", "" + track.trackIndex);
        if (track.blockIndex >= 0) {
            AppendMultipartField(body, boundary, "blockIndex", "" + track.blockIndex);
        }
    }

    string NextMultipartBoundary() {
        return "----ARLGpsBoundary_" + tostring(Time::Now);
    }

    void AppendMultipartField(MemoryBuffer &inout body, const string &in boundary, const string &in name, const string &in value) {
        body.Write("--" + boundary + "\r\n");
        body.Write("Content-Disposition: form-data; name=\"" + SanitizeMultipartValue(name) + "\"\r\n\r\n");
        body.Write(value);
        body.Write("\r\n");
    }

    bool AppendMultipartFile(MemoryBuffer &inout body, const string &in boundary, const string &in fieldName, const string &in filePath, const string &in fileName, string &out err) {
        err = "";
        if (!IO::FileExists(filePath)) {
            err = "Map file does not exist: " + filePath;
            return false;
        }

        IO::File file(filePath, IO::FileMode::Read);
        uint64 size = file.Size();
        auto buf = file.Read(size);
        file.Close();

        if (buf is null || buf.GetSize() == 0) {
            err = "Map file is empty: " + filePath;
            return false;
        }

        body.Write("--" + boundary + "\r\n");
        body.Write("Content-Disposition: form-data; name=\"" + SanitizeMultipartValue(fieldName) + "\"; filename=\"" + SanitizeMultipartValue(fileName) + "\"\r\n");
        body.Write("Content-Type: application/octet-stream\r\n\r\n");
        AppendBuffer(body, buf);
        body.Write("\r\n");
        return true;
    }

    void AppendMultipartEnd(MemoryBuffer &inout body, const string &in boundary) {
        body.Write("--" + boundary + "--\r\n");
    }

    string MemoryBufferToString(MemoryBuffer@ buf) {
        if (buf is null) return "";
        buf.Seek(0);
        return buf.ReadString(buf.GetSize());
    }

    string SanitizeMultipartValue(const string &in value) {
        return value.Replace("\"", "_").Replace("\r", " ").Replace("\n", " ");
    }

    void AppendBuffer(MemoryBuffer@ dest, MemoryBuffer@ src) {
        if (dest is null || src is null) return;
        src.Seek(0);
        uint64 size = src.GetSize();
        for (uint64 i = 0; i < size; i++) {
            dest.Write(src.ReadUInt8());
        }
    }

    void AppendRawStringToBuffer(MemoryBuffer@ dest, const string &in src) {
        if (dest is null || src.Length == 0) return;
        uint srcLen = uint(src.Length);
        for (uint i = 0; i < srcLen; i++) {
            dest.Write(uint8(src[i]));
        }
    }

    bool TryParseHttpUrl(const string &in url, string &out scheme, string &out host, uint16 &out port, string &out path, string &out err) {
        err = "";
        scheme = "";
        host = "";
        port = 0;
        path = "/";

        int schemeEnd = url.IndexOf("://");
        if (schemeEnd <= 0) {
            err = "Clip-To-Ghost URL is missing a scheme.";
            return false;
        }

        scheme = url.SubStr(0, schemeEnd).ToLower();
        string remainder = url.SubStr(schemeEnd + 3);
        int slash = remainder.IndexOf("/");
        string hostPort = slash >= 0 ? remainder.SubStr(0, slash) : remainder;
        path = slash >= 0 ? remainder.SubStr(slash) : "/";
        if (hostPort.Length == 0) {
            err = "Clip-To-Ghost URL is missing a host.";
            return false;
        }

        int colon = hostPort.LastIndexOf(":");
        if (colon > 0) {
            host = hostPort.SubStr(0, colon);
            try { port = Text::ParseUInt(hostPort.SubStr(colon + 1)); } catch { port = 0; }
        } else {
            host = hostPort;
            port = scheme == "https" ? 443 : 80;
        }

        if (host.Length == 0 || port == 0) {
            err = "Clip-To-Ghost URL host/port could not be parsed.";
            return false;
        }

        return true;
    }

    bool WaitForSocketConnected(Net::Socket@ sock, uint timeoutMs, string &out err) {
        uint start = Time::Now;
        while (Time::Now - start < timeoutMs) {
            if (sock.IsReady()) return true;
            if (sock.CanWrite()) return true;
            yield();
        }
        err = "Timed out while connecting socket.";
        return false;
    }

    bool WriteAll(Net::Socket@ sock, const string &in headers, MemoryBuffer@ body, string &out err) {
        err = "";
        if (!sock.WriteRaw(headers)) {
            err = "Failed to write HTTP request headers.";
            return false;
        }
        return WriteBody(sock, body, err);
    }

    bool WriteAll(Net::Socket@ sock, const string &in headers, const string &in filePath, string &out err) {
        err = "";
        if (!sock.WriteRaw(headers)) {
            err = "Failed to write HTTP request headers.";
            return false;
        }
        return WriteFileBody(sock, filePath, err);
    }

    bool WriteBody(Net::Socket@ sock, MemoryBuffer@ body, string &out err) {
        err = "";
        uint64 total = body.GetSize();
        uint64 offset = 0;
        auto progress = TransferProgressState();
        while (offset < total) {
            UpdateTransferProgress("Uploading current map to Clip-To-Ghost...", "Clip-To-Ghost upload progress:", offset, int64(total), progress);
            if (!sock.IsReady()) { yield(); continue; }
            uint64 chunkSize = uint64(Math::Min(int(SOCKET_WRITE_CHUNK_BYTES), int(total - offset)));
            body.Seek(offset);
            auto part = body.ReadBuffer(chunkSize);
            if (part is null || part.GetSize() == 0) { err = "Failed to read multipart body chunk."; return false; }
            uint waitStart = Time::Now;
            while (true) {
                UpdateTransferProgress("Uploading current map to Clip-To-Ghost...", "Clip-To-Ghost upload progress:", offset, int64(total), progress);
                if (sock.IsHungUp()) { err = "Socket hung up while uploading the current map."; return false; }
                if (sock.IsReady()) {
                    part.Seek(0);
                    if (sock.Write(part, part.GetSize())) break;
                }
                if (Time::Now - waitStart >= SOCKET_WRITE_STALL_TIMEOUT_MS) {
                    err = "Timed out while uploading the current map chunk.";
                    return false;
                }
                yield();
            }
            offset += part.GetSize();
        }
        UpdateTransferProgress("Uploading current map to Clip-To-Ghost...", "Clip-To-Ghost upload progress:", total, int64(total), progress);
        return true;
    }

    bool WriteFileBody(Net::Socket@ sock, const string &in filePath, string &out err) {
        err = "";
        IO::File file(filePath, IO::FileMode::Read);
        uint64 total = file.Size();
        uint64 offset = 0;
        auto progress = TransferProgressState();
        while (offset < total) {
            UpdateTransferProgress("Uploading current map to Clip-To-Ghost...", "Clip-To-Ghost upload progress:", offset, int64(total), progress);
            uint64 chunkSize = uint64(Math::Min(int(SOCKET_WRITE_CHUNK_BYTES), int(total - offset)));
            auto part = file.Read(chunkSize);
            if (part is null || part.GetSize() == 0) { file.Close(); err = "Failed to read upload file chunk."; return false; }
            uint waitStart = Time::Now;
            while (true) {
                UpdateTransferProgress("Uploading current map to Clip-To-Ghost...", "Clip-To-Ghost upload progress:", offset, int64(total), progress);
                if (sock.IsHungUp()) { file.Close(); err = "Socket hung up while uploading the current map."; return false; }
                if (sock.IsReady()) {
                    part.Seek(0);
                    if (sock.Write(part, part.GetSize())) break;
                }
                if (Time::Now - waitStart >= SOCKET_WRITE_STALL_TIMEOUT_MS) {
                    file.Close();
                    err = "Timed out while uploading the current map chunk.";
                    return false;
                }
                yield();
            }
            offset += part.GetSize();
        }
        file.Close();
        UpdateTransferProgress("Uploading current map to Clip-To-Ghost...", "Clip-To-Ghost upload progress:", total, int64(total), progress);
        return true;
    }

    bool ReadHttpResponse(Net::Socket@ sock, HttpResponseData@ &out resp, string &out err) {
        @resp = HttpResponseData();
        return ReadHttpResponseImpl(sock, resp, err);
    }

    bool ReadHttpResponseImpl(Net::Socket@ sock, HttpResponseData@ resp, string &out err) {
        string line;
        if (!ReadLineWithTimeout(sock, line, 10000, err)) return false;
        resp.statusCode = ParseStatusCode(line, err);
        if (resp.statusCode <= 0) return false;
        if (!ReadHeaders(sock, resp.headersLower, err)) return false;
        return ReadResponseBody(sock, resp, err);
    }

    int ParseStatusCode(const string &in statusLine, string &out err) {
        auto parts = statusLine.Trim().Split(" ");
        if (parts.Length < 2) {
            err = "Invalid HTTP status line: " + statusLine;
            return -1;
        }
        try { return Text::ParseInt(parts[1]); } catch {}
        err = "Invalid HTTP status line: " + statusLine;
        return -1;
    }

    bool ReadHeaders(Net::Socket@ sock, dictionary@ headersLower, string &out err) {
        while (true) {
            string line;
            if (!ReadLineWithTimeout(sock, line, 10000, err)) return false;
            string trimmed = line.Trim();
            if (trimmed.Length == 0) return true;
            int colon = trimmed.IndexOf(":");
            if (colon <= 0) continue;
            headersLower[trimmed.SubStr(0, colon).ToLower()] = trimmed.SubStr(colon + 1).Trim();
        }
        return true;
    }

    bool ReadResponseBody(Net::Socket@ sock, HttpResponseData@ resp, string &out err) {
        string transfer = resp.Header("transfer-encoding").ToLower();
        if (transfer.Contains("chunked")) return ReadChunkedBody(sock, resp.body, err);

        string contentLength = resp.Header("content-length");
        if (contentLength.Length > 0) {
            int64 len = 0;
            try { len = Text::ParseInt(contentLength); } catch { len = -1; }
            if (len >= 0) return ReadExactBytes(sock, resp.body, len, err);
        }

        return ReadToClose(sock, resp.body, err);
    }

    bool ReadLineWithTimeout(Net::Socket@ sock, string &out line, uint timeoutMs, string &out err) {
        uint start = Time::Now;
        while (Time::Now - start < timeoutMs) {
            if (sock.Available() > 0 && sock.ReadLine(line)) return true;
            if (sock.IsHungUp() && sock.Available() == 0) break;
            yield();
        }
        err = "Timed out while reading HTTP response line.";
        return false;
    }

    bool ReadExactBytes(Net::Socket@ sock, MemoryBuffer@ outBuf, int64 bytesToRead, string &out err) {
        uint64 total = uint64(Math::Max(int64(0), bytesToRead));
        auto progress = TransferProgressState();
        while (bytesToRead > 0) {
            uint64 done = total - uint64(Math::Max(int64(0), bytesToRead));
            UpdateTransferProgress("Downloading Clip-To-Ghost response...", "Clip-To-Ghost download progress:", done, int64(total), progress);
            int avail = sock.Available();
            if (avail <= 0) {
                if (sock.IsHungUp()) break;
                yield();
                continue;
            }
            int chunk = Math::Min(avail, int(bytesToRead));
            auto part = sock.ReadBuffer(chunk);
            AppendBuffer(outBuf, part);
            bytesToRead -= chunk;
        }
        UpdateTransferProgress("Downloading Clip-To-Ghost response...", "Clip-To-Ghost download progress:", total, int64(total), progress);
        if (bytesToRead == 0) return true;
        err = "Socket closed before the response body finished.";
        return false;
    }

    bool ReadChunkedBody(Net::Socket@ sock, MemoryBuffer@ outBuf, string &out err) {
        while (true) {
            string line;
            if (!ReadLineWithTimeout(sock, line, 10000, err)) return false;
            string chunkLine = line.Trim();
            int semi = chunkLine.IndexOf(";");
            if (semi >= 0) chunkLine = chunkLine.SubStr(0, semi);
            int64 chunkSize = 0;
            try { chunkSize = Text::ParseInt64(chunkLine, 16); } catch { chunkSize = -1; }
            if (chunkSize < 0) { err = "Invalid chunked response size."; return false; }
            if (chunkSize == 0) {
                string endLine;
                ReadLineWithTimeout(sock, endLine, 2000, err);
                return true;
            }
            if (!ReadExactBytes(sock, outBuf, chunkSize, err)) return false;
            string crlf;
            if (!ReadLineWithTimeout(sock, crlf, 2000, err)) return false;
        }
        return true;
    }

    bool ReadToClose(Net::Socket@ sock, MemoryBuffer@ outBuf, string &out err) {
        uint idleStart = Time::Now;
        auto progress = TransferProgressState();
        while (Time::Now - idleStart < 2000) {
            UpdateTransferProgress("Downloading Clip-To-Ghost response...", "Clip-To-Ghost download progress:", outBuf.GetSize(), -1, progress);
            int avail = sock.Available();
            if (avail > 0) {
                auto part = sock.ReadBuffer(avail);
                AppendBuffer(outBuf, part);
                idleStart = Time::Now;
                continue;
            }
            if (sock.IsHungUp()) return true;
            yield();
        }
        UpdateTransferProgress("Downloading Clip-To-Ghost response...", "Clip-To-Ghost download progress:", outBuf.GetSize(), -1, progress);
        return true;
    }

    string BuildUserAgent() {
        auto plugin = Meta::ExecutingPlugin();
        return "TM_Plugin:" + plugin.Name + " / component=CurrentMapGPS / version=" + plugin.Version;
    }

    string FormatBytesShort(uint64 bytes) {
        const uint64 KB = 1024;
        const uint64 MB = 1024 * 1024;
        const uint64 GB = 1024 * 1024 * 1024;

        if (bytes >= GB) return (bytes / GB) + " GB";
        if (bytes >= MB) return (bytes / MB) + " MB";
        if (bytes >= KB) return (bytes / KB) + " KB";
        return bytes + " B";
    }

    string FormatTransferProgress(uint64 done, int64 total = -1) {
        if (total > 0) {
            uint64 safeTotal = uint64(total);
            uint pct = safeTotal == 0 ? 0 : uint(Math::Min(100, int((done * 100) / safeTotal)));
            return FormatBytesShort(done) + " / " + FormatBytesShort(safeTotal) + " (" + pct + "%)";
        }
        return FormatBytesShort(done) + " received";
    }

    void UpdateTransferProgress(const string &in statusPrefix, const string &in logPrefix, uint64 done, int64 total, TransferProgressState@ state) {
        if (state is null) return;
        uint now = Time::Now;
        bool finished = total > 0 && done >= uint64(total);
        string progress = FormatTransferProgress(done, total);

        if (state.lastStatusTick == 0 || finished || now - state.lastStatusTick >= 500) {
            SetStatus(Icons::Refresh + " " + statusPrefix + " " + progress);
            state.lastStatusTick = now;
        }

        if (state.lastLogTick == 0 || finished || now - state.lastLogTick >= 2000) {
            log(logPrefix + " " + progress, LogLevel::Info, -1, "CurrentMap::GPS");
            state.lastLogTick = now;
        }
    }

    string BuildHttpError(const string &in prefix, HttpResponseData@ req) {
        if (req is null) return prefix + ".";

        return BuildHttpErrorFromBody(prefix, req.statusCode, req.String());
    }

    string BuildHttpError(const string &in prefix, Net::HttpRequest@ req) {
        if (req is null) return prefix + ".";
        return BuildHttpErrorFromBody(prefix, req.ResponseCode(), req.String());
    }

    string BuildHttpErrorFromBody(const string &in prefix, int statusCode, const string &in bodyText) {
        Json::Value bodyJson = Json::Parse(bodyText);
        if (bodyJson.GetType() == Json::Type::Object && bodyJson.HasKey("error")) {
            return prefix + ": " + string(bodyJson["error"]);
        }

        string compactBody = bodyText.Replace("\r", " ").Replace("\n", " ").Trim();
        if (compactBody.Length > 180) compactBody = compactBody.SubStr(0, 180) + "...";

        string compactBodyLower = compactBody.ToLower();
        if (statusCode == 413 || compactBodyLower.Contains("request entity too large")) {
            return prefix + ": request entity too large. The Clip-To-Ghost backend rejected the uploaded map file.";
        }

        if (compactBody.Length > 0) {
            return prefix + " (HTTP " + statusCode + "): " + compactBody;
        }

        return prefix + " (HTTP " + statusCode + ").";
    }

    void SetStatus(const string &in status) {
        g_LastGpsStatus = status;
        g_LastGpsStatusTime = Time::Now;
    }

    string GetJsonString(const Json::Value &in value, const string &in key, const string &in fallback = "") {
        if (value.GetType() != Json::Type::Object || !value.HasKey(key)) return fallback;
        if (value[key].GetType() == Json::Type::Null) return fallback;
        return string(value[key]);
    }

    int GetJsonInt(const Json::Value &in value, const string &in key, int fallback = 0) {
        if (value.GetType() != Json::Type::Object || !value.HasKey(key)) return fallback;
        if (value[key].GetType() == Json::Type::Null) return fallback;
        return int(value[key]);
    }

    uint GetJsonUInt(const Json::Value &in value, const string &in key, uint fallback = 0) {
        int parsed = GetJsonInt(value, key, int(fallback));
        return parsed < 0 ? fallback : uint(parsed);
    }
}
}
}
