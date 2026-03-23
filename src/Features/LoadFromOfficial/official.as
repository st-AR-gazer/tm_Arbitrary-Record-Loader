namespace Features {
namespace LRFromOfficialMaps {
namespace Official {
    int selectedYear = -1;
    int selectedSeason = -1;
    int selectedMap = -1;
    array<int> years;
    array<string> seasons;
    array<string> maps;

    void Init() {
        log("Initializing OfficialManager::UI", LogLevel::Info, 12, "Init");
        UpdateYears();
        UpdateSeasons();
        UpdateMaps();
    }

    string FetchOfficialMapUID() {
        if (selectedYear == -1 || selectedSeason == -1 || selectedMap == -1) {
            return "";
        }

        string season = seasons[selectedSeason];
        int year = years[selectedYear];
        int mapPosition = selectedMap;

        string filePath = Server::officialJsonFilesDirectory + "/" + season + "_" + tostring(year) + ".json";
        if (!IO::FileExists(filePath)) {
            log("File not found: " + filePath, LogLevel::Error, 29, "FetchOfficialMapUID");
            return "";
        }

        Json::Value root = Json::Parse(_IO::File::ReadFileToEnd(filePath));
        if (root.GetType() == Json::Type::Null) {
            log("Failed to parse JSON file: " + filePath, LogLevel::Error, 35, "FetchOfficialMapUID");
            return "";
        }

        for (uint i = 0; i < root.Length; i++) {
            auto playlist = root["playlist"];
            if (playlist.GetType() != Json::Type::Array) {
                continue;
            }

            for (uint j = 0; j < playlist.Length; j++) {
                auto map = playlist[j];
                if (map["position"] == mapPosition) {
                    return map["mapUid"];
                }
            }
        }

        log("Map UID not found for position: " + tostring(mapPosition), LogLevel::Error, 53, "FetchOfficialMapUID");
        return "";
    }

    void UpdateSeasons() {
        seasons = {"Spring", "Summer", "Fall", "Winter"};
        log("Seasons updated: " + seasons.Length + " seasons", LogLevel::Info, 59, "UpdateSeasons");
    }

    void UpdateMaps() {
        maps.Resize(0);
        for (int i = 1; i <= 25; i++) {
            maps.InsertLast("Map " + tostring(i));
        }
        log("Maps updated: " + maps.Length + " maps", LogLevel::Info, 67, "UpdateMaps");
    }

    void UpdateYears() {
        years.Resize(0);
        Time::Info info = Time::Parse();
        for (int y = 2020; y <= info.Year; y++) {
            years.InsertLast(y);
        }
        log("Years populated: " + years.Length + " years", LogLevel::Info, 76, "UpdateYears");
    }

    void SetSeasonYearToCurrent() {
        selectedSeason = 0;
        selectedYear = 0;

        int64 currentTime = Time::Stamp;

        string path = Server::officialJsonFilesDirectory;

        array<string>@ jsonFiles = IO::IndexFolder(path, true);

        for (uint i = 0; i < jsonFiles.Length; i++) {
            string filePath = jsonFiles[i];
            IO::File file(filePath, IO::FileMode::Read);
            string jsonContent = file.ReadToEnd();
            file.Close();

            Json::Value root = Json::Parse(jsonContent);

            auto latestSeasons = root["latestSeasons"];
            for (uint j = 0; j < latestSeasons.Length; j++) {
                auto season = latestSeasons[j];
                int64 startTimestamp = season["startTimestamp"];
                int64 endTimestamp = season["endTimestamp"];
                if (currentTime >= startTimestamp && currentTime <= endTimestamp) {
                    string seasonName = season["name"];
                    ParseSeasonYear(seasonName);
                    return;
                }
            }
        }
    }

    void ParseSeasonYear(const string &in seasonName) {
        array<string> parts = seasonName.Split(" ");
        if (parts.Length == 2) {
            string season = parts[0];
            int year = Text::ParseInt(parts[1]);

            if (season == "Spring") {
                selectedSeason = 0;
            } else if (season == "Summer") {
                selectedSeason = 1;
            } else if (season == "Fall") {
                selectedSeason = 2;
            } else if (season == "Winter") {
                selectedSeason = 3;
            }

            const int baseYear = 2020;
            selectedYear = year - baseYear;
        }
    }

    void SetCurrentMapBasedOnName() {
        auto root = GetApp().RootMap;
        if (root is null) return;

        string mapName = root.MapInfo.Name;
        if (mapName.Length == 0) return;

        string pattern = "\\b(0[1-9]|1[0-9]|2[0-5])\\b";
        
        auto matches = Regex::Search(mapName, pattern);

        if (matches.Length > 0) {
            for (uint i = 0; i < matches.Length; i++) {
                string match = matches[i];
                int matchIndex = mapName.IndexOf(match);
                
                if (matchIndex > 1) {
                    string prefix = mapName.SubStr(matchIndex - 2, 2);
                    if (prefix == "20") {
                        continue;
                    }
                }

                int mapNumber = Text::ParseInt(match);
                selectedMap = mapNumber - 1;
                break;
            }
        }
    }
}
}
}
