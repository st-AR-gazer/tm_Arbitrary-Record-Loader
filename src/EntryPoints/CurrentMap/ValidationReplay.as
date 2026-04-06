namespace EntryPoints {
namespace CurrentMap {
namespace ValidationReplay {
    void Add() {
        if (!Exists()) return;

        string path = GetFilePath();
        if (path.Length == 0) return;

        Domain::LoadRequest@ req = Domain::LoadRequest();
        req.selectorKind = Domain::SelectorKind::LocalFile;
        req.context = Domain::LoadContext::LocalFile;
        req.filePath = path;
        req.mapUid = CurrentMap::GetMapUid();
        req.useGhostLayer = true;
        req.forceRefresh = false;
        req.sourceKind = LoadedRecords::SourceKind::Replay;
        req.sourceRef = "Validation | " + req.mapUid;

        Services::LoadQueue::Enqueue(req);
    }

    bool Exists() {
        auto dataFileMgr = GameCtx::GetDFM();
        if (dataFileMgr is null || GetApp().RootMap is null) return false;
        return dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap) !is null;
    }

    void OnMapLoad() {
        if (!Exists()) return;
        Extract();
    }

    void Extract() {
        try {
            auto dataFileMgr = GameCtx::GetDFM();
            if (dataFileMgr is null || GetApp().RootMap is null) return;

            auto authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
            if (authorGhost is null) return;

            string outputFileName = GetFilePath();
            if (outputFileName.Length == 0) return;

            auto taskResult = dataFileMgr.Replay_Save(outputFileName, GetApp().RootMap, authorGhost);
            if (taskResult is null) {
                log("Replay task returned null", LogLevel::Error, 34, "CurrentMap::ValidationReplay::Extract");
                return;
            }

            while (taskResult.IsProcessing) { yield(); }

            if (!taskResult.HasSucceeded) {
                log("Error while saving validation replay: " + taskResult.ErrorDescription, LogLevel::Error, 41, "CurrentMap::ValidationReplay::Extract");
            }
        } catch {
            log("Validation replay extract failed: " + getExceptionInfo(), LogLevel::Warning, 44, "CurrentMap::ValidationReplay::Extract");
        }
    }

    int GetTime() {
        auto dataFileMgr = GameCtx::GetDFM();
        if (dataFileMgr is null || GetApp().RootMap is null) return -1;
        auto authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
        if (authorGhost is null) return -1;
        return authorGhost.Result.Time;
    }

    string GetFilePath() {
        if (!CurrentMap::IsMapLoaded()) return "";
        string safeMapName = CurrentMap::GetSafeMapName();
        if (safeMapName.Length == 0) return "";
        return Server::currentMapRecordsValidationReplay + "Validation_" + safeMapName + ".Replay.Gbx";
    }
}
}
}
