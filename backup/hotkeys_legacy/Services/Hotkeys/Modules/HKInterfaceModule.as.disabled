namespace Features {
namespace Hotkeys {

    [Setting hidden]
    bool S_hotkeyWindowPopup = false;

    namespace HKInterfaceModule {
        class HKInterfaceModule : Features::Hotkeys::IHotkeyModule {
            array<string> actions = {
                "Open/Close Hotkey Interface", "Open Hotkey Interface", "Close Hotkey Interface"
            };

            void Initialize() { }

            array<string> GetAvailableActions() {
                return actions;
            }

            bool ExecuteAction(const string &in action, Features::Hotkeys::Hotkey@ hotkey) {
                if (action == "Open/Close Hotkey Interface") {
                    S_hotkeyWindowPopup = !S_hotkeyWindowPopup;
                    return true;
                } else if (action == "Open Hotkey Interface") {
                    S_hotkeyWindowPopup = true;
                    return true;
                } else if (action == "Close Hotkey Interface") {
                    S_hotkeyWindowPopup = false;
                    return true;
                }
                return false;
            }
        }

        Features::Hotkeys::IHotkeyModule@ CreateInstance() {
            return HKInterfaceModule();
        }

        void RenderInterface() {
            if (S_hotkeyWindowPopup) {
                Features::Hotkeys::RT_Hotkeys_Popout();
            }
        }
    }
    
}
}
