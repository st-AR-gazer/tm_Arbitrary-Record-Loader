#if DEPENDENCY_MLHOOK
namespace ToggleGhostMgr {
    array<ToggleEntry@> lr_w_s;

    class ToggleEntry {
        string pid;
        int offset;

        string name;
        int score;
        bool isLoaded;
        uint loadedAt = 0;

        ToggleEntry() {
            isLoaded = false;
        }
    }

    const string CUSTOM_EVENT_TOGGLE_GHOST = "TMGame_Record_ToggleGhost";

    bool IsMLHookAvailable() {
        return PluginState::IsPluginLoaded("MLHook");
    }

    void ToggleGhost(const string &in playerId) {
        if (!IsMLHookAvailable()) return;
        if (playerId.Length == 0) { log("ToggleGhost: Player ID is empty.", LogLevel::Warning, 26, "ToggleGhost"); return; }

        ToggleEntry@ ghost = FindGhostByPlayerId(playerId);
        if (ghost !is null) {
            if (ghost.isLoaded) {
                UnloadGhost(playerId);
            } else {
                LoadGhost(playerId, ghost.offset);
            }
        }
    }

    void LoadGhost(const string &in playerId, int offset, const string &in name = "", int score = 0) {
        if (!IsMLHookAvailable()) return;
        if (playerId.Length == 0) {
            log("LoadGhost: Player ID is empty.", LogLevel::Warning, 41, "LoadGhost");
            return;
        }

        ToggleEntry@ ghost = FindGhostByPlayerId(playerId);
        if (ghost !is null && ghost.isLoaded) {
            if (name.Length > 0) ghost.name = name;
            if (score > 0) ghost.score = score;
            log("LoadGhost: Ghost with Player ID " + playerId + " is already loaded.", LogLevel::Warning, 49, "LoadGhost");
            return;
        }

        string[] eventData = { playerId, tostring(offset) };
        MLHook::Queue_SH_SendCustomEvent(CUSTOM_EVENT_TOGGLE_GHOST, eventData);

        if (offset >= int(lr_w_s.Length)) {
            lr_w_s.Resize(offset + 1);
        }
        if (ghost is null) @ghost = ToggleEntry();
        @lr_w_s[offset] = ghost;
        lr_w_s[offset].pid = playerId;
        lr_w_s[offset].offset = offset;
        lr_w_s[offset].name = name;
        lr_w_s[offset].score = score;
        lr_w_s[offset].isLoaded = true;
        lr_w_s[offset].loadedAt = Time::Now;
    }

    void UnloadGhost(const string &in playerId) {
        if (!IsMLHookAvailable()) return;
        if (playerId.Length == 0) {
            log("UnloadGhost: Player ID is empty.", LogLevel::Warning, 71, "UnloadGhost");
            return;
        }

        ToggleEntry@ ghost = FindGhostByPlayerId(playerId);
        if (ghost is null || !ghost.isLoaded) {
            log("UnloadGhost: Ghost with Player ID " + playerId + " is not loaded.", LogLevel::Warning, 77, "UnloadGhost");
            return;
        }

        string[] eventData = { playerId };
        MLHook::Queue_SH_SendCustomEvent(CUSTOM_EVENT_TOGGLE_GHOST, eventData);

        ghost.isLoaded = false;
    }

    void ForgetGhost(const string &in playerId) {
        if (playerId.Length == 0) return;
        ToggleEntry@ ghost = FindGhostByPlayerId(playerId);
        if (ghost !is null && ghost.isLoaded) {
            UnloadGhost(playerId);
        }

        for (uint i = 0; i < lr_w_s.Length; i++) {
            if (lr_w_s[i] !is null && lr_w_s[i].pid == playerId) {
                @lr_w_s[i] = null;
            }
        }
    }


    ToggleEntry@ FindGhostByPlayerId(const string &in playerId) {
        for (uint i = 0; i < lr_w_s.Length; i++) {
            if (lr_w_s[i] !is null && lr_w_s[i].pid == playerId) {
                return lr_w_s[i];
            }
        }
        return null;
    }


    void UpdateLoadedGhosts(const string &in pid, int offset) {
        if (pid.Length == 0) { log("UpdateLoadedGhosts: Player ID is empty.", LogLevel::Warning, 113, "UpdateLoadedGhosts"); return; }

        ToggleEntry@ ghost = FindGhostByPlayerId(pid);
        if (ghost is null) {
            log("No ghost exists for this, it was not loaded with this plugin, adding it as visible anyway.", LogLevel::Warning, 117, "UpdateLoadedGhosts");
            @ghost = ToggleEntry();
            ghost.pid = pid;
            ghost.offset = offset;
            ghost.isLoaded = true;
            ghost.loadedAt = Time::Now;
            if (offset >= int(lr_w_s.Length)) lr_w_s.Resize(offset + 1);
            @lr_w_s[offset] = ghost;
            return;
        }

        ghost.isLoaded = !ghost.isLoaded;
        ghost.offset = offset;
        if (ghost.isLoaded) ghost.loadedAt = Time::Now;
    }

    array<ToggleEntry@>@ GetTrackedEntries() {
        array<ToggleEntry@>@ entries = array<ToggleEntry@>();
        for (uint i = 0; i < lr_w_s.Length; i++) {
            if (lr_w_s[i] !is null && lr_w_s[i].pid.Length > 0) entries.InsertLast(lr_w_s[i]);
        }
        return entries;
    }
}
#endif
