namespace SavedRecords {
    class SavedRecord {
        string id;
        string fileId;
        string fileName;
        string nickname;
        int time = -1;
        int score = 0;
        string source;
        string sourceRef;
        string mapUid;
        string accountId;
        string savedAt;
    }

    array<SavedRecord@> records;
    bool _dirty = true;
    bool _saving = false;

    void MarkDirty() { _dirty = true; }

    void RefreshIfNeeded() {
        if (!_dirty) return;
        _dirty = false;
        records.RemoveRange(0, records.Length);

        auto rows = Services::Storage::FileStore::GetSavedReplays();
        if (rows is null) return;

        for (uint i = 0; i < rows.Length; i++) {
            auto row = rows[i];
            if (row is null) continue;

            auto rec = SavedRecord();
            rec.id = row.savedId;
            rec.fileId = row.fileId;
            rec.nickname = row.nickname;
            rec.time = row.time;
            rec.score = row.score;
            rec.source = row.source;
            rec.sourceRef = row.sourceRef;
            rec.mapUid = row.mapUid;
            rec.accountId = row.accountId;
            rec.savedAt = row.savedAt;

            auto stored = Services::Storage::FileStore::GetByFileId(row.fileId);
            if (stored !is null) rec.fileName = stored.fileName;

            records.InsertLast(rec);
        }
    }

    LoadedRecords::LoadedItem@ _pendingSave;

    void SaveFromLoaded(LoadedRecords::LoadedItem@ it) {
        if (it is null || it.ghost is null) {
            NotifyError("No ghost data to save.");
            return;
        }
        if (_saving) {
            NotifyError("A save is already in progress.");
            return;
        }
        _saving = true;
        @_pendingSave = it;
        startnew(_DoSave);
    }

    string BuildSavedReplayBaseName(LoadedRecords::LoadedItem@ it, const string &in timeStamp) {
        string safeName = it is null || it.ghost is null ? "ghost" : Text::StripFormatCodes(it.ghost.Nickname);
        safeName = safeName.Replace(" ", "_").Replace(":", "-").Replace("/", "_")
                           .Replace("\\", "_").Replace("\"", "").Replace("<", "")
                           .Replace(">", "").Replace("|", "").Replace("?", "").Replace("*", "");
        if (safeName.Length == 0) safeName = "ghost";
        return safeName + "_" + timeStamp;
    }

    void _DoSave() {
        auto it = _pendingSave;
        @_pendingSave = null;
        if (it is null || it.ghost is null) { _saving = false; return; }

        string timeStamp = Time::FormatString("%Y%m%d_%H%M%S", Time::Stamp);
        string baseName = BuildSavedReplayBaseName(it, timeStamp);
        string fileId = Services::Storage::FileStore::BuildFileId(Services::Storage::FileStore::KIND_SAVED_REPLAY, baseName + "|" + it.mapUid + "|" + tostring(Time::Stamp));
        string tempRelPath = "Replays/ArbitraryRecordLoader/Tmp/ARL_save_" + fileId + ".Replay.Gbx";
        string tempAbsPath = IO::FromUserGameFolder(tempRelPath);
        string storedPath = Services::Storage::FileStore::BuildStoredFilePath(Services::Storage::FileStore::KIND_SAVED_REPLAY, fileId, ".Replay.Gbx");

        bool fileSaved = false;
        auto app = GetApp();
        if (app !is null && app.RootMap !is null && app.Network !is null && app.Network.ClientManiaAppPlayground !is null) {
            auto rootMap = cast<CGameCtnChallenge@>(app.RootMap);
            if (rootMap !is null) {
                auto task = app.Network.ClientManiaAppPlayground.DataFileMgr.Replay_Save(tempRelPath, rootMap, it.ghost);
                while (task.IsProcessing) { yield(); }
                if (task.HasSucceeded && IO::FileExists(tempAbsPath)) {
                    string storedDir = Path::GetDirectoryName(storedPath);
                    if (storedDir.Length > 0 && !IO::FolderExists(storedDir)) {
                        IO::CreateFolder(storedDir, true);
                    }
                    if (IO::FileExists(storedPath)) {
                        try { IO::Delete(storedPath); } catch {}
                    }
                    IO::Move(tempAbsPath, storedPath);
                    fileSaved = IO::FileExists(storedPath);
                }
            }
        }

        if (!fileSaved) {
            NotifyError("Could not save ghost.");
            _saving = false;
            return;
        }

        Services::Storage::FileStore::StoredFileRecord@ fileRecord = Services::Storage::FileStore::StoredFileRecord();
        fileRecord.fileId = fileId;
        fileRecord.kind = Services::Storage::FileStore::KIND_SAVED_REPLAY;
        fileRecord.sourceKind = int(it.source);
        fileRecord.fileName = Path::GetFileName(storedPath);
        fileRecord.storedPath = storedPath;
        fileRecord.originalFileName = baseName + ".Replay.Gbx";
        fileRecord.sourceRef = it.sourceRef;
        fileRecord.mapUid = it.mapUid;
        fileRecord.accountId = it.accountId;
        fileRecord.useGhostLayer = it.useGhostLayer;
        Services::Storage::FileStore::Upsert(fileRecord);

        Services::Storage::FileStore::SavedReplayRecord@ savedRow = Services::Storage::FileStore::SavedReplayRecord();
        savedRow.savedId = baseName;
        savedRow.fileId = fileId;
        savedRow.nickname = it.ghost.Nickname;
        savedRow.time = it.ghost.Result.Time;
        savedRow.score = it.ghost.Result.Score;
        savedRow.source = LoadedRecords::SourceKindToString(it.source);
        savedRow.sourceRef = it.sourceRef;
        savedRow.mapUid = it.mapUid;
        savedRow.accountId = it.accountId;
        savedRow.savedAt = Time::FormatString("%Y-%m-%d %H:%M:%S", Time::Stamp);
        Services::Storage::FileStore::UpsertSavedReplay(savedRow);

        MarkDirty();
        _saving = false;
        NotifyInfo("Saved: " + Text::StripFormatCodes(it.ghost.Nickname));
    }

    void ImportFile(const string &in filePath) {
        if (!IO::FileExists(filePath)) {
            NotifyError("Failed to import file: " + Path::GetFileName(filePath));
            return;
        }

        string originalFileName = Path::GetFileName(filePath);
        string timeStamp = Time::FormatString("%Y%m%d_%H%M%S", Time::Stamp);
        string baseName = (Path::GetFileName(filePath).Length > 0 ? Path::GetFileName(filePath) : "import") + "_" + timeStamp;
        string fileId = Services::Storage::FileStore::BuildFileId(Services::Storage::FileStore::KIND_SAVED_REPLAY, originalFileName + "|" + tostring(Time::Stamp));
        string ext = Services::Storage::FileStore::InferManagedExtension(originalFileName, ".Replay.Gbx");
        string storedPath;
        string ingestErr;
        if (!Services::Storage::FileStore::IngestExternalFileCopy(filePath, Services::Storage::FileStore::KIND_SAVED_REPLAY, fileId, ext, storedPath, ingestErr)) {
            NotifyError(ingestErr.Length > 0 ? ingestErr : ("Failed to import file: " + Path::GetFileName(filePath)));
            return;
        }

        Services::Storage::FileStore::StoredFileRecord@ fileRecord = Services::Storage::FileStore::StoredFileRecord();
        fileRecord.fileId = fileId;
        fileRecord.kind = Services::Storage::FileStore::KIND_SAVED_REPLAY;
        fileRecord.sourceKind = int(LoadedRecords::SourceKind::LocalFile);
        fileRecord.fileName = Path::GetFileName(storedPath);
        fileRecord.storedPath = storedPath;
        fileRecord.originalFileName = originalFileName;
        fileRecord.sourceRef = filePath;
        Services::Storage::FileStore::Upsert(fileRecord);

        Services::Storage::FileStore::SavedReplayRecord@ savedRow = Services::Storage::FileStore::SavedReplayRecord();
        savedRow.savedId = baseName;
        savedRow.fileId = fileId;
        savedRow.nickname = "";
        savedRow.time = -1;
        savedRow.score = 0;
        savedRow.source = "Import";
        savedRow.sourceRef = filePath;
        savedRow.savedAt = Time::FormatString("%Y-%m-%d %H:%M:%S", Time::Stamp);
        Services::Storage::FileStore::UpsertSavedReplay(savedRow);

        MarkDirty();
    }

    void DeleteRecord(uint idx) {
        if (idx >= records.Length) return;
        auto rec = records[idx];

        string fileId;
        string err;
        Services::Storage::FileStore::DeleteSavedReplay(rec.id, fileId, err);
        if (fileId.Length > 0) {
            Services::Storage::FileStore::DeleteStoredFile(fileId, err);
        }

        records.RemoveAt(idx);
    }

    void LoadRecord(uint idx) {
        if (idx >= records.Length) return;
        auto rec = records[idx];

        auto stored = Services::Storage::FileStore::GetByFileId(rec.fileId);
        if (stored is null || !IO::FileExists(stored.storedPath)) {
            NotifyError("Replay file not found: " + rec.fileName);
            return;
        }

        Domain::LoadRequest@ req = Domain::LoadRequest();
        req.selectorKind = Domain::SelectorKind::LocalFile;
        req.context = Domain::LoadContext::Saved;
        req.filePath = stored.storedPath;
        req.mapUid = rec.mapUid;
        req.accountId = rec.accountId;
        req.useGhostLayer = GhostLoader::S_UseGhostLayer;
        req.cacheFile = true;
        req.forceRefresh = false;
        req.sourceKind = LoadedRecords::SourceKind::Replay;
        req.sourceRef = rec.sourceRef.Length > 0 ? rec.sourceRef : stored.storedPath;

        Services::LoadQueue::Enqueue(req);
    }
}
