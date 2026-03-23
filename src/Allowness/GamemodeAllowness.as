//   __  __   _   ___    ___   _   __  __ ___ __  __  ___  ___  ___     _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
//  |  \/  | /_\ | _ \  / __| /_\ |  \/  | __|  \/  |/ _ \|   \| __|   /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
//  | |\/| |/ _ \|  _/ | (_ |/ _ \| |\/| | _|| |\/| | (_) | |) | _|   / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
//  |_|  |_/_/ \_\_|    \___/_/ \_\_|  |_|___|_|  |_|\___/|___/|___| /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/ 
// MAP GAMEMODE ALLOWNESS MOD

namespace GamemodeAllowness {
    string[] gameModeBlackList = {
        "TM_COTDQualifications_Online", "TM_KnockoutDaily_Online"
    };

    class GamemodeAllownessCheck : AllowCheck::IAllownessCheck {
        bool isAllowed = false;
        bool initialized = false;
        
        void Initialize() {
            OnMapLoad();
            initialized = true;
        }
        bool IsInitialized() { return initialized; }
        bool IsConditionMet() { return isAllowed; }

        // 

        string mode = "";

        string GetDisallowReason() { return isAllowed ? "" : "You cannot load maps in the blacklisted game mode: '"+mode+"'"; }

        void OnMapLoad() {
            auto net = cast<CGameCtnNetwork>(GetApp().Network);
            if (net is null) return;
            auto cnsi = cast<CGameCtnNetServerInfo>(net.ServerInfo);
            if (cnsi is null) return;
            mode = cnsi.ModeName;

            if (mode.Length == 0 || !IsBlacklisted(mode)) {
                isAllowed = true;
            } else {
                // log("Map loading disabled due to blacklisted mode: " + mode, LogLevel::Warn, 107, "OnMapLoad");
                isAllowed = false;
            }
        }

        bool IsBlacklisted(const string &in mode) {
            return gameModeBlackList.Find(mode) >= 0;
        }        
    }

    AllowCheck::IAllownessCheck@ CreateInstance() {
        return GamemodeAllownessCheck();
    }
}

// Updating the gamemode remotely, incase more need to be added
namespace GamemodeAllowness {
    bool mainRequestFailed;

    string url = "http://allowness.p.xjk.yt/arl/gamemode/allowness";
    string backupUrl = "http://maniacdn.net/ar_/Allowness/allowed_gamemodes.json";

    void FetchAllowedGamemodes() {
        startnew(Coro_FetchAllowedGamemodes);
    }

    void Coro_FetchAllowedGamemodes() {
        mainRequestFailed = false;
        Coro_FetchAllowedGamemodesFromNet(url);
        if (mainRequestFailed) {
            Coro_FetchAllowedGamemodesFromNet(backupUrl);
        }
    }

    void Coro_FetchAllowedGamemodesFromNet(const string &in url) {

        _Net::GetRequestToEndpoint(url, "gamemodeAllowness");
        while (!_Net::downloadedData.Exists("gamemodeAllowness")) { yield(); }
        string reqBody = string(_Net::downloadedData["gamemodeAllowness"]);
        _Net::downloadedData.Delete("gamemodeAllowness");
        
        if (Json::Parse(reqBody).GetType() != Json::Type::Object) { log("Failed to parse JSON.", LogLevel::Error, 27, "Coro_FetchAllowedGamemodesFromNet"); mainRequestFailed = true; return; }

        Json::Value manifest = Json::Parse(reqBody);
        if (manifest.HasKey("error") && manifest["code"] != 200) { log("Failed to fetch data", LogLevel::Error, 30, "Coro_FetchAllowedGamemodesFromNet"); mainRequestFailed = true; return; }

        for (uint i = 0; i < manifest["blockedGamemodeList"].Length; i++) {
            GamemodeAllowness::gameModeBlackList.InsertLast(manifest["blockedGamemodeList"][i]);
        }
    }
}