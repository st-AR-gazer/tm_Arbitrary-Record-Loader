namespace EntryPoints {
namespace CurrentMap {
namespace Medals {

    /*
    string g_PlayerMedalDisplayName = "";
    string g_PlayerMedalColorCode = "\\$3f3";

#if DEPENDENCY_PLAYERMEDALS
    namespace ImportedPlayerMedals {
        import string GetMapMedalTimesJson(const string &in mapUid) from "PlayerMedals";
    }
#endif

    bool IsPlayerMedalsAvailable() {
        return PluginState::IsPluginLoaded("PlayerMedals", "Player Medals");
    }

    uint TryGetPlayerMedalTime() {
        if (!IsPlayerMedalsAvailable()) return 0;
#if DEPENDENCY_PLAYERMEDALS
        try {
            string mapUid = CurrentMap::GetMapUid();
            if (mapUid.Length == 0) return 0;

            Json::Value medals = Json::Parse(ImportedPlayerMedals::GetMapMedalTimesJson(mapUid));
            if (medals.GetType() != Json::Type::Array || medals.Length == 0) return 0;

            auto first = medals[0];
            if (first.GetType() != Json::Type::Object) return 0;

            g_PlayerMedalDisplayName = first.HasKey("playerName") ? Json::Write(first["playerName"]) : "";
            if (g_PlayerMedalDisplayName.StartsWith("\"") && g_PlayerMedalDisplayName.EndsWith("\"") && g_PlayerMedalDisplayName.Length >= 2) {
                g_PlayerMedalDisplayName = g_PlayerMedalDisplayName.SubStr(1, g_PlayerMedalDisplayName.Length - 2);
            }

            string playerColor = first.HasKey("playerColor") ? Json::Write(first["playerColor"]) : "";
            if (playerColor.StartsWith("\"") && playerColor.EndsWith("\"") && playerColor.Length >= 2) {
                playerColor = playerColor.SubStr(1, playerColor.Length - 2);
            }
            g_PlayerMedalColorCode = playerColor.Length > 0 ? ("\\$" + playerColor) : "\\$3f3";

            int64 playerMedalTime = int64(first["time"]);
            if (playerMedalTime < 0 || playerMedalTime > int64(0x7FFFFFFF)) return 0;
            return uint(playerMedalTime);
        } catch {
            log("Player medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 546, "CurrentMap::Medals");
        }
#endif
        return 0;
    }

    PlayerMedal playerMedal;
    class PlayerMedal : PluginMedalWithExport {}
    void RefreshPlayerMedal() {
        g_PlayerMedalDisplayName = "";
        g_PlayerMedalColorCode = "\\$3f3";
        UpdatePluginMedalWithExportState(playerMedal, TryGetPlayerMedalTime());
    }

    void AppendPlayerDisplayEntry(array<DisplayEntry@>@ entries) {
        string label = "Player";
        if (g_PlayerMedalDisplayName.Length > 0) {
            label += ": " + g_PlayerMedalColorCode + g_PlayerMedalDisplayName + "\\$z";
        }
        AddDisplayEntry(entries, label, "", playerMedal, IsPlayerMedalsAvailable());
    }
    */
}
}
}
