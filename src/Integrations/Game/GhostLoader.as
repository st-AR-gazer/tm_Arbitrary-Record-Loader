namespace GhostLoader {
    [Setting hidden]
    bool S_UseGhostLayer = true;

    bool CleanupManagedFileAfterLoad(bool deleteManagedFileAfterLoad, const string &in fileId) {
        if (!deleteManagedFileAfterLoad || fileId.Length == 0) return false;
        string cleanupErr;
        if (!Services::Storage::FileStore::DeleteStoredFile(fileId, cleanupErr)) {
            if (cleanupErr.Length > 0) {
                log("Failed to delete non-cached ghost file after load: " + cleanupErr, LogLevel::Warning, 10, "CleanupManagedFileAfterLoad");
            }
            return false;
        }
        return true;
    }

    string NormalizeManagedFileKey(const string &in keyOrName) {
        string managedId = Services::Storage::FileStore::TryGetManagedFileIdFromName(keyOrName);
        if (managedId.Length > 0) return managedId;
        return keyOrName.Trim();
    }

    int GetUrlQueryParamInt(const string &in url, const string &in key) {
        int q = url.IndexOf("?");
        if (q < 0 || q + 1 >= int(url.Length)) return -1;
        string query = url.SubStr(q + 1);
        auto parts = query.Split("&");
        for (uint i = 0; i < parts.Length; i++) {
            int eq = parts[i].IndexOf("=");
            if (eq <= 0) continue;
            string partKey = parts[i].SubStr(0, eq);
            if (partKey != key) continue;
            string val = parts[i].SubStr(eq + 1);
            if (val.Length == 0) return -1;
            try { return Text::ParseInt(val); } catch {
                log("Failed to parse URL query param '" + key + "' as int from value '" + val + "': " + getExceptionInfo(), LogLevel::Debug, -1, "GetUrlQueryParamInt");
                return -1;
            }
        }
        return -1;
    }

    string GetUrlQueryParamString(const string &in url, const string &in key) {
        int q = url.IndexOf("?");
        if (q < 0 || q + 1 >= int(url.Length)) return "";
        string query = url.SubStr(q + 1);
        auto parts = query.Split("&");
        for (uint i = 0; i < parts.Length; i++) {
            int eq = parts[i].IndexOf("=");
            if (eq <= 0) continue;
            string partKey = parts[i].SubStr(0, eq);
            if (partKey != key) continue;
            return Net::UrlDecode(parts[i].SubStr(eq + 1));
        }
        return "";
    }

    bool UrlHasQueryFlag(const string &in url, const string &in key) {
        int q = url.IndexOf("?");
        if (q < 0 || q + 1 >= int(url.Length)) return false;
        string query = url.SubStr(q + 1);
        auto parts = query.Split("&");
        for (uint i = 0; i < parts.Length; i++) {
            int eq = parts[i].IndexOf("=");
            string partKey = eq >= 0 ? parts[i].SubStr(0, eq) : parts[i];
            if (partKey == key) return true;
        }
        return false;
    }

    int TryResolveGpsDerivedRaceTimeMs(const string &in fileKey) {
        auto storedRecord = Services::Storage::FileStore::ResolveManagedRecord(fileKey);
        if (storedRecord !is null && storedRecord.kind == Services::Storage::FileStore::KIND_GPS_GHOST && storedRecord.derivedRaceTimeMs >= 0) {
            return storedRecord.derivedRaceTimeMs;
        }
        return -1;
    }

    int TryParseExpectedRaceTimeMs(const string &in sourceRef) {
        if (sourceRef.Length == 0) return -1;
        int idx = sourceRef.IndexOf("rt=");
        if (idx < 0) return -1;
        int start = idx + 3;
        if (start >= int(sourceRef.Length)) return -1;
        int end = start;
        while (end < int(sourceRef.Length)) {
            int c = int(sourceRef[uint(end)]);
            if (c < 48 || c > 57) break;
            end++;
        }
        if (end <= start) return -1;
        string digits = sourceRef.SubStr(start, end - start);
        int value = -1;
        try { value = Text::ParseInt(digits); } catch {
            log("Failed to parse expected race time from source ref '" + sourceRef + "': " + getExceptionInfo(), LogLevel::Debug, -1, "TryParseExpectedRaceTimeMs");
            value = -1;
        }
        return value;
    }

    bool ShouldUseWaypointSyncedGhostAdd(LoadedRecords::SourceKind srcKind, const string &in srcRef) {
        if (srcKind != LoadedRecords::SourceKind::Replay) return false;
        return srcRef.StartsWith("GPS | ");
    }

    void LoadGhostFromLocalFile(const string &in filePath, const string &in _destinationPath = Server::serverDirectoryAutoMove) {
        LoadGhostFromLocalFileWithMeta(filePath, LoadedRecords::SourceKind::LocalFile, filePath, "", "", S_UseGhostLayer, _destinationPath, false);
    }

    void LoadGhostFromLocalFileWithMeta(
        const string &in filePath,
        LoadedRecords::SourceKind source,
        const string &in sourceRef = "",
        const string &in mapUid = "",
        const string &in accountId = "",
        bool useGhostLayer = true,
        const string &in _destinationPath = Server::serverDirectoryAutoMove,
        bool deleteManagedFileAfterLoad = false
    ) {
        if (filePath.ToLower().EndsWith(".gbx")) {
            auto storedRecord = Services::Storage::FileStore::GetByStoredPath(filePath);
            string fileKey = storedRecord !is null ? storedRecord.fileId : NormalizeManagedFileKey(Path::GetFileName(filePath));
            string fileName = storedRecord !is null ? storedRecord.fileName : Path::GetFileName(filePath);
            string destinationPath = _destinationPath + fileName;
            bool useManagedStore = storedRecord !is null && IO::FileExists(storedRecord.storedPath);
            log((useManagedStore ? "Staging managed file " : "Moving file from ") + filePath + (useManagedStore ? (" into " + destinationPath) : (" to " + destinationPath)), LogLevel::Info, 120, "LoadGhostFromLocalFile");
            string effectiveSourceRef = sourceRef.Length > 0 ? sourceRef : filePath;
            string effectiveFilePath = storedRecord !is null ? storedRecord.storedPath : filePath;
            LoadedRecords::TrackPendingFile(fileKey, source, effectiveSourceRef, mapUid, accountId, useGhostLayer, fileKey, effectiveFilePath, deleteManagedFileAfterLoad);
            if (useManagedStore) {
                string stageErr;
                string stagedPath;
                if (!Services::Storage::FileStore::StageForGame(fileKey, _destinationPath, stagedPath, stageErr)) {
                    NotifyError(stageErr);
                    return;
                }
            } else if (filePath != destinationPath) {
                if (IO::FileExists(destinationPath)) {
                    try {
                        IO::Delete(destinationPath);
                    } catch {
                        log("Failed to delete existing staged ghost before overwrite: " + destinationPath, LogLevel::Warning, 136, "LoadGhostFromLocalFile");
                    }
                }
                _IO::File::CopyFileTo(filePath, destinationPath);
            }
            string url = Server::HTTP_BASE_URL + "get_ghost/" + Net::UrlEncode(fileName) + "?t=" + Time::Now;
            if (fileKey != fileName) {
                url += "&fid=" + Net::UrlEncode(fileKey);
            }
            int derived = TryParseExpectedRaceTimeMs(effectiveSourceRef);
            bool looksLikeGps = (storedRecord !is null && storedRecord.kind == Services::Storage::FileStore::KIND_GPS_GHOST) || ShouldUseWaypointSyncedGhostAdd(source, effectiveSourceRef);
            if (looksLikeGps) {
                url += "&gps=1";
                if (derived <= 0) derived = TryResolveGpsDerivedRaceTimeMs(fileKey);
                if (derived > 0) url += "&rt=" + derived;
            }
            LoadGhostFromUrl(url);
        } else {
            NotifyError("Unsupported file type.");
        }
    }

    void LoadGhostFromUrl(const string &in url) {
        log("Loading ghost from URL: " + url, LogLevel::Info, 159, "LoadGhostFromUrl");
        startnew(LoadGhostFromUrlAsync, url);
    }

    void LoadGhostFromUrlAsync(const string &in url) {
        auto dfm = GameCtx::GetDFM();
        if (dfm is null) { log("DataFileMgr is null (ClientManiaAppPlayground backend not ready)", LogLevel::Error, 165, "LoadGhostFromUrlAsync"); return; }

        string downloadFileName = "";
        string localPrefix = Server::HTTP_BASE_URL + "get_ghost/";
        string stagedFileKey = "";
        if (url.StartsWith(localPrefix)) {
            string downloadName = Net::UrlDecode(url.SubStr(localPrefix.Length));
            int q = downloadName.IndexOf("?");
            if (q >= 0) downloadName = downloadName.SubStr(0, q);
            string fid = GetUrlQueryParamString(url, "fid");
            stagedFileKey = fid.Length > 0 ? NormalizeManagedFileKey(fid) : NormalizeManagedFileKey(downloadName);
            auto storedRecord = Services::Storage::FileStore::ResolveManagedRecord(stagedFileKey);
            downloadFileName = storedRecord !is null && storedRecord.fileName.Length > 0 ? storedRecord.fileName : (downloadName.Length == 0 ? "ghost.Ghost.Gbx" : downloadName);
        }
        bool urlSaysGps = UrlHasQueryFlag(url, "gps");
        int urlExpectedTimeMs = GetUrlQueryParamInt(url, "rt");

        CWebServicesTaskResult_GhostScript@ task = dfm.Ghost_Download(downloadFileName, url);
        log("Started Ghost_Download for URL: " + url + (downloadFileName.Length > 0 ? (" (fileName=" + downloadFileName + ")") : ""), LogLevel::Info, 183, "LoadGhostFromUrlAsync");

        while (task.IsProcessing) { yield(); }
        log("Ghost_Download finished. Success=" + (task.HasSucceeded ? "true" : "false") + ", Failed=" + (task.HasFailed ? "true" : "false"), LogLevel::Info, 186, "LoadGhostFromUrlAsync");

        if (task.HasFailed || !task.HasSucceeded) {
            if (stagedFileKey.Length > 0) {
                string restoreErr;
                if (!Services::Storage::FileStore::RestoreFromGameStage(stagedFileKey, restoreErr) && restoreErr.Length > 0) {
                    log("Failed to restore staged file after Ghost_Download failure: " + restoreErr, LogLevel::Warning, 192, "LoadGhostFromUrlAsync");
                }
                auto pendingMeta = LoadedRecords::ConsumePendingFile(stagedFileKey);
                if (pendingMeta !is null && pendingMeta.deleteManagedFileAfterLoad) {
                    string pendingFileId = pendingMeta.fileId.Length > 0 ? pendingMeta.fileId : stagedFileKey;
                    CleanupManagedFileAfterLoad(true, pendingFileId);
                }
            }
            log('Ghost_Download failed: ' + task.ErrorCode + ", " + task.ErrorType + ", " + task.ErrorDescription + " Url used: " + url, LogLevel::Error, 200, "LoadGhostFromUrlAsync");
            return;
        }

        CGameGhostMgrScript@ gm = GameCtx::WaitForGhostMgr();
        if (gm is null) {
            if (stagedFileKey.Length > 0) {
                string restoreErr;
                if (!Services::Storage::FileStore::RestoreFromGameStage(stagedFileKey, restoreErr) && restoreErr.Length > 0) {
                    log("Failed to restore staged file after GhostMgr wait failed: " + restoreErr, LogLevel::Warning, 209, "LoadGhostFromUrlAsync");
                }
                auto pendingMeta = LoadedRecords::ConsumePendingFile(stagedFileKey);
                if (pendingMeta !is null && pendingMeta.deleteManagedFileAfterLoad) {
                    string pendingFileId = pendingMeta.fileId.Length > 0 ? pendingMeta.fileId : stagedFileKey;
                    CleanupManagedFileAfterLoad(true, pendingFileId);
                }
            }
            log("GhostMgr is null (playground/backend not ready after wait)", LogLevel::Error, 217, "LoadGhostFromUrlAsync");
            return;
        }
        log("GhostMgr resolved after download; proceeding to Ghost_Add", LogLevel::Info, 220, "LoadGhostFromUrlAsync");

        LoadedRecords::SourceKind srcKind = LoadedRecords::SourceKind::Url;
        string srcRef = url;
        string srcMapUid = "";
        string srcAccountId = "";
        string srcFileId = "";
        string srcFilePath = "";
        bool useGhostLayer = S_UseGhostLayer;
        bool deleteManagedFileAfterLoad = false;
        if (url.StartsWith(localPrefix)) {
            string fileKey = GetUrlQueryParamString(url, "fid");
            if (fileKey.Length == 0) {
                fileKey = Net::UrlDecode(url.SubStr(localPrefix.Length));
                int q = fileKey.IndexOf("?");
                if (q >= 0) fileKey = fileKey.SubStr(0, q);
            }
            fileKey = NormalizeManagedFileKey(fileKey);
            auto meta = LoadedRecords::ConsumePendingFile(fileKey);
            if (meta !is null) {
                srcKind = meta.source;
                srcRef = meta.sourceRef;
                srcMapUid = meta.mapUid;
                srcAccountId = meta.accountId;
                useGhostLayer = meta.useGhostLayer;
                srcFileId = meta.fileId;
                srcFilePath = meta.filePath;
                deleteManagedFileAfterLoad = meta.deleteManagedFileAfterLoad;
                log("ConsumePendingFile ok: key=" + fileKey + ", kind=" + LoadedRecords::SourceKindToString(srcKind) + ", ref=" + srcRef, LogLevel::Info, 248, "LoadGhostFromUrlAsync");
            } else {
                auto storedRecord = Services::Storage::FileStore::ResolveManagedRecord(fileKey);
                if (storedRecord !is null) {
                    srcKind = LoadedRecords::SourceKind(storedRecord.sourceKind);
                    srcRef = storedRecord.sourceRef.Length > 0 ? storedRecord.sourceRef : storedRecord.storedPath;
                    srcMapUid = storedRecord.mapUid;
                    srcAccountId = storedRecord.accountId;
                    srcFileId = storedRecord.fileId;
                    srcFilePath = storedRecord.storedPath;
                    useGhostLayer = storedRecord.useGhostLayer;
                    if (srcKind == LoadedRecords::SourceKind::Unknown && storedRecord.kind == Services::Storage::FileStore::KIND_GPS_GHOST) {
                        srcKind = LoadedRecords::SourceKind::Replay;
                    }
                    log("FileStore metadata hit: key=" + fileKey + ", kind=" + LoadedRecords::SourceKindToString(srcKind) + ", ref=" + srcRef, LogLevel::Info, 262, "LoadGhostFromUrlAsync");
                } else {
                    if (stagedFileKey.Length > 0) {
                        string restoreErr;
                        if (!Services::Storage::FileStore::RestoreFromGameStage(stagedFileKey, restoreErr) && restoreErr.Length > 0) {
                            log("Failed to restore staged file after missing FileStore entry: " + restoreErr, LogLevel::Warning, 267, "LoadGhostFromUrlAsync");
                        }
                    }
                    log("ConsumePendingFile miss and no FileStore entry for key=" + fileKey, LogLevel::Warning, 270, "LoadGhostFromUrlAsync");
                    return;
                }
            }
        }

        int expectedTimeMs = TryParseExpectedRaceTimeMs(srcRef);
        if (expectedTimeMs <= 0 && urlExpectedTimeMs > 0) {
            expectedTimeMs = urlExpectedTimeMs;
        }
        if (expectedTimeMs <= 0 && url.StartsWith(localPrefix)) {
            string fileKey = GetUrlQueryParamString(url, "fid");
            if (fileKey.Length == 0) {
                fileKey = Net::UrlDecode(url.SubStr(localPrefix.Length));
                int q = fileKey.IndexOf("?");
                if (q >= 0) fileKey = fileKey.SubStr(0, q);
            }
            fileKey = NormalizeManagedFileKey(fileKey);
            expectedTimeMs = TryResolveGpsDerivedRaceTimeMs(fileKey);
        }

        bool gpsHint = urlSaysGps || ShouldUseWaypointSyncedGhostAdd(srcKind, srcRef);
        string addMode = "Default";
        LoadedRecords::EnsureArlMarkers(task.Ghost);
        MwId instId = gm.Ghost_Add(task.Ghost, useGhostLayer);
        bool isVisible = false;
        try {
            isVisible = gm.Ghost_IsVisible(instId);
        } catch {
            log("Ghost visibility check failed for Ghost_Add id=" + Text::Format("%08x", instId.Value) + ": " + getExceptionInfo(), LogLevel::Debug, -1, "LoadGhostFromUrlAsync");
        }

        if (gpsHint && (instId.Value == 0 || !isVisible)) {
            try {
                if (instId.Value != 0) gm.Ghost_Remove(instId);
            } catch {
                log("Failed to remove non-visible Ghost_Add instance before waypoint-synced fallback: " + Text::Format("%08x", instId.Value) + " " + getExceptionInfo(), LogLevel::Warning, -1, "LoadGhostFromUrlAsync");
            }
            instId = gm.Ghost_AddWaypointSynced(task.Ghost, useGhostLayer);
            addMode = "WaypointSynced";
            isVisible = false;
            try {
                isVisible = gm.Ghost_IsVisible(instId);
            } catch {
                log("Ghost visibility check failed for waypoint-synced id=" + Text::Format("%08x", instId.Value) + ": " + getExceptionInfo(), LogLevel::Debug, -1, "LoadGhostFromUrlAsync");
            }
        }

        MwId registeredId = instId;
        try {
            if (registeredId.Value == 0 && task.Ghost !is null && task.Ghost.Id.Value != 0) {
                registeredId = task.Ghost.Id;
                isVisible = gm.Ghost_IsVisible(registeredId);
            }
        } catch {
            log("Ghost registration fallback visibility check failed: " + getExceptionInfo(), LogLevel::Debug, -1, "LoadGhostFromUrlAsync");
        }

        log('Instance ID: ' + registeredId.GetName() + " / " + Text::Format("%08x", registeredId.Value), LogLevel::Info, 320, "LoadGhostFromUrlAsync");
        log("Ghost_Add mode: " + addMode + ", IsGhostLayer=" + (useGhostLayer ? "true" : "false") + ", urlSaysGps=" + (urlSaysGps ? "true" : "false") + (expectedTimeMs > 0 ? (", expectedTimeMs=" + expectedTimeMs) : ""), LogLevel::Info, 321, "LoadGhostFromUrlAsync");
        if (task.Ghost !is null && task.Ghost.Result !is null) {
            log("Ghost_Result.Time: " + task.Ghost.Result.Time, LogLevel::Info, 323, "LoadGhostFromUrlAsync");
        }
        log("Ghost_IsVisible: " + (isVisible ? "true" : "false"), LogLevel::Info, 325, "LoadGhostFromUrlAsync");

        bool addSucceeded = registeredId.Value != 0 || isVisible || (gpsHint && addMode == "WaypointSynced");
        if (!addSucceeded) {
            if (stagedFileKey.Length > 0) {
                string restoreErr;
                if (!Services::Storage::FileStore::RestoreFromGameStage(stagedFileKey, restoreErr) && restoreErr.Length > 0) {
                    log("Failed to restore staged file after Ghost_Add failure: " + restoreErr, LogLevel::Warning, 332, "LoadGhostFromUrlAsync");
                }
            }
            CleanupManagedFileAfterLoad(deleteManagedFileAfterLoad, srcFileId);
            log("Ghost_Add failed; not registering a loaded ghost entry.", LogLevel::Warning, 336, "LoadGhostFromUrlAsync");
            try { dfm.TaskResult_Release(task.Id); } catch {
                log("Failed to release Ghost_Download task result after Ghost_Add failure: " + getExceptionInfo(), LogLevel::Warning, -1, "LoadGhostFromUrlAsync");
            }
            return;
        }

        dfm.TaskResult_Release(task.Id);
        if (stagedFileKey.Length > 0) {
            string restoreErr;
            if (!Services::Storage::FileStore::RestoreFromGameStage(stagedFileKey, restoreErr) && restoreErr.Length > 0) {
                log("Failed to restore staged file after successful ghost load: " + restoreErr, LogLevel::Warning, 345, "LoadGhostFromUrlAsync");
            }
        }

        string finalFilePath = "";
        if (stagedFileKey.Length > 0) {
            auto storedRecord = Services::Storage::FileStore::GetByFileId(stagedFileKey);
            if (storedRecord !is null) finalFilePath = storedRecord.storedPath;
        }
        if (srcFileId.Length == 0 && stagedFileKey.Length > 0) srcFileId = stagedFileKey;
        if (srcFilePath.Length == 0 && finalFilePath.Length > 0) srcFilePath = finalFilePath;
        if (CleanupManagedFileAfterLoad(deleteManagedFileAfterLoad, srcFileId)) {
            srcFileId = "";
            srcFilePath = "";
        }
        LoadedRecords::RegisterGhost(task.Ghost, registeredId, srcKind, srcRef, srcMapUid, srcAccountId, useGhostLayer, srcFileId, srcFilePath);
    }
}
