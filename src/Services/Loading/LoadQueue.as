namespace Services {
namespace LoadQueue {
    [Setting name="Force refresh record downloads"]
    bool S_ForceRefresh = false;

    const uint REPLAY_URL_BACKEND_WAIT_MS = 3000;

    enum JobState {
        Queued = 0,
        Running,
        Succeeded,
        Failed,
        Cancelled
    }

    class RecordLoadJob {
        int id = -1;
        Domain::LoadRequest@ req = null;
        JobState state = JobState::Queued;
        string error = "";
        string userError = "";

        string resolvedAccountId = "";
        string replayUrl = "";
        string cachePath = "";

        bool cancelled = false;
        uint enqueuedAt = 0;
        uint startedAt = 0;
        uint finishedAt = 0;
    }

    class RecordLoadStatus {
        JobState state = JobState::Queued;
        string error = "";
        string resolvedAccountId = "";
        string replayUrl = "";
        string cachePath = "";
    }

    class MapInfoCandidate {
        string routeLabel = "";
        string mapId = "";
        string mapType = "";
        bool hasClones = false;
    }

    int g_NextJobId = 1;
    RecordLoadJob@ g_ActiveJob = null;
    array<RecordLoadJob@> g_Queue;
    dictionary g_JobsById;
    bool g_WorkerRunning = false;

    int Enqueue(Domain::LoadRequest@ req) {
        if (req is null) return -1;


        RecordLoadJob@ job = RecordLoadJob();
        job.id = g_NextJobId++;
        @job.req = req;
        job.enqueuedAt = Time::Now;

        g_Queue.InsertLast(job);
        g_JobsById.Set(tostring(job.id), @job);
        log("Queued load job #" + job.id + " kind=" + tostring(req.selectorKind) + ", ctx=" + Domain::LoadContextToString(req.context) + ", mapUid=" + req.mapUid + ", rankOffset=" + req.rankOffset, LogLevel::Info, 69, "LoadQueue");

        if (!g_WorkerRunning) {
            g_WorkerRunning = true;
            startnew(CoroutineFunc(WorkerLoop));
        }

        return job.id;
    }

    void Cancel(int jobId) {
        RecordLoadJob@ job = GetJob(jobId);
        if (job is null) return;
        job.cancelled = true;
    }

    RecordLoadStatus@ GetStatus(int jobId) {
        RecordLoadJob@ job = GetJob(jobId);
        if (job is null) return null;

        RecordLoadStatus@ st = RecordLoadStatus();
        st.state = job.state;
        st.error = job.error;
        st.resolvedAccountId = job.resolvedAccountId;
        st.replayUrl = job.replayUrl;
        st.cachePath = job.cachePath;
        return st;
    }

    RecordLoadJob@ GetJob(int jobId) {
        if (jobId < 0) return null;
        if (!g_JobsById.Exists(tostring(jobId))) return null;
        ref@ r;
        g_JobsById.Get(tostring(jobId), @r);
        return cast<RecordLoadJob@>(r);
    }

    bool IsScoreMgrReady() {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) return false;
        if (ps.ScoreMgr is null) return false;
        if (ps.UserMgr is null) return false;
        if (ps.UserMgr.Users.Length == 0) return false;
        return true;
    }

    bool WaitForScoreMgrReady(uint timeout = REPLAY_URL_BACKEND_WAIT_MS) {
        uint startTime = Time::Now;
        while (Time::Now - startTime <= timeout) {
            if (IsScoreMgrReady()) return true;
            yield();
        }
        return IsScoreMgrReady();
    }

    bool CanTryPlaygroundReplayLookup() {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) return false;
        if (ps.UserMgr is null) return false;
        if (ps.UserMgr.Users.Length == 0) return false;
        return true;
    }

    bool IsJobCancellationRequested(RecordLoadJob@ job) {
        return job !is null && job.cancelled;
    }

    void AddUniqueString(array<string> &inout arr, const string &in value) {
        if (arr.Find(value) < 0) arr.InsertLast(value);
    }

    string JoinStrings(const array<string> &in arr, const string &in sep = ", ") {
        string result = "";
        for (uint i = 0; i < arr.Length; i++) {
            if (i > 0) result += sep;
            result += arr[i];
        }
        return result;
    }

    string FormatGameModeLabel(const string &in gameMode) {
        return gameMode.Length > 0 ? gameMode : "<default>";
    }

    string CompactForLog(const string &in value, uint maxLen = 320) {
        string compact = value.Replace("\r", "\\r").Replace("\n", "\\n");
        if (uint(compact.Length) <= maxLen) return compact;
        return compact.SubStr(0, maxLen) + "...";
    }

    array<string> BuildReplayLookupGameModes(const string &in mapType = "", bool hasClones = false) {
        array<string> modes;
        string preferred = InferReplayLookupGameMode(mapType, hasClones);
        AddUniqueString(modes, preferred);
        return modes;
    }

    void AddMapInfoCandidate(array<MapInfoCandidate@> &inout candidates, const string &in routeLabel, const Json::Value &in mapInfo) {
        if (mapInfo.GetType() != Json::Type::Object) return;

        string mapId = string(mapInfo["mapId"]).Trim();
        if (mapId.Length == 0) return;

        for (uint i = 0; i < candidates.Length; i++) {
            if (candidates[i] !is null && candidates[i].mapId == mapId) return;
        }

        MapInfoCandidate@ candidate = MapInfoCandidate();
        candidate.routeLabel = routeLabel;
        candidate.mapId = mapId;
        candidate.mapType = string(mapInfo["mapType"]);
        candidate.hasClones = bool(mapInfo["hasClones"]);
        candidates.InsertLast(candidate);
    }

    array<MapInfoCandidate@> ResolveMapInfoCandidates(const string &in mapUid) {
        array<MapInfoCandidate@> candidates;
        AddMapInfoCandidate(candidates, "core", ResolveMapInfoFromUrl(mapUid, "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + mapUid, "core"));
        return candidates;
    }

    array<string> CollectMapIds(const string &in providedMapId, const array<MapInfoCandidate@> &in candidates) {
        array<string> mapIds;
        string trimmedProvided = providedMapId.Trim();
        if (trimmedProvided.Length > 0) AddUniqueString(mapIds, trimmedProvided);

        for (uint i = 0; i < candidates.Length; i++) {
            if (candidates[i] is null) continue;
            AddUniqueString(mapIds, candidates[i].mapId);
        }
        return mapIds;
    }

    string PreferredMapType(const array<MapInfoCandidate@> &in candidates) {
        for (uint i = 0; i < candidates.Length; i++) {
            if (candidates[i] is null) continue;
            if (candidates[i].mapType.Length > 0) return candidates[i].mapType;
        }
        return "";
    }

    bool PreferredHasClones(const array<MapInfoCandidate@> &in candidates) {
        for (uint i = 0; i < candidates.Length; i++) {
            if (candidates[i] is null) continue;
            if (candidates[i].hasClones) return true;
        }
        return false;
    }

    void LogMapInfoCandidates(const string &in mapUid, const string &in providedMapId, const array<MapInfoCandidate@> &in candidates) {
        array<string> parts;
        if (providedMapId.Trim().Length > 0) {
            parts.InsertLast("provided=" + providedMapId.Trim());
        }
        for (uint i = 0; i < candidates.Length; i++) {
            if (candidates[i] is null) continue;
            string part = candidates[i].routeLabel + "=" + candidates[i].mapId;
            if (candidates[i].mapType.Length > 0) part += " (" + candidates[i].mapType + ")";
            if (candidates[i].hasClones) part += " [hasClones]";
            parts.InsertLast(part);
        }
        if (parts.Length == 0) {
            log("No mapId candidates resolved for mapUid=" + mapUid, LogLevel::Warning, 169, "RecordLoadService");
            return;
        }
        log("Resolved mapId candidates for mapUid=" + mapUid + ": " + JoinStrings(parts), LogLevel::Info, 172, "RecordLoadService");
    }

    string DefaultSourceRef(Domain::LoadRequest@ req, const string &in accountId = "") {
        if (req is null) return "";
        string source = Domain::LoadContextToString(req.context);
        string ref = source + " | " + req.mapUid + " | #" + tostring(req.rankOffset + 1);
        if (req.context == Domain::LoadContext::PlayerId && accountId.Length > 0) {
            ref += " | " + accountId;
        }
        return ref;
    }

    void WorkerLoop() {
        while (g_Queue.Length > 0) {
            RecordLoadJob@ job = g_Queue[0];
            g_Queue.RemoveAt(0);
            @g_ActiveJob = job;
            log("Starting record load job #" + job.id, LogLevel::Info, 131, "RecordLoadService");


            job.startedAt = Time::Now;
            job.error = "";
            job.userError = "";
            job.resolvedAccountId = "";
            job.replayUrl = "";
            job.cachePath = "";

            if (job.cancelled) {
                job.state = JobState::Cancelled;
                job.finishedAt = Time::Now;
                @g_ActiveJob = null;
                yield();
                continue;
            }

            job.state = JobState::Running;

            ProcessJob(job);

            if (job.cancelled) job.state = JobState::Cancelled;
            else if (job.error.Length > 0) job.state = JobState::Failed;
            else job.state = JobState::Succeeded;

            if (job.state == JobState::Failed) {
                log("Record load job failed #" + job.id + ": " + job.error, LogLevel::Error, 142, "RecordLoadService");
                string notifyMsg = job.userError.Length > 0 ? job.userError : job.error;
                NotifyWarning("Record load failed: " + notifyMsg);
            } else if (job.state == JobState::Cancelled) {
                log("Record load job cancelled #" + job.id, LogLevel::Warning, 145, "RecordLoadService");
            }

            job.finishedAt = Time::Now;
            @g_ActiveJob = null;
            yield();
        }

        g_WorkerRunning = false;
    }

    void ProcessJob(RecordLoadJob@ job) {
        if (job is null) return;
        Domain::LoadRequest@ req = job.req;
        if (req is null) { job.error = "Internal error: request is null"; return; }

        AllowCheck::InitializeAllowCheckWithTimeout(500);
        if (!AllowCheck::ConditionCheckMet()) {
            string reason = AllowCheck::DisallowReason();
            job.error = "Blocked by allow-check: " + reason;
            job.userError = reason;
            return;
        }

        if (req.selectorKind == Domain::SelectorKind::LocalFile) {
            string path = req.filePath.Trim();
            if (path.Length == 0) { job.error = "File path is empty"; return; }
            if (!IO::FileExists(path)) { job.error = "File does not exist: " + path; return; }

            string fileName = Path::GetFileName(path);
            LoadedRecords::SourceKind srcKind = (req.sourceKind != LoadedRecords::SourceKind::Unknown) ? req.sourceKind : DefaultSourceKind(req);
            string srcRef = req.sourceRef.Length > 0 ? req.sourceRef : path;
            LoadedRecords::TrackPendingFile(fileName, srcKind, srcRef, req.mapUid.Trim(), req.accountId.Trim(), req.useGhostLayer);

            job.cachePath = path;
            Integrations::GameLoader::LoadLocalFile(path);
            return;
        }

        if (req.selectorKind == Domain::SelectorKind::Url) {
            string url = req.url.Trim();
            if (url.Length == 0) { job.error = "URL is empty"; return; }

            string dlErr = "";
            string dlPath = DownloadUrlToLinksFolder(url, dlErr);
            if (dlPath.Length == 0) {
                job.error = dlErr.Length > 0 ? dlErr : "Failed to download URL";
                return;
            }

            string fileName = Path::GetFileName(dlPath);
            LoadedRecords::SourceKind srcKind = (req.sourceKind != LoadedRecords::SourceKind::Unknown) ? req.sourceKind : LoadedRecords::SourceKind::Url;
            string srcRef = req.sourceRef.Length > 0 ? req.sourceRef : url;
            LoadedRecords::TrackPendingFile(fileName, srcKind, srcRef, req.mapUid.Trim(), req.accountId.Trim(), req.useGhostLayer);

            job.replayUrl = url;
            job.cachePath = dlPath;
            Integrations::GameLoader::LoadLocalFile(dlPath);
            return;
        }

        string mapUid = req.mapUid.Trim();
        if (mapUid.Length == 0) { job.error = "Map UID is empty"; return; }
        if (req.rankOffset < 0) { job.error = "Rank offset must be >= 0"; return; }

        array<MapInfoCandidate@> mapInfoCandidates = ResolveMapInfoCandidates(mapUid);
        string preferredMapType = PreferredMapType(mapInfoCandidates);
        bool preferredHasClones = PreferredHasClones(mapInfoCandidates);
        LogMapInfoCandidates(mapUid, req.mapId, mapInfoCandidates);


        string accountId = req.accountId.Trim();
        if (accountId.Length == 0) {
            log("Resolving accountId for job #" + job.id + " via leaderboard", LogLevel::Info, 189, "LoadQueue");
            accountId = ResolveAccountIdFromLeaderboard(mapUid, req.rankOffset);
            if (accountId.Length == 0) { job.error = "Could not resolve accountId from leaderboard"; return; }
        }

        job.resolvedAccountId = accountId;
        if (IsJobCancellationRequested(job)) return;

        string replayUrl = "";
        string wsid = ResolveWebServicesUserId(accountId);
        bool gameBackendUnavailable = false;
        if (wsid.Length > 0) {
            if (!IsScoreMgrReady()) {
                gameBackendUnavailable = true;
                log("ScoreMgr backend not ready for job #" + job.id + "; waiting up to " + REPLAY_URL_BACKEND_WAIT_MS + " ms before HTTP fallback", LogLevel::Warning, 208, "LoadQueue");
                bool becameReady = WaitForScoreMgrReady(REPLAY_URL_BACKEND_WAIT_MS);
                if (becameReady) {
                    gameBackendUnavailable = false;
                    log("ScoreMgr backend became ready for job #" + job.id + "; retrying in-game replay-url resolution", LogLevel::Info, 209, "LoadQueue");
                }
            }

            replayUrl = ResolveReplayUrlViaGameBackends(job.id, wsid, mapUid, preferredMapType, preferredHasClones);
        }
        if (replayUrl.Length == 0) {
            log("Falling back to HTTP replay-url resolution for job #" + job.id, LogLevel::Warning, 210, "LoadQueue");
            replayUrl = ResolveReplayUrlFallback(mapUid, accountId, req.mapId, req.seasonId, mapInfoCandidates);
        }
        if (replayUrl.Length == 0) {
            array<string> mapIds = CollectMapIds(req.mapId, mapInfoCandidates);
            job.error = "Could not resolve replay URL for mapUid=" + mapUid
                + ", accountId=" + accountId
                + ", wsid=" + (wsid.Length > 0 ? wsid : "<empty>")
                + ", mapIds=" + (mapIds.Length > 0 ? JoinStrings(mapIds) : "<none>");
            job.userError = "Leaderboard entry exists, but Nadeo mapRecords/by-account returned [] for this map/account, so no downloadable ghost URL was available.";
            if (gameBackendUnavailable) {
                job.userError += " The in-game replay backend was not ready either, so try again once the map is fully loaded.";
            }
            return;
        }
        job.replayUrl = replayUrl;
        if (IsJobCancellationRequested(job)) return;

        string cachePath = CachePathFor(req, accountId);
        if (cachePath.Length == 0) { job.error = "Could not determine cache path"; return; }
        job.cachePath = cachePath;

        bool doRefresh = req.forceRefresh || S_ForceRefresh;
        bool cacheOk = IO::FileExists(cachePath) && IO::FileSize(cachePath) > 0;
        if (!cacheOk || doRefresh) {
            log("Downloading record file for job #" + job.id + " to cache: " + cachePath, LogLevel::Info, 222, "LoadQueue");
            if (doRefresh && IO::FileExists(cachePath)) {
                try { IO::Delete(cachePath); } catch {}
            }
            string dlErr = "";
            if (!DownloadToFile(replayUrl, cachePath, dlErr)) {
                job.error = dlErr.Length > 0 ? dlErr : "Failed to download record file";
                return;
            }
        } else {
            log("Using cached record file for job #" + job.id + ": " + cachePath, LogLevel::Info, 231, "LoadQueue");
        }

        if (IsJobCancellationRequested(job)) return;

        string fileName = Path::GetFileName(cachePath);
        LoadedRecords::SourceKind srcKind = (req.sourceKind != LoadedRecords::SourceKind::Unknown) ? req.sourceKind : DefaultSourceKind(req);
        string sourceRef = req.sourceRef.Length > 0 ? req.sourceRef : DefaultSourceRef(req, accountId);
        LoadedRecords::TrackPendingFile(
            fileName,
            srcKind,
            sourceRef,
            mapUid,
            accountId,
            req.useGhostLayer
        );
        log("Dispatching cached file to local loader for job #" + job.id + ": " + cachePath, LogLevel::Info, 245, "LoadQueue");
        Integrations::GameLoader::LoadLocalFile(cachePath);
    }

    string CachePathFor(Domain::LoadRequest@ req, const string &in accountId) {
        if (req is null) return "";
        if (accountId.Length == 0) return "";

        string baseDir = Server::serverDirectoryAutoMove;
        string prefix = "AnyMap";
        string ext = ".Ghost.Gbx";

        switch (req.context) {
            case Domain::LoadContext::Official:
                baseDir = Server::officialFilesDirectory;
                prefix = "Official";
                ext = ".Ghost.Gbx";
                break;
            case Domain::LoadContext::Profile:
                baseDir = Server::specificDownloadedFilesDirectory;
                prefix = "OtherMaps";
                ext = ".Ghost.Gbx";
                break;
            case Domain::LoadContext::Medal:
                baseDir = Server::serverDirectoryMedal;
                prefix = "Medal";
                ext = ".Ghost.Gbx";
                break;
            case Domain::LoadContext::PlayerId:
                baseDir = Server::serverDirectoryAutoMove;
                prefix = "PlayerId";
                ext = ".Ghost.Gbx";
                break;
            case Domain::LoadContext::AnyMap:
            default:
                baseDir = Server::serverDirectoryAutoMove;
                prefix = "AnyMap";
                ext = ".Ghost.Gbx";
                break;
        }

        string mapUid = req.mapUid.Trim();
        if (mapUid.Length == 0) return "";

        int off = req.rankOffset;
        if (off < 0) off = 0;

        string fileName = prefix + "_" + mapUid + "_rank" + tostring(off) + "_" + accountId + ext;
        return baseDir + fileName;
    }

    LoadedRecords::SourceKind DefaultSourceKind(const Domain::LoadRequest@ req) {
        if (req is null) return LoadedRecords::SourceKind::MapRecord;
        switch (req.context) {
            case Domain::LoadContext::Official: return LoadedRecords::SourceKind::Official;
            case Domain::LoadContext::Profile: return LoadedRecords::SourceKind::Profile;
            case Domain::LoadContext::PlayerId: return LoadedRecords::SourceKind::PlayerId;
            case Domain::LoadContext::Url: return LoadedRecords::SourceKind::Url;
            case Domain::LoadContext::LocalFile: return LoadedRecords::SourceKind::LocalFile;
            case Domain::LoadContext::Saved: return LoadedRecords::SourceKind::LocalFile;
            case Domain::LoadContext::Medal: return LoadedRecords::SourceKind::MapRecord;
            case Domain::LoadContext::AnyMap:
            default:
                return LoadedRecords::SourceKind::MapRecord;
        }
    }

    string ResolveAccountIdFromLeaderboard(const string &in mapUid, int rankOffset) {
        if (rankOffset < 0) rankOffset = 0;
        Json::Value data = api.GetMapRecords("Personal_Best", mapUid, true, 1, uint(rankOffset));
        if (data.GetType() == Json::Type::Null) return "";

        auto tops = data["tops"];
        if (tops.GetType() != Json::Type::Array || tops.Length == 0) return "";
        auto top = tops[0]["top"];
        if (top.GetType() != Json::Type::Array || top.Length == 0) return "";
        return string(top[0]["accountId"]);
    }

    string ResolveWebServicesUserId(const string &in accountId) {
        if (accountId.Length == 0) return "";
        try {
            return NadeoServices::AccountIdToLogin(accountId);
        } catch {
            log("Failed to resolve web services user id from accountId=" + accountId, LogLevel::Warning, 327, "RecordLoadService");
        }
        return "";
    }

    string ResolveReplayUrlViaGameBackends(int jobId, const string &in wsid, const string &in mapUid, const string &in mapType = "", bool hasClones = false) {
        array<string> gameModes = BuildReplayLookupGameModes(mapType, hasClones);

        if (IsScoreMgrReady()) {
            for (uint i = 0; i < gameModes.Length; i++) {
                string gameMode = gameModes[i];
                log("Trying ScoreMgr replay-url resolution for job #" + jobId + " using wsid=" + wsid + ", gameMode=" + FormatGameModeLabel(gameMode), LogLevel::Info, 341, "RecordLoadService");
                string replayUrl = ResolveReplayUrlFromScoreMgr(wsid, mapUid, gameMode);
                if (replayUrl.Length > 0) return replayUrl;
            }
        }

        if (!CanTryPlaygroundReplayLookup()) {
            ResolveReplayUrlFromPlayground(wsid, mapUid, gameModes[0]);
            return "";
        }

        for (uint i = 0; i < gameModes.Length; i++) {
            string gameMode = gameModes[i];
            log("Trying playground replay-url resolution for job #" + jobId + " using wsid=" + wsid + ", gameMode=" + FormatGameModeLabel(gameMode), LogLevel::Info, 349, "RecordLoadService");
            string replayUrl = ResolveReplayUrlFromPlayground(wsid, mapUid, gameMode);
            if (replayUrl.Length > 0) return replayUrl;
        }

        return "";
    }

    string ResolveReplayUrlFromScoreMgr(const string &in wsid, const string &in mapUid, const string &in gameMode = "TimeAttack") {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null || ps.ScoreMgr is null || ps.UserMgr is null) return "";
        if (ps.UserMgr.Users.Length == 0) return "";

        MwFastBuffer<wstring> wsids;
        wsids.Add(wsid);
        RequestThrottle::WaitForSlot("ScoreMgr replay lookup");
        auto resp = ps.ScoreMgr.Map_GetPlayerListRecordList(ps.UserMgr.Users[0].Id, wsids, mapUid, "PersonalBest", "", gameMode, "");
        if (resp is null) return "";

        while (resp.IsProcessing) { yield(); }

        string replayUrl = "";
        if (!resp.HasFailed && resp.HasSucceeded && resp.MapRecordList.Length > 0) {
            replayUrl = resp.MapRecordList[0].ReplayUrl;
        }
        else {
            log("ScoreMgr replay-url lookup returned no records for mapUid=" + mapUid + ", wsid=" + wsid + ", gameMode=" + FormatGameModeLabel(gameMode), LogLevel::Warning, 328, "RecordLoadService");
        }

        try { ps.ScoreMgr.TaskResult_Release(resp.Id); } catch {}
        return replayUrl;
    }

    string ResolveReplayUrlFromPlayground(const string &in wsid, const string &in mapUid, const string &in gameMode = "TimeAttack") {
        auto ps = cast<CSmArenaRulesMode>(GetApp().PlaygroundScript);
        if (ps is null) {
            log("Playground replay-url lookup unavailable: playground script is null for mapUid=" + mapUid, LogLevel::Warning, 362, "RecordLoadService");
            return "";
        }
        if (ps.UserMgr is null) {
            log("Playground replay-url lookup unavailable: UserMgr is null for mapUid=" + mapUid, LogLevel::Warning, 365, "RecordLoadService");
            return "";
        }
        if (ps.UserMgr.Users.Length == 0) {
            log("Playground replay-url lookup unavailable: no local users for mapUid=" + mapUid, LogLevel::Warning, 368, "RecordLoadService");
            return "";
        }

        MwFastBuffer<wstring> wsids;
        wsids.Add(wsid);
        RequestThrottle::WaitForSlot("Playground replay lookup");
        auto resp = ps.MapRecord_GetListByMapAndPlayerList(ps.UserMgr.Users[0].Id, wsids, mapUid, "PersonalBest", "", gameMode, "");
        if (resp is null) {
            log("Playground replay-url lookup returned null task for mapUid=" + mapUid + ", wsid=" + wsid + ", gameMode=" + FormatGameModeLabel(gameMode), LogLevel::Warning, 374, "RecordLoadService");
            return "";
        }

        while (resp.IsProcessing) { yield(); }

        string replayUrl = "";
        if (!resp.HasFailed && resp.HasSucceeded && resp.MapRecordList.Length > 0) {
            replayUrl = resp.MapRecordList[0].ReplayUrl;
        } else {
            log("Playground replay-url lookup returned no records for mapUid=" + mapUid + ", wsid=" + wsid + ", gameMode=" + FormatGameModeLabel(gameMode) + ", failed=" + tostring(resp.HasFailed) + ", succeeded=" + tostring(resp.HasSucceeded), LogLevel::Warning, 380, "RecordLoadService");
        }

        try { ps.TaskResult_Release(resp.Id); } catch {}
        return replayUrl;
    }

    string ResolveReplayUrlFallback(const string &in mapUid, const string &in accountId, const string &in providedMapId, const string &in seasonId, const array<MapInfoCandidate@> &in resolvedCandidates) {
        array<MapInfoCandidate@> mapInfoCandidates = resolvedCandidates;
        if (mapInfoCandidates.Length == 0) {
            mapInfoCandidates = ResolveMapInfoCandidates(mapUid);
        }

        array<string> mapIds = CollectMapIds(providedMapId, mapInfoCandidates);
        if (mapIds.Length == 0) {
            log("HTTP replay-url fallback could not resolve mapId for mapUid=" + mapUid, LogLevel::Warning, 356, "RecordLoadService");
            return "";
        }

        array<string> gameModes = BuildReplayLookupGameModes(PreferredMapType(mapInfoCandidates), PreferredHasClones(mapInfoCandidates));
        for (uint mapIdx = 0; mapIdx < mapIds.Length; mapIdx++) {
            string mapId = mapIds[mapIdx];
            for (uint modeIdx = 0; modeIdx < gameModes.Length; modeIdx++) {
                string replayUrl = TryResolveReplayUrlVariants(mapUid, accountId, mapId, seasonId, gameModes[modeIdx]);
                if (replayUrl.Length > 0) return replayUrl;
            }
        }

        return "";
    }

    Json::Value ResolveMapInfo(const string &in mapUid) {
        return ResolveMapInfoFromUrl(mapUid, "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + mapUid, "core");
    }

    Json::Value ResolveMapInfoFromUrl(const string &in mapUid, const string &in url, const string &in routeLabel = "") {
        RequestThrottle::WaitForSlot("ResolveMapInfo");
        auto req = NadeoServices::Get("NadeoServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }
        if (req.ResponseCode() != 200) {
            string routeSuffix = routeLabel.Length > 0 ? " (" + routeLabel + ")" : "";
            log("ResolveMapInfo" + routeSuffix + " failed for mapUid=" + mapUid + ", code=" + req.ResponseCode(), LogLevel::Warning, 424, "RecordLoadService");
            return Json::Object();
        }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() != Json::Type::Array || data.Length == 0) {
            string routeSuffix = routeLabel.Length > 0 ? " (" + routeLabel + ")" : "";
            log("ResolveMapInfo" + routeSuffix + " returned no map data for mapUid=" + mapUid, LogLevel::Warning, 429, "RecordLoadService");
            return Json::Object();
        }
        return data[0];
    }

    string ResolveMapId(const string &in mapUid) {
        Json::Value mapInfo = ResolveMapInfo(mapUid);
        if (mapInfo.GetType() != Json::Type::Object) return "";
        return string(mapInfo["mapId"]);
    }

    string InferCoreRecordGameMode(const string &in mapType) {
        if (mapType == "TrackMania\\TM_Stunt" || mapType == "Trackmania\\TM_Stunt") return "Stunt";
        if (mapType == "TrackMania\\TM_Platform" || mapType == "Trackmania\\TM_Platform") return "Platform";
        return "";
    }

    string InferReplayLookupGameMode(const string &in mapType, bool hasClones = false) {
        string inferred = InferCoreRecordGameMode(mapType);
        if (inferred.Length > 0) return inferred;
        if (mapType == "TrackMania\\TM_Race" || mapType == "Trackmania\\TM_Race" || mapType.Length == 0) {
            return hasClones ? "TimeAttackClone" : "TimeAttack";
        }
        return "";
    }

    string TryResolveReplayUrlVariants(const string &in mapUid, const string &in accountId, const string &in mapId, const string &in seasonId = "", const string &in gameMode = "") {
        string gameModeParam = gameMode.Length > 0 ? "&gameMode=" + gameMode : "";
        string routeSuffix = gameMode.Length > 0 ? " [" + gameMode + "]" : "";
        string seasonParam = seasonId.Trim().Length > 0 ? "&seasonId=" + seasonId.Trim() : "";

        return TryResolveReplayUrlFromCoreEndpoint(
            "by-account v2" + routeSuffix,
            "https://prod.trackmania.core.nadeo.online/v2/mapRecords/by-account/?accountIdList=" + accountId + "&mapId=" + mapId + seasonParam + gameModeParam,
            mapUid,
            accountId,
            mapId
        );
    }

    string TryResolveReplayUrlFromCoreEndpoint(const string &in routeLabel, const string &in url, const string &in mapUid, const string &in accountId, const string &in mapId) {
        RequestThrottle::WaitForSlot("Core replay-url fallback");
        auto req = NadeoServices::Get("NadeoServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }
        string responseText = req.String();
        if (req.ResponseCode() != 200) {
            log("HTTP replay-url fallback (" + routeLabel + ") failed for mapUid=" + mapUid + ", accountId=" + accountId + ", code=" + req.ResponseCode() + ", url=" + url + ", body=" + CompactForLog(responseText), LogLevel::Warning, 452, "RecordLoadService");
            return "";
        }

        Json::Value data = Json::Parse(responseText);
        if (data.GetType() == Json::Type::Object) {
            string code = string(data["code"]);
            string message = string(data["message"]);
            log("HTTP replay-url fallback (" + routeLabel + ") returned error for mapUid=" + mapUid + ", accountId=" + accountId + ", mapId=" + mapId + ": " + code + " " + message + ", url=" + url + ", body=" + CompactForLog(responseText), LogLevel::Warning, 459, "RecordLoadService");
            return "";
        }
        if (data.GetType() != Json::Type::Array || data.Length == 0) {
            log("HTTP replay-url fallback (" + routeLabel + ") returned no records for mapUid=" + mapUid + ", accountId=" + accountId + ", mapId=" + mapId + ", url=" + url + ", body=" + CompactForLog(responseText), LogLevel::Warning, 463, "RecordLoadService");
            return "";
        }

        string replayUrl = string(data[0]["url"]);
        if (replayUrl.Length == 0) {
            log("HTTP replay-url fallback (" + routeLabel + ") returned a record without a url for mapUid=" + mapUid + ", accountId=" + accountId + ", mapId=" + mapId + ", url=" + url + ", body=" + CompactForLog(responseText), LogLevel::Warning, 468, "RecordLoadService");
            return "";
        }
        return replayUrl;
    }

    bool DownloadToFile(const string &in url, const string &in path, string &out err) {
        err = "";
        if (url.Length == 0) { err = "Replay URL is empty"; return false; }
        if (path.Length == 0) { err = "Cache path is empty"; return false; }

        RequestThrottle::WaitForSlot("DownloadToFile NadeoServices");
        auto req = NadeoServices::Get("NadeoServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }

        int code = req.ResponseCode();
        if (code != 200) {
            RequestThrottle::WaitForSlot("DownloadToFile NadeoLiveServices");
            auto req2 = NadeoServices::Get("NadeoLiveServices", url);
            req2.Start();
            while (!req2.Finished()) { yield(); }
            code = req2.ResponseCode();
            if (code != 200) {
                err = "Failed to download record file (HTTP " + code + ")";
                return false;
            }
            req2.SaveToFile(path);
        } else {
            req.SaveToFile(path);
        }

        if (!IO::FileExists(path) || IO::FileSize(path) == 0) {
            err = "Downloaded file missing or empty: " + path;
            return false;
        }

        return true;
    }

    string DownloadUrlToLinksFolder(const string &in url, string &out err) {
        err = "";
        if (url.Trim().Length == 0) { err = "URL is empty"; return ""; }

        if (!IO::FolderExists(Server::linksFilesDirectory)) {
            IO::CreateFolder(Server::linksFilesDirectory, true);
        }

        string fileName = Path::GetFileName(url);

        Net::HttpRequest@ req = Net::HttpRequest();
        req.Url = url;
        req.Method = Net::HttpMethod::Get;
        RequestThrottle::WaitForSlot("DownloadUrlToLinksFolder");
        req.Start();
        while (!req.Finished()) { yield(); }

        auto headersJson = req.ResponseHeaders().ToJson();
        if (headersJson.GetType() == Json::Type::Object && headersJson.HasKey("content-disposition")) {
            string cd = string(headersJson["content-disposition"]);
            int idx = cd.ToLower().IndexOf("filename=");
            if (idx >= 0) {
                string tail = cd.SubStr(idx + 9).Trim();
                if (tail.StartsWith("\"")) {
                    int endQ = tail.SubStr(1).IndexOf("\"");
                    if (endQ >= 0) tail = tail.SubStr(1, endQ);
                    else tail = tail.Replace("\"", "");
                } else {
                    int semi = tail.IndexOf(";");
                    if (semi >= 0) tail = tail.SubStr(0, semi);
                }
                if (tail.Length > 0) fileName = tail;
            }
        }

        if (fileName.Trim().Length == 0) {
            fileName = "download_" + tostring(Time::Now) + ".Gbx";
        }
        fileName = Path::SanitizeFileName(fileName);

        string destPath = Server::linksFilesDirectory + fileName;
        if (IO::FileExists(destPath)) {
            string ext = Path::GetExtension(fileName);
            string baseName = ext.Length > 0 ? fileName.SubStr(0, fileName.Length - ext.Length) : fileName;
            destPath = Server::linksFilesDirectory + baseName + "_" + tostring(Time::Now) + ext;
        }

        bool downloaded = false;
        int code = req.ResponseCode();
        if (code == 200) {
            req.SaveToFile(destPath);
            downloaded = true;
        } else {
            auto req2 = NadeoServices::Get("NadeoServices", url);
            req2.Start();
            while (!req2.Finished()) { yield(); }
            code = req2.ResponseCode();
            if (code == 200) {
                req2.SaveToFile(destPath);
                downloaded = true;
            } else {
                auto req3 = NadeoServices::Get("NadeoLiveServices", url);
                req3.Start();
                while (!req3.Finished()) { yield(); }
                code = req3.ResponseCode();
                if (code == 200) {
                    req3.SaveToFile(destPath);
                    downloaded = true;
                }
            }
        }

        if (!downloaded) {
            err = "Failed to download URL (HTTP " + code + ")";
            return "";
        }

        if (!IO::FileExists(destPath) || IO::FileSize(destPath) == 0) {
            err = "Downloaded file missing or empty: " + destPath;
            return "";
        }

        return destPath;
    }
}
}
