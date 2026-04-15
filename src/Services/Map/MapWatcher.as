namespace MapTracker {
    string oldMapUid = "";

    [Setting category="General" name="Enable Ghosts" hidden]
    bool enableGhosts = true;

    void MapMonitor() {
        while (true) {    
            sleep(273);

            bool mapChanged = HasMapChanged();

            if (mapChanged && oldMapUid.Length > 0) {
                EntryPoints::CurrentMap::OnMapLeave();
            }

            if (!enableGhosts) {
                if (mapChanged) oldMapUid = get_CurrentMapUID();
                continue;
            }

            if (mapChanged) {
                while (!_Game::IsPlayingMap()) yield();

                AllowCheck::InitializeAllowCheckWithTimeout(2000);
                if (AllowCheck::ConditionCheckMet()) {
                    EntryPoints::CurrentMap::OnMapLoad();
                } else {
                    NotifyWarning("Map is not allowed to load records: " + AllowCheck::DisallowReason());
                }
            }

            if (HasMapChanged()) oldMapUid = get_CurrentMapUID();
        }
    }

    bool HasMapChanged() {
        return oldMapUid != get_CurrentMapUID();
    }
}

string get_CurrentMapUID() {
    if (_Game::IsMapLoaded()) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return "";
        CGameCtnChallenge@ map = app.RootMap;
        if (map is null) return "";
        return map.MapInfo.MapUid;
    }
    return "";
}

string get_CurrentMapName() {
    if (_Game::IsMapLoaded()) {
        CTrackMania@ app = cast<CTrackMania>(GetApp());
        if (app is null) return "";
        CGameCtnChallenge@ map = app.RootMap;
        if (map is null) return "";
        return map.MapInfo.Name;
    }
    return "";
}
