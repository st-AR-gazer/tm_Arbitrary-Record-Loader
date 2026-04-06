#if DEPENDENCY_MLHOOK
namespace PBVisibilityHook {
    bool pbToggleReceived = false;

    class PBVisibilityUpdateHook : MLHook::HookMLEventsByType {
        PBVisibilityUpdateHook(const string &in typeToHook) {
            super(typeToHook);
        }

        void OnEvent(MLHook::PendingEvent@ event) override {
            if (this.type == "TMGame_Record_TogglePB") {
                pbToggleReceived = true;
            }
            else if (this.type == "TMGame_Record_UpdatePBGhostVisibility") {
                if (!pbToggleReceived) {
                    return;
                }

                pbToggleReceived = false;

                bool shouldShow = tostring(event.data[0]).ToLower().Contains("true");

                if (shouldShow) {
                    log("PBVisibilityHook: PB ghost visibility set to true. Forcing visibility update.", LogLevel::Info, 34, "PBVisibilityUpdateHook::OnEvent");
                } else {
                    log("PBVisibilityHook: PB ghost visibility set to false. Forcing visibility update.", LogLevel::Info, 36, "PBVisibilityUpdateHook::OnEvent");
                }
            }
        }
    }

    PBVisibilityUpdateHook@ togglePBHook;
    PBVisibilityUpdateHook@ updateVisibilityHook;

    void InitializeHook() {
        @togglePBHook = PBVisibilityUpdateHook("TMGame_Record_TogglePB");
        MLHook::RegisterMLHook(togglePBHook, "TMGame_Record_TogglePB", true);

        @updateVisibilityHook = PBVisibilityUpdateHook("TMGame_Record_UpdatePBGhostVisibility");
        MLHook::RegisterMLHook(updateVisibilityHook, "TMGame_Record_UpdatePBGhostVisibility", true);

        log("PBVisibilityHook: Hooks registered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 41, "InitializeHook");
    }

    void UninitializeHook() {
        if (togglePBHook !is null) {
            MLHook::UnregisterMLHookFromAll(togglePBHook);
            @togglePBHook = null;
        }
        if (updateVisibilityHook !is null) {
            MLHook::UnregisterMLHookFromAll(updateVisibilityHook);
            @updateVisibilityHook = null;
        }
        log("PBVisibilityHook: Hooks unregistered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 53, "UninitializeHook");
    }
}
#endif
