namespace LoadedRecords {
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

    class LoadedItem {
        MwId instId;
        bool isLoaded = true;

        SourceKind source = SourceKind::Unknown;
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
        string sourceRef = "";
        string mapUid = "";
        string accountId = "";
        bool useGhostLayer = true;
    }

    void Clear() {
        items.RemoveRange(0, items.Length);
        auto keys = pendingByFileName.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            pendingByFileName.Delete(keys[i]);
        }
    }

    void TrackPendingFile(const string &in fileName, SourceKind source, const string &in sourceRef = "", const string &in mapUid = "", const string &in accountId = "", bool useGhostLayer = true) {
        if (fileName.Length == 0) return;
        PendingMeta@ meta = PendingMeta();
        meta.source = source;
        meta.sourceRef = sourceRef;
        meta.mapUid = mapUid;
        meta.accountId = accountId;
        meta.useGhostLayer = useGhostLayer;
        pendingByFileName.Set(fileName, @meta);
    }

    PendingMeta@ ConsumePendingFile(const string &in fileName) {
        if (fileName.Length == 0) return null;
        if (!pendingByFileName.Exists(fileName)) return null;
        PendingMeta@ meta;
        ref@ metaRef;
        pendingByFileName.Get(fileName, @metaRef);
        @meta = cast<PendingMeta@>(metaRef);
        pendingByFileName.Delete(fileName);
        return meta;
    }

    LoadedItem@ FindByInstId(MwId id) {
        for (uint i = 0; i < items.Length; i++) {
            if (items[i] !is null && items[i].instId.Value == id.Value) return items[i];
        }
        return null;
    }

    LoadedItem@ FindByAccountId(const string &in accountId) {
        for (uint i = 0; i < items.Length; i++) {
            if (items[i] !is null && items[i].accountId == accountId) return items[i];
        }
        return null;
    }

    void RegisterGhost(CGameGhostScript@ ghost, MwId instId, SourceKind source, const string &in sourceRef = "", const string &in mapUid = "", const string &in accountId = "", bool useGhostLayer = true) {
        auto it = LoadedItem();
        it.instId = instId;
        it.isLoaded = true;
        it.source = source;
        it.sourceRef = sourceRef;
        it.mapUid = mapUid;
        it.accountId = accountId;
        it.loadedAt = Time::Now;
        @it.ghost = ghost;
        it.useGhostLayer = useGhostLayer;
        items.InsertLast(it);
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
        it.instId = gm.Ghost_Add(it.ghost, it.useGhostLayer);
        it.isLoaded = true;

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
}