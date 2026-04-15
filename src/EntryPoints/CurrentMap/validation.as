namespace EntryPoints {
namespace CurrentMap {
namespace ValidationReplay {
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

            string tempOutputFileName = GetTempFilePath();
            if (tempOutputFileName.Length == 0) return;

            auto taskResult = dataFileMgr.Replay_Save(tempOutputFileName, GetApp().RootMap, authorGhost);
            if (taskResult is null) {
                log("Replay task returned null", LogLevel::Error, 34, "CurrentMap::ValidationReplay::Extract");
                return;
            }

            while (taskResult.IsProcessing) { yield(); }

            if (!taskResult.HasSucceeded) {
                log("Error while saving validation replay: " + taskResult.ErrorDescription, LogLevel::Error, 41, "CurrentMap::ValidationReplay::Extract");
                return;
            }

            string tempPath = IO::FromUserGameFolder(tempOutputFileName);
            if (!IO::FileExists(tempPath)) return;

            string fileId = GetFileId();
            if (fileId.Length == 0) return;

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
