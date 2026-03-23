namespace Features {
namespace LRBasedOnCurrentMap {

    namespace ValidationReplay {

        void AddValidationReplay() {
            if (ValidationReplayExists()) {
                ReplayLoader::LoadReplayFromPath(GetValidationReplayFilePathForCurrentMap());
            }
        }

        bool ValidationReplayExists() {
            auto dataFileMgr = GameCtx::GetDFM();
            if (dataFileMgr is null) { /*log("DataFileMgr is null", LogLevel::Error, 20, "ValidationReplayExists");*/ return false; }
            if (GetApp().RootMap is null) return false;
            CGameGhostScript@ authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
            if (authorGhost is null) { /*log("Author ghost is empty", LogLevel::Warn, 22, "ValidationReplayExists");*/ return false; }
            return true;
        }

        void OnMapLoad() {
            if (ValidationReplayExists()) {
                ExtractValidationReplay();
            }
        }

        void ExtractValidationReplay() {
            try {
                auto dataFileMgr = GameCtx::GetDFM();
                if (dataFileMgr is null) { log("DataFileMgr is null", LogLevel::Error, 35, "ExtractValidationReplay"); }
                string outputFileName = Server::currentMapRecordsValidationReplay + "Validation_" + Text::StripFormatCodes(GetApp().RootMap.MapName) + ".Replay.Gbx";
                CGameGhostScript@ authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
                if (authorGhost is null) { log("Author ghost is empty", LogLevel::Warn, 38, "ExtractValidationReplay"); }
                CWebServicesTaskResult@ taskResult = dataFileMgr.Replay_Save(outputFileName, GetApp().RootMap, authorGhost);
                if (taskResult is null) { log("Replay task returned null", LogLevel::Error, 40, "ExtractValidationReplay"); }
                while (taskResult.IsProcessing) { yield(); }
                if (!taskResult.HasSucceeded) { log("Error while saving replay " + taskResult.ErrorDescription, LogLevel::Error, 42, "ExtractValidationReplay"); }
                log("Replay extracted to: " + outputFileName, LogLevel::Info, 43, "ExtractValidationReplay");
            } catch {
                log("Error occurred when trying to extract replay: " + getExceptionInfo(), LogLevel::Info, 45, "ExtractValidationReplay");
            }
        }

        int GetValidationReplayTime() {
            auto dataFileMgr = GameCtx::GetDFM();
            if (dataFileMgr is null) return -1;
            CGameGhostScript@ authorGhost = dataFileMgr.Map_GetAuthorGhost(GetApp().RootMap);
            if (authorGhost is null) return -1;
            return authorGhost.Result.Time;
        }

        string GetValidationReplayFilePathForCurrentMap() {
            if (GetApp().RootMap is null) { log("RootMap is null, no replay can be loaded...", LogLevel::Info, 62, "GetValidationReplayFilePathForCurrentMap"); return ""; }
            string path = Server::currentMapRecordsValidationReplay + "Validation_" + Text::StripFormatCodes(GetApp().RootMap.MapName) + ".Replay.Gbx";
            if (!IO::FileExists(path)) { log("Validation replay does not exist at path: " + path + " | This is likely due to the validation replay not yet being extracted.", LogLevel::Info, 64, "GetValidationReplayFilePathForCurrentMap"); return ""; }
            return path;
        }
    }

}
}
