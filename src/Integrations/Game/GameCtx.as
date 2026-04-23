namespace GameCtx {
    uint16 g_CSmArenaInterfaceUI_GhostMgrOffset = 0;
    bool g_CSmArenaInterfaceUI_GhostMgrOffsetInit = false;

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

    uint16 GetOffset(const string &in className, const string &in memberName) {
        auto ty = Reflection::GetType(className);
        if (ty is null) return 0;
        auto memberTy = ty.GetMember(memberName);
        if (memberTy is null) return 0;
        return memberTy.Offset;
    }

    uint16 GetPlaygroundGhostMgrOffset() {
        if (!g_CSmArenaInterfaceUI_GhostMgrOffsetInit) {
            g_CSmArenaInterfaceUI_GhostMgrOffsetInit = true;

            uint16 manialinkPageOffset = GetOffset("CSmArenaInterfaceUI", "ManialinkPage");
            if (manialinkPageOffset > 0) {
                g_CSmArenaInterfaceUI_GhostMgrOffset = manialinkPageOffset - (0x518 - 0x500);
            } else {
                uint16 hud3dOffset = GetOffset("CSmArenaInterfaceUI", "Hud3d");
                if (hud3dOffset > 0) {
                    g_CSmArenaInterfaceUI_GhostMgrOffset = hud3dOffset + (0x500 - 0x418);
                }
            }

            if (g_CSmArenaInterfaceUI_GhostMgrOffset > 0) {
                log("Resolved online GhostMgr offset: 0x" + Text::Format("%x", g_CSmArenaInterfaceUI_GhostMgrOffset), LogLevel::Info, 50, "GetPlaygroundGhostMgrOffset");
            } else {
                log("Failed to resolve online GhostMgr offset", LogLevel::Warning, 52, "GetPlaygroundGhostMgrOffset");
            }
        }
        return g_CSmArenaInterfaceUI_GhostMgrOffset;
    }

    CGameGhostMgrScript@ GetPlaygroundGhostMgr() {
        auto app = cast<CGameCtnApp>(GetApp());
        if (app is null) return null;

        auto pg = cast<CSmArenaClient>(app.CurrentPlayground);
        if (pg is null) return null;
        if (pg.Interface is null) return null;

        uint16 offset = GetPlaygroundGhostMgrOffset();
        if (offset == 0) return null;

        auto nod = Dev::GetOffsetNod(pg.Interface, offset);
        if (nod is null) return null;
        return cast<CGameGhostMgrScript>(nod);
    }

    CGameGhostMgrScript@ GetGhostMgr() {
        auto cmap = GetCMap();
        if (cmap !is null && cmap.GhostMgr !is null) return cmap.GhostMgr;

        auto pgGhostMgr = GetPlaygroundGhostMgr();
        if (pgGhostMgr !is null) return pgGhostMgr;

        return null;
    }

    CGameGhostMgrScript@ WaitForGhostMgr(uint timeout = 15000) {
        uint startTime = Time::Now;
        while (Time::Now - startTime <= timeout) {
            auto gm = GetGhostMgr();
            if (gm !is null) return gm;
            yield();
        }
        return null;
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
