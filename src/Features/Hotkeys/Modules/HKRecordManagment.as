namespace Features {
namespace Hotkeys {

    namespace HKRecordManagment {
        class RecordManagmentHotkeyModule : Features::Hotkeys::IHotkeyModule {

            array<string> actions = {
                "Load top 1 time", "Load top 2 time", "Load top 3 time",
                "Load top 4 time", "Load top 5 time", "Load X time",
                "Remove all ghosts from current map", "Remove PB Ghost", 
                "Open/Close Interface", "Open Interface", "Close Interface"
            };

            void Initialize() { }

            array<string> GetAvailableActions() {
                return actions;
            }

            bool ExecuteAction(const string &in action, Features::Hotkeys::Hotkey@ hotkey) {
                if (action == "Load top 1 time") {
                    loadRecord.LoadRecordFromMapUid(get_CurrentMapUID(), "0", "AnyMap");
                    return true;
                } else if (action == "Load top 2 time") {
                    loadRecord.LoadRecordFromMapUid(get_CurrentMapUID(), "1", "AnyMap");
                    return true;
                } else if (action == "Load top 3 time") {
                    loadRecord.LoadRecordFromMapUid(get_CurrentMapUID(), "2", "AnyMap");
                    return true;
                } else if (action == "Load top 4 time") {
                    loadRecord.LoadRecordFromMapUid(get_CurrentMapUID(), "3", "AnyMap");
                    return true;
                } else if (action == "Load top 5 time") {
                    loadRecord.LoadRecordFromMapUid(get_CurrentMapUID(), "4", "AnyMap");
                    return true;
                } else if (action == "Load X time" && hotkey.extraValue > 0) {
                    loadRecord.LoadRecordFromMapUid(get_CurrentMapUID(), tostring(hotkey.extraValue - 1), "AnyMap");
                    return true;
                } else if (action == "Open/Close Interface") {
                    S_ARL_WindowOpen = !S_ARL_WindowOpen;
                    return true;
                } else if (action == "Open Interface") {
                    S_ARL_WindowOpen = true;
                    return true;
                } else if (action == "Close Interface") {
                    S_ARL_WindowOpen = false;
                    return true;
                } else if (action == "Remove all ghosts from current map") {
                    RecordManager::RemoveAllRecords();
                    return true;
                } else if (action == "Remove PB Ghost") {
                    RecordManager::RemovePBRecord();
                    return true;
                } else {
                    log("Action not implemented: " + action, LogLevel::Warn, 145, "ExecuteHotkeyAction");
                    return false;
                }

            }
        }

        Features::Hotkeys::IHotkeyModule@ CreateInstance() {
            return RecordManagmentHotkeyModule();
        }
    }

}
}