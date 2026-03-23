namespace Features {
namespace LRFromMapIdentifier {
    RecordInfo@ recordInfo;
    
    class RecordInfo {
        string mapUid;
        string offset;
        string saveLocation;
        string mapId;
        string accountId;

        bool mapIdFetched = false;
        bool accountIdFetched = false;

        RecordInfo(const string &in _mapUid, const string &in _offset, const string &in _saveLocation = "", const string &in _accountId = "", const string &in _mapId = "") {
            mapUid = _mapUid;
            offset = _offset;
            saveLocation = _saveLocation;

                   if (saveLocation == "Official") {  defaultSaveLocation = Server::officialFilesDirectory;
            } else if (saveLocation == "GPS") {       defaultSaveLocation = Server::currentMapRecordsGPS;
            } else if (saveLocation == "AnyMap") {    defaultSaveLocation = Server::serverDirectoryAutoMove;
            } else if (saveLocation == "OtherMaps") { defaultSaveLocation = Server::specificDownloadedFilesDirectory;
            } else if (saveLocation == "Medal") {     defaultSaveLocation = Server::serverDirectoryMedal;
            } else if (saveLocation == "") {          defaultSaveLocation = Server::serverDirectoryAutoMove;
            }

            accountId = _accountId;
            accountIdFetched = accountId.Length > 0;
            mapId = _mapId;
            mapIdFetched = mapId.Length > 0;
        }
    }

    string defaultSaveLocation = Server::serverDirectoryAutoMove;

    void LoadSelectedRecord(const string &in _mapUid, const string &in _offset, const string &in _specialSaveLocation, const string &in _accountId = "", const string &in _mapId = "") {
        recordInfo = RecordInfo(_mapUid, _offset, _specialSaveLocation, _accountId, _mapId);

        startnew(Coro_LoadSelectedGhost);
    }

    void Coro_LoadSelectedGhost() {
        if (!recordInfo.accountIdFetched) { startnew(Coro_FetchAccountId); }
        if (!recordInfo.mapIdFetched) { startnew(Coro_FetchMapId); }

        while (!(recordInfo.accountIdFetched && recordInfo.mapIdFetched)) { yield(); }

        if (recordInfo.accountId.Length == 0) { log("Account ID not found.", LogLevel::Error, 54, "Coro_LoadSelectedGhost"); return; }
        if (recordInfo.mapId.Length == 0) { log("Map ID not found.", LogLevel::Error, 55, "Coro_LoadSelectedGhost"); return; }

        SaveReplay();
    }

    void Coro_FetchAccountId() {
        if (recordInfo.accountId.Length > 0) { 
            log("AccountId provided in LoadSelectedRecord", LogLevel::Info, 62, "Coro_FetchAccountId"); 
            recordInfo.accountIdFetched = true; 
            return; 
        }

        recordInfo.accountIdFetched = false;

        string url = "https://live-services.trackmania.nadeo.live/api/token/leaderboard/group/Personal_Best/map/" + recordInfo.mapUid + "/top?onlyWorld=true&length=1&offset=" + recordInfo.offset;
        auto req = NadeoServices::Get("NadeoLiveServices", url);

        req.Start();

        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("Failed to fetch account ID, response code: " + req.ResponseCode(), LogLevel::Error, 77, "Coro_FetchAccountId");
            recordInfo.accountId = "";
        } else {
            Json::Value data = Json::Parse(req.String());
            if (data.GetType() == Json::Type::Null) {
                log("Failed to parse response for account ID.", LogLevel::Error, 82, "Coro_FetchAccountId");
                recordInfo.accountId = "";
            } else {
                auto tops = data["tops"];
                if (tops.GetType() != Json::Type::Array || tops.Length == 0) {
                    log("Invalid tops data in response.", LogLevel::Error, 87, "Coro_FetchAccountId");
                    recordInfo.accountId = "";
                } else {
                    auto top = tops[0]["top"];
                    if (top.GetType() != Json::Type::Array || top.Length == 0) {
                        log("Invalid top data in response.", LogLevel::Error, 92, "Coro_FetchAccountId");
                        recordInfo.accountId = "";
                    } else {
                        recordInfo.accountId = top[0]["accountId"];
                        log("Found account ID: " + recordInfo.accountId, LogLevel::Info, 96, "Coro_FetchAccountId");
                    }
                }
            }
        }
        recordInfo.accountIdFetched = true;
    }

    void Coro_FetchMapId() {
        if (recordInfo.mapId.Length > 0) { 
            log("MapId provided in LoadSelectedRecord", LogLevel::Info, 106, "Coro_FetchMapId"); 
            recordInfo.mapIdFetched = true; 
            return; 
        }

        recordInfo.mapIdFetched = false;
        string url = "https://prod.trackmania.core.nadeo.online/maps/?mapUidList=" + recordInfo.mapUid;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();

        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            log("Failed to fetch map ID, response code: " + req.ResponseCode(), LogLevel::Error, 120, "Coro_FetchMapId");
            recordInfo.mapId = "";
        } else {
            Json::Value data = Json::Parse(req.String());
            if (data.GetType() == Json::Type::Null) {
                log("Failed to parse response for map ID.", LogLevel::Error, 125, "Coro_FetchMapId");
                recordInfo.mapId = "";
            } else {
                if (data.GetType() != Json::Type::Array || data.Length == 0) {
                    log("Invalid map data in response.", LogLevel::Error, 129, "Coro_FetchMapId");
                    recordInfo.mapId = "";
                } else {
                    recordInfo.mapId = data[0]["mapId"];
                    log("Found map ID: " + recordInfo.mapId, LogLevel::Info, 133, "Coro_FetchMapId");
                }
            }
        }
        recordInfo.mapIdFetched = true;
    }

    void SaveReplay() {
        string url = "https://prod.trackmania.core.nadeo.online/v2/mapRecords/?accountIdList=" + recordInfo.accountId + "&mapId=" + recordInfo.mapId;
        auto req = NadeoServices::Get("NadeoServices", url);

        req.Start();

        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) { log("Failed to fetch replay record, response code: " + req.ResponseCode(), LogLevel::Error, 148, "SaveReplay"); return; }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() == Json::Type::Null) { log("Failed to parse response for replay record.", LogLevel::Error, 151, "SaveReplay"); return; }
        if (data.GetType() != Json::Type::Array || data.Length == 0) { log("Invalid replay data in response.", LogLevel::Error, 152, "SaveReplay"); return; }

        string fileUrl = data[0]["url"];

        string savePath = "";

               if (recordInfo.saveLocation == "Official") {  savePath = Server::officialFilesDirectory +           "Official_" +  recordInfo.mapUid + "_Position" + recordInfo.offset + "_" + recordInfo.accountId + "_" + tostring(Time::Stamp) + ".Ghost.Gbx";
        } else if (recordInfo.saveLocation == "GPS") {       savePath = Server::currentMapRecordsGPS +             "GPS_" +       recordInfo.mapUid + "_Position" + recordInfo.offset + "_" + recordInfo.accountId + "_" + tostring(Time::Stamp) + ".Replay.Gbx";
        } else if (recordInfo.saveLocation == "AnyMap") {    savePath = Server::serverDirectoryAutoMove +          "AnyMap_" +    recordInfo.mapUid + "_Position" + recordInfo.offset + "_" + recordInfo.accountId + "_" + tostring(Time::Stamp) + ".Ghost.Gbx";
        } else if (recordInfo.saveLocation == "OtherMaps") { savePath = Server::specificDownloadedFilesDirectory + "OtherMaps_" + recordInfo.mapUid + "_Position" + recordInfo.offset + "_" + recordInfo.accountId + "_" + tostring(Time::Stamp) + ".Ghost.Gbx";
        } else if (recordInfo.saveLocation == "Medal") {     savePath = Server::serverDirectoryMedal +             "Medal_" +     recordInfo.mapUid + "_Position" + recordInfo.offset + "_" + recordInfo.accountId + "_" + tostring(Time::Stamp) + ".Ghost.Gbx";
        } else if (recordInfo.saveLocation == "") {          savePath = Server::savedFilesDirectory +              "AutoMove_" +  recordInfo.mapUid + "_Position" + recordInfo.offset + "_" + recordInfo.accountId + "_" + tostring(Time::Stamp) + ".Replay.Gbx";
        }

        auto fileReq = NadeoServices::Get("NadeoServices", fileUrl);

        fileReq.Start();

        while (!fileReq.Finished()) { yield(); }

        if (fileReq.ResponseCode() != 200) { log("Failed to download replay file, response code: " + fileReq.ResponseCode(), LogLevel::Error, 172, "SaveReplay"); return; }

        fileReq.SaveToFile(savePath);

        LoadedRecords::SourceKind srcKind = LoadedRecords::SourceKind::MapRecord;
        if (recordInfo.saveLocation == "Official") srcKind = LoadedRecords::SourceKind::Official;
        else if (recordInfo.saveLocation == "OtherMaps") srcKind = LoadedRecords::SourceKind::Profile;
        LoadedRecords::TrackPendingFile(Path::GetFileName(savePath), srcKind, savePath, recordInfo.mapUid, recordInfo.accountId);

        loadRecord.LoadRecordFromLocalFile(savePath);

        log(savePath.ToLower().EndsWith(".replay.gbx") ? "Replay" : "Ghost" + " file saved to: " + savePath, LogLevel::Info, 178, "SaveReplay");
    }
}
}
