namespace EntryPoints {
namespace CurrentMap {
namespace Medals {

#if DEPENDENCY_GLACIALMEDALS
    namespace ImportedGlacialMedals {
        ///<
        import uint GetGlacialMedalTime(const string &in mapUid) from "GlacialMedals";
        import uint GetChallengeMedalTime(const string &in mapUid) from "GlacialMedals";
        ///>
    }
#endif

    bool IsGlacialMedalsAvailable() {
        return PluginState::IsPluginLoaded("GlacialMedals", "Glacial Medals");
    }

    uint TryGetGlacialMedalTime() {
#if DEPENDENCY_GLACIALMEDALS
        try {
            string mapUid = CurrentMap::GetMapUid();
            if (mapUid.Length == 0) return 0;
            return ImportedGlacialMedals::GetGlacialMedalTime(mapUid);
        } catch {
            log("Glacial medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 23, "TryGetGlacialMedalTime");
        }
#endif
        return 0;
    }

    uint TryGetChallengeMedalTime() {
#if DEPENDENCY_GLACIALMEDALS
        try {
            string mapUid = CurrentMap::GetMapUid();
            if (mapUid.Length == 0) return 0;
            return ImportedGlacialMedals::GetChallengeMedalTime(mapUid);
        } catch {
            log("Challenge medal lookup failed: " + getExceptionInfo(), LogLevel::Warning, 36, "TryGetChallengeMedalTime");
        }
#endif
        return 0;
    }

    GlacialMedal glacialMedal;
    class GlacialMedal : PluginMedalWithExport {}
    void RefreshGlacialMedal() {
        UpdatePluginMedalWithExportState(glacialMedal, TryGetGlacialMedalTime());
    }
    void AppendGlacialDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Glacial", "\\$29b", glacialMedal, IsGlacialMedalsAvailable());
    }

    ChallengeMedal challengeMedal;
    class ChallengeMedal : PluginMedalWithExport {}
    void RefreshChallengeMedal() {
        UpdatePluginMedalWithExportState(challengeMedal, TryGetChallengeMedalTime());
    }
    void AppendChallengeDisplayEntry(array<DisplayEntry@>@ entries) {
        AddDisplayEntry(entries, "Challenge", "\\$049", challengeMedal, IsGlacialMedalsAvailable());
    }
}
}
}
