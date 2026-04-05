namespace Features {
namespace LRFromProfile {
namespace Create {
    array<string> jsonFilePaths;
    array<string> jsonFileNames;
    bool isDownloading = false;
    bool isCreatingProfile = false;

    class MapEntry {
        string mapName;
        string mapUid;
    }

    array<MapEntry> newProfileMaps;

    void RefreshFileList() {
        jsonFilePaths.RemoveRange(0, jsonFilePaths.Length);
        jsonFileNames.RemoveRange(0, jsonFileNames.Length);

        if (IO::FolderExists(Server::specificDownloadedJsonFilesDirectory)) {
            auto files = IO::IndexFolder(Server::specificDownloadedJsonFilesDirectory, true);
            if (files !is null) {
                for (uint i = 0; i < files.Length; i++) {
                    if (files[i].ToLower().EndsWith(".json")) {
                        jsonFilePaths.InsertLast(files[i]);
                        jsonFileNames.InsertLast(Path::GetFileName(files[i]));
                    }
                }
            }
        }

        if (IO::FolderExists(Server::specificDownloadedCreatedProfilesDirectory)) {
            auto files = IO::IndexFolder(Server::specificDownloadedCreatedProfilesDirectory, true);
            if (files !is null) {
                for (uint i = 0; i < files.Length; i++) {
                    if (files[i].ToLower().EndsWith(".json")) {
                        jsonFilePaths.InsertLast(files[i]);
                        jsonFileNames.InsertLast(Icons::Star + " " + Path::GetFileName(files[i]));
                    }
                }
            }
        }
    }

    void StartDownload(const string &in downloadPath) {
        startnew(CoroutineFuncUserdataString(Coro_DownloadAndRefreshJsonFiles), downloadPath);
    }

    void Coro_DownloadAndRefreshJsonFiles(const string &in downloadPath) {
        isDownloading = true;
        if (Path::GetExtension(downloadPath).ToLower() != "json" && Path::GetExtension(downloadPath).ToLower() != ".json") {
            NotifyWarn("Error | Invalid file extension.");
            isDownloading = false;
        } else if (downloadPath != "") {
            string destinationPath = Server::specificDownloadedJsonFilesDirectory + Path::GetFileName(downloadPath);
            DownloadFileToDestination(downloadPath, destinationPath);
            RefreshFileList();
            isDownloading = false;
        } else {
            NotifyWarn("Error | No Json Download provided.");
            isDownloading = false;
        }
    }

    string LoadJsonContentByIndex(int index) {
        if (index < 0 || uint(index) >= jsonFilePaths.Length) return "";
        return _IO::File::ReadFileToEnd(jsonFilePaths[index]);
    }

    array<Json::Value> GetMapListFromJson(const string &in content) {
        array<Json::Value> mapList;
        if (content != "") {
            Json::Value json = Json::Parse(content);
            if (json.GetType() == Json::Type::Object && json.HasKey("maps")) {
                Json::Value maps = json["maps"];
                for (uint i = 0; i < maps.Length; i++) {
                    mapList.InsertLast(maps[i]);
                }
            }
        }
        return mapList;
    }

    void DownloadFileToDestination(const string &in url, const string &in destinationPath) {
        RequestThrottle::WaitForSlot("Profile download");
        auto req = Net::HttpGet(url);
        while (!req.Finished()) {
            yield();
        }
        if (req.ResponseCode() == 200) {
            auto content = req.String();
            _IO::File::WriteFile(destinationPath, content);
        } else {
            NotifyWarn("Error | Failed to download file from URL.");
        }
    }

    void SaveNewProfile(const string &in jsonName) {
        Json::Value newProfile = Json::Object();
        newProfile["jsonName"] = jsonName;
        newProfile["maps"] = Json::Array();

        for (uint i = 0; i < newProfileMaps.Length; i++) {
            Json::Value newMap = Json::Object();
            newMap["mapName"] = newProfileMaps[i].mapName;
            newMap["mapUid"] = newProfileMaps[i].mapUid;
            newProfile["maps"].Add(newMap);
        }

        string filePath = Server::specificDownloadedCreatedProfilesDirectory + jsonName + ".json";
        _IO::File::WriteFile(filePath, Json::Write(newProfile));

        newProfileMaps.RemoveRange(0, newProfileMaps.Length);
    }

    void DeleteProfile(int index) {
        if (index < 0 || uint(index) >= jsonFilePaths.Length) return;
        string path = jsonFilePaths[index];
        if (IO::FileExists(path)) IO::Delete(path);
        RefreshFileList();
    }
}
}
}
