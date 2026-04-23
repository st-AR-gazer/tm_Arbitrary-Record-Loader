#if DEPENDENCY_MLHOOK
namespace ToggleGhostVisibilityHook {

    class ToggleGhostVisibilityUpdateHook : MLHook::HookMLEventsByType {
        ToggleGhostVisibilityUpdateHook(const string &in typeToHook) {
            super(typeToHook);
        }

        void OnEvent(MLHook::PendingEvent@ event) override {
            if (this.type != "TMGame_Record_ToggleGhost") return;

            if (event.data.Length >= 2) {
                string pid = tostring(event.data[0]);
                int offset = Text::ParseInt(tostring(event.data[1]));
                ToggleGhostMgr::UpdateLoadedGhosts(pid, offset);
            }
            else {
                log("TMGame_Record_ToggleGhost event data is incomplete.", LogLevel::Error, 18, "UnknownFunction");
            }
        }
    }

    ToggleGhostVisibilityUpdateHook@ toggleGhostHook;

    void InitializeHook() {
        if (!PluginState::IsPluginLoaded("MLHook")) return;
        @toggleGhostHook = ToggleGhostVisibilityUpdateHook("TMGame_Record_ToggleGhost");
        MLHook::RegisterMLHook(toggleGhostHook, "TMGame_Record_ToggleGhost", true);
    }

    void UninitializeHook() {
        if (toggleGhostHook !is null) {
            MLHook::UnregisterMLHookFromAll(toggleGhostHook);
            @toggleGhostHook = null;
        }
    }
}
#endif
