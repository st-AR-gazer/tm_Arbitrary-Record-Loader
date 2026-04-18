namespace ReplayLoader {
    bool CleanupManagedFileAfterLoad(bool deleteManagedFileAfterLoad, const string &in fileId) {
        if (!deleteManagedFileAfterLoad || fileId.Length == 0) return false;
        string cleanupErr;
        if (!Services::Storage::FileStore::DeleteStoredFile(fileId, cleanupErr)) {
            if (cleanupErr.Length > 0) {
                log("Failed to delete non-cached replay file after load: " + cleanupErr, LogLevel::Warning, 4, "LoadReplayFromPath");
            }
            return false;
        }
        return true;
    }

    void LoadReplayFromPath(const string &in path) {
        if (!_Game::IsPlayingMap()) { NotifyWarning("You are currently not playing a map! Please load a map in a playing state first!"); return; }
        auto dfm = GameCtx::GetDFM();
        if (dfm is null) { NotifyWarning("Replay loading backend not ready (DataFileMgr unavailable)."); return; }

        auto storedRecord = Services::Storage::FileStore::GetByStoredPath(path);
        string fileKey = storedRecord !is null ? storedRecord.fileId : Path::GetFileName(path);
        string fileName = storedRecord !is null ? storedRecord.fileName : Path::GetFileName(path);
        LoadedRecords::SourceKind srcKind = LoadedRecords::SourceKind::Replay;
        string srcRef = path;
        string srcMapUid = "";
        string srcAccountId = "";
        string canonicalFilePath = storedRecord !is null ? storedRecord.storedPath : path;
        string srcFileId = storedRecord !is null ? storedRecord.fileId : "";
        string srcFilePath = canonicalFilePath;
        bool deleteManagedFileAfterLoad = false;
        auto meta = LoadedRecords::ConsumePendingFile(fileKey);
        if (meta !is null) {
            srcKind = meta.source;
            srcRef = meta.sourceRef.Length > 0 ? meta.sourceRef : path;
            srcMapUid = meta.mapUid;
            srcAccountId = meta.accountId;
            if (meta.fileId.Length > 0) srcFileId = meta.fileId;
            if (meta.filePath.Length > 0) canonicalFilePath = meta.filePath;
            srcFilePath = canonicalFilePath;
            deleteManagedFileAfterLoad = meta.deleteManagedFileAfterLoad;
        }

        string stagedPath = Server::replayARLAutoMove + fileName;
        if (storedRecord !is null) {
            string stageErr;
            string actualStagedPath;
            if (!Services::Storage::FileStore::StageForGame(fileKey, Server::replayARLAutoMove, actualStagedPath, stageErr)) {
                NotifyError(stageErr);
                log("Failed to stage replay file to the target directory!", LogLevel::Error, 11, "LoadReplayFromPath");
                return;
            }
            stagedPath = actualStagedPath;
        } else {
            log("Moving the replay file to the temp replay folder to load it.", LogLevel::Warning, 15, "LoadReplayFromPath");
            _IO::File::CopyFileTo(path, stagedPath);
        }

        auto task = dfm.Replay_Load(stagedPath);

        while (task.IsProcessing) { yield(); }

        if (storedRecord !is null) {
            string restoreErr;
            if (!Services::Storage::FileStore::RestoreFromGameStage(fileKey, restoreErr) && restoreErr.Length > 0) {
                log("Failed to restore staged replay file after load: " + restoreErr, LogLevel::Warning, 24, "LoadReplayFromPath");
            }
        } else {
            IO::Delete(stagedPath);
        }

        if (task.HasFailed || !task.HasSucceeded) {
            CleanupManagedFileAfterLoad(deleteManagedFileAfterLoad, srcFileId);
            NotifyError("Failed to load replay file!");
            log("Failed to load replay file!", LogLevel::Error, 27, "LoadReplayFromPath");
            log(task.ErrorCode, LogLevel::Error, 28, "LoadReplayFromPath");
            log(task.ErrorDescription, LogLevel::Error, 29, "LoadReplayFromPath");
            log(task.ErrorType, LogLevel::Error, 30, "LoadReplayFromPath");
            log(tostring(task.Ghosts.Length), LogLevel::Error, 31, "LoadReplayFromPath");
            return;
        } else {
            log(task.ErrorCode, LogLevel::Info, 34, "LoadReplayFromPath");
            log(task.ErrorDescription, LogLevel::Info, 35, "LoadReplayFromPath");
            log(task.ErrorType, LogLevel::Info, 36, "LoadReplayFromPath");
            log(tostring(task.Ghosts.Length), LogLevel::Info, 37, "LoadReplayFromPath");
        }

        auto ghostMgr = GameCtx::WaitForGhostMgr();
        if (ghostMgr is null) {
            CleanupManagedFileAfterLoad(deleteManagedFileAfterLoad, srcFileId);
            return;
        }
        if (CleanupManagedFileAfterLoad(deleteManagedFileAfterLoad, srcFileId)) {
            srcFileId = "";
            srcFilePath = "";
        }
        for (uint i = 0; i < task.Ghosts.Length; i++) {
            LoadedRecords::EnsureHiddenMarker(task.Ghosts[i]);
            MwId instId = ghostMgr.Ghost_Add(task.Ghosts[i]);
            LoadedRecords::RegisterGhost(task.Ghosts[i], instId, srcKind, srcRef, srcMapUid, srcAccountId, true, srcFileId, srcFilePath);
        }

        if (task.Ghosts.Length == 0) {
            NotifyWarning("No ghosts found in the replay file!");
            log("No ghosts found in the replay file!", LogLevel::Warning, 54, "LoadReplayFromPath");
            return;
        }
    }
}
