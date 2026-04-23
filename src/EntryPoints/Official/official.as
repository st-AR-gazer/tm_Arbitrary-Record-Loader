namespace EntryPoints {
namespace Official {
namespace Official {
    int selectedYear = -1;
    int selectedSeason = -1;
    int selectedMap = -1;
    array<int> years;
    array<string> seasons;
    array<string> maps;

    // - Winter 2020 == Training
    // - Spring 2020 == Spring 2020 campaign
    array<string> Legacy_Spring2020_MapUids = {
        "vRmotLWfPJjvqlWqUybhkRmOy95",
        "61llSQ5JlZSy7VmdC6kSknD5bfc",
        "7SOK1BmR1z7xyHuKWdW5456CBll",
        "UP_Gg9kq62b1QNERf4SmpBpYSE7",
        "XfLWmX5hriHYH6BfCmd9CZBwUm0",
        "gtcGN2eQv7MZGRRzh0f2EFS1erd",
        "EYrl5uKyBMIb1QYF8foncZog8Ih",
        "dTpbVvkFdBzCJtLmfTk6wcpCUG7",
        "_gqdWt54s9LYGVbZuuLfwZKyndl",
        "G9IhptfgxZ1GCrO4fYirW9sKQw8",
        "poje8Ki8VVZvYsT9CNzAXBOdxx1",
        "Vy5hhla1x34Y86UtsTnGvuq3bAd",
        "3Xh_2OdV20gfgqZ3WHJvhGzuI6a",
        "Y7hDz5EeFcL0yizHn3NTV4oXURm",
        "WMiX2P9UzIhbRQbLc87kWgqfAh1",
        "4B2UrTFqTsH_ugVWqGX1EPq4zWf",
        "yPwO3xovgk8MbHOpHj3ydndGSi8",
        "K7nhXeWHt8qY8xJsBz2RkOjUpg8",
        "qIVkpjFcBnkETRZAd78iDb3Eypb",
        "SmpgE2AjfPDeDIy0oNN1tz4r_yf",
        "OzvoomDwptrHfnmrKLMmJOX6tZ",
        "O783pJwn7ZTTKRWaSQq70y0iPr4",
        "JfR2nmgEFjNQUcsZ_0gif3U9C4k",
        "FsaAocj28Yon0os_aauglPq2fi1",
        "jfVEZTOxGFyy29NusaGqg59Edjk"
    };

    array<string> Legacy_Training_MapUids = {
        "olsKnq_qAghcVAnEkoeUnVHFZei",
        "btmbJWADQOS20ginP9DJ0i8sh3f",
        "lNP8O0sqatiHqecUXrhH65rpQ8a",
        "ga3zTKvSo7yJca60Ry_Z003L031",
        "xSOA3Fs8k3bGNHFQhwskyAjN3Nh",
        "LcBa4OZLeElnJksgbBEpQggitsh",
        "vTqUpE1iiXupNABp5Mfx0YOf33j",
        "OeJCW8sHENIcYscK8o5zVHAxADd",
        "us4gaCDQSxmjVMtp5nYfReezTqh",
        "DyNBxhQ6006991FwvVOaBX9Gcv1",
        "PhJGvGjkCaw299rBhVsEhNJKX1",
        "AJFJd6yABuSMfgJGc8UpWRwUVa0",
        "Nw8BZ8CtZZcFO547WnqdPzp8ydi",
        "eOA1X_xnvKbdDSuyymweOZzSrQ3",
        "0hI2P3y8sENgIkruI_X7s3efES",
        "RlZ2HVhAwN5nD7I1lLciKhPsbb7",
        "EnMnBg3D4Uvb5bz8VLod73z6n47",
        "TVUF91YlnL78BFJwG5ADkNlymqe",
        "SsCdL6nGC__n8UrYnsX8xaqnjCh",
        "f1tlOzXvdELVhwrhPpoJDsg9xs8",
        "Yakz8xDlVWDfVCfXxW2_paCaHil",
        "OHRxJCE_cKxEGOGmhF9z6Hf0YZb",
        "qQEgNKxDhXtTsxWYRW0V4pvpER7",
        "1rwAkLrbqhN47zCsVvJJFJimlcf",
        "TkyKsOEG7gHqVqjjc3A1Qj5rPgi"
    };

    void Init() {
        log("Initializing OfficialManager::UI", LogLevel::Debug, 70, "Init");
        UpdateYears();
        UpdateSeasons();
        UpdateMaps();
        EnsureLegacyCampaignJsonFiles();
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
            log("File not found: " + filePath, LogLevel::Error, 88, "FetchOfficialMapUID");
            return "";
        }

        Json::Value root = Json::Parse(_IO::File::ReadFileToEnd(filePath));
        if (root.GetType() == Json::Type::Null) {
            log("Failed to parse JSON file: " + filePath, LogLevel::Error, 94, "FetchOfficialMapUID");
            return "";
        }

        auto playlist = root["playlist"];
        if (playlist.GetType() != Json::Type::Array) {
            log("Playlist missing or invalid in: " + filePath, LogLevel::Error, 100, "FetchOfficialMapUID");
            return "";
        }

        for (uint j = 0; j < playlist.Length; j++) {
            auto map = playlist[j];
            if (map.GetType() != Json::Type::Object) continue;
            int pos = int(map["position"]);
            if (pos == mapPosition) {
                string uid = string(map["mapUid"]);
                if (uid.Length > 0) return uid;
            }
        }

        log("Map UID not found for position: " + tostring(mapPosition), LogLevel::Error, 114, "FetchOfficialMapUID");
        return "";
    }

    void UpdateSeasons() {
        seasons = {"Spring", "Summer", "Fall", "Winter"};
        log("Seasons updated: " + seasons.Length + " seasons", LogLevel::Info, 120, "UpdateSeasons");
    }

    void UpdateMaps() {
        maps.Resize(0);
        for (int i = 1; i <= 25; i++) {
            maps.InsertLast("Map " + tostring(i));
        }
        log("Maps updated: " + maps.Length + " maps", LogLevel::Info, 128, "UpdateMaps");
    }

    void UpdateYears() {
        years.Resize(0);
        Time::Info info = Time::Parse();
        for (int y = 2020; y <= info.Year; y++) {
            years.InsertLast(y);
        }
        log("Years populated: " + years.Length + " years", LogLevel::Info, 137, "UpdateYears");
    }

    void EnsureLegacyCampaignJsonFiles() {
        EnsureLegacyCampaignJsonFile("Spring_2020", "Spring 2020", Legacy_Spring2020_MapUids);
        EnsureLegacyCampaignJsonFile("Winter_2020", "Training", Legacy_Training_MapUids);
    }

    void EnsureLegacyCampaignJsonFile(const string &in key, const string &in name, const array<string> &in uids) {
        string filePath = Server::officialJsonFilesDirectory + "/" + key + ".json";
        if (IO::FileExists(filePath)) return;

        Json::Value root = Json::Object();
        root["name"] = name;
        root["playlist"] = Json::Array();

        for (uint i = 0; i < uids.Length; i++) {
            Json::Value item = Json::Object();
            item["position"] = int(i);
            item["mapUid"] = uids[i];
            root["playlist"].Add(item);
        }

        _IO::File::WriteFile(filePath, Json::Write(root));
    }

    void SetSeasonYearToCurrent() {
        int prevSeason = selectedSeason;
        int prevYear = selectedYear;

        int64 currentTime = Time::Stamp;

        string path = Server::officialJsonFilesDirectory;

        array<string>@ jsonFiles = IO::IndexFolder(path, true);

        for (uint i = 0; i < jsonFiles.Length; i++) {
            string filePath = jsonFiles[i];
            IO::File file(filePath, IO::FileMode::Read);
            string jsonContent = file.ReadToEnd();
            file.Close();

            Json::Value root = Json::Parse(jsonContent);
            if (root.GetType() != Json::Type::Object) continue;

            if (root.HasKey("latestSeasons")) {
                auto latestSeasons = root["latestSeasons"];
                if (latestSeasons.GetType() == Json::Type::Array) {
                    for (uint j = 0; j < latestSeasons.Length; j++) {
                        auto season = latestSeasons[j];
                        if (season.GetType() != Json::Type::Object) continue;
                        int64 startTimestamp = season["startTimestamp"];
                        int64 endTimestamp = season["endTimestamp"];
                        if (currentTime >= startTimestamp && currentTime <= endTimestamp) {
                            string seasonName = season["name"];
                            ParseSeasonYear(seasonName);
                            return;
                        }
                    }
                }
            } else if (root.HasKey("startTimestamp") && root.HasKey("endTimestamp") && root.HasKey("name")) {
                int64 startTimestamp = root["startTimestamp"];
                int64 endTimestamp = root["endTimestamp"];
                if (currentTime >= startTimestamp && currentTime <= endTimestamp) {
                    ParseSeasonYear(string(root["name"]));
                    return;
                }
            }
        }

        selectedSeason = prevSeason;
        selectedYear = prevYear;
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

            selectedYear = -1;
            for (uint i = 0; i < years.Length; i++) {
                if (years[i] == year) {
                    selectedYear = int(i);
                    break;
                }
            }
        }
    }

    int SeasonNameToIndex(const string &in seasonName) {
        string lower = seasonName.ToLower();
        if (lower == "spring") return 0;
        if (lower == "summer") return 1;
        if (lower == "fall") return 2;
        if (lower == "winter") return 3;
        return -1;
    }

    int YearToIndex(int year) {
        for (uint i = 0; i < years.Length; i++) {
            if (years[i] == year) return int(i);
        }
        return -1;
    }

    string NormalizeMapNameForDetection(const string &in rawName) {
        return Text::StripFormatCodes(rawName)
            .Replace("-", " ")
            .Replace("_", " ")
            .Replace("|", " ")
            .Replace(":", " ")
            .Replace("/", " ")
            .Replace("\\", " ")
            .Replace(".", " ")
            .Replace(",", " ")
            .Replace("(", " ")
            .Replace(")", " ")
            .Replace("[", " ")
            .Replace("]", " ");
    }

    bool TryParseSeasonYearMapFromName(const string &in rawName, int &out seasonIdx, int &out yearIdx, int &out mapIdx) {
        seasonIdx = -1;
        yearIdx = -1;
        mapIdx = -1;

        string normalized = NormalizeMapNameForDetection(rawName);
        auto tokens = normalized.Split(" ");

        int parsedSeasonIdx = -1;
        int parsedYear = -1;
        int parsedMapNumber = -1;
        bool sawTraining = false;

        for (uint i = 0; i < tokens.Length; i++) {
            string token = tokens[i].Trim();
            if (token.Length == 0) continue;

            if (parsedSeasonIdx < 0) {
                parsedSeasonIdx = SeasonNameToIndex(token);
            }

            string lower = token.ToLower();
            if (lower == "training") {
                sawTraining = true;
            }

            if (parsedYear < 0 && token.Length == 4 && token.StartsWith("20")) {
                try {
                    int year = Text::ParseInt(token);
                    if (year >= 2020 && year <= 2099) parsedYear = year;
                } catch {}
            }

            if (parsedMapNumber < 0) {
                try {
                    int number = Text::ParseInt(token);
                    if (number >= 1 && number <= 25 && !(token.Length == 4 && token.StartsWith("20"))) {
                        parsedMapNumber = number;
                    }
                } catch {}
            }
        }

        if (sawTraining && parsedMapNumber > 0) {
            parsedSeasonIdx = SeasonNameToIndex("Winter");
            parsedYear = 2020;
        }

        if (parsedSeasonIdx < 0 || parsedYear < 0 || parsedMapNumber < 1) {
            return false;
        }

        seasonIdx = parsedSeasonIdx;
        yearIdx = YearToIndex(parsedYear);
        mapIdx = parsedMapNumber - 1;
        return yearIdx >= 0;
    }

    bool DetectSeasonYearAndMapFromCurrentMapName() {
        auto root = GetApp().RootMap;
        if (root is null || root.MapInfo is null) return false;

        int seasonIdx = -1;
        int yearIdx = -1;
        int mapIdx = -1;
        if (!TryParseSeasonYearMapFromName(root.MapInfo.Name, seasonIdx, yearIdx, mapIdx)) {
            return false;
        }

        selectedSeason = seasonIdx;
        selectedYear = yearIdx;
        selectedMap = mapIdx;
        return true;
    }

    void SetCurrentMapBasedOnName() {
        DetectSeasonYearAndMapFromCurrentMapName();
    }
}
}
}
