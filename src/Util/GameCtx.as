namespace GameCtx {
    CTrackMania@ GetTmApp() {
        return cast<CTrackMania>(GetApp());
    }

    CGameCtnNetwork@ GetNetwork() {
        auto app = GetTmApp();
        if (app is null) return null;
        return cast<CGameCtnNetwork>(app.Network);
    }

    CGameManiaAppPlayground@ GetCMap() {
        auto net = GetNetwork();
        if (net is null) return null;
        return cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
    }

    CGameDataFileManagerScript@ GetDFM() {
        auto cmap = GetCMap();
        if (cmap is null) return null;
        return cmap.DataFileMgr;
    }

    CGameGhostMgrScript@ GetGhostMgr() {
        auto cmap = GetCMap();
        if (cmap is null) return null;
        return cmap.GhostMgr;
    }

    bool IsBackendReady() {
        return GetCMap() !is null && GetDFM() !is null && GetGhostMgr() !is null;
    }

    string GetModeName() {
        auto net = GetNetwork();
        if (net is null) return "";
        auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
        if (cnsi is null) return "";
        return cnsi.ModeName;
    }
}

