namespace Features {
namespace LRBasedOnCurrentMap {
    
/* Pain Pain Go Away 
// GPS extraction/loading is something I've canned for now, due to lack of knowledge on my part...

// namespace GPS {
//     string savePathBase = "";
//     CGameCtnChallenge@ rootMap = null;
//     array<GhostData@> ghosts;
//     string finalSavePath = "";
//     uint64 CTmRaceResult_VTable_Ptr = 0x0;
//     int selectedGhostIndex = -1;

//     bool gpsReplayCanBeLoaded = false;

//     void LoadReplay() {
//         if (selectedGhostIndex >= 0 && selectedGhostIndex < ghosts.Length) {
//             ReplayLoader::LoadReplayFromPath(ghosts[selectedGhostIndex].savePath);
//         }
//     }

//     void OnMapLoad() {
//         FetchMap();
        
//         gpsReplayCanBeLoaded = GPSReplayCanBeLoadedForCurrentMap();
//         if (!gpsReplayCanBeLoaded) { return; }

//         FetchPath();
//         FetchVTablePtr();
//         FetchGhosts();
//         ConvertGhosts();
//         SaveReplays();
//     }

//     bool GPSReplayCanBeLoadedForCurrentMap() {
//         if (rootMap is null || rootMap.ClipGroupInGame is null) {
//             log("rootMap or ClipGroupInGame is null", LogLevel::Error, 40, "GPSReplayCanBeLoadedForCurrentMap");
//             return false;
//         }

//         for (uint i = 0; i < rootMap.ClipGroupInGame.Clips.Length; i++) {
//             auto clip = rootMap.ClipGroupInGame.Clips[i];
//             if (clip is null) continue;
//             for (uint j = 0; j < clip.Tracks.Length; j++) {
//                 auto track = clip.Tracks[j];
//                 if (track is null) continue;
//                 if (track.Name.StartsWith("Ghost:")) {
//                     return true;
//                 }
//             }
//         }
//         return false;
//     }

//     void FetchPath() {
//         savePathBase = Server::currentMapRecordsGPS + Text::StripFormatCodes(GetApp().RootMap.MapName) + "_" + GetApp().RootMap.MapInfo.MapUid + "/";
//     }

//     void FetchMap() {
//         @rootMap = GetApp().RootMap;
//     }

//     void FetchVTablePtr() {
//         string ghostFilePath = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Dummy/CTmRaceResult_VTable_Ptr.Replay.Gbx");

//         while (rootMap is null) { yield(); }    // Change to something that waits until the player is loaded.
//         sleep(1000);                            // Change to something that waits until the player is loaded.

//         auto dfm = cast<CGameDataFileManagerScript>(GetApp().Network.ClientManiaAppPlayground.DataFileMgr);
//         if (dfm is null) { log("DataFileMgr is null", LogLevel::Error, 73, "FetchVTablePtr"); return; }

//         auto task = dfm.Replay_Load(ghostFilePath);
//         while (task.IsProcessing) { yield(); }

//         if (task.HasFailed || !task.HasSucceeded) {
//             log("Failed to load replay file!", LogLevel::Error, 79, "FetchVTablePtr");
//             log(task.ErrorCode, LogLevel::Error, 80, "FetchVTablePtr");
//             log(task.ErrorDescription, LogLevel::Error, 81, "FetchVTablePtr");
//             log(task.ErrorType, LogLevel::Error, 82, "FetchVTablePtr");
//             log(tostring(task.Ghosts.Length), LogLevel::Error, 83, "FetchVTablePtr");
//             return;
//         }

//         if (task.Ghosts.Length == 0) { log("No ghosts found in the replay file!", LogLevel::Warn, 87, "FetchVTablePtr"); return; }

//         auto ghost = task.Ghosts[0];
//         if (ghost is null) { log("Failed to retrieve the ghost from the replay file", LogLevel::Error, 90, "FetchVTablePtr"); return; }

//         uint64 pointer = Dev::GetOffsetUint64(ghost.Result, 0x0);
//         log("Hexadecimal pointer: " + Text::FormatPointer(pointer), LogLevel::Info, 93, "FetchVTablePtr");

//         CTmRaceResult_VTable_Ptr = pointer;
//     }

//     array<CGameGhostScript@> GetGhost(CGameDataFileManagerScript@ dfm) {
//         array<CGameGhostScript@> ghosts;
//         for (uint i = 0; i < dfm.Ghosts.Length; i++) {
//             if (dfm.Ghosts[i].Nickname == "cfa844b7-6b53-4663-ac0d-9bdd3ad1af22") {
//                 ghosts.InsertLast(dfm.Ghosts[i]);
//             }
//         }
//         return ghosts;
//     }

//     void FetchGhosts() {
//         for (uint i = 0; i < rootMap.ClipGroupInGame.Clips.Length; i++) {
//             auto clip = rootMap.ClipGroupInGame.Clips[i];
//             for (uint j = 0; j < clip.Tracks.Length; j++) {
//                 auto track = clip.Tracks[j];
//                 if (track.Name.StartsWith("Ghost:")) {
//                     for (uint k = 0; k < track.Blocks.Length; k++) {
//                         auto block = cast<CGameCtnMediaBlockEntity>(track.Blocks[k]);
//                         if (block !is null) {
//                             auto recordData = cast<CPlugEntRecordData>(Dev::GetOffsetNod(block, 0x58));
//                             if (recordData !is null) {
//                                 auto newGhost = CGameCtnGhost();
//                                 Dev::SetOffset(newGhost, 0x2e0, recordData);
//                                 recordData.MwAddRef();
                                
//                                 newGhost.ModelIdentName.SetName("CarSport");
//                                 newGhost.ModelIdentAuthor.SetName("Nadeo");
//                                 newGhost.Validate_ChallengeUid.SetName(rootMap.EdChallengeId);

//                                 auto ptr1 = GetSomeMemory();
//                                 auto ptr2 = GetSomeMemory();
//                                 Dev::SetOffset(newGhost, 0x2e8, ptr1);
//                                 Dev::SetOffset(newGhost, 0x2F0, uint(1));
//                                 Dev::SetOffset(newGhost, 0x2F4, uint(1));
//                                 Dev::Write(ptr1, ptr2);
//                                 Dev::Write(ptr2, uint(2));
//                                 Dev::Write(ptr2 + 4, uint(0x02000156));
//                                 Dev::Write(ptr2 + 8, uint(0));
//                                 Dev::Write(ptr2 + 0xC, uint(45450));
//                                 Dev::Write(ptr2 + 0x10, uint64(0));
//                                 Dev::Write(ptr2 + 0x18, uint64(0));
//                                 Dev::Write(ptr2 + 0x20, uint(0xD100000));
//                                 Dev::Write(ptr2 + 0x24, uint(1));

//                                 string ghostName = track.Name.SubStr(6);  // Remove "ghost:" prefix
//                                 string savePath = savePathBase + ghostName + "_" + Text::Format("%d", i) + ".Replay.Gbx";

//                                 if (!IO::FolderExists(_IO::File::GetFilePathWithoutFileName(savePath))) {
//                                     IO::CreateFolder(_IO::File::GetFilePathWithoutFileName(savePath), true);
//                                 }

//                                 print(ghostName + " _ " + newGhost.GhostNickname);

//                                 ghosts.InsertLast(GhostData(ghostName, savePath, newGhost));
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }

//     uint64 GetSomeMemory() {
//         CGameGhostScript@ tmp1 = CGameGhostScript();
//         Dev::SetOffset(tmp1, 0x8, tmp1);
//         auto ptr = Dev::GetOffsetUint64(tmp1, 0x8);
//         for (uint i = 0; i < 0x58; i += 8) {
//             Dev::SetOffset(tmp1, i, uint64(0));
//         }
//         return ptr;
//     }


//     void ConvertGhosts() {
//         for (uint i = 0; i < ghosts.Length; i++) {
//             if (ghosts[i] is null) { log("Ghost at index " + i + " is null", LogLevel::Error, 173, "ConvertGhosts"); continue; }
//             ghosts[i].ConvertToScript(CTmRaceResult_VTable_Ptr, ghosts[i].ghost);
//         }
//     }

//     void SaveReplays() {
//         for (uint i = 0; i < ghosts.Length; i++) {
//             if (ghosts[i] is null) {
//                 log("Ghost at index " + i + " is null", LogLevel::Error, 181, "SaveReplays");
//                 continue;
//             }
//             ghosts[i].Save(rootMap);
//         }
//     }
// }

// class GhostData {
//     int selcetedGhostIndex = -1;

//     string name;
//     string savePath;
//     CGameCtnGhost@ ghost;
//     CGameGhostScript@ ghostScript;

//     GhostData(const string &in name, const string &in savePath, CGameCtnGhost@ ghost) {
//         this.name = name;
//         this.savePath = savePath;
//         @this.ghost = ghost;
//     }

//     void ConvertToScript(uint64 CTmRaceResult_VTable_Ptr, CGameCtnGhost@ ghost) {
//         if (ghost is null) { log("Ghost is null in ConvertToScript", LogLevel::Error, 204, "ConvertToScript"); return; }

//         ghost.MwAddRef();

//         @ghostScript = CGameGhostScript();
//         MwId ghostId = MwId();
//         Dev::SetOffset(ghostScript, 0x18, ghostId.Value);
//         Dev::SetOffset(ghostScript, 0x20, ghost);
//         uint64 ghostPtr = Dev::GetOffsetUint64(ghostScript, 0x20);

//         CGameGhostScript@ tmRaceResultNodPre = CGameGhostScript();
//         Dev::SetOffset(tmRaceResultNodPre, 0x0, CTmRaceResult_VTable_Ptr);
//         CTmRaceResultNod@ tmRaceResultNod = Dev::ForceCast<CTmRaceResultNod@>(tmRaceResultNodPre).Get();
//         @tmRaceResultNodPre = null;
//         Dev::SetOffset(tmRaceResultNod, 0x18, ghostPtr + 0x28);
//         tmRaceResultNod.MwAddRef();

//         Dev::SetOffset(ghostScript, 0x28, tmRaceResultNod);
//     }

//     void Save(CGameCtnChallenge@ rootMap) {
//         if (ghostScript is null) { log("GhostScript is null in Save for ghost " + name, LogLevel::Error, 225, "Save"); return; }

//         print(savePath);
//         print(rootMap.MapName);
//         print(ghostScript.Nickname);

//         CGameDataFileManagerScript@ dataFileMgr = GetApp().PlaygroundScript.DataFileMgr;
//         CWebServicesTaskResult@ taskResult = dataFileMgr.Replay_Save(savePath, rootMap, ghostScript);
//         if (taskResult is null) {
//             log("Replay task returned null for ghost " + name, LogLevel::Error, 234, "Save");
//         }
//     }
// }
*/

}
}