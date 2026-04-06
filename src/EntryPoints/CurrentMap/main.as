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

    void OnMapLoad() {
        ValidationReplay::OnMapLoad();
        Medals::OnMapLoad();
        // GPS is intentionally disabled for now while the extraction flow is being redesigned.
        // Keep the implementation in EntryPoints/CurrentMap/GPS.as for the later pass.
        // GPS::OnMapLoad();
    }
}
}
