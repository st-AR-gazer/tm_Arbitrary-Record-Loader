namespace Features {
namespace LRFromProfile {
namespace Preinstalled {
    [Setting name="Should download files from CDN if they are already downloaded" category="CDN"]
    bool shouldDownloadFilesIfTheyAreAleadyDownloaded = false;

    const string baseUrl = "http://maniacdn.net/ar_/Arbitrary-Record-Loader/preinstalled/";
    const string manifestUrl = baseUrl + "manifest.json";

    void Init() {
        StartManifestDownload();
    }
    
    void StartManifestDownload() {
        startnew(FetchPreinstalledManifest);
    }

    void FetchPreinstalledManifest() {
        startnew(Coro_FetchPreinstalledManifest);
    }

    void Coro_FetchPreinstalledManifest() {
        _Net::GetRequestToEndpoint(manifestUrl, "preinstalledManifest");
        while (!_Net::downloadedData.Exists("preinstalledManifest")) { yield(); }
        string reqBody = string(_Net::downloadedData["preinstalledManifest"]);
        _Net::downloadedData.Delete("preinstalledManifest");

        if (Json::Parse(reqBody).GetType() != Json::Type::Object) { log("Failed to parse JSON.", LogLevel::Error, 59, "Coro_FetchPreinstalledManifest"); return; }

        ParseManifest(reqBody);
    }

    void ParseManifest(const string &in reqBody) {
        Json::Value manifest = Json::Parse(reqBody);
        if (manifest.GetType() != Json::Type::Object) { log("Failed to parse JSON.", LogLevel::Error, 66, "ParseManifest"); return; }

        bool shouldUpdate = manifest["shouldUpdate"];
        if (!shouldUpdate) return;

        int version = manifest["version"];
        if (version > get_StoredVersion()) {
            log("New version available: " + version, LogLevel::Info, 73, "ParseManifest");
            DownloadFiles(manifest);
            set_StoredVersion(version);
        } else {
            log("No new version available.", LogLevel::Info, 77, "ParseManifest");
        }
    }

    void DownloadFiles(Json::Value &manifest) {
        Json::Value files = manifest["fileNames"];

        array<string> keys = files.GetKeys();

        for (uint i = 0; i < keys.Length; i++) {
            string key = keys[i];
            
            string filename = string(files[key]);
            string url = baseUrl + filename;
            string path = Server::specificDownloadedJsonFilesDirectory + filename;

            if (shouldDownloadFilesIfTheyAreAleadyDownloaded || !IO::FileExists(path)) {
                log("Downloading: " + filename, LogLevel::Info, 94, "DownloadFiles");

                _Net::DownloadFileToDestination(url, path, "other", Path::GetFileName(filename));
            }
        }
    }

    int get_StoredVersion() {
        if (!IO::FileExists(IO::FromStorageFolder("version.txt"))) { return -1; }

        string version = _IO::File::ReadFileToEnd(IO::FromStorageFolder("version.txt"));
        return Text::ParseInt(version);
    }

    void set_StoredVersion(int version) {
        _IO::File::WriteFile(IO::FromStorageFolder("version.txt"), "" + version);
    }
}
}
}
