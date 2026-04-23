namespace EntryPoints {
namespace CurrentMap {
    string GetSafeMapName() {
        auto root = GetApp().RootMap;
        if (root is null || root.MapInfo is null) return "";
        return Path::SanitizeFileName(Text::StripFormatCodes(root.MapInfo.Name));
    }

    string GetMapUid() {
        return get_CurrentMapUID();
    }

    bool IsMapLoaded() {
        return GetApp().RootMap !is null;
    }

    void OnMapLeave() {
        LoadedRecords::UnloadAndClearAll();
        EntryPoints::MapUid::OnMapChanged();
    }

    void OnMapLoad() {
        LoadedRecords::RecoverMarkedGhostsFromGame();
        EntryPoints::MapUid::OnMapChanged();
        ValidationReplay::OnMapLoad();
        Medals::OnMapLoad();
        GPS::OnMapLoad();
#if DEPENDENCY_MLHOOK
        MLHookGhosts::OnMapLoad();
#endif
    }
}
}
