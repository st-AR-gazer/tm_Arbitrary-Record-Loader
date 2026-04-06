LoadRecord@ loadRecord;

class LoadRecord {
    void LoadRecordFromLocalFile(const string &in filePath) {
        Domain::LoadRequest@ req = Domain::LoadRequest();
        req.selectorKind = Domain::SelectorKind::LocalFile;
        req.context = Domain::LoadContext::LocalFile;
        req.filePath = filePath;
        req.useGhostLayer = GhostLoader::S_UseGhostLayer;
        req.forceRefresh = false;
        req.sourceKind = LoadedRecords::SourceKind::LocalFile;
        req.sourceRef = filePath;
        Services::LoadQueue::Enqueue(req);
    }

    void LoadRecordFromLocalFile(string[] filePaths) {
        for (uint i = 0; i < filePaths.Length; i++) {
            LoadRecordFromLocalFile(filePaths[i]);
        }
    }

    void LoadRecordFromUrl(const string &in url) {
        string normalized = url.Trim();
        if (normalized.Length == 0) { NotifyWarning("Invalid URL."); return; }

        if (!normalized.StartsWith("https://") && !normalized.StartsWith("http://")) {
            if (normalized.StartsWith("www.") || normalized.Contains("trackmania.exchange")) {
                normalized = "https://" + normalized;
            }
        }

        if (normalized.StartsWith("https://") || normalized.StartsWith("http://")) {
            Domain::LoadRequest@ req = Domain::LoadRequest();
            req.selectorKind = Domain::SelectorKind::Url;
            req.context = Domain::LoadContext::Url;
            req.url = normalized;
            req.useGhostLayer = GhostLoader::S_UseGhostLayer;
            req.forceRefresh = false;
            req.sourceKind = LoadedRecords::SourceKind::Url;
            req.sourceRef = url;
            Services::LoadQueue::Enqueue(req);
        } else {
            log("Invalid URL.", LogLevel::Error, 58, "LoadRecordFromUrl");
            NotifyWarning("Invalid URL.");
        }
    }

    void LoadRecordFromMapUid(const string &in mapUid, const string &in offset, const string &in _specialSaveLocation, const string &in _accountId = "", const string &in _mapId = "", const string &in _seasonId = "") {
        if (mapUid.Trim().Length == 0) { NotifyWarning("Map UID is empty."); return; }

        int rankOffset = 0;
        try {
            rankOffset = Text::ParseInt(offset.Trim());
        } catch {
            rankOffset = 0;
        }
        if (rankOffset < 0) rankOffset = 0;

        Domain::LoadRequest@ req = Domain::LoadRequest();
        req.selectorKind = Domain::SelectorKind::MapRecord;
        req.mapUid = mapUid;
        req.rankOffset = rankOffset;
        req.accountId = _accountId;
        req.mapId = _mapId;
        req.seasonId = _seasonId;

        if (_specialSaveLocation == "Official") req.context = Domain::LoadContext::Official;
        else if (_specialSaveLocation == "OtherMaps") req.context = Domain::LoadContext::Profile;
        else if (_specialSaveLocation == "Medal") req.context = Domain::LoadContext::Medal;
        else if (_specialSaveLocation == "PlayerId") req.context = Domain::LoadContext::PlayerId;
        else req.context = Domain::LoadContext::AnyMap;

        req.useGhostLayer = GhostLoader::S_UseGhostLayer;
        req.forceRefresh = false;
        req.sourceKind = Services::LoadQueue::DefaultSourceKind(req);

        Services::LoadQueue::Enqueue(req);
    }

    void LoadRecordFromPlayerId(const string &in _accountId) {
        if (_accountId.Trim().Length == 0) { NotifyWarning("Player Id is empty."); return; }
        string mapUid = get_CurrentMapUID();
        if (mapUid.Length == 0) { NotifyWarning("No map loaded. Player Id loading requires a current map."); return; }
        LoadRecordFromMapUid(mapUid, "0", "PlayerId", _accountId);
    }

}
