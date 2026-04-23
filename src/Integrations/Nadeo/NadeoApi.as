NadeoApi@ api;

class NadeoApi {
    string liveSvcUrl;

    NadeoApi() {
        NadeoServices::AddAudience("NadeoServices");
        NadeoServices::AddAudience("NadeoLiveServices");
        liveSvcUrl = NadeoServices::BaseURLLive();
    }

    Json::Value GetOfficialCampaign(uint offset) {
        return CallLiveApiPath("/api/token/campaign/official?offset=" + offset + "&length=1");
    }

    void AssertGoodPath(const string &in path) {
        if (path.Length <= 0 || !path.StartsWith("/")) {
            log("API Paths should start with '/'!", LogLevel::Error, 18, "AssertGoodPath");
        }
    }

    Json::Value CallLiveApiPath(const string &in path) {
        AssertGoodPath(path);
        return FetchLiveEndpoint(liveSvcUrl + path);
    }

    Json::Value GetMapRecords(const string &in seasonUid = "Personal_Best", const string &in mapUid = "", bool onlyWorld = true, uint length = 1, uint offset = 0) {
        string qParams = onlyWorld ? "?onlyWorld=true" : "";
        if (onlyWorld) qParams += "&" + "length=" + length + "&offset=" + offset;
        return CallLiveApiPath("/api/token/leaderboard/group/" + seasonUid + "/map/" + mapUid + "/top" + qParams);
    }
}

Json::Value FetchLiveEndpoint(const string &in route) {
    log("[FetchLiveEndpoint] Requesting: " + route, LogLevel::Info, 35, "AssertGoodPath");
    RequestThrottle::WaitForSlot("FetchLiveEndpoint");
    auto req = NadeoServices::Get("NadeoLiveServices", route);
    req.Start();
    while(!req.Finished()) { yield(); }
    return Json::Parse(req.String());
}
