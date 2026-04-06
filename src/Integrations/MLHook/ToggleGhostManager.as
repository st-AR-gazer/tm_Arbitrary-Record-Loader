#if DEPENDENCY_MLHOOK
namespace ToggleGhostMgr {
    array<ToggleEntry@> lr_w_s;

    class ToggleEntry {
        string pid;
        int offset;

        string name;
        int score;
        bool isLoaded;

        ToggleEntry() {
            isLoaded = false;
        }
    }

    const string CUSTOM_EVENT_TOGGLE_GHOST = "TMGame_Record_ToggleGhost";

    void ToggleGhost(const string &in playerId) {
        if (playerId.Length == 0) { log("ToggleGhost: Player ID is empty.", LogLevel::Warning, 20, "ToggleGhost"); return; }

        ToggleEntry@ ghost = FindGhostByPlayerId(playerId);
        if (ghost !is null) {
            if (ghost.isLoaded) {
                UnloadGhost(playerId);
            } else {
                LoadGhost(playerId, ghost.offset);
            }
        }
    }

    void LoadGhost(const string &in playerId, int offset) {
        if (playerId.Length == 0) {
            log("LoadGhost: Player ID is empty.", LogLevel::Warning, 20, "LoadGhost");
            return;
        }

        ToggleEntry@ ghost = FindGhostByPlayerId(playerId);
        if (ghost !is null && ghost.isLoaded) {
            log("LoadGhost: Ghost with Player ID " + playerId + " is already loaded.", LogLevel::Warning, 20, "LoadGhost");
            return;
        }

        string[] eventData = { playerId, tostring(offset) };
        MLHook::Queue_SH_SendCustomEvent(CUSTOM_EVENT_TOGGLE_GHOST, eventData);

        if (offset >= int(lr_w_s.Length)) {
            lr_w_s.Resize(offset + 1);
        }
        @lr_w_s[offset] = ToggleEntry();
        lr_w_s[offset].pid = playerId;
        lr_w_s[offset].offset = offset;
        lr_w_s[offset].isLoaded = true;
    }

    void UnloadGhost(const string &in playerId) {
        if (playerId.Length == 0) {
            log("UnloadGhost: Player ID is empty.", LogLevel::Warning, 20, "UnloadGhost");
            return;
        }

        ToggleEntry@ ghost = FindGhostByPlayerId(playerId);
        if (ghost is null || !ghost.isLoaded) {
            log("UnloadGhost: Ghost with Player ID " + playerId + " is not loaded.", LogLevel::Warning, 20, "UnloadGhost");
            return;
        }

        string[] eventData = { playerId };
        MLHook::Queue_SH_SendCustomEvent(CUSTOM_EVENT_TOGGLE_GHOST, eventData);

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
        if (pid.Length == 0) { log("UpdateLoadedGhosts: Player ID is empty.", LogLevel::Warning, 20, "UpdateLoadedGhosts"); return; }

        ToggleEntry@ ghost = FindGhostByPlayerId(pid);
        if (ghost is null) {
            log("No ghost exists for this, it was not loaded with this plugin, adding it as visible anyway.", LogLevel::Warning, 20, "UpdateLoadedGhosts");
            @ghost = ToggleEntry();
            ghost.pid = pid;
            ghost.offset = offset;
            ghost.isLoaded = true;
            return;
        }

        ghost.isLoaded = !ghost.isLoaded;
        ghost.offset = offset;
    }
}
#endif
