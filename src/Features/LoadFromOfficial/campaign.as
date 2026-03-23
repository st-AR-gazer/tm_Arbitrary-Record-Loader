namespace Features {
namespace LRFromOfficialMaps {
namespace Campaign {
int64 endTimestamp = 0;
    array<string> localCampaigns;

    void Init() {
        log("Initializing CampaignManager", LogLevel::Info, 8, "Init");
        LoadEndTimestamp();
        CheckForNewCampaign();
    }

    void LoadEndTimestamp() {
        log("Loading end timestamp", LogLevel::Info, 14, "LoadEndTimestamp");
        string endTimestampFilePath = Server::officialInfoFilesDirectory + "/end_timestamp.txt";

        if (IO::FileExists(endTimestampFilePath)) {
            endTimestamp = Text::ParseInt64(_IO::File::ReadFileToEnd(endTimestampFilePath));
            log("Loaded endTimestamp: " + endTimestamp, LogLevel::Info, 19, "LoadEndTimestamp");
        } else {
            endTimestamp = 0;
            log("End timestamp file not found, setting endTimestamp to 0", LogLevel::Warn, 22, "LoadEndTimestamp");
        }
    }

    void CheckForNewCampaign() {
        if (Time::Stamp >= endTimestamp) {
            log("New campaign check needed", LogLevel::Info, 28, "CheckForNewCampaign");
            startnew(Coro_CheckForNewCampaign);
        } else {
            log("No new campaign check needed", LogLevel::Info, 31, "CheckForNewCampaign");
        }
    }

    void Coro_CheckForNewCampaign() {
        IndexLocalFiles();

        uint offset = 0;
        bool continueChecking = true;
        while (continueChecking) {
            Json::Value data = api.GetOfficialCampaign(offset);
            if (data.HasKey("campaignList") && data["campaignList"].Length > 0) {
                for (uint j = 0; j < data["campaignList"].Length; j++) {
                    Json::Value campaign = data["campaignList"][j];
                    string campaignName = string(campaign["name"]).Replace(" ", "_");

                    if (localCampaigns.Find(campaignName) == -1) {
                        log("Downloading missing campaign: " + campaignName, LogLevel::Info, 48, "Coro_CheckForNewCampaign");
                        SaveCampaignData(campaign);
                    }

                    int64 newEndTimestamp = campaign["endTimestamp"];
                    if (newEndTimestamp > endTimestamp) {
                        endTimestamp = newEndTimestamp;
                    }
                }
                offset++;
            } else {
                log("No more campaigns found at offset: " + tostring(offset), LogLevel::Info, 59, "Coro_CheckForNewCampaign");
                continueChecking = false;
            }
        }

        SaveEndTimestamp();
    }

    void IndexLocalFiles() {
        localCampaigns.Resize(0);
        bool recursive = false;
        array<string>@ files = IO::IndexFolder(Server::officialJsonFilesDirectory, recursive);

        for (uint i = 0; i < files.Length; ++i) {
            string fileName = Path::GetFileNameWithoutExtension(files[i]);
            localCampaigns.InsertLast(fileName);
        }
    }

    void SaveCampaignData(const Json::Value &in campaign) {
        string campaignName = campaign["name"];
        log("Saving campaign data: " + campaignName, LogLevel::Info, 80, "SaveCampaignData");

        string specificSeason = campaignName.Replace(" ", "_");
        string fullFileName = Server::officialJsonFilesDirectory + "/" + specificSeason + ".json";

        _IO::File::WriteFile(fullFileName, Json::Write(campaign));
        log("Campaign data saved to: " + fullFileName, LogLevel::Info, 86, "SaveCampaignData");
    }

    void SaveEndTimestamp() {
        log("Saving end timestamp", LogLevel::Info, 90, "SaveEndTimestamp");

        string endTimestampFilePath = Server::officialInfoFilesDirectory + "/end_timestamp.txt";
        IO::File endTimestampFile(endTimestampFilePath, IO::FileMode::Write);
        endTimestampFile.Write("" + endTimestamp);
        endTimestampFile.Close();

        log("Saved endTimestamp: " + endTimestamp, LogLevel::Info, 97, "SaveEndTimestamp");
    }

}
}
}
