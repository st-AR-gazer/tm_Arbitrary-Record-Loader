namespace EntryPoints {
namespace CurrentMap {
namespace Medals {

    class DisplayEntry {
        string label;
        string colorCode;
        string iconText;
        Medal@ medal;
        bool depPresent;
    }

    void OnMapLoad() {
        g_lastExternalRefreshMapUid = "";
        g_nextExternalRefreshAt = 0;
        ResetCustomMedalsState();
        RefreshPluginMedalSources();
        StartDedicatedMedalRefresh();
    }

    void StartDedicatedMedalRefresh() {
        startnew(CoroutineFunc(authorMedal.OnMapLoad));
        startnew(CoroutineFunc(goldMedal.OnMapLoad));
        startnew(CoroutineFunc(silverMedal.OnMapLoad));
        startnew(CoroutineFunc(bronzeMedal.OnMapLoad));
        startnew(CoroutineFunc(autoGoldMedal.OnMapLoad));
        startnew(CoroutineFunc(autoSilverMedal.OnMapLoad));
        startnew(CoroutineFunc(autoBronzeMedal.OnMapLoad));
    }

    array<DisplayEntry@>@ GetDisplayEntriesSorted() {
        EnsurePluginMedalSourcesFresh();
        array<DisplayEntry@>@ entries = array<DisplayEntry@>();

        AppendNadeoDisplayEntries(entries);
        AppendPluginDisplayEntries(entries);

        return GetSortedDisplayEntries(entries);
    }

    array<DisplayEntry@>@ GetSortedDisplayEntries(array<DisplayEntry@>@ entries) {
        array<DisplayEntry@>@ sorted = array<DisplayEntry@>();
        if (entries is null || entries.Length == 0) return sorted;

        bool desc = IsStuntMode();
        array<bool> used(entries.Length, false);

        for (uint count = 0; count < entries.Length; count++) {
            int bestIx = -1;
            for (uint i = 0; i < entries.Length; i++) {
                if (used[i]) continue;

                auto candidate = entries[i];
                if (candidate is null || candidate.medal is null) {
                    used[i] = true;
                    continue;
                }

                if (bestIx < 0) {
                    bestIx = i;
                    continue;
                }

                auto best = entries[bestIx];
                if (best is null || best.medal is null) {
                    bestIx = i;
                    continue;
                }

                uint lhs = best.medal.currentMapMedalTime;
                uint rhs = candidate.medal.currentMapMedalTime;
                bool candidateFirst = desc ? rhs > lhs : rhs < lhs;
                if (candidateFirst) bestIx = i;
            }

            if (bestIx < 0) break;
            used[bestIx] = true;
            sorted.InsertLast(entries[bestIx]);
        }

        return sorted;
    }

    void AddDisplayEntry(array<DisplayEntry@>@ entries, const string &in label, const string &in colorCode, Medal@ medal, bool depPresent, const string &in iconText = "") {
        if (entries is null || medal is null || !depPresent || !medal.ShouldRender()) return;
        DisplayEntry@ entry = DisplayEntry();
        entry.label = label;
        entry.colorCode = colorCode;
        entry.iconText = iconText;
        @entry.medal = medal;
        entry.depPresent = depPresent;
        entries.InsertLast(entry);
    }

    void AppendNadeoDisplayEntries(array<DisplayEntry@>@ entries) {
        AppendAuthorDisplayEntry(entries);
        AppendGoldDisplayEntry(entries);
        AppendSilverDisplayEntry(entries);
        AppendBronzeDisplayEntry(entries);
        AppendAutoGoldDisplayEntry(entries);
        AppendAutoSilverDisplayEntry(entries);
        AppendAutoBronzeDisplayEntry(entries);
    }

    void AppendPluginDisplayEntries(array<DisplayEntry@>@ entries) {
        AppendPluginDisplayEntriesWithExports(entries);
        AppendPluginDisplayEntriesWithoutExports(entries);
    }

    void AppendPluginDisplayEntriesWithExports(array<DisplayEntry@>@ entries) {
        AppendChampionDisplayEntry(entries);
        AppendWarriorDisplayEntry(entries);
        AppendS314keDisplayEntry(entries);
        AppendPlayerDisplayEntry(entries);
        AppendSBVilleDisplayEntry(entries);
    }

    void AppendPluginDisplayEntriesWithoutExports(array<DisplayEntry@>@ entries) {
        AppendAdeptDisplayEntries(entries);
        AppendDuckDisplayEntry(entries);
        AppendGlacialDisplayEntry(entries);
        AppendMilkDisplayEntry(entries);
        AppendCustomMedalsDisplayEntries(entries);
    }

    enum AutoMedalKind {
        Gold = 0,
        Silver,
        Bronze
    }

    CGameCtnChallengeParameters@ GetChallengeParams() {
        auto rootMap = GetApp().RootMap;
        if (rootMap is null) return null;
        return rootMap.ChallengeParameters;
    }

    bool IsExpectedMapStillLoaded(const string &in expectedMapUid) {
        if (expectedMapUid.Length == 0) return false;
        return CurrentMap::GetMapUid() == expectedMapUid;
    }

    string GetCurrentMapType() {
        auto rootMap = GetApp().RootMap;
        if (rootMap is null) return "";

        string mapType = string(rootMap.MapType);
        if (mapType.Length > 0) return mapType;

        return string(rootMap.MapTypeOrLegacyMode);
    }

    bool IsStuntMode() {
        string mapType = GetCurrentMapType();
        return mapType == "TrackMania\\TM_Stunt" || mapType == "Trackmania\\TM_Stunt";
    }

    bool IsPlatformMode() {
        string mapType = GetCurrentMapType();
        return mapType == "TrackMania\\TM_Platform" || mapType == "Trackmania\\TM_Platform";
    }

    bool IsRoyalMode() {
        string mapType = GetCurrentMapType();
        return mapType == "TrackMania\\TM_Royal" || mapType == "Trackmania\\TM_Royal";
    }

#if DEPENDENCY_ADEPTMEDALS
    namespace ImportedAdeptMedals {
        import bool IsIgnoredMode() from "AdeptMedals";
    }
#endif

    bool IsAdeptMedalsAvailable() {
        auto plugin = Meta::GetPluginFromID("AdeptMedals");
        if (plugin !is null) return true;

        auto plugins = Meta::AllPlugins();
        for (uint i = 0; i < plugins.Length; i++) {
            auto loadedPlugin = plugins[i];
            if (loadedPlugin is null) continue;
            if (loadedPlugin.Name == "Adept Medals") return true;
        }
        return false;
    }

    bool IsAdeptMedalsIgnoredMode() {
#if DEPENDENCY_ADEPTMEDALS
        try {
            return ImportedAdeptMedals::IsIgnoredMode();
        } catch {}
#endif
        return IsStuntMode() || IsPlatformMode() || IsRoyalMode();
    }

    uint ComputeAdeptMedalTime(float gapRatio) {
        if (!IsAdeptMedalsAvailable() || IsAdeptMedalsIgnoredMode()) return 0;

        auto params = GetChallengeParams();
        if (params is null) return 0;

        uint goldTime = params.GoldTime;
        uint authorTime = params.AuthorTime;
        if (goldTime == 0 || authorTime == 0 || goldTime <= authorTime) return 0;

        int gap = int(goldTime) - int(authorTime);
        return uint(int(goldTime) - int(float(gap) * gapRatio));
    }

    uint ComputeAutoMedalTime(uint authorTime, AutoMedalKind kind) {
        if (authorTime == 0) return 0;

        if (IsStuntMode()) {
            switch (kind) {
                case AutoMedalKind::Gold:   return uint(Math::Floor(float(authorTime) * 0.085f) * 10.0f);
                case AutoMedalKind::Silver: return uint(Math::Floor(float(authorTime) * 0.060f) * 10.0f);
                case AutoMedalKind::Bronze: return uint(Math::Floor(float(authorTime) * 0.037f) * 10.0f);
            }
        } else if (IsPlatformMode()) {
            switch (kind) {
                case AutoMedalKind::Gold:   return authorTime + 3;
                case AutoMedalKind::Silver: return authorTime + 10;
                case AutoMedalKind::Bronze: return authorTime + 30;
            }
        } else {
            switch (kind) {
                case AutoMedalKind::Gold:   return uint((Math::Floor(float(authorTime) * 0.00106f) + 1.0f) * 1000.0f);
                case AutoMedalKind::Silver: return uint((Math::Floor(float(authorTime) * 0.00120f) + 1.0f) * 1000.0f);
                case AutoMedalKind::Bronze: return uint((Math::Floor(float(authorTime) * 0.00150f) + 1.0f) * 1000.0f);
            }
        }

        return 0;
    }

    class Medal {
        bool medalExists = false;
        uint currentMapMedalTime = 0;
        int timeDifference = 0;
        bool medalHasExactMatch = false;
        bool reqForCurrentMapFinished = false;
        bool showWhenMissing = true;

        void AddMedal() {
            if (medalExists) startnew(CoroutineFunc(FetchSurroundingRecords));
        }

        void OnMapLoad() {
            ResetState();
            string expectedMapUid = CurrentMap::GetMapUid();
            if (!WaitForMedalTime(expectedMapUid)) return;
            if (!IsExpectedMapStillLoaded(expectedMapUid)) return;
            medalExists = true;
            currentMapMedalTime = GetMedalTime();
        }

        void ResetState() {
            medalExists = false;
            currentMapMedalTime = 0;
            timeDifference = 0;
            medalHasExactMatch = false;
            reqForCurrentMapFinished = false;
        }

        bool ShouldRender() const {
            return showWhenMissing || medalExists;
        }

        bool WaitForMedalTime(const string &in expectedMapUid) {
            int startTime = Time::Now;
            while (Time::Now - startTime < 2000 && GetMedalTime() == 0) {
                if (!IsExpectedMapStillLoaded(expectedMapUid)) return false;
                yield();
            }
            if (!IsExpectedMapStillLoaded(expectedMapUid)) return false;
            return GetMedalTime() > 0;
        }

        void FetchSurroundingRecords() {
            if (!medalExists) return;

            string mapUid = CurrentMap::GetMapUid();
            if (mapUid.Length == 0) return;

            string url = "https://live-services.trackmania.nadeo.live/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/surround/1/1?score=" + currentMapMedalTime;
            RequestThrottle::WaitForSlot("Surrounding records");
            auto req = NadeoServices::Get("NadeoLiveServices", url);
            req.Start();

            while (!req.Finished()) { yield(); }
            if (req.ResponseCode() != 200) return;

            Json::Value data = Json::Parse(req.String());
            if (data.GetType() == Json::Type::Null) return;

            auto tops = data["tops"];
            if (tops.GetType() != Json::Type::Array || tops.Length == 0) return;
            auto top = tops[0]["top"];
            if (top.GetType() != Json::Type::Array || top.Length == 0) return;

            int smallestDifference = int(0x7FFFFFFF);
            string closestAccountId;
            int closestPosition = -1;
            bool exactMatchFound = false;

            for (uint i = 0; i < top.Length; i++) {
                if (i == top.Length / 2) continue;

                uint score = top[i]["score"];
                string accountId = top[i]["accountId"];
                int position = top[i]["position"];
                int difference = int(currentMapMedalTime) - int(score);

                if (difference == 0) {
                    closestAccountId = accountId;
                    closestPosition = position;
                    smallestDifference = difference;
                    exactMatchFound = true;
                    break;
                } else if (difference > 0 && difference < smallestDifference) {
                    closestAccountId = accountId;
                    closestPosition = position;
                    smallestDifference = difference;
                }
            }

            if (closestAccountId.Length > 0) {
                timeDifference = smallestDifference;
                medalHasExactMatch = exactMatchFound;
                loadRecord.LoadRecordFromMapUid(mapUid, tostring(closestPosition), "Medal", closestAccountId);
            }

            reqForCurrentMapFinished = true;
        }

        uint GetMedalTime() { return 0; }
    }

    class AutoMedal : Medal {
        AutoMedal() {
            showWhenMissing = false;
        }

        void OnMapLoad() override {
            ResetState();
            string expectedMapUid = CurrentMap::GetMapUid();
            if (!IsExpectedMapStillLoaded(expectedMapUid)) return;

            int startTime = Time::Now;
            while (Time::Now - startTime < 2000 && GetMedalTime() == 0) {
                if (!IsExpectedMapStillLoaded(expectedMapUid)) return;
                yield();
            }
            if (!IsExpectedMapStillLoaded(expectedMapUid)) return;

            uint authorTime = GetMedalTime();
            if (authorTime == 0) return;

            uint autoTime = ComputeAutoMedalTime(authorTime, GetAutoKind());
            if (autoTime == 0) return;

            uint actualTime = GetActualMapMedalTime();
            if (actualTime == 0 || actualTime == autoTime) return;

            medalExists = true;
            currentMapMedalTime = autoTime;
        }

        AutoMedalKind GetAutoKind() { return AutoMedalKind::Gold; }
        uint GetActualMapMedalTime() { return 0; }
    }

    class UnsupportedPluginMedal : Medal {
        UnsupportedPluginMedal() {
            showWhenMissing = false;
        }

        uint GetMedalTime() override {
            return 0;
        }
    }

    class PluginMedalWithExport : Medal {
        PluginMedalWithExport() {
            showWhenMissing = false;
        }

        uint GetMedalTime() override {
            return currentMapMedalTime;
        }
    }

    class PluginMedalWithoutExport : Medal {
        PluginMedalWithoutExport() {
            showWhenMissing = false;
        }

        uint GetMedalTime() override {
            return currentMapMedalTime;
        }
    }

    void UpdatePluginMedalWithoutExportState(PluginMedalWithoutExport@ medal, uint time) {
        if (medal is null) return;

        if (time == 0) {
            medal.ResetState();
            return;
        }

        medal.medalExists = true;
        medal.currentMapMedalTime = time;
    }

    // ------------------------------------------------
    // Nadeo Medals
    // ------------------------------------------------

    // ---------------- Author ----------------
    namespace AuthorMedalNs { AuthorMedal medal; }
    AuthorMedal authorMedal;
    class AuthorMedal : Medal {
        uint GetMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.AuthorTime;
        }
    }
    void AppendAuthorDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Author", "\\$7e0", authorMedal, true);
    }

    // ---------------- Gold ----------------
    namespace GoldMedalNs { GoldMedal medal; }
    GoldMedal goldMedal;
    class GoldMedal : Medal {
        uint GetMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.GoldTime;
        }
    }
    void AppendGoldDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Gold", "\\$fd0", goldMedal, true);
    }

    // ---------------- Silver ----------------
    namespace SilverMedalNs { SilverMedal medal; }
    SilverMedal silverMedal;
    class SilverMedal : Medal {
        uint GetMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.SilverTime;
        }
    }
    void AppendSilverDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Silver", "\\$ddd", silverMedal, true);
    }

    // ---------------- Bronze ----------------
    namespace BronzeMedalNs { BronzeMedal medal; }
    BronzeMedal bronzeMedal;
    class BronzeMedal : Medal {
        uint GetMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.BronzeTime;
        }
    }
    void AppendBronzeDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Bronze", "\\$c73", bronzeMedal, true);
    }

    // ---------------- Auto Gold ----------------
    AutoGoldMedal autoGoldMedal;
    class AutoGoldMedal : AutoMedal {
        uint GetMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.AuthorTime;
        }

        AutoMedalKind GetAutoKind() override {
            return AutoMedalKind::Gold;
        }

        uint GetActualMapMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.GoldTime;
        }
    }
    void AppendAutoGoldDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Auto Gold", "\\$db0", autoGoldMedal, true);
    }

    // ---------------- Auto Silver ----------------
    AutoSilverMedal autoSilverMedal;
    class AutoSilverMedal : AutoMedal {
        uint GetMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.AuthorTime;
        }

        AutoMedalKind GetAutoKind() override {
            return AutoMedalKind::Silver;
        }

        uint GetActualMapMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.SilverTime;
        }
    }
    void AppendAutoSilverDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Auto Silver", "\\$bbb", autoSilverMedal, true);
    }

    // ---------------- Auto Bronze ----------------
    AutoBronzeMedal autoBronzeMedal;
    class AutoBronzeMedal : AutoMedal {
        uint GetMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.AuthorTime;
        }

        AutoMedalKind GetAutoKind() override {
            return AutoMedalKind::Bronze;
        }

        uint GetActualMapMedalTime() override {
            auto params = GetChallengeParams();
            return params is null ? 0 : params.BronzeTime;
        }
    }
    void AppendAutoBronzeDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Auto Bronze", "\\$a62", autoBronzeMedal, true);
    }


    // ------------------------------------------------
    // Plugin Medals (With Export)
    // ------------------------------------------------
    
    const uint EXTERNAL_MEDAL_REFRESH_INTERVAL_MS = 1000;
    uint g_nextExternalRefreshAt = 0;
    string g_lastExternalRefreshMapUid = "";
    bool g_s314keFetchInFlight = false;
    string g_s314keFetchMapUid = "";
    const string S314KE_ACCOUNT_ID = "5f9c2a43-593f-4e84-a64d-82319058dd3a";
    const string S314KE_LOGIN = "X5wqQ1k_ToSmTYIxkFjdOg";

    void EnsurePluginMedalSourcesFresh() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) {
            ResetPluginMedalsWithExports();
            ResetCustomMedalsState();
            g_lastExternalRefreshMapUid = "";
            g_nextExternalRefreshAt = 0;
            return;
        }

        bool mapChanged = mapUid != g_lastExternalRefreshMapUid;
        if (mapChanged) {
            ResetPluginMedalsWithExports();
            ResetCustomMedalsState();
            g_lastExternalRefreshMapUid = mapUid;
        }

        if (!mapChanged && Time::Now < g_nextExternalRefreshAt) return;

        g_nextExternalRefreshAt = Time::Now + EXTERNAL_MEDAL_REFRESH_INTERVAL_MS;
        RefreshPluginMedalSources();
    }

    void ResetPluginMedalsWithExports() {
        champMedal.ResetState();
        warriorMedal.ResetState();
        sbVilleMedal.ResetState();
        s314keMedal.ResetState();
        g_s314keFetchInFlight = false;
        g_s314keFetchMapUid = "";
    }

    void UpdatePluginMedalWithExportState(PluginMedalWithExport@ medal, uint time) {
        if (medal is null) return;

        if (time == 0) {
            medal.ResetState();
            return;
        }

        medal.medalExists = true;
        medal.currentMapMedalTime = time;
    }

    uint TryGetChampionTime() {
#if DEPENDENCY_CHAMPIONMEDALS
        try {
            return ChampionMedals::GetCMTime();
        } catch {
            log("Champion medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 511, "CurrentMap::Medals");
        }
#endif
        return 0;
    }

    uint TryGetWarriorTime() {
#if DEPENDENCY_WARRIORMEDALS
        try {
            return WarriorMedals::GetWMTime();
        } catch {
            log("Warrior medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 521, "CurrentMap::Medals");
        }
#endif
        return 0;
    }

    uint TryGetSBVilleTime() {
#if DEPENDENCY_SBVILLECAMPAIGNCHALLENGES
        try {
            return SBVilleCampaignChallenges::getChallengeTime();
        } catch {
            log("SBVille medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 531, "CurrentMap::Medals");
        }
#endif
        return 0;
    }

// ---------------- Champion ----------------
    ChampionMedal champMedal;

    class ChampionMedal : PluginMedalWithExport {}
    void RefreshChampionMedal() {
        UpdatePluginMedalWithExportState(champMedal, TryGetChampionTime());
    }
    void AppendChampionDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Champion", "\\$e79", champMedal, true);
    }

// ---------------- Warrior ----------------
    WarriorMedal warriorMedal;
    class WarriorMedal : PluginMedalWithExport {}
    void RefreshWarriorMedal() {
        UpdatePluginMedalWithExportState(warriorMedal, TryGetWarriorTime());
    }
    void AppendWarriorDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Warrior", "\\$0cf", warriorMedal, true);
    }

// ---------------- s314ke ----------------
    S314keMedal s314keMedal;
    class S314keMedal : PluginMedalWithExport {
        void AddMedal() override {
            if (medalExists) startnew(CoroutineFunc(LoadPreferredGhost));
        }

        void LoadPreferredGhost() {
            string mapUid = CurrentMap::GetMapUid();
            if (mapUid.Length == 0) return;

            reqForCurrentMapFinished = false;
            medalHasExactMatch = false;
            timeDifference = 0;

            array<Services::LoadQueue::MapInfoCandidate@> candidates;
            string replayUrl = Services::LoadQueue::ResolveReplayUrlFallback(mapUid, S314KE_ACCOUNT_ID, "", "", candidates);
            if (replayUrl.Length > 0) {
                medalHasExactMatch = true;
                timeDifference = 0;
                reqForCurrentMapFinished = true;
                loadRecord.LoadRecordFromMapUid(mapUid, "1", "Medal", S314KE_ACCOUNT_ID);
                return;
            }

            FetchSurroundingRecords();
        }
    }
    void Coro_RefreshS314keMedal() {
        string expectedMapUid = g_s314keFetchMapUid;
        uint medalTime = 0;

#if DEPENDENCY_S314KEMEDALS
        try {
            medalTime = s314keMedals::GetS314keMedalTime();
        } catch {
            log("s314ke medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 526, "CurrentMap::Medals");
        }
#endif

        if (expectedMapUid == CurrentMap::GetMapUid()) {
            UpdatePluginMedalWithExportState(s314keMedal, medalTime);
        }

        if (g_s314keFetchMapUid == expectedMapUid) {
            g_s314keFetchInFlight = false;
        }
    }

    void RefreshS314keMedal() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) {
            s314keMedal.ResetState();
            g_s314keFetchInFlight = false;
            g_s314keFetchMapUid = "";
            return;
        }

        if (g_s314keFetchMapUid != mapUid) {
            s314keMedal.ResetState();
            g_s314keFetchMapUid = mapUid;
            g_s314keFetchInFlight = false;
        }

        if (g_s314keFetchInFlight) return;

        g_s314keFetchInFlight = true;
        startnew(CoroutineFunc(Coro_RefreshS314keMedal));
    }
    void AppendS314keDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "s314ke", "\\$36c", s314keMedal, true);
    }

// ---------------- SB Ville ----------------
    SBVilleMedal sbVilleMedal;
    class SBVilleMedal : PluginMedalWithExport {}
    void RefreshSBVilleMedal() {
        UpdatePluginMedalWithExportState(sbVilleMedal, TryGetSBVilleTime());
    }
    void AppendSBVilleDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "SB Ville", "\\$f90", sbVilleMedal, true);
    }

    // ------------------------------------------------
    // Plugin Medals (Without Export)
    // ------------------------------------------------

// ---------------- Adept ----------------
    class Adept1Medal : PluginMedalWithoutExport {}
    Adept1Medal adept1Medal;
    void RefreshAdept1Medal() {
        UpdatePluginMedalWithoutExportState(adept1Medal, ComputeAdeptMedalTime(0.40f));
    }

    class Adept2Medal : PluginMedalWithoutExport {}
    Adept2Medal adept2Medal;
    void RefreshAdept2Medal() {
        UpdatePluginMedalWithoutExportState(adept2Medal, ComputeAdeptMedalTime(0.60f));
    }

    class Adept3Medal : PluginMedalWithoutExport {}
    Adept3Medal adept3Medal;
    void RefreshAdept3Medal() {
        UpdatePluginMedalWithoutExportState(adept3Medal, ComputeAdeptMedalTime(0.80f));
    }

    void RefreshAdeptMedals() {
        RefreshAdept1Medal();
        RefreshAdept2Medal();
        RefreshAdept3Medal();
    }

    void AppendAdeptDisplayEntries(array<DisplayEntry@>@ entries) {
        bool depPresent = IsAdeptMedalsAvailable();
        AddDisplayEntry(entries, "Adept I", "\\$0ef", adept1Medal, depPresent);
        AddDisplayEntry(entries, "Adept II", "\\$a5f", adept2Medal, depPresent);
        AddDisplayEntry(entries, "Adept III", "\\$f39", adept3Medal, depPresent);
    }

// ---------------- Duck ----------------
    UnsupportedPluginMedal duckMedal;
    void AppendDuckDisplayEntry(array<DisplayEntry@>@ entries) {
        // Tbh I CBA to implement for this since this is only a medal that is avalible in what? tm2? who even plays that Chatting
    }

// ---------------- Glacial ----------------
    UnsupportedPluginMedal glacialMedal;
    void AppendGlacialDisplayEntry(array<DisplayEntry@>@ entries) {
        // TODO: Add Glacial Medals integration.
    }

// ---------------- Milk ----------------
    UnsupportedPluginMedal milkMedal;
    void AppendMilkDisplayEntry(array<DisplayEntry@>@ entries) {
        // TODO: Add Milk Medals integration.
    }

// ---------------- Custom Medals ----------------
#if DEPENDENCY_CUSTOMMEDALS
    namespace ImportedCustomMedals {
        import string GetCustomMedalsJson() from "CustomMedals";
    }
#endif

    class CustomMedalsPluginMedal : Medal {
        string displayName = "";
        string displayColorCode = "\\$fff";

        CustomMedalsPluginMedal() {
            showWhenMissing = false;
        }

        uint GetMedalTime() override {
            return currentMapMedalTime;
        }
    }

    array<CustomMedalsPluginMedal@> g_CustomMedalsPluginMedals;

    void ResetCustomMedalsState() {
        g_CustomMedalsPluginMedals.RemoveRange(0, g_CustomMedalsPluginMedals.Length);
    }

    bool IsCustomMedalsAvailable() {
#if DEPENDENCY_CUSTOMMEDALS
        return Meta::GetPluginFromID("CustomMedals") !is null;
#else
        return false;
#endif
    }

    void RefreshCustomMedalsPluginMedals() {
        g_CustomMedalsPluginMedals.RemoveRange(0, g_CustomMedalsPluginMedals.Length);
        if (!IsCustomMedalsAvailable()) return;

#if DEPENDENCY_CUSTOMMEDALS
        try {
            Json::Value medals = Json::Parse(ImportedCustomMedals::GetCustomMedalsJson());
            if (medals.GetType() != Json::Type::Array) return;

            for (uint i = 0; i < medals.Length; i++) {
                auto item = medals[i];
                if (item.GetType() != Json::Type::Object) continue;

                int medalTime = int(item["time"]);
                if (medalTime <= 0) continue;
                if (bool(item["isPb"])) continue;

                auto medal = CustomMedalsPluginMedal();
                medal.displayName = string(item["name"]);
                if (medal.displayName.Length == 0) medal.displayName = "Custom Medal";

                string iconColor = string(item["iconColor"]);
                if (iconColor.Length == 0) iconColor = "fff";
                medal.displayColorCode = "\\$" + iconColor;
                medal.currentMapMedalTime = uint(medalTime);
                medal.medalExists = true;
                g_CustomMedalsPluginMedals.InsertLast(medal);
            }
        } catch {
            log("Custom medals export lookup failed: " + getExceptionInfo(), LogLevel::Warning, 1068, "CurrentMap::Medals");
        }
#endif
    }

    void AppendCustomMedalsDisplayEntries(array<DisplayEntry@>@ entries) {
        for (uint i = 0; i < g_CustomMedalsPluginMedals.Length; i++) {
            auto medal = g_CustomMedalsPluginMedals[i];
            if (medal is null) continue;
            AddDisplayEntry(entries, medal.displayName, medal.displayColorCode, medal, true);
        }
    }

    void RefreshPluginMedalsWithExports() {
        RefreshChampionMedal();
        RefreshWarriorMedal();
        RefreshS314keMedal();
        RefreshPlayerMedal();
        RefreshSBVilleMedal();
    }

    void RefreshPluginMedalsWithoutExports() {
        RefreshAdeptMedals();
        RefreshCustomMedalsPluginMedals();
    }

    void RefreshPluginMedalSources() {
        RefreshPluginMedalsWithExports();
        RefreshPluginMedalsWithoutExports();
    }
}
}
}
