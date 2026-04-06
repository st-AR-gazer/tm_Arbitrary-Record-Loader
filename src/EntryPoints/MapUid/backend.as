namespace EntryPoints {
namespace MapUid {
    void LoadSelectedRecord(const string &in mapUid, const string &in offset, const string &in specialSaveLocation, const string &in accountId = "", const string &in mapId = "", const string &in seasonId = "") {
        loadRecord.LoadRecordFromMapUid(mapUid, offset, specialSaveLocation, accountId, mapId, seasonId);
    }
}
}
