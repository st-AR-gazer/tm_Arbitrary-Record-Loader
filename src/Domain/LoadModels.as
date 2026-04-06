namespace Domain {

    enum SelectorKind {
        MapRecord = 0,
        LocalFile,
        Url
    }

    enum LoadContext {
        AnyMap = 0,
        Official,
        Profile,
        Medal,
        PlayerId,
        Saved,
        Url,
        LocalFile
    }

    string LoadContextToString(LoadContext ctx) {
        switch (ctx) {
            case LoadContext::AnyMap: return "AnyMap";
            case LoadContext::Official: return "Official";
            case LoadContext::Profile: return "Profile";
            case LoadContext::Medal: return "Medal";
            case LoadContext::PlayerId: return "PlayerId";
            case LoadContext::Saved: return "Saved";
            case LoadContext::Url: return "Url";
            case LoadContext::LocalFile: return "LocalFile";
            default: return "Unknown";
        }
    }

    class LoadRequest {
        SelectorKind selectorKind = SelectorKind::MapRecord;
        LoadContext context = LoadContext::AnyMap;

        LoadedRecords::SourceKind sourceKind = LoadedRecords::SourceKind::Unknown;
        string sourceRef = "";

        bool useGhostLayer = true;
        bool forceRefresh = false;

        string mapUid = "";
        int rankOffset = 0;
        string accountId = "";
        string mapId = "";
        string seasonId = "";

        string filePath = "";

        string url = "";
    }
}
