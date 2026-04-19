namespace EntryPoints {
namespace CurrentMap {
namespace Medals {

    const string PVM_INFO_URL = "https://raw.githubusercontent.com/Naxanria/tm_stuff/refs/heads/main/pvm_info.json";

    class PVMJsonMapData {
        string mapUid;
        array<uint> medalTimes;
    }

    class PVMJsonSource {
        int id = -1;
        string name;
        string author;
        string jsonUrl;

        bool dataRequested = false;
        bool dataLoaded = false;
        bool dataFailed = false;

        array<string> medalNames;
        array<string> medalColorCodes;
        array<string> medalIcons;
        array<PVMJsonMapData@> maps;
        dictionary mapIndexByUid;
    }

    class PVMPluginMedal : PluginMedalWithoutExport {
        string displayName = "";
        string displayColorCode = "\\$fff";
        string displayIconText = "";
    }

    bool g_PvmInfoRequested = false;
    bool g_PvmInfoLoaded = false;
    bool g_PvmInfoFailed = false;
    array<PVMJsonSource@> g_PvmSources;
    array<PVMPluginMedal@> g_PvmPluginMedals;

    bool IsPVMAvailable() {
        return PluginState::IsPluginLoaded("PVM", "PVM");
    }

    string MakePVMColorCode(const string &in colorValue) {
        if (colorValue.Length == 0) return "\\$fff";
        if (colorValue.StartsWith("\\$")) return colorValue;
        return "\\$" + colorValue;
    }

    void ResetPVMMedalsState() {
        g_PvmPluginMedals.RemoveRange(0, g_PvmPluginMedals.Length);
    }

    void EnsurePVMInfoRequested() {
        if (g_PvmInfoRequested || g_PvmInfoLoaded || g_PvmInfoFailed) return;
        g_PvmInfoRequested = true;
        startnew(CoroutineFunc(LoadPVMInfo));
    }

    void LoadPVMInfo() {
        auto req = Net::HttpRequest();
        req.Method = Net::HttpMethod::Get;
        req.Url = PVM_INFO_URL;
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            g_PvmInfoFailed = true;
            log("PVM manifest request failed with HTTP " + req.ResponseCode(), LogLevel::Warning, 547, "CurrentMap::Medals");
            return;
        }

        Json::Value manifest = Json::Parse(req.String());
        auto pvms = manifest["PVMS"];
        if (pvms.GetType() != Json::Type::Array) {
            g_PvmInfoFailed = true;
            log("PVM manifest JSON did not contain a PVMS array.", LogLevel::Warning, 548, "CurrentMap::Medals");
            return;
        }

        g_PvmSources.RemoveRange(0, g_PvmSources.Length);
        for (uint i = 0; i < pvms.Length; i++) {
            auto item = pvms[i];
            if (item.GetType() != Json::Type::Object) continue;

            auto source = PVMJsonSource();
            source.id = int(item["id"]);
            source.name = string(item["name"]);
            source.author = string(item["author"]);
            source.jsonUrl = string(item["json"]);
            if (source.jsonUrl.Length == 0) continue;

            g_PvmSources.InsertLast(source);
        }

        g_PvmInfoLoaded = true;
    }

    void EnsurePVMSourceDataRequested(PVMJsonSource@ source) {
        if (source is null || source.dataRequested || source.dataLoaded || source.dataFailed) return;
        source.dataRequested = true;
        startnew(CoroutineFuncUserdata(LoadPVMSourceData), source);
    }

    void LoadPVMSourceData(ref@ r) {
        PVMJsonSource@ source = cast<PVMJsonSource@>(r);
        if (source is null) return;

        auto req = Net::HttpRequest();
        req.Method = Net::HttpMethod::Get;
        req.Url = source.jsonUrl;
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            source.dataFailed = true;
            log("PVM source data request failed with HTTP " + req.ResponseCode() + " for " + source.name, LogLevel::Warning, 549, "CurrentMap::Medals");
            return;
        }

        Json::Value sourceJson = Json::Parse(req.String());
        auto structure = sourceJson["structure"];
        auto medals = structure["medals"];
        auto maps = sourceJson["maps"];
        if (medals.GetType() != Json::Type::Array || maps.GetType() != Json::Type::Array) {
            source.dataFailed = true;
            log("PVM source JSON was missing medals or maps arrays for " + source.name, LogLevel::Warning, 550, "CurrentMap::Medals");
            return;
        }

        source.medalNames.RemoveRange(0, source.medalNames.Length);
        source.medalColorCodes.RemoveRange(0, source.medalColorCodes.Length);
        source.medalIcons.RemoveRange(0, source.medalIcons.Length);
        source.maps.RemoveRange(0, source.maps.Length);
        source.mapIndexByUid.DeleteAll();

        for (uint i = 0; i < medals.Length; i++) {
            auto medal = medals[i];
            if (medal.GetType() != Json::Type::Object) continue;

            source.medalNames.InsertLast(string(medal["name"]));
            source.medalColorCodes.InsertLast(MakePVMColorCode(string(medal["colour"])));
            source.medalIcons.InsertLast(string(medal["icon"]));
        }

        for (uint i = 0; i < maps.Length; i++) {
            auto item = maps[i];
            if (item.GetType() != Json::Type::Object) continue;

            string mapUid = string(item["uid"]);
            if (mapUid.Length == 0) continue;

            auto mapData = PVMJsonMapData();
            mapData.mapUid = mapUid;

            auto pvm = item["pvm"];
            auto times = pvm["times"];
            if (times.GetType() != Json::Type::Array) continue;

            for (uint j = 0; j < times.Length; j++) {
                int64 medalTime = int64(times[j]);
                if (medalTime < 0 || medalTime > int64(0xFFFFFFFF)) {
                    mapData.medalTimes.InsertLast(0);
                } else {
                    mapData.medalTimes.InsertLast(uint(medalTime));
                }
            }

            source.mapIndexByUid[mapUid] = int(source.maps.Length);
            source.maps.InsertLast(mapData);
        }

        source.dataLoaded = true;
    }

    PVMJsonSource@ FindMatchingPVMSource(const string &in mapUid) {
        if (mapUid.Length == 0) return null;

        for (uint i = 0; i < g_PvmSources.Length; i++) {
            auto source = g_PvmSources[i];
            if (source is null) continue;

            if (source.dataLoaded) {
                int mapIndex = -1;
                if (source.mapIndexByUid.Get(mapUid, mapIndex)) return source;
            } else {
                EnsurePVMSourceDataRequested(source);
            }
        }

        return null;
    }

    PVMJsonMapData@ GetPVMMapData(PVMJsonSource@ source, const string &in mapUid) {
        if (source is null || mapUid.Length == 0 || !source.dataLoaded) return null;

        int mapIndex = -1;
        if (!source.mapIndexByUid.Get(mapUid, mapIndex)) return null;
        if (mapIndex < 0 || uint(mapIndex) >= source.maps.Length) return null;
        return source.maps[mapIndex];
    }

    bool IsPVMSourceEnabled(int pvmId) {
        return true;
    }

    bool IsPVMMedalVisible(int pvmId, int medalIndex) {
        return true;
    }

    string GetPVMDisplayName(PVMJsonSource@ source, int medalIndex) {
        string sourceName = source is null || source.name.Length == 0 ? "PVM" : source.name;
        string medalName = "Medal " + (medalIndex + 1);
        if (source !is null && medalIndex >= 0 && uint(medalIndex) < source.medalNames.Length && source.medalNames[medalIndex].Length > 0) {
            medalName = source.medalNames[medalIndex];
        }
        return sourceName + " " + medalName;
    }

    void RefreshPVMMedals() {
        ResetPVMMedalsState();
        if (!IsPVMAvailable()) return;

        EnsurePVMInfoRequested();
        if (!g_PvmInfoLoaded) return;

        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return;

        PVMJsonSource@ source = FindMatchingPVMSource(mapUid);
        if (source is null) return;
        if (!IsPVMSourceEnabled(source.id)) return;

        EnsurePVMSourceDataRequested(source);
        if (!source.dataLoaded) return;

        PVMJsonMapData@ mapData = GetPVMMapData(source, mapUid);
        if (mapData is null) return;

        for (uint i = 0; i < mapData.medalTimes.Length; i++) {
            if (!IsPVMMedalVisible(source.id, i)) continue;

            uint medalTime = mapData.medalTimes[i];
            if (medalTime == 0) continue;

            auto medal = PVMPluginMedal();
            medal.displayName = GetPVMDisplayName(source, i);
            if (i < source.medalColorCodes.Length) medal.displayColorCode = source.medalColorCodes[i];
            if (i < source.medalIcons.Length && source.medalIcons[i].Length > 0) {
                medal.displayIconText = medal.displayColorCode + source.medalIcons[i];
            }
            medal.currentMapMedalTime = medalTime;
            medal.medalExists = true;
            g_PvmPluginMedals.InsertLast(medal);
        }
    }

    void AppendPVMDisplayEntries(array<DisplayEntry@>@ entries) {
        if (!IsPVMAvailable()) return;

        for (uint i = 0; i < g_PvmPluginMedals.Length; i++) {
            auto medal = g_PvmPluginMedals[i];
            if (medal is null) continue;
            AddDisplayEntry(entries, medal.displayName, medal.displayColorCode, medal, true, medal.displayIconText);
        }
    }
}
}
}
