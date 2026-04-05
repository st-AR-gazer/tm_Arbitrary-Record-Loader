#if false

namespace Features {
namespace LRBasedOnCurrentMap {

    namespace PB {
#if DEPENDENCY_ARCHIVIST
        string archivist_base_folder = IO::FromUserGameFolder("Replays/Archivist");

        void IndexAndSaveToArchivist() {
            pbRecords.RemoveRange(0, pbRecords.Length);

            string currentMapName = GetCurrentMapName();
            if (currentMapName == "") { return; }

            string map_folder = archivist_base_folder + "/" + currentMapName;

            if (!IO::FolderExists(map_folder)) { return; }

            array<string> subfolders = { "Complete", "Segmented", "Partial" };

            dictionary bestPBPerMap;

            for (uint i = 0; i < subfolders.Length; i++) {
                string subfolder_path = map_folder + "/" + subfolders[i];
                
                if (!IO::FolderExists(subfolder_path)) {
                    log("PBManager: Subfolder does not exist: " + subfolder_path, LogLevel::Warn, 28, "IndexAndSaveToArchivist");
                    continue;
                }

                array<string>@ ghostFiles = IO::IndexFolder(subfolder_path, false);

                            for (uint j = 0; j < ghostFiles.Length; j++) {
                    string filePath = ghostFiles[j];
                    string fileName = Path::GetFileName(filePath);
                
                    array<string> parts = fileName.Split(" ");
                    if (parts.Length < 4) { continue; }
                
                    string msStr = parts[2];
                    if (!msStr.EndsWith("ms")) { continue; }
                
                    string msNumberStr = msStr.SubStr(0, msStr.Length - 2);
                    int ms = 0;
                    if (Text::ParseInt(msNumberStr) > 0) { continue; }
                
                    string mapUid = GetCurrentMapUID();
                    if (mapUid == "") { return; }
                
                    if (bestPBPerMap.Exists(mapUid)) {
                        int existingMs = int(bestPBPerMap[mapUid + "_ms"]);
                        if (ms < existingMs) {
                            bestPBPerMap[mapUid] = filePath;
                            bestPBPerMap[mapUid + "_ms"] = ms;
                        }
                    } else {
                        bestPBPerMap[mapUid] = filePath;
                        bestPBPerMap[mapUid + "_ms"] = ms;
                    }
                }}
                
                string[]@ keys = bestPBPerMap.GetKeys();
                for (uint i = 0; i < keys.Length; i++) {
                    string key = keys[i];
                    
                    if (key.EndsWith("_ms")) { continue; }
                
                    string mapUid = key;
                    string filePath = string(bestPBPerMap[mapUid]);
                    string fileName = Path::GetFileName(filePath);
                
                    PBRecord@ pbRecord = PBRecord(mapUid, fileName, filePath);
                    pbRecords.InsertLast(pbRecord);
                }


            SavePBRecordsToFile();
            log("PBManager: Successfully indexed Archivist folder for map: " + currentMapName, LogLevel::Info, 81, "IndexAndSaveToArchivist");
        }

        string GetCurrentMapName() {
            auto app = GetApp();
            if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) {
                return "";
            }
            return app.RootMap.MapInfo.Name;
        }

        string GetCurrentMapUID() {
            auto app = GetApp();
            if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) {
                return "";
            }
            return app.RootMap.MapInfo.MapUid;
        }

        void IndexAndSaveToFile() {
#if DEPENDENCY_ARCHIVIST
            IndexAndSaveToArchivist();
#else
            pbRecords.RemoveRange(0, pbRecords.Length);

            for (uint i = 0; i < GetApp().ReplayRecordInfos.Length; i++) {
                auto record = GetApp().ReplayRecordInfos[i];
                string path = record.Path;

                if (path.StartsWith("Autosaves\\")) {
                    string mapUid = record.MapUid;
                    string fileName = record.FileName;

                    string relativePath = "Replays/" + fileName;
                    string fullFilePath = IO::FromUserGameFolder(relativePath);

                    PBRecord@ pbRecord = PBRecord(mapUid, fileName, fullFilePath);
                    pbRecords.InsertLast(pbRecord);
                }
            }

            SavePBRecordsToFile();
#endif
        }

        namespace PBManager {
            void LoadCompletePB() {
                LoadPBFromSubfolder("Complete");
            }

            void LoadSegmentedPB() {
                LoadPBFromSubfolder("Segmented");
            }

            void LoadPartialPB() {
                LoadPBFromSubfolder("Partial");
            }

            void LoadPBFromSubfolder(const string &in subfolder) {
                auto ghostMgr = GameCtx::GetGhostMgr();
                auto dfm = GameCtx::GetDFM();
                if (ghostMgr is null || dfm is null) {
                    log("LoadPBFromSubfolder skipped: ghost or replay backend unavailable", LogLevel::Warn, 140, "LoadPBFromSubfolder");
                    return;
                }

                for (uint i = 0; i < pbRecords.Length; i++) {
                    string filePath = pbRecords[i].FullFilePath;
                    string fileName = Path::GetFileName(filePath);

                    if (filePath.Contains("/" + subfolder + "/")) {
                        if (IO::FileExists(filePath)) {
                            auto task = dfm.Replay_Load(filePath);
                            while (task.IsProcessing) { yield(); }

                            if (task.HasFailed || !task.HasSucceeded) {
                                log("Failed to load replay file from " + filePath, LogLevel::Error, 152, "LoadPBFromSubfolder");
                                continue;
                            }

                            for (uint j = 0; j < task.Ghosts.Length; j++) {
                                auto ghost = task.Ghosts[j];
                                ghost.IdName = "Personal best";
                                ghost.Nickname = "$5d8" + "Personal best";
                                ghost.Trigram = "PB";
                                ghostMgr.Ghost_Add(ghost);
                            }
                            
                            log("Loaded " + subfolder + " PB ghost from " + filePath, LogLevel::Info, 164, "LoadPBFromSubfolder");
                        }
                    }
                }
            }

            void SavePBRecordsToFile() {
                string savePath = Server::serverPB;
                Json::Value jsonData = Json::Array();

                for (uint i = 0; i < pbRecords.Length; i++) {
                    Json::Value@ record = Json::Object();
                    record["MapUid"] = pbRecords[i].MapUid;
                    record["FileName"] = pbRecords[i].FileName;
                    record["FullFilePath"] = pbRecords[i].FullFilePath;
                    jsonData.Add(record);
                }

                string saveData = Json::Write(jsonData, true);
                _IO::File::WriteFile(savePath, saveData, true);
            }
        }

#endif








































        /* ************************************************************************************************** */

        array<PBRecord@> pbRecords;
        string autosaves_index = Server::serverPB + "autosaves_index.json";

        void SavePBRecordsToFile() {
            string savePath = autosaves_index;
            Json::Value jsonData = Json::Array();

            for (uint i = 0; i < pbRecords.Length; i++) {
                Json::Value@ record = Json::Object();
                record["MapUid"] = pbRecords[i].MapUid;
                record["FileName"] = pbRecords[i].FileName;
                record["FullFilePath"] = pbRecords[i].FullFilePath;
                jsonData.Add(record);
            }

            string saveData = Json::Write(jsonData, true);

            _IO::File::WriteFile(savePath, saveData, true);
        }

        void LoadPBRecordsFromFile() {
            string loadPath = autosaves_index;
            if (!IO::FileExists(loadPath)) {
                log("PBManager: Autosaves index file does not exist. Indexing will be performed on map load.", LogLevel::Info, 259, "LoadPBRecordsFromFile");
                return;
            }

            string str_jsonData = _IO::File::ReadFileToEnd(loadPath);
            Json::Value jsonData = Json::Parse(str_jsonData);

            pbRecords.RemoveRange(0, pbRecords.Length);

            for (uint i = 0; i < jsonData.Length; i++) {
                auto j = jsonData[i];
                string mapUid = j["MapUid"];
                string fileName = j["FileName"];
                string fullFilePath = j["FullFilePath"];
                PBRecord@ pbRecord = PBRecord(mapUid, fileName, fullFilePath);
                pbRecords.InsertLast(pbRecord);
            }

            log("PBManager: Successfully loaded autosaves index from " + loadPath, LogLevel::Info, 278, "LoadPBRecordsFromFile");
        }

        void main() {
            PBVisibilityHook::InitializeHook();
            if (!IO::FileExists(autosaves_index)) {
                IndexAndSaveToFile();
            }
            startnew(MapTracker::MapMonitor);

            PBManager::Initialize(GetApp());
            PBManager::LoadPB();
        }

        void OnDisabled() {
            PBVisibilityHook::UninitializeHook();
            PBManager::UnloadAllPBs();
        }

        void OnDestroyed() {
            OnDisabled();
        }

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
                            startnew(PBManager::LoadPB);
                        } else {
                            startnew(PBManager::UnloadAllPBs);
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

                log("PBVisibilityHook: Hooks registered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 345, "InitializeHook");
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
                log("PBVisibilityHook: Hooks unregistered for TogglePB and UpdatePBGhostVisibility.", LogLevel::Info, 357, "UninitializeHook");
            }
        }

        class PBRecord {
            string MapUid;
            string FileName;
            string FullFilePath;

            PBRecord(const string &in mapUid, const string &in fileName, const string &in fullFilePath) {
                MapUid = mapUid;
                FileName = fileName;
                FullFilePath = fullFilePath;
            }
        }

        namespace PBManager {
            array<PBRecord@> pbRecords;
            string autosaves_index = Server::serverPB + "autosaves_index.json";

            NGameGhostClips_SMgr@ ghostMgr;
            CGameCtnMediaClipPlayer@ currentPBGhostPlayer;
            array<PBRecord@> currentMapPBRecords;
            array<uint> saving;

            void Initialize(CGameCtnApp@ app) {
                @ghostMgr = GhostClipsMgr::Get(app);
                needsRefresh = true;
            }

            bool IsPBLoaded() {
                if (ghostMgr is null) return false;
                CGameCtnMediaClipPlayer@ pbClipPlayer = GhostClipsMgr::GetPBClipPlayer(ghostMgr);
                return pbClipPlayer !is null;
            }

            bool IsLocalPBLoaded() {
                auto net = cast<CGameCtnNetwork>(GetApp().Network);
                if (net is null) return false;
                auto cmap = cast<CGameManiaAppPlayground>(net.ClientManiaAppPlayground);
                if (cmap is null) return false;
                auto dfm = cmap.DataFileMgr;
                if (dfm is null) return false;
                
                for (uint i = 0; i < dfm.Ghosts.Length; i++) {
                    if (dfm.Ghosts[i].IdName.ToLower().Contains("personal best")) {
                        return true;
                    }
                }
                return false;
            }

            bool needsRefresh = true;
            void LoadPB() {
                UnloadAllPBs();
                if (needsRefresh) LoadPBFromIndex();
                needsRefresh = false;
                LoadPBFromCache();
            }
            
            void LoadPBFromIndex() {
                string loadPath = autosaves_index;
                if (!IO::FileExists(loadPath)) { return; }

                string str_jsonData = _IO::File::ReadFileToEnd(loadPath);
                Json::Value jsonData = Json::Parse(str_jsonData);

                pbRecords.RemoveRange(0, pbRecords.Length);

                for (uint i = 0; i < jsonData.Length; i++) {
                    auto j = jsonData[i];
                    string mapUid = j["MapUid"];
                    string fileName = j["FileName"];
                    string fullFilePath = j["FullFilePath"];
                    PBRecord@ pbRecord = PBRecord(mapUid, fileName, fullFilePath);
                    pbRecords.InsertLast(pbRecord);
                    // log("LoadPBFromIndex: Loaded PBRecord for MapUid: " + mapUid + ", FileName: " + fileName, LogLevel::Dark, 434, "LoadPBFromIndex");
                }

                currentMapPBRecords = GetPBRecordsForCurrentMap();
            }

            void LoadPBFromCache() {
                currentMapPBRecords = GetPBRecordsForCurrentMap();
                auto ghostMgr = GameCtx::GetGhostMgr();
                auto dfm = GameCtx::GetDFM();
                if (ghostMgr is null || dfm is null) {
                    log("LoadPBFromCache skipped: ghost or replay backend unavailable", LogLevel::Warn, 431, "LoadPBFromCache");
                    return;
                }

                for (uint i = 0; i < currentMapPBRecords.Length; i++) {
                    if (IO::FileExists(currentMapPBRecords[i].FullFilePath)) {
                        auto task = dfm.Replay_Load(currentMapPBRecords[i].FullFilePath);
                        while (task.IsProcessing) { yield(); }

                        if (task.HasFailed || !task.HasSucceeded) {
                            log("Failed to load replay file from cache: " + currentMapPBRecords[i].FullFilePath, LogLevel::Error, 450, "LoadPBFromCache");
                            continue;
                        }

                        for (uint j = 0; j < task.Ghosts.Length; j++) {
                            auto ghost = task.Ghosts[j];
                            ghost.IdName = "Personal best";
                            ghost.Nickname = "$5d8" + "Personal best";
                            ghost.Trigram = "PB";
                            ghostMgr.Ghost_Add(ghost);
                        }
                        
                        log("Loaded PB ghost from " + currentMapPBRecords[i].FullFilePath, LogLevel::Info, 462, "LoadPBFromCache");
                    }
                }
            }

            void UnloadAllPBs() {
                auto mgr = GhostClipsMgr::Get(GetApp());
                if (mgr is null) { return; }

                for (int i = int(mgr.Ghosts.Length) - 1; i >= 0; i--) {
                    string ghostNickname;
                    try {
                        ghostNickname = mgr.Ghosts[i].GhostModel.GhostNickname;
                    } catch {
                        log("UnloadAllPBs: Failed to access GhostNickname for ghost at index " + i, LogLevel::Warn, 478, "UnloadAllPBs");
                        continue;
                    }

                    if (ghostNickname.ToLower().Contains("personal best")) {
                        UnloadPB(uint(i));
                    }
                }

                auto dfm = GameCtx::GetDFM();
                if (dfm is null) return;
                
                array<MwId> ghostIds;

                for (uint i = 0; i < dfm.Ghosts.Length; i++) {
                    if (dfm.Ghosts[i].IdName.ToLower().Contains("personal best")) {
                        ghostIds.InsertLast(dfm.Ghosts[i].Id);
                    }
                }

                for (uint i = 0; i < ghostIds.Length; i++) {
                    dfm.Ghost_Release(ghostIds[i]);
                }

                currentMapPBRecords.RemoveRange(0, currentMapPBRecords.Length);
            }

            void UnloadPB(uint i) {
                auto ghostMgr = GameCtx::GetGhostMgr();
                if (ghostMgr is null) { return; }
                auto mgr = GhostClipsMgr::Get(GetApp());
                if (mgr is null) { return; }
                if (i >= mgr.Ghosts.Length) { return; }

                uint id = GhostClipsMgr::GetInstanceIdAtIx(mgr, i);
                if (id == uint(-1)) { return; }

                string wsid = LoginToWSID(mgr.Ghosts[i].GhostModel.GhostLogin);
                Update_ML_SetGhostUnloaded(wsid);

                ghostMgr.Ghost_Remove(MwId(id));

                int ix = saving.Find(id);
                if (ix >= 0) { saving.RemoveAt(ix); }

                if (i < currentMapPBRecords.Length) {
                    string removedMapUid = currentMapPBRecords[i].MapUid;
                    string removedFilePath = currentMapPBRecords[i].FullFilePath;
                    currentMapPBRecords.RemoveAt(i);
                }
            }

            array<PBRecord@>@ GetPBRecordsForCurrentMap() {
                string currentMapUid = get_CurrentMapUID();
                array<PBRecord@> currentMapRecords;
                currentMapRecords.Resize(0);

                for (uint i = 0; i < pbRecords.Length; i++) {
                    if (pbRecords[i].MapUid == currentMapUid) {
                        currentMapRecords.InsertLast(pbRecords[i]);
                    }
                }

                return currentMapRecords;
            }

            const string SetFocusedRecord_PageUID = "SetFocusedRecord";
            dictionary ghostWsidsLoaded;

            void Update_ML_SetGhostUnloaded(const string &in wsid) {
                if (ghostWsidsLoaded.Exists(wsid)) {
                    ghostWsidsLoaded.Delete(wsid);
                }
                MLHook::Queue_MessageManialinkPlayground(SetFocusedRecord_PageUID, {"SetGhostUnloaded", wsid});
            }

            string LoginToWSID(const string &in login) {
                try {
                    auto buf = MemoryBuffer();
                    buf.WriteFromBase64(login, true);
                    string hex = Utils::BufferToHex(buf);
                    string wsid = hex.SubStr(0, 8)
                        + "-" + hex.SubStr(8, 4)
                        + "-" + hex.SubStr(12, 4)
                        + "-" + hex.SubStr(16, 4)
                        + "-" + hex.SubStr(20);
                    return wsid;
                } catch {
                    return login;
                }
            }
        }

        namespace GhostClipsMgr {
            const uint16 GhostsOffset = GetOffset("NGameGhostClips_SMgr", "Ghosts");
            const uint16 GhostInstIdsOffset = GhostsOffset + 0x10;

            NGameGhostClips_SMgr@ Get(CGameCtnApp@ app) {
                return GetGhostClipsMgr(app);
            }

            NGameGhostClips_SMgr@ GetGhostClipsMgr(CGameCtnApp@ app) {
                if (app.GameScene is null) return null;
                auto nod = Dev::GetOffsetNod(app.GameScene, 0x120);
                if (nod is null) return null;
                return Dev::ForceCast<NGameGhostClips_SMgr@>(nod).Get();
            }

            CGameCtnMediaClipPlayer@ GetPBClipPlayer(NGameGhostClips_SMgr@ mgr) {
                return cast<CGameCtnMediaClipPlayer>(Dev::GetOffsetNod(mgr, 0x40));
            }

            uint GetInstanceIdAtIx(NGameGhostClips_SMgr@ mgr, uint ix) {
                if (mgr is null) return uint(-1);
                uint bufOffset = GhostInstIdsOffset;
                uint64 bufPtr = Dev::GetOffsetUint64(mgr, bufOffset);
                uint nextIdOrSomething = Dev::GetOffsetUint32(mgr, bufOffset + 0x8);
                uint bufLen = Dev::GetOffsetUint32(mgr, bufOffset + 0xC);
                uint bufCapacity = Dev::GetOffsetUint32(mgr, bufOffset + 0x10);

                if (bufLen == 0 || bufCapacity == 0) return uint(-1);

                // A bunch of trial and error to figure this out >.< // Thank you XertroV :peeepoLove:
                if (bufLen <= ix) return uint(-1);
                if (bufPtr == 0 || bufPtr % 8 != 0) return uint(-1);
                uint slot = Dev::ReadUInt32(bufPtr + (bufCapacity * 4) + ix * 4);
                uint msb = Dev::ReadUInt32(bufPtr + slot * 4) & 0xFF000000;
                return msb + slot;
            }
        }

        uint16 GetOffset(const string &in className, const string &in memberName) {
            auto ty = Reflection::GetType(className);
            auto memberTy = ty.GetMember(memberName);
            return memberTy.Offset;
        }

        namespace Utils {
            string BufferToHex(MemoryBuffer@ buf) {
                buf.Seek(0);
                uint size = buf.GetSize();
                string ret;
                for (uint i = 0; i < size; i++) {
                    ret += Uint8ToHex(buf.ReadUInt8());
                }
                return ret;
            }

            string Uint8ToHex(uint8 val) {
                return Uint4ToHex(val >> 4) + Uint4ToHex(val & 0xF);
            }

            string Uint4ToHex(uint8 val) {
                if (val > 0xF) throw('val out of range: ' + val);
                string ret = " ";
                if (val < 10) {
                    ret[0] = val + 0x30;
                } else {
                    // 0x61 = a
                    ret[0] = val - 10 + 0x61;
                }
                return ret;
            }
        }
    }

}
}
#endif
