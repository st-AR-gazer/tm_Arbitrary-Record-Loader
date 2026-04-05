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
        log("Started Ghost_Download for URL: " + url, LogLevel::Info, 31, "LoadGhostFromUrlAsync");

        while (task.IsProcessing) { yield(); }
        log("Ghost_Download finished. Success=" + (task.HasSucceeded ? "true" : "false") + ", Failed=" + (task.HasFailed ? "true" : "false"), LogLevel::Info, 34, "LoadGhostFromUrlAsync");

        if (task.HasFailed || !task.HasSucceeded) {
            log('Ghost_Download failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription + " Url used: " + url, LogLevel::Error, 36, "LoadGhostFromUrlAsync");
            return;
        }

        CGameGhostMgrScript@ gm = GameCtx::WaitForGhostMgr();
        if (gm is null) { log("GhostMgr is null (playground/backend not ready after wait)", LogLevel::Error, 39, "LoadGhostFromUrlAsync"); return; }
        log("GhostMgr resolved after download; proceeding to Ghost_Add", LogLevel::Info, 40, "LoadGhostFromUrlAsync");

        LoadedRecords::SourceKind srcKind = LoadedRecords::SourceKind::Url;
        string srcRef = url;
        string srcMapUid = "";
        string srcAccountId = "";
        bool useGhostLayer = S_UseGhostLayer;
        string localPrefix = Server::HTTP_BASE_URL + "get_ghost/";
        if (url.StartsWith(localPrefix)) {
            string fname = Net::UrlDecode(url.SubStr(localPrefix.Length));
            auto meta = LoadedRecords::ConsumePendingFile(fname);
            if (meta !is null) {
                srcKind = meta.source;
                srcRef = meta.sourceRef.Length > 0 ? meta.sourceRef : (Server::serverDirectoryAutoMove + fname);
                srcMapUid = meta.mapUid;
                srcAccountId = meta.accountId;
                useGhostLayer = meta.useGhostLayer;
            } else {
                srcKind = LoadedRecords::SourceKind::LocalFile;
                srcRef = Server::serverDirectoryAutoMove + fname;
            }
        }

        MwId instId = gm.Ghost_Add(task.Ghost, useGhostLayer);
        log('Instance ID: ' + instId.GetName() + " / " + Text::Format("%08x", instId.Value), LogLevel::Info, 40, "LoadGhostFromUrlAsync");

        LoadedRecords::RegisterGhost(task.Ghost, instId, srcKind, srcRef, srcMapUid, srcAccountId, useGhostLayer);

        dfm.TaskResult_Release(task.Id);
    }
}
