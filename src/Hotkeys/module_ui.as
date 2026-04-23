namespace ARLHotkeyUIActions {
    void OpenWindowPage(WindowPage page) {
        windowOpen = true;
        g_WindowPage = page;
    }

    void OpenLoadTab(LoadPageTab tab) {
        OpenWindowPage(WindowPage::Load);
        RequestLoadPageTab(tab);
    }

    bool HideAllTrackedGhosts() {
        LoadedRecords::UnloadAll();
        return true;
    }

    bool ShowAllTrackedGhosts() {
        for (uint i = 0; i < LoadedRecords::items.Length; i++) {
            LoadedRecords::Reload(LoadedRecords::items[i]);
        }
        return true;
    }

    bool ForgetAllTrackedGhosts() {
        LoadedRecords::UnloadAndClearAll();
        return true;
    }
}

namespace Hotkey_ARLUIModule {
    class Module : Hotkeys::IHotkeyModule {
        array<string> acts = {
            "Toggle main window",
            "Open main window",
            "Toggle settings window",
            "Open settings window",
            "Show Load page",
            "Show Loaded page",
            "Show Library page",
            "Show Help page",
            "Show Settings page",
            "Open Local Files tab",
            "Open URL tab",
            "Open Map UID tab",
            "Open Official tab",
            "Open Current Map tab"
        };

        string GetId() { return "UI"; }
        array<string> GetAvailableActions() { return acts; }

        string GetActionDescription(const string &in act) {
            if (act == "Toggle main window") return "Toggle the main ARL window.";
            if (act == "Open main window") return "Open the main ARL window.";
            if (act == "Toggle settings window") return "Toggle the standalone ARL settings window.";
            if (act == "Open settings window") return "Open the standalone ARL settings window.";
            if (act == "Show Load page") return "Switch to the main Load page.";
            if (act == "Show Loaded page") return "Switch to the Loaded page.";
            if (act == "Show Library page") return "Switch to the Library page.";
            if (act == "Show Help page") return "Switch to the Help page.";
            if (act == "Show Settings page") return "Switch to the Settings page in the main ARL window.";
            if (act == "Open Local Files tab") return "Open the Load page on the Local Files tab.";
            if (act == "Open URL tab") return "Open the Load page on the URL tab.";
            if (act == "Open Map UID tab") return "Open the Load page on the Map UID + Rank tab.";
            if (act == "Open Official tab") return "Open the Load page on the Official tab.";
            if (act == "Open Current Map tab") return "Open the Load page on the Current Map tab.";
            return "";
        }

        bool ExecuteAction(const string &in act, Hotkeys::Hotkey@) {
            if (act == "Toggle main window") { windowOpen = !windowOpen; return true; }
            if (act == "Open main window") { windowOpen = true; return true; }
            if (act == "Toggle settings window") { settingsWindowOpen = !settingsWindowOpen; return true; }
            if (act == "Open settings window") { settingsWindowOpen = true; return true; }
            if (act == "Show Load page") { ARLHotkeyUIActions::OpenWindowPage(WindowPage::Load); return true; }
            if (act == "Show Loaded page") { ARLHotkeyUIActions::OpenWindowPage(WindowPage::Loaded); return true; }
            if (act == "Show Library page") { ARLHotkeyUIActions::OpenWindowPage(WindowPage::Library); return true; }
            if (act == "Show Help page") { ARLHotkeyUIActions::OpenWindowPage(WindowPage::Help); return true; }
            if (act == "Show Settings page") { ARLHotkeyUIActions::OpenWindowPage(WindowPage::Settings); return true; }
            if (act == "Open Local Files tab") { ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::LocalFiles); return true; }
            if (act == "Open URL tab") { ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::Url); return true; }
            if (act == "Open Map UID tab") { ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::MapUid); return true; }
            if (act == "Open Official tab") { ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::Official); return true; }
            if (act == "Open Current Map tab") { ARLHotkeyUIActions::OpenLoadTab(LoadPageTab::CurrentMap); return true; }
            return false;
        }
    }

    Hotkeys::IHotkeyModule@ g_module;

    void Initialize() {
        @g_module = Module();
        Hotkeys::RegisterModule(Meta::ExecutingPlugin().Name, g_module);
    }
}

namespace Hotkey_ARLLoadedModule {
    class Module : Hotkeys::IHotkeyModule {
        array<string> acts = {
            "Hide all tracked ghosts",
            "Show all tracked ghosts",
            "Forget all tracked ghosts"
        };

        string GetId() { return "Loaded Ghosts"; }
        array<string> GetAvailableActions() { return acts; }

        string GetActionDescription(const string &in act) {
            if (act == "Hide all tracked ghosts") return "Hide every ARL-tracked ghost that is currently visible.";
            if (act == "Show all tracked ghosts") return "Show every ARL-tracked ghost that can be reloaded.";
            if (act == "Forget all tracked ghosts") return "Unload and clear all ARL-tracked ghosts.";
            return "";
        }

        bool ExecuteAction(const string &in act, Hotkeys::Hotkey@) {
            if (act == "Hide all tracked ghosts") return ARLHotkeyUIActions::HideAllTrackedGhosts();
            if (act == "Show all tracked ghosts") return ARLHotkeyUIActions::ShowAllTrackedGhosts();
            if (act == "Forget all tracked ghosts") return ARLHotkeyUIActions::ForgetAllTrackedGhosts();
            return false;
        }
    }

    Hotkeys::IHotkeyModule@ g_module;

    void Initialize() {
        @g_module = Module();
        Hotkeys::RegisterModule(Meta::ExecutingPlugin().Name, g_module);
    }
}

auto arl_hotkeys_ui_initializer = startnew(Hotkey_ARLUIModule::Initialize);
auto arl_hotkeys_loaded_initializer = startnew(Hotkey_ARLLoadedModule::Initialize);

class ARLUIHotkeys_OnUnload {
    ~ARLUIHotkeys_OnUnload() {
        const string plugin = Meta::ExecutingPlugin().Name;
        if (Hotkey_ARLUIModule::g_module !is null) Hotkeys::UnregisterModule(plugin, Hotkey_ARLUIModule::g_module);
        if (Hotkey_ARLLoadedModule::g_module !is null) Hotkeys::UnregisterModule(plugin, Hotkey_ARLLoadedModule::g_module);
    }
}

ARLUIHotkeys_OnUnload g_ARLUIHotkeysUnloader;
