namespace SavedRecords {
    class SavedRecord {
        string id;
        string nickname;
        int time = -1;
        int score = 0;
        string source;
        string sourceRef;
        string mapUid;
        string accountId;
        string savedAt;
        string replayFileName;
        string jsonFileName;
    }

    array<SavedRecord@> records;
    bool _dirty = true;
    bool _saving = false;

    void MarkDirty() { _dirty = true; }

    void RefreshIfNeeded() {
        if (!_dirty) return;
        _dirty = false;
        records.RemoveRange(0, records.Length);

        array<string>@ files = IO::IndexFolder(Server::savedJsonDirectory, true);
        if (files is null) return;

        for (uint i = 0; i < files.Length; i++) {
            if (!files[i].ToLower().EndsWith(".json")) continue;
            auto rec = _LoadFromJson(files[i]);
            if (rec !is null) records.InsertLast(rec);
        }
    }

    SavedRecord@ _LoadFromJson(const string &in path) {
        string content = _IO::File::ReadFileToEnd(path);
        if (content.Length == 0) return null;

        Json::Value json = Json::Parse(content);
        if (json.GetType() == Json::Type::Null) return null;

        auto rec = SavedRecord();
        rec.id = string(json["id"]);
        rec.nickname = string(json["nickname"]);
        rec.time = int(json["time"]);
        rec.score = int(json["score"]);
        rec.source = string(json["source"]);
        rec.sourceRef = string(json["sourceRef"]);
        rec.mapUid = string(json["mapUid"]);
        rec.accountId = string(json["accountId"]);
        rec.savedAt = string(json["savedAt"]);
        rec.replayFileName = string(json["replayFileName"]);
        rec.jsonFileName = Path::GetFileName(path);
        return rec;
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

    void _DoSave() {
        auto it = _pendingSave;
        @_pendingSave = null;
        if (it is null || it.ghost is null) { _saving = false; return; }

        string timeStamp = Time::FormatString("%Y%m%d_%H%M%S", Time::Stamp);
        string safeName = Text::StripFormatCodes(it.ghost.Nickname);
        safeName = safeName.Replace(" ", "_").Replace(":", "-").Replace("/", "_")
                           .Replace("\\", "_").Replace("\"", "").Replace("<", "")
                           .Replace(">", "").Replace("|", "").Replace("?", "").Replace("*", "");
        if (safeName.Length == 0) safeName = "ghost";
        string baseName = safeName + "_" + timeStamp;
        string replayFileName = baseName + ".Replay.Gbx";
        string jsonFileName = baseName + ".json";

        string destPath = Server::savedFilesDirectory + replayFileName;
        bool saved = false;

        if (it.sourceRef.Length > 0 && IO::FileExists(it.sourceRef)) {
            _IO::File::CopyFileTo(it.sourceRef, destPath);
            saved = IO::FileExists(destPath);
        }

        if (!saved && it.sourceRef.Length > 0) {
            string stagingPath = Server::serverDirectoryAutoMove + Path::GetFileName(it.sourceRef);
            if (IO::FileExists(stagingPath)) {
                _IO::File::CopyFileTo(stagingPath, destPath);
                saved = IO::FileExists(destPath);
            }
        }

        if (!saved) {
            auto app = GetApp();
            if (app !is null && app.RootMap !is null && app.Network !is null
                && app.Network.ClientManiaAppPlayground !is null) {
                auto rootMap = cast<CGameCtnChallenge@>(app.RootMap);
                if (rootMap !is null) {
                    string relTmpPath = "Replays/ArbitraryRecordLoader/Tmp/" + replayFileName;
                    auto task = app.Network.ClientManiaAppPlayground.DataFileMgr.Replay_Save(relTmpPath, rootMap, it.ghost);
                    while (task.IsProcessing) { yield(); }
                    if (task.HasSucceeded) {
                        string absTmpPath = IO::FromUserGameFolder(relTmpPath);
                        if (IO::FileExists(absTmpPath)) {
                            _IO::File::CopyFileTo(absTmpPath, destPath);
                            IO::Delete(absTmpPath);
                            saved = IO::FileExists(destPath);
                        }
                    }
                }
            }
        }

        if (!saved) {
            NotifyError("Could not save ghost — no source file found.");
            _saving = false;
            return;
        }

        Json::Value json = Json::Object();
        json["id"] = baseName;
        json["nickname"] = it.ghost.Nickname;
        json["time"] = it.ghost.Result.Time;
        json["score"] = it.ghost.Result.Score;
        json["source"] = LoadedRecords::SourceKindToString(it.source);
        json["sourceRef"] = it.sourceRef;
        json["mapUid"] = it.mapUid;
        json["accountId"] = it.accountId;
        json["savedAt"] = Time::FormatString("%Y-%m-%d %H:%M:%S", Time::Stamp);
        json["replayFileName"] = replayFileName;

        _IO::File::WriteFile(Server::savedJsonDirectory + jsonFileName, Json::Write(json, true));

        MarkDirty();
        _saving = false;

        NotifyInfo("Saved: " + Text::StripFormatCodes(it.ghost.Nickname));
    }

    void ImportFile(const string &in filePath) {
        string originalFileName = Path::GetFileName(filePath);
        string destPath = Server::savedFilesDirectory + originalFileName;

        if (IO::FileExists(destPath)) {
            string ts = Time::FormatString("%Y%m%d_%H%M%S", Time::Stamp);
            int dotIdx = originalFileName.LastIndexOf(".");
            string nameBase = (dotIdx > 0) ? originalFileName.SubStr(0, dotIdx) : originalFileName;
            string ext = (dotIdx > 0) ? originalFileName.SubStr(dotIdx) : "";
            originalFileName = nameBase + "_" + ts + ext;
            destPath = Server::savedFilesDirectory + originalFileName;
        }

        _IO::File::CopyFileTo(filePath, destPath);
        if (!IO::FileExists(destPath)) {
            NotifyError("Failed to import file: " + Path::GetFileName(filePath));
            return;
        }

        string timeStamp = Time::FormatString("%Y%m%d_%H%M%S", Time::Stamp);
        int dotIdx = originalFileName.LastIndexOf(".");
        string baseName = (dotIdx > 0) ? originalFileName.SubStr(0, dotIdx) : originalFileName;
        string jsonFileName = baseName + ".json";

        Json::Value json = Json::Object();
        json["id"] = baseName;
        json["nickname"] = "";
        json["time"] = -1;
        json["score"] = 0;
        json["source"] = "Import";
        json["sourceRef"] = filePath;
        json["mapUid"] = "";
        json["accountId"] = "";
        json["savedAt"] = Time::FormatString("%Y-%m-%d %H:%M:%S", Time::Stamp);
        json["replayFileName"] = originalFileName;

        _IO::File::WriteFile(Server::savedJsonDirectory + jsonFileName, Json::Write(json, true));

        MarkDirty();
    }

    void DeleteRecord(uint idx) {
        if (idx >= records.Length) return;
        auto rec = records[idx];

        string replayPath = Server::savedFilesDirectory + rec.replayFileName;
        string jsonPath = Server::savedJsonDirectory + rec.jsonFileName;

        if (IO::FileExists(replayPath)) IO::Delete(replayPath);
        if (IO::FileExists(jsonPath)) IO::Delete(jsonPath);

        records.RemoveAt(idx);
    }

    void LoadRecord(uint idx) {
        if (idx >= records.Length) return;
        auto rec = records[idx];

        string replayPath = Server::savedFilesDirectory + rec.replayFileName;
        if (!IO::FileExists(replayPath)) {
            NotifyError("Replay file not found: " + rec.replayFileName);
            return;
        }

        LoadedRecords::TrackPendingFile(
            Path::GetFileName(replayPath),
            LoadedRecords::SourceKind::LocalFile,
            replayPath,
            rec.mapUid,
            rec.accountId,
            GhostLoader::S_UseGhostLayer
        );

        GhostLoader::LoadGhostFromLocalFile(replayPath);
    }
}
