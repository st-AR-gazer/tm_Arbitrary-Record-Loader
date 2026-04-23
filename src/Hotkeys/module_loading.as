namespace ARLHotkeyLoadingActions {
    [Setting category="Hotkeys - Loading" name="Configured rank" hidden]
    int S_ConfiguredRank = 1;

    [Setting category="Hotkeys - Loading" name="Configured range start" hidden]
    int S_ConfiguredRangeFrom = 1;

    [Setting category="Hotkeys - Loading" name="Configured range end" hidden]
    int S_ConfiguredRangeTo = 5;

    [Setting category="Hotkeys - Loading" name="Max range load count" hidden]
    int S_MaxRangeLoadCount = 25;

    int NormalizeRangeLimit() {
        if (S_MaxRangeLoadCount < 1) S_MaxRangeLoadCount = 1;
        if (S_MaxRangeLoadCount > 50) S_MaxRangeLoadCount = 50;
        return S_MaxRangeLoadCount;
    }

    bool ResolveCurrentMapUid(string &out uid) {
        uid = get_CurrentMapUID();
        if (uid.Length > 0) return true;
        NotifyWarning("No map loaded.");
        return false;
    }

    void SyncMapUidTab(const string &in uid, int rank) {
        EntryPoints::MapUid::mapUID = uid;
        EntryPoints::MapUid::ghostPosition = tostring(NormalizeRankInput(rank));
    }

    bool LoadCurrentMapRank(int rank, bool openTab = false) {
        string uid;
        if (!ResolveCurrentMapUid(uid)) return false;

        int normalizedRank = NormalizeRankInput(rank);
        SyncMapUidTab(uid, normalizedRank);
        if (openTab) ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::MapUid);
        loadRecord.LoadRecordFromMapUid(uid, tostring(normalizedRank), "AnyMap");
        return true;
    }

    bool LoadCurrentMapRankRange(int fromRank, int toRank, int maxCount = -1, bool openTab = false) {
        string uid;
        if (!ResolveCurrentMapUid(uid)) return false;

        int from = NormalizeRankInput(fromRank);
        int to = NormalizeRankInput(toRank);
        if (to < from) {
            int tmp = from;
            from = to;
            to = tmp;
        }

        int count = to - from + 1;
        int limit = maxCount > 0 ? maxCount : NormalizeRangeLimit();
        if (count <= 0) return false;
        if (count > limit) {
            NotifyWarning("Hotkey range is too large (" + count + " ghosts). Limit: " + limit + ".");
            return false;
        }

        SyncMapUidTab(uid, from);
        if (openTab) ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::MapUid);
        for (int rank = from; rank <= to; rank++) {
            loadRecord.LoadRecordFromMapUid(uid, tostring(rank), "AnyMap");
        }
        NotifyInfo("Queued current map ranks #" + from + "-" + to + ".");
        return true;
    }

    bool LoadCurrentMapConfiguredRank() {
        return LoadCurrentMapRank(S_ConfiguredRank);
    }

    bool LoadCurrentMapConfiguredRange() {
        return LoadCurrentMapRankRange(S_ConfiguredRangeFrom, S_ConfiguredRangeTo);
    }

    bool OpenCurrentMapLeaderboardBrowser() {
        string uid;
        if (!ResolveCurrentMapUid(uid)) return false;

        ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::MapUid);
        EntryPoints::MapUid::RequestOpenLeaderboardBrowser(uid);
        return true;
    }

    bool LoadCurrentMapValidationReplay() {
        string uid;
        if (!ResolveCurrentMapUid(uid)) return false;

        EntryPoints::CurrentMap::ValidationReplay::Add();
        return true;
    }
}

namespace Hotkey_ARLLoadingModule {
    void RenderSettings() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        UI::Text(Icons::Download + " Loading Hotkey Defaults");

        UI::SetNextItemWidth(110);
        ARLHotkeyLoadingActions::S_ConfiguredRank = UI::InputInt("Configured Rank", ARLHotkeyLoadingActions::S_ConfiguredRank);
        _UI::SimpleTooltip("Used by the 'Load current map configured rank' hotkey action.");

        UI::SetNextItemWidth(110);
        ARLHotkeyLoadingActions::S_ConfiguredRangeFrom = UI::InputInt("Configured Range From", ARLHotkeyLoadingActions::S_ConfiguredRangeFrom);
        _UI::SimpleTooltip("Start rank for the configurable hotkey range.");

        UI::SameLine();
        UI::SetNextItemWidth(110);
        ARLHotkeyLoadingActions::S_ConfiguredRangeTo = UI::InputInt("To", ARLHotkeyLoadingActions::S_ConfiguredRangeTo);
        _UI::SimpleTooltip("End rank for the configurable hotkey range.");

        UI::SetNextItemWidth(110);
        ARLHotkeyLoadingActions::S_MaxRangeLoadCount = UI::SliderInt("Range Safety Limit", ARLHotkeyLoadingActions::NormalizeRangeLimit(), 1, 50);
        _UI::SimpleTooltip("Prevents a single hotkey press from queueing too many leaderboard downloads.");

        UI::Separator();
        UI::PopStyleVar();
    }

    class Module : Hotkeys::IHotkeyModule {
        array<string> acts = {
            "Load current map WR",
            "Load current map rank 2",
            "Load current map rank 3",
            "Load current map default rank",
            "Load current map configured rank",
            "Load current map top 3",
            "Load current map top 5",
            "Load current map top 10",
            "Load current map configured range",
            "Load current map validation replay",
            "Open current map leaderboard browser"
        };

        string GetId() { return "Loading"; }
        array<string> GetAvailableActions() { return acts; }

        string GetActionDescription(const string &in act) {
            if (act == "Load current map WR") return "Load rank #1 for the current map.";
            if (act == "Load current map rank 2") return "Load rank #2 for the current map.";
            if (act == "Load current map rank 3") return "Load rank #3 for the current map.";
            if (act == "Load current map at default rank") return "Load the current map using ARL's default rank setting.";
            if (act == "Load current map default rank") return "Load the current map using ARL's default rank setting.";
            if (act == "Load current map configured rank") return "Load the configured hotkey rank for the current map.";
            if (act == "Load current map top 3") return "Load ranks #1-#3 for the current map.";
            if (act == "Load current map top 5") return "Load ranks #1-#5 for the current map.";
            if (act == "Load current map top 10") return "Load ranks #1-#10 for the current map.";
            if (act == "Load current map configured range") return "Load the configured hotkey rank range for the current map.";
            if (act == "Load current map validation replay") return "Load the current map's validation replay when one exists.";
            if (act == "Open current map leaderboard browser") return "Open the Map UID leaderboard browser for the current map.";
            return "";
        }

        bool ExecuteAction(const string &in act, Hotkeys::Hotkey@) {
            if (act == "Load current map WR") return ARLHotkeyLoadingActions::LoadCurrentMapRank(1);
            if (act == "Load current map rank 2") return ARLHotkeyLoadingActions::LoadCurrentMapRank(2);
            if (act == "Load current map rank 3") return ARLHotkeyLoadingActions::LoadCurrentMapRank(3);
            if (act == "Load current map at default rank") return ARLHotkeyLoadingActions::LoadCurrentMapRank(g_DefaultRankOffset, true);
            if (act == "Load current map default rank") return ARLHotkeyLoadingActions::LoadCurrentMapRank(g_DefaultRankOffset, true);
            if (act == "Load current map configured rank") return ARLHotkeyLoadingActions::LoadCurrentMapConfiguredRank();
            if (act == "Load current map top 3") return ARLHotkeyLoadingActions::LoadCurrentMapRankRange(1, 3, 3);
            if (act == "Load current map top 5") return ARLHotkeyLoadingActions::LoadCurrentMapRankRange(1, 5, 5);
            if (act == "Load current map top 10") return ARLHotkeyLoadingActions::LoadCurrentMapRankRange(1, 10, 10);
            if (act == "Load current map configured range") return ARLHotkeyLoadingActions::LoadCurrentMapConfiguredRange();
            if (act == "Load current map validation replay") return ARLHotkeyLoadingActions::LoadCurrentMapValidationReplay();
            if (act == "Open current map leaderboard browser") return ARLHotkeyLoadingActions::OpenCurrentMapLeaderboardBrowser();
            return false;
        }
    }

    Hotkeys::IHotkeyModule@ g_module;

    void Initialize() {
        @g_module = Module();
        Hotkeys::RegisterModule(Meta::ExecutingPlugin().Name, g_module);
    }
}

auto arl_hotkeys_loading_initializer = startnew(Hotkey_ARLLoadingModule::Initialize);

class ARLLoadingHotkeys_OnUnload {
    ~ARLLoadingHotkeys_OnUnload() {
        const string plugin = Meta::ExecutingPlugin().Name;
        if (Hotkey_ARLLoadingModule::g_module !is null) Hotkeys::UnregisterModule(plugin, Hotkey_ARLLoadingModule::g_module);
    }
}

ARLLoadingHotkeys_OnUnload g_ARLLoadingHotkeysUnloader;
