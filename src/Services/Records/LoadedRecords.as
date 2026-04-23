namespace LoadedRecords {
    const string ARL_HIDDEN_MARKER = "$ARL";
    const string ARL_NICKNAME_MARKER = " $A$R$L$z";

    enum SourceKind {
        Unknown = 0,
        LocalFile,
        Url,
        MapRecord,
        Official,
        Profile,
        PlayerId,
        Replay
    }

    string SourceKindToString(SourceKind k) {
        switch (k) {
            case SourceKind::LocalFile: return "Local File";
            case SourceKind::Url: return "URL";
            case SourceKind::MapRecord: return "Map Record";
            case SourceKind::Official: return "Official";
            case SourceKind::Profile: return "Profile";
            case SourceKind::PlayerId: return "Player Id";
            case SourceKind::Replay: return "Replay";
            default: return "Unknown";
        }
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
        try { return Text::ParseInt(sourceRef.SubStr(start, end - start)); } catch {}
        return -1;
    }

    string TryParseStorageObjectUuid(const string &in sourceRef) {
        if (sourceRef.Length == 0) return "";
        int idx = sourceRef.IndexOf("so=");
        if (idx < 0) return "";
        int start = idx + 3;
        if (start >= int(sourceRef.Length)) return "";
        int end = start;
        while (end < int(sourceRef.Length)) {
            int c = int(sourceRef[uint(end)]);
            bool isHex = (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102);
            if (!isHex) break;
            end++;
        }
        if (end <= start) return "";
        return sourceRef.SubStr(start, end - start).ToLower();
    }

    class LoadedItem {
        MwId instId;
        bool isLoaded = true;

        SourceKind source = SourceKind::Unknown;
        string fileId = "";
        string filePath = "";
        string sourceRef = "";
        string mapUid = "";
        string accountId = "";

        uint loadedAt = 0;

        CGameGhostScript@ ghost = null;

        string dossard = "";

        bool useGhostLayer = true;
    }

    array<LoadedItem@> items;
    dictionary pendingByFileName;

    class PendingMeta {
        SourceKind source = SourceKind::Unknown;
        string fileId = "";
        string filePath = "";
        string sourceRef = "";
        string mapUid = "";
        string accountId = "";
        bool useGhostLayer = true;
        bool deleteManagedFileAfterLoad = false;
    }

    bool HasHiddenMarker(const string &in value) {
        return value.EndsWith(ARL_HIDDEN_MARKER);
    }

    bool HasNicknameMarker(const string &in value) {
        return value.EndsWith(ARL_NICKNAME_MARKER);
    }

    string StripHiddenMarker(const string &in value) {
        if (!HasHiddenMarker(value)) return value;
        return value.SubStr(0, value.Length - ARL_HIDDEN_MARKER.Length);
    }

    string StripNicknameMarker(const string &in value) {
        if (!HasNicknameMarker(value)) return value;
        return value.SubStr(0, value.Length - ARL_NICKNAME_MARKER.Length);
    }

    string VisibleIdName(CGameGhostScript@ ghost) {
        if (ghost is null) return "";
        return StripHiddenMarker(string(ghost.IdName));
    }

    string VisibleNickname(CGameGhostScript@ ghost) {
        if (ghost is null) return "";
        return StripNicknameMarker(string(ghost.Nickname));
    }

    bool IsMarkedGhost(CGameGhostScript@ ghost) {
        if (ghost is null) return false;
        return HasHiddenMarker(string(ghost.IdName)) || HasNicknameMarker(string(ghost.Nickname));
    }

    void EnsureHiddenMarker(CGameGhostScript@ ghost) {
        if (ghost is null || HasHiddenMarker(string(ghost.IdName))) return;
        ghost.IdName = string(ghost.IdName) + ARL_HIDDEN_MARKER;
    }

    void EnsureNicknameMarker(CGameGhostScript@ ghost) {
        if (ghost is null || HasNicknameMarker(string(ghost.Nickname))) return;
        ghost.Nickname = StripNicknameMarker(string(ghost.Nickname)) + ARL_NICKNAME_MARKER;
    }

    void EnsureArlMarkers(CGameGhostScript@ ghost) {
        EnsureHiddenMarker(ghost);
        EnsureNicknameMarker(ghost);
    }

    void ClearHiddenMarker(CGameGhostScript@ ghost) {
        if (ghost is null || !HasHiddenMarker(string(ghost.IdName))) return;
        ghost.IdName = StripHiddenMarker(string(ghost.IdName));
    }

    void ClearNicknameMarker(CGameGhostScript@ ghost) {
        if (ghost is null || !HasNicknameMarker(string(ghost.Nickname))) return;
        ghost.Nickname = StripNicknameMarker(string(ghost.Nickname));
    }

    void ClearArlMarkers(CGameGhostScript@ ghost) {
        ClearHiddenMarker(ghost);
        ClearNicknameMarker(ghost);
    }

    string NormalizePendingFileKey(const string &in fileName) {
        return fileName.Trim().ToLower();
    }

    void Clear() {
        for (uint i = 0; i < items.Length; i++) {
            if (items[i] !is null) ClearArlMarkers(items[i].ghost);
        }
        items.RemoveRange(0, items.Length);
        auto keys = pendingByFileName.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            pendingByFileName.Delete(keys[i]);
        }
    }

    void TrackPendingFile(const string &in fileName, SourceKind source, const string &in sourceRef = "", const string &in mapUid = "", const string &in accountId = "", bool useGhostLayer = true, const string &in fileId = "", const string &in filePath = "", bool deleteManagedFileAfterLoad = false) {
        string key = NormalizePendingFileKey(fileName);
        if (key.Length == 0) return;
        PendingMeta@ meta = PendingMeta();
        meta.source = source;
        meta.fileId = fileId;
        meta.filePath = filePath;
        meta.sourceRef = sourceRef;
        meta.mapUid = mapUid;
        meta.accountId = accountId;
        meta.useGhostLayer = useGhostLayer;
        meta.deleteManagedFileAfterLoad = deleteManagedFileAfterLoad;
        pendingByFileName.Set(key, @meta);
    }

    PendingMeta@ ConsumePendingFile(const string &in fileName) {
        string key = NormalizePendingFileKey(fileName);
        if (key.Length == 0) return null;
        if (!pendingByFileName.Exists(key)) return null;
        PendingMeta@ meta;
        ref@ metaRef;
        pendingByFileName.Get(key, @metaRef);
        @meta = cast<PendingMeta@>(metaRef);
        pendingByFileName.Delete(key);
        return meta;
    }

    LoadedItem@ FindByInstId(MwId id) {
        for (uint i = 0; i < items.Length; i++) {
            if (items[i] !is null && items[i].instId.Value == id.Value) return items[i];
        }
        return null;
    }

    void ForgetAt(uint idx) {
        if (idx >= items.Length) return;
        if (items[idx] !is null) ClearArlMarkers(items[idx].ghost);
        items.RemoveAt(idx);
    }

    void RecoverMarkedGhostsFromGame() {
        auto dfm = GameCtx::GetDFM();
        if (dfm is null) return;

        for (uint i = 0; i < dfm.Ghosts.Length; i++) {
            auto ghost = cast<CGameGhostScript@>(dfm.Ghosts[i]);
            if (ghost is null || !IsMarkedGhost(ghost)) continue;

            MwId instId = ghost.Id;
            if (instId.Value == 0 || FindByInstId(instId) !is null) continue;

            RegisterGhost(ghost, instId, SourceKind::Unknown, "Recovered ARL ghost");
        }
    }

    LoadedItem@ FindByAccountId(const string &in accountId) {
        for (uint i = 0; i < items.Length; i++) {
            if (items[i] !is null && items[i].accountId == accountId) return items[i];
        }
        return null;
    }

    void RegisterGhost(CGameGhostScript@ ghost, MwId instId, SourceKind source, const string &in sourceRef = "", const string &in mapUid = "", const string &in accountId = "", bool useGhostLayer = true, const string &in fileId = "", const string &in filePath = "") {
        EnsureArlMarkers(ghost);

        if (ghost !is null && accountId.Trim().Length > 0) {
            string observedName = Text::StripFormatCodes(VisibleNickname(ghost)).Trim();
            if (observedName.Length == 0) observedName = Text::StripFormatCodes(VisibleIdName(ghost)).Trim();
            if (observedName.Length > 0) {
                PlayerDirectory::ObserveAccountDisplayName(accountId, observedName, "arl-loaded-ghost");
            }
        }

        auto it = FindByInstId(instId);
        if (it is null) {
            @it = LoadedItem();
            items.InsertLast(it);
        }

        it.instId = instId;
        it.isLoaded = true;
        it.source = source;
        it.fileId = fileId;
        it.filePath = filePath;
        it.sourceRef = sourceRef;
        it.mapUid = mapUid;
        it.accountId = accountId;
        it.loadedAt = Time::Now;
        @it.ghost = ghost;
        it.useGhostLayer = useGhostLayer;
    }

    void Unload(LoadedItem@ it) {
        if (it is null || !it.isLoaded) return;
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return;
        gm.Ghost_Remove(it.instId);
        it.isLoaded = false;
    }

    void Reload(LoadedItem@ it) {
        if (it is null || it.isLoaded) return;
        if (it.ghost is null) return;
        auto gm = GameCtx::GetGhostMgr();
        if (gm is null) return;
        EnsureArlMarkers(it.ghost);
        bool gpsHint = it.source == SourceKind::Replay && it.sourceRef.StartsWith("GPS | ");
        it.instId = gm.Ghost_Add(it.ghost, it.useGhostLayer);
        bool isVisible = false;
        try {
            isVisible = gm.Ghost_IsVisible(it.instId);
        } catch {}
        if (gpsHint && (it.instId.Value == 0 || !isVisible)) {
            try {
                if (it.instId.Value != 0) gm.Ghost_Remove(it.instId);
            } catch {}
            it.instId = gm.Ghost_AddWaypointSynced(it.ghost, it.useGhostLayer);
            try {
                isVisible = gm.Ghost_IsVisible(it.instId);
            } catch {}
        }
        try {
            if (it.instId.Value == 0 && it.ghost !is null && it.ghost.Id.Value != 0) {
                it.instId = it.ghost.Id;
                isVisible = gm.Ghost_IsVisible(it.instId);
            }
        } catch {}
        it.isLoaded = it.instId.Value != 0 || isVisible || gpsHint;

        if (it.dossard.Length > 0) {
            try {
                gm.Ghost_SetDossard(it.instId, it.dossard, vec3());
            } catch {}
        }
    }

    void UnloadAll() {
        for (uint i = 0; i < items.Length; i++) {
            Unload(items[i]);
        }
    }

    void UnloadAndClearAll() {
        UnloadAll();
        Clear();
    }
}
