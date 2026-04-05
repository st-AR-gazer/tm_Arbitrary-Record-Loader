namespace Features {
namespace LRFromMapIdentifier {
    // Backwards-compatible entrypoint; all record loading now routes through RecordLoadService.
    void LoadSelectedRecord(const string &in mapUid, const string &in offset, const string &in specialSaveLocation, const string &in accountId = "", const string &in mapId = "", const string &in seasonId = "") {
        if (mapUid.Trim().Length == 0) { NotifyWarn("Map UID is empty."); return; }

        int rankOffset = 0;
        try {
            rankOffset = Text::ParseInt(offset.Trim());
        } catch {
            rankOffset = 0;
        }
        if (rankOffset < 0) rankOffset = 0;

        RecordLoadService::RecordLoadRequest@ req = RecordLoadService::RecordLoadRequest();
        req.mapUid = mapUid;
        req.rankOffset = rankOffset;
        req.accountId = accountId;
        req.mapId = mapId;
        req.seasonId = seasonId;
        req.saveLocation = specialSaveLocation;
        req.useGhostLayer = GhostLoader::S_UseGhostLayer;
        req.forceRefresh = false;
        req.sourceKind = RecordLoadService::DefaultSourceKind(req);

        RecordLoadService::Enqueue(req);
    }
}
}
