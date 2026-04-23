namespace RecordManager {

    void RemoveAllRecords_KeepReferences() {
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return;
        gm.Ghost_RemoveAll();
        log("All ghosts removed.", LogLevel::Info, 7, "RemoveAllRecords_KeepReferences");
    }

    void RemoveAllRecords() {
        auto dataFileMgr = GameCtx::GetDFM();
        if (dataFileMgr is null) return;
        auto newGhosts = dataFileMgr.Ghosts;

        for (uint i = 0; i < newGhosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(newGhosts[i]);
            RemoveInstanceRecord(ghost.Id);
        }
    }

    void RemoveInstanceRecord(MwId instanceId) {
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return;
        gm.Ghost_Remove(instanceId);
        log("Record with the MwID of: " + instanceId.GetName() + " removed.", LogLevel::Info, 25, "RemoveInstanceRecord");
    }

    void RemovePBRecord() {
        auto dataFileMgr = GameCtx::GetDFM();
        if (dataFileMgr is null) return;
        auto newGhosts = dataFileMgr.Ghosts;

        for (uint i = 0; i < newGhosts.Length; i++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(newGhosts[i]);
            if (LoadedRecords::VisibleNickname(ghost) == "PB") {
                RemoveInstanceRecord(ghost.Id);
                return;
            }
        } 
    }

    void set_RecordDossard(MwId instanceId, const string &in dossard, vec3 color = vec3()) {
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return;
        gm.Ghost_SetDossard(instanceId, dossard, color);
        log("Record dossard set.", LogLevel::Info, 46, "RemovePBRecord");
    }

    bool IsRecordVisible(MwId instanceId) {
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return false;
        bool isVisible = gm.Ghost_IsVisible(instanceId);
        return isVisible;
    }

    bool IsRecordOver(MwId instanceId) {
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return false;
        bool isOver = gm.Ghost_IsReplayOver(instanceId);
        return isOver;
    }

    void AddRecordWithOffset(CGameGhostScript@ ghost, const int &in offset) {
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return;
        gm.Ghost_Add(ghost, true, offset);
        log("Ghost added with offset.", LogLevel::Info, 67, "AddRecordWithOffset");
    }

    string get_RecordNameFromId(MwId id) {
        auto dfm = GameCtx::GetDFM();
        if (dfm is null) return "";
        auto ghosts = dfm.Ghosts;
        if (ghosts.Length == 0) return "";

        for (uint i = 0; i < ghosts.Length; i++) {
            if (ghosts[i].Id.Value == id.Value) {
                return LoadedRecords::VisibleNickname(cast<CGameGhostScript@>(ghosts[i]));
            }
        }
        return "";
    }

    MwId[] get_RecordIdFromName(const string &in name) {
        array<MwId> ids;

        auto dfm = GameCtx::GetDFM();
        if (dfm is null) return ids;
        auto ghosts = dfm.Ghosts;
        if (ghosts.Length == 0) return ids;

        for (uint i = 0; i < ghosts.Length; i++) {
            if (LoadedRecords::VisibleNickname(cast<CGameGhostScript@>(ghosts[i])) == name) {
                ids.InsertLast(ghosts[i].Id);
            }
        }
        return ids;
    }

    string get_GhostInfo(MwId id) {
        auto dfm = GameCtx::GetDFM();
        if (dfm is null) return "";
        auto ghosts = dfm.Ghosts;
        if (ghosts.Length == 0) return "";

        for (uint i = 0; i < ghosts.Length; i++) {
            if (ghosts[i].Id.Value == id.Value) {
                auto ghost = ghosts[i];
                
                return "Nickname: " + LoadedRecords::VisibleNickname(ghost) + "\n"
                    + "Trigram: " + ghost.Trigram + "\n"
                    + "CountryPath: " + ghost.CountryPath + "\n"
                    + "Time: " + ghost.Result.Time + "\n"
                    + "StuntScore: " + ghost.Result.Score + "\n"
                    + "MwId: " + ghost.Id.Value + "\n";
            }
        }
        return "No ghost selected.";
    }

}