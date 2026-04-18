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
        // AppendPlayerDisplayEntry(entries);
        AppendGlacialDisplayEntry(entries);
        AppendChallengeDisplayEntry(entries);
        AppendMilkDisplayEntry(entries);
        AppendCustomMedalsDisplayEntries(entries);
        AppendSBVilleDisplayEntry(entries);
    }

    void AppendPluginDisplayEntriesWithoutExports(array<DisplayEntry@>@ entries) {
        AppendAdeptDisplayEntries(entries);
        AppendCCMDisplayEntry(entries);
        AppendDuckDisplayEntry(entries);
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
        return PluginState::IsPluginLoaded("AdeptMedals", "Adept Medals");
    }

    bool IsChampionMedalsAvailable() {
        return PluginState::IsPluginLoaded("ChampionMedals", "Champion Medals");
    }

    bool IsWarriorMedalsAvailable() {
        return PluginState::IsPluginLoaded("WarriorMedals", "Warrior Medals");
    }

    bool IsSBVilleCampaignChallengesAvailable() {
        return PluginState::IsPluginLoaded("SBVilleCampaignChallenges", "SBVilleCampaignChallenges");
    }

    bool IsS314keMedalsAvailable() {
        return PluginState::IsPluginLoaded("s314keMedals", "s314keMedals");
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
        bool loadedGhostBeatsMedal = true;
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
            loadedGhostBeatsMedal = true;
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

        bool CanResolveReplayForCandidate(const string &in mapUid, const string &in accountId, const array<Services::LoadQueue::MapInfoCandidate@> &in mapInfoCandidates) {
            if (mapUid.Length == 0 || accountId.Length == 0) return false;
            string replayUrl = Services::LoadQueue::ResolveReplayUrlFallback(mapUid, accountId, "", "", mapInfoCandidates);
            return replayUrl.Length > 0;
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

            string exactAccountId;
            int exactPosition = -1;

            int fastestBetterDifference = int(0x7FFFFFFF);
            string betterAccountId;
            int betterPosition = -1;

            int slowestWorseDifference = int(0x7FFFFFFF);
            string worseAccountId;
            int worsePosition = -1;

            for (uint i = 0; i < top.Length; i++) {
                if (top.Length > 2 && i == top.Length / 2) continue;

                uint score = top[i]["score"];
                string accountId = top[i]["accountId"];
                int position = top[i]["position"];
                if (accountId.Length == 0 || position < 1) continue;
                int difference = int(currentMapMedalTime) - int(score);

                if (difference == 0) {
                    exactAccountId = accountId;
                    exactPosition = position;
                } else if (difference > 0 && difference < fastestBetterDifference) {
                    betterAccountId = accountId;
                    betterPosition = position;
                    fastestBetterDifference = difference;
                } else if (difference < 0 && -difference < slowestWorseDifference) {
                    worseAccountId = accountId;
                    worsePosition = position;
                    slowestWorseDifference = -difference;
                }
            }

            array<Services::LoadQueue::MapInfoCandidate@> mapInfoCandidates = Services::LoadQueue::ResolveMapInfoCandidates(mapUid);

            if (exactAccountId.Length > 0 && CanResolveReplayForCandidate(mapUid, exactAccountId, mapInfoCandidates)) {
                timeDifference = 0;
                medalHasExactMatch = true;
                loadedGhostBeatsMedal = true;
                loadRecord.LoadRecordFromMapUid(mapUid, tostring(exactPosition), "Medal", exactAccountId);
            } else if (betterAccountId.Length > 0 && CanResolveReplayForCandidate(mapUid, betterAccountId, mapInfoCandidates)) {
                timeDifference = fastestBetterDifference;
                medalHasExactMatch = false;
                loadedGhostBeatsMedal = true;
                loadRecord.LoadRecordFromMapUid(mapUid, tostring(betterPosition), "Medal", betterAccountId);
            } else if (worseAccountId.Length > 0 && CanResolveReplayForCandidate(mapUid, worseAccountId, mapInfoCandidates)) {
                timeDifference = slowestWorseDifference;
                medalHasExactMatch = false;
                loadedGhostBeatsMedal = false;
                loadRecord.LoadRecordFromMapUid(mapUid, tostring(worsePosition), "Medal", worseAccountId);
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

    void EnsurePluginMedalSourcesFresh() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) {
            ResetPluginMedalsWithExports();
            ResetCustomMedalsState();
            ResetCCMState();
            g_lastExternalRefreshMapUid = "";
            g_nextExternalRefreshAt = 0;
            return;
        }

        bool mapChanged = mapUid != g_lastExternalRefreshMapUid;
        if (mapChanged) {
            ResetPluginMedalsWithExports();
            ResetCustomMedalsState();
            ResetCCMState();
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
        if (!IsChampionMedalsAvailable()) return 0;
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
        if (!IsWarriorMedalsAvailable()) return 0;
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
        if (!IsSBVilleCampaignChallengesAvailable()) return 0;
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
        AddDisplayEntry(entries, "Champion", "\\$e79", champMedal, IsChampionMedalsAvailable());
    }

// ---------------- Warrior ----------------
    WarriorMedal warriorMedal;
    class WarriorMedal : PluginMedalWithExport {}
    void RefreshWarriorMedal() {
        UpdatePluginMedalWithExportState(warriorMedal, TryGetWarriorTime());
    }
    void AppendWarriorDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Warrior", "\\$0cf", warriorMedal, IsWarriorMedalsAvailable());
    }

// ---------------- s314ke ----------------
    S314keMedal s314keMedal;
    class S314keMedal : PluginMedalWithExport {
        void AddMedal() override {
            if (!IsS314keMedalsAvailable()) return;
            if (medalExists) startnew(CoroutineFunc(LoadPreferredGhost));
        }

        void LoadPreferredGhost() {
            string mapUid = CurrentMap::GetMapUid();
            if (mapUid.Length == 0) return;

            reqForCurrentMapFinished = false;
            medalHasExactMatch = false;
            loadedGhostBeatsMedal = true;
            timeDifference = 0;

            array<Services::LoadQueue::MapInfoCandidate@> candidates;
            string replayUrl = Services::LoadQueue::ResolveReplayUrlFallback(mapUid, S314KE_ACCOUNT_ID, "", "", candidates);
            if (replayUrl.Length > 0) {
                medalHasExactMatch = true;
                loadedGhostBeatsMedal = true;
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

        if (!IsS314keMedalsAvailable()) {
            if (expectedMapUid == CurrentMap::GetMapUid()) {
                s314keMedal.ResetState();
            }
            if (g_s314keFetchMapUid == expectedMapUid) {
                g_s314keFetchInFlight = false;
            }
            return;
        }

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

        if (!IsS314keMedalsAvailable()) {
            s314keMedal.ResetState();
            g_s314keFetchInFlight = false;
            return;
        }

        if (g_s314keFetchInFlight) return;

        g_s314keFetchInFlight = true;
        startnew(CoroutineFunc(Coro_RefreshS314keMedal));
    }
    void AppendS314keDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "s314ke", "\\$36c", s314keMedal, IsS314keMedalsAvailable());
    }

// ---------------- SB Ville ----------------
    SBVilleMedal sbVilleMedal;
    class SBVilleMedal : PluginMedalWithExport {}
    void RefreshSBVilleMedal() {
        UpdatePluginMedalWithExportState(sbVilleMedal, TryGetSBVilleTime());
    }
    void AppendSBVilleDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "SB Ville", "\\$f90", sbVilleMedal, IsSBVilleCampaignChallengesAvailable());
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

// ---------------- Milk ----------------
#if DEPENDENCY_MILKMEDALS
    namespace ImportedMilkMedals {
        import uint CalculateMilkTime() from "MilkMedals";
    }
#endif

    bool IsMilkMedalsAvailable() {
        return PluginState::IsPluginLoaded("MilkMedals", "Milk Medals");
    }

    uint TryGetMilkTime() {
        if (!IsMilkMedalsAvailable()) return 0;
#if DEPENDENCY_MILKMEDALS
        try {
            return ImportedMilkMedals::CalculateMilkTime();
        } catch {
            log("Milk medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 538, "CurrentMap::Medals");
        }
#endif
        return 0;
    }

    MilkMedal milkMedal;
    class MilkMedal : PluginMedalWithExport {}
    void RefreshMilkMedal() {
        UpdatePluginMedalWithExportState(milkMedal, TryGetMilkTime());
    }
    void AppendMilkDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Milk", "\\$fec", milkMedal, IsMilkMedalsAvailable());
    }

// ---------------- Custom Medals ----------------
#if DEPENDENCY_CUSTOMMEDALS
    namespace ImportedCustomMedals {
        import string GetCustomMedalsJson() from "CustomMedals";
    }
#endif

    class CustomMedalsPluginMedal : PluginMedalWithExport {
        string displayName = "";
        string displayColorCode = "\\$fff";
    }

    array<CustomMedalsPluginMedal@> g_CustomMedalsPluginMedals;

    void ResetCustomMedalsState() {
        g_CustomMedalsPluginMedals.RemoveRange(0, g_CustomMedalsPluginMedals.Length);
    }

    bool IsCustomMedalsAvailable() {
#if DEPENDENCY_CUSTOMMEDALS
        return PluginState::IsPluginLoaded("CustomMedals", "Custom Medals");
#else
        return false;
#endif
    }

    void RefreshCustomMedalsPluginMedals() {
        ResetCustomMedalsState();
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
        if (!IsCustomMedalsAvailable()) return;
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
        // Player Medals integration is temporarily disabled (issue with upstream export).
        // RefreshPlayerMedal();
        RefreshGlacialMedal();
        RefreshChallengeMedal();
        RefreshMilkMedal();
        RefreshSBVilleMedal();
    }

    void RefreshPluginMedalsWithoutExports() {
        RefreshAdeptMedals();
        RefreshCCMMedal();
        RefreshCustomMedalsPluginMedals();
    }

    void RefreshPluginMedalSources() {
        RefreshPluginMedalsWithExports();
        RefreshPluginMedalsWithoutExports();
    }
}
}
}
