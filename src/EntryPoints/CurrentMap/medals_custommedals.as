namespace EntryPoints {
namespace CurrentMap {
namespace Medals {

#if DEPENDENCY_CUSTOMMEDALS
    namespace ImportedCustomMedals {
        import string GetCustomMedalsJson() from "CustomMedals";
    }
#endif

    class CustomMedalsPluginMedal : Medal {
        string displayName = "";
        string displayColorCode = "\\$fff";

        CustomMedalsPluginMedal() {
            showWhenMissing = false;
        }

        uint GetMedalTime() override {
            return currentMapMedalTime;
        }
    }

    array<CustomMedalsPluginMedal@> g_CustomMedalsPluginMedals;

    void ResetCustomMedalsState() {
        g_CustomMedalsPluginMedals.RemoveRange(0, g_CustomMedalsPluginMedals.Length);
    }

    bool IsCustomMedalsAvailable() {
#if DEPENDENCY_CUSTOMMEDALS
        return Meta::GetPluginFromID("CustomMedals") !is null;
#else
        return false;
#endif
    }

    void RefreshCustomMedalsPluginMedals() {
        g_CustomMedalsPluginMedals.RemoveRange(0, g_CustomMedalsPluginMedals.Length);
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
        for (uint i = 0; i < g_CustomMedalsPluginMedals.Length; i++) {
            auto medal = g_CustomMedalsPluginMedals[i];
            if (medal is null) continue;
            AddDisplayEntry(entries, medal.displayName, medal.displayColorCode, medal, true);
        }
    }
}
}
}
