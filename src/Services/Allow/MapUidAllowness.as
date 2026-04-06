//  __  __   _   ___   _   _ ___ ___     _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
// |  \/  | /_\ | _ \ | | | |_ _|   \   /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
// | |\/| |/ _ \|  _/ | |_| || || |) | / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
// |_|  |_/_/ \_\_|    \___/|___|___/ /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/ 
// MAP UID ALLOWNESS MOD

namespace MapUidAllowness {
    class MapUidAllownessCheck : AllowCheck::IAllownessCheck {
        bool isAllowed = true;
        string disallowReason = "";
        bool initialized = false;

        void Initialize() {
            OnMapLoad();
            initialized = true;
        }
        bool IsInitialized() { return initialized; }
        bool IsConditionMet() { return isAllowed; }
        string GetDisallowReason() { return isAllowed ? "" : disallowReason; }

        string endpoint = "allowness.p.xjk.yt/v1/arl/map_uid/check";

        void OnMapLoad() {
            auto app = cast<CGameManiaPlanet>(GetApp());
            auto map = app.RootMap;

            Json::Value payload = Json::Object();
            payload["mapUids"] = Json::Array();
            payload["mapUids"].Add(map.MapInfo.MapUid);

            string jsonPayload = Json::Write(payload);
            _Net::PostJsonToEndpoint(endpoint, jsonPayload, "Allowness_MapUid");
            while (!_Net::downloadedData.Exists("Allowness_MapUid")) { yield(); }
            string response = string(_Net::downloadedData["Allowness_MapUid"]);
            _Net::downloadedData.Delete("Allowness_MapUid");
            Json::Value data = Json::Parse(response);

            if (data.GetType() == Json::Type::Null) {
                isAllowed = true;
                return;
            }

            if (data.HasKey("results")) {
                auto results = data["results"];
                if (results.HasKey(map.MapInfo.MapUid)) {
                    auto result = results[map.MapInfo.MapUid];
                    if (result.HasKey("isAllowed")) {
                        isAllowed = bool(result["isAllowed"]);
                    }
                    if (result.HasKey("reason")) {
                        disallowReason = string(result["reason"]);
                    }
                }
            }
        }
    }

    AllowCheck::IAllownessCheck@ CreateInstance() {
        return MapUidAllownessCheck();
    }
}
