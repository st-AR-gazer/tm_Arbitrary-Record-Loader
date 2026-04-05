namespace ReplayLoader {
    void LoadReplayFromPath(const string &in path) {
        if (!_Game::IsPlayingMap()) { NotifyWarn("You are currently not playing a map! Please load a map in a playing state first!"); return; }
        auto dfm = GameCtx::GetDFM();
        if (dfm is null) { NotifyWarn("Replay loading backend not ready (DataFileMgr unavailable)."); return; }

        LoadedRecords::SourceKind srcKind = LoadedRecords::SourceKind::Replay;
        string srcRef = path;
        string srcMapUid = "";
        string srcAccountId = "";
        auto meta = LoadedRecords::ConsumePendingFile(Path::GetFileName(path));
        if (meta !is null) {
            srcKind = meta.source;
            srcRef = meta.sourceRef.Length > 0 ? meta.sourceRef : path;
            srcMapUid = meta.mapUid;
            srcAccountId = meta.accountId;
        }

        if (!path.Contains("Trackmania") || !path.Contains("Trackmania2020")) {
            log("The replay file is located in the Trackmania folder, moving to the replay folder to load it.", LogLevel::Warn, 6, "LoadReplayFromPath");
            NotifyWarn("The replay file is located in the Trackmania folder, moving to the replay folder to load it.");
            _IO::File::CopyFileTo(path, Server::replayARLAutoMove + Path::GetFileName(path));
            if (!IO::FileExists(Server::replayARLAutoMove + Path::GetFileName(path))) {
                NotifyError("Failed to move replay file to the target directory!");
                log("Failed to move replay file to the target directory!", LogLevel::Error, 11, "LoadReplayFromPath");
                return;
            }
        } else {
            log("Moving the replay file to the temp replay folder to load it.", LogLevel::Warn, 15, "LoadReplayFromPath");
            _IO::File::CopyFileTo(path, Server::replayARLAutoMove + Path::GetFileName(path));
        }

        auto task = dfm.Replay_Load(Server::replayARLAutoMove + Path::GetFileName(path));

        IO::Delete(Server::replayARLAutoMove + Path::GetFileName(path));

        while (task.IsProcessing) { yield(); }

        if (task.HasFailed || !task.HasSucceeded) {
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
        if (ghostMgr is null) return;
        for (uint i = 0; i < task.Ghosts.Length; i++) {
            MwId instId = ghostMgr.Ghost_Add(task.Ghosts[i]);
            LoadedRecords::RegisterGhost(task.Ghosts[i], instId, srcKind, srcRef, srcMapUid, srcAccountId, true);
        }

        if (task.Ghosts.Length == 0) {
            NotifyWarn("No ghosts found in the replay file!");
            log("No ghosts found in the replay file!", LogLevel::Warn, 54, "LoadReplayFromPath");
            return;
        }
    }
}
