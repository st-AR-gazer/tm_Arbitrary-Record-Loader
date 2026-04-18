namespace EntryPoints {
namespace CurrentMap {
namespace ValidationReplay {
    [Setting category="Current Map" name="Cache validation replay fallback files"]
    bool S_CacheValidationReplay = false;

    bool g_ExtractInProgress = false;

    string GetFileId() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return "";
        return Services::Storage::FileStore::BuildFileId(Services::Storage::FileStore::KIND_VALIDATION_REPLAY, mapUid);
    }

    Services::Storage::FileStore::StoredFileRecord@ GetStoredRecord() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return null;
        return Services::Storage::FileStore::FindLatestByKindAndMapUid(Services::Storage::FileStore::KIND_VALIDATION_REPLAY, mapUid);
    }

    void Add() {
        if (!Exists()) {
            NotifyWarning("No validation replay is available for the current map.");
            return;
        }

        if (TryLoadDirect()) {
            return;
        }

        string path = GetFilePath();
        if (path.Length == 0) {
            log("Validation replay file missing for mapUid=" + CurrentMap::GetMapUid() + "; trying on-demand extraction before load.", LogLevel::Info, 18, "CurrentMap::ValidationReplay::Add");
            Extract();
            path = GetFilePath();
        }

        if (path.Length == 0) {
            NotifyWarning("Validation replay is available, but ARL could not extract it yet. Try again in a moment.");
            log("Validation replay still unavailable after on-demand extraction for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Warning, 24, "CurrentMap::ValidationReplay::Add");
            return;
        }

        Domain::LoadRequest@ req = Domain::LoadRequest();
        req.selectorKind = Domain::SelectorKind::LocalFile;
        req.context = Domain::LoadContext::LocalFile;
        req.filePath = path;
        req.mapUid = CurrentMap::GetMapUid();
        req.useGhostLayer = true;
        req.cacheFile = S_CacheValidationReplay;
        req.forceRefresh = false;
        req.sourceKind = LoadedRecords::SourceKind::Replay;
        req.sourceRef = "Validation | " + req.mapUid;

        Services::LoadQueue::Enqueue(req);
    }

    bool TryLoadDirect() {
        auto dataFileMgr = GameCtx::GetDFM();
        if (dataFileMgr is null || GetApp().RootMap is null) {
            log("Direct validation load skipped because DataFileMgr or RootMap is unavailable.", LogLevel::Warning, 17, "CurrentMap::ValidationReplay::TryLoadDirect");
            return false;
        }

        auto authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
        if (authorGhost is null) {
            log("Direct validation load skipped because the author ghost is null for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Warning, 18, "CurrentMap::ValidationReplay::TryLoadDirect");
            return false;
        }

        auto ghostMgr = GameCtx::WaitForGhostMgr();
        if (ghostMgr is null) {
            NotifyWarning("Validation replay is available, but the ghost manager is not ready yet.");
            log("Direct validation load failed because GhostMgr was unavailable for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Warning, 19, "CurrentMap::ValidationReplay::TryLoadDirect");
            return false;
        }

        LoadedRecords::EnsureHiddenMarker(authorGhost);
        MwId instId = ghostMgr.Ghost_Add(authorGhost, true);
        bool isVisible = false;
        try {
            isVisible = ghostMgr.Ghost_IsVisible(instId);
        } catch {}

        if (instId.Value == 0 && authorGhost.Id.Value != 0) {
            instId = authorGhost.Id;
            try {
                isVisible = ghostMgr.Ghost_IsVisible(instId);
            } catch {}
        }

        if (instId.Value == 0 && !isVisible) {
            log("Direct validation load failed because Ghost_Add returned no visible instance for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Warning, 20, "CurrentMap::ValidationReplay::TryLoadDirect");
            return false;
        }

        string fileId = S_CacheValidationReplay ? GetFileId() : "";
        string filePath = S_CacheValidationReplay ? GetFilePath() : "";
        LoadedRecords::RegisterGhost(authorGhost, instId, LoadedRecords::SourceKind::Replay, "Validation | " + CurrentMap::GetMapUid(), CurrentMap::GetMapUid(), "", true, fileId, filePath);
        log("Loaded validation replay directly from the embedded author ghost for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Info, 21, "CurrentMap::ValidationReplay::TryLoadDirect");
        return true;
    }

    bool Exists() {
        auto dataFileMgr = GameCtx::GetDFM();
        if (dataFileMgr is null || GetApp().RootMap is null) return false;
        return dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap) !is null;
    }

    void OnMapLoad() {
        if (!S_CacheValidationReplay) return;
        startnew(TryExtractWhenReady);
    }

    void TryExtractWhenReady() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return;

        uint startTime = Time::Now;
        while (Time::Now - startTime < 5000) {
            if (mapUid != CurrentMap::GetMapUid()) return;
            if (Exists()) {
                Extract();
                return;
            }
            yield();
        }

        log("Validation replay extraction skipped on map load because the author ghost/backend never became ready for mapUid=" + mapUid, LogLevel::Warning, 44, "CurrentMap::ValidationReplay::TryExtractWhenReady");
    }

    void Extract() {
        if (g_ExtractInProgress) return;
        g_ExtractInProgress = true;
        try {
            auto dataFileMgr = GameCtx::GetDFM();
            if (dataFileMgr is null || GetApp().RootMap is null) {
                log("Validation replay extract aborted because DataFileMgr or RootMap is unavailable.", LogLevel::Warning, 70, "CurrentMap::ValidationReplay::Extract");
                g_ExtractInProgress = false;
                return;
            }

            auto authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
            if (authorGhost is null) {
                log("Validation replay extract aborted because the author ghost is null for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Warning, 71, "CurrentMap::ValidationReplay::Extract");
                g_ExtractInProgress = false;
                return;
            }

            string tempOutputFileName = GetTempFilePath();
            if (tempOutputFileName.Length == 0) {
                log("Validation replay extract aborted because no temp replay path could be built for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Warning, 72, "CurrentMap::ValidationReplay::Extract");
                g_ExtractInProgress = false;
                return;
            }

            auto taskResult = dataFileMgr.Replay_Save(tempOutputFileName, GetApp().RootMap, authorGhost);
            if (taskResult is null) {
                log("Replay task returned null", LogLevel::Error, 34, "CurrentMap::ValidationReplay::Extract");
                g_ExtractInProgress = false;
                return;
            }

            while (taskResult.IsProcessing) { yield(); }

            if (!taskResult.HasSucceeded) {
                log("Error while saving validation replay: " + taskResult.ErrorDescription, LogLevel::Error, 41, "CurrentMap::ValidationReplay::Extract");
                g_ExtractInProgress = false;
                return;
            }

            string tempPath = IO::FromUserGameFolder(tempOutputFileName);
            if (!IO::FileExists(tempPath)) {
                log("Validation replay extract completed without producing a temp file: " + tempPath, LogLevel::Warning, 73, "CurrentMap::ValidationReplay::Extract");
                g_ExtractInProgress = false;
                return;
            }

            string fileId = GetFileId();
            if (fileId.Length == 0) {
                log("Validation replay extract aborted because no managed file id could be built for mapUid=" + CurrentMap::GetMapUid(), LogLevel::Warning, 74, "CurrentMap::ValidationReplay::Extract");
                g_ExtractInProgress = false;
                return;
            }

            string storedPath = Services::Storage::FileStore::BuildStoredFilePath(Services::Storage::FileStore::KIND_VALIDATION_REPLAY, fileId, ".Replay.Gbx");
            string storedDir = Path::GetDirectoryName(storedPath);
            if (storedDir.Length > 0 && !IO::FolderExists(storedDir)) {
                IO::CreateFolder(storedDir, true);
            }
            if (IO::FileExists(storedPath)) {
                try { IO::Delete(storedPath); } catch {}
            }

            IO::Move(tempPath, storedPath);

            Services::Storage::FileStore::StoredFileRecord@ record = Services::Storage::FileStore::StoredFileRecord();
            record.fileId = fileId;
            record.kind = Services::Storage::FileStore::KIND_VALIDATION_REPLAY;
            record.sourceKind = int(LoadedRecords::SourceKind::Replay);
            record.fileName = Path::GetFileName(storedPath);
            record.storedPath = storedPath;
            record.originalFileName = Path::GetFileName(storedPath);
            record.sourceRef = "Validation | " + CurrentMap::GetMapUid();
            record.mapUid = CurrentMap::GetMapUid();
            record.useGhostLayer = true;
            Services::Storage::FileStore::Upsert(record);
        } catch {
            log("Validation replay extract failed: " + getExceptionInfo(), LogLevel::Warning, 44, "CurrentMap::ValidationReplay::Extract");
        }
        g_ExtractInProgress = false;
    }

    string GetTempFilePath() {
        if (!CurrentMap::IsMapLoaded()) return "";
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return "";
        return "Replays/ArbitraryRecordLoader/Tmp/Validation_" + Path::SanitizeFileName(mapUid) + ".Replay.Gbx";
    }

    string GetFilePath() {
        auto record = GetStoredRecord();
        if (record is null) return "";
        if (!IO::FileExists(record.storedPath)) return "";
        return record.storedPath;
    }

    int GetTime() {
        auto dataFileMgr = GameCtx::GetDFM();
        if (dataFileMgr is null || GetApp().RootMap is null) return -1;
        auto authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
        if (authorGhost is null) return -1;
        return authorGhost.Result.Time;
    }

}
}
}
