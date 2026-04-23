namespace EntryPoints {
namespace CurrentMap {
namespace Medals {

    const string CCM_MEDAL_INFO_URL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vRc12yiAEsQAvJ80knzkhRsBfu5Mp5Az6yrg1XLO8OhfkN58VjB1Vwd4AK7OmJVtCwmmlE5k_iokWDD/pub?gid=0&single=true&output=csv";

    bool g_CcmDataRequested = false;
    bool g_CcmDataLoaded = false;
    bool g_CcmDataFailed = false;
    dictionary g_CcmTargetScores;

    bool IsCCMAvailable() {
        return PluginState::IsPluginLoaded("CCM", "Custom Campaign Medal");
    }

    string StripCCMField(const string &in value) {
        string trimmed = value.Trim();
        if (trimmed.StartsWith("\"") && trimmed.EndsWith("\"") && trimmed.Length >= 2) {
            return trimmed.SubStr(1, trimmed.Length - 2);
        }
        return trimmed;
    }

    void ResetCCMState() {
        g_CcmDataRequested = false;
        g_CcmDataLoaded = false;
        g_CcmDataFailed = false;
        g_CcmTargetScores.DeleteAll();
    }

    void EnsureCCMDataRequested() {
        if (g_CcmDataRequested || g_CcmDataLoaded || g_CcmDataFailed) return;
        g_CcmDataRequested = true;
        startnew(CoroutineFunc(LoadCCMData));
    }

    void LoadCCMData() {
        auto req = Net::HttpRequest();
        req.Method = Net::HttpMethod::Get;
        req.Url = CCM_MEDAL_INFO_URL;
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            g_CcmDataFailed = true;
            log("CCM medal info request failed with HTTP " + req.ResponseCode(), LogLevel::Warning, 46, "LoadCCMData");
            return;
        }

        string csv = req.String();
        auto lines = csv.Split("\n");
        for (uint i = 0; i < lines.Length; i++) {
            string line = lines[i].Trim();
            if (line.Length == 0) continue;

            auto parts = line.Split(",");
            if (parts.Length < 2) continue;

            string mapUid = StripCCMField(parts[0]);
            string scoreText = StripCCMField(parts[1]);
            if (mapUid.Length == 0) continue;

            uint targetScore = 0;
            if (!Text::TryParseUInt(scoreText, targetScore)) continue;
            g_CcmTargetScores[mapUid] = targetScore;
        }

        g_CcmDataLoaded = true;
    }

    uint TryGetCCMTime() {
        if (!IsCCMAvailable()) return 0;
        EnsureCCMDataRequested();
        if (!g_CcmDataLoaded) return 0;

        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return 0;

        uint targetScore = 0;
        if (!g_CcmTargetScores.Get(mapUid, targetScore)) return 0;
        return targetScore;
    }

    CCMMedal ccmMedal;
    class CCMMedal : PluginMedalWithoutExport {}
    void RefreshCCMMedal() {
        UpdatePluginMedalWithoutExportState(ccmMedal, TryGetCCMTime());
    }

    void AppendCCMDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "CCM", "\\$ddd", ccmMedal, IsCCMAvailable());
    }
}
}
}
