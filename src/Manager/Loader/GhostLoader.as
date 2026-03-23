namespace GhostLoader {
    [Setting hidden]
    bool S_UseGhostLayer = true;

    void LoadGhostFromLocalFile(const string &in filePath, const string &in _destinationPath = Server::serverDirectoryAutoMove) {
        if (filePath.ToLower().EndsWith(".gbx")) {
            string fileName = Path::GetFileName(filePath);
            string destinationPath = _destinationPath + fileName;
            log("Moving file from " + filePath + " to " + destinationPath, LogLevel::Info, 9, "LoadGhostFromLocalFile");
            if (!LoadedRecords::pendingByFileName.Exists(fileName)) {
                LoadedRecords::TrackPendingFile(fileName, LoadedRecords::SourceKind::LocalFile, filePath, "", "", S_UseGhostLayer);
            }
            if (filePath != destinationPath) {
                _IO::File::CopyFileTo(filePath, destinationPath);
            }
            LoadGhostFromUrl(Server::HTTP_BASE_URL + "get_ghost/" + fileName);
        } else {
            NotifyError("Unsupported file type.");
        }
    }

    void LoadGhostFromUrl(const string &in url) {
        log("Loading ghost from URL: " + url, LogLevel::Info, 18, "LoadGhostFromUrl");
        startnew(LoadGhostFromUrlAsync, url);
    }

    void LoadGhostFromUrlAsync(const string &in url) {
        auto dfm = GameCtx::GetDFM();
        if (dfm is null) { log("DataFileMgr is null (ClientManiaAppPlayground backend not ready)", LogLevel::Error, 25, "LoadGhostFromUrlAsync"); return; }

        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download("", url);

        while (task.IsProcessing) { yield(); }

        if (task.HasFailed || !task.HasSucceeded) {
            log('Ghost_Download failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription + " Url used: " + url, LogLevel::Error, 34, "LoadGhostFromUrlAsync");
            return;
        }

        CGameGhostMgrScript@ gm = GameCtx::GetGhostMgr();
        if (gm is null) { log("GhostMgr is null (ClientManiaAppPlayground backend not ready)", LogLevel::Error, 39, "LoadGhostFromUrlAsync"); return; }
        MwId instId = gm.Ghost_Add(task.Ghost, S_UseGhostLayer);
        log('Instance ID: ' + instId.GetName() + " / " + Text::Format("%08x", instId.Value), LogLevel::Info, 40, "LoadGhostFromUrlAsync");

        LoadedRecords::SourceKind srcKind = LoadedRecords::SourceKind::Url;
        string srcRef = url;
        string srcMapUid = "";
        string srcAccountId = "";
        string localPrefix = Server::HTTP_BASE_URL + "get_ghost/";
        if (url.StartsWith(localPrefix)) {
            string fname = Net::UrlDecode(url.SubStr(localPrefix.Length));
            auto meta = LoadedRecords::ConsumePendingFile(fname);
            if (meta !is null) {
                srcKind = meta.source;
                srcRef = meta.sourceRef.Length > 0 ? meta.sourceRef : (Server::serverDirectoryAutoMove + fname);
                srcMapUid = meta.mapUid;
                srcAccountId = meta.accountId;
            } else {
                srcKind = LoadedRecords::SourceKind::LocalFile;
                srcRef = Server::serverDirectoryAutoMove + fname;
            }
        }
        LoadedRecords::RegisterGhost(task.Ghost, instId, srcKind, srcRef, srcMapUid, srcAccountId, S_UseGhostLayer);

        dfm.TaskResult_Release(task.Id);
    }
}