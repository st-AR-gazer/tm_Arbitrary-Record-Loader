//   __  __   _   ___    ___ ___  __  __ __  __ ___ _  _ _____    _   _    _    _____      ___  _ ___ ___ ___   __  __  ___  ___  
//  |  \/  | /_\ | _ \  / __/ _ \|  \/  |  \/  | __| \| |_   _|  /_\ | |  | |  / _ \ \    / / \| | __/ __/ __| |  \/  |/ _ \|   \ 
//  | |\/| |/ _ \|  _/ | (_| (_) | |\/| | |\/| | _|| .` | | |   / _ \| |__| |_| (_) \ \/\/ /| .` | _|\__ \__ \ | |\/| | (_) | |) |
//  |_|  |_/_/ \_\_|    \___\___/|_|  |_|_|  |_|___|_|\_| |_|  /_/ \_\____|____\___/ \_/\_/ |_|\_|___|___/___/ |_|  |_|\___/|___/ 
// MAP COMMENT ALLOWNESS MOD

namespace MapCommentAllowness {
    enum MapperSetting {
        Hide,
        HideUCI,
        Order,
        Xdd,
        Always,
        None
    }

    class MapCommentAllownessCheck : AllowCheck::IAllownessCheck {
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

        void OnMapLoad() {
            auto app = cast<CGameManiaPlanet>(GetApp());
            auto map = app.RootMap;
            if (map is null) {
                isAllowed = false;
                disallowReason = "Map is null.";
                return;
            }

            MapperSetting setting = DetermineMapperSetting(map);

            switch (setting) {
                case MapperSetting::Hide:
                    isAllowed = false;
                    disallowReason = "Map loading disabled due to ARL Hide setting.";
                    break;

                case MapperSetting::HideUCI:
                    isAllowed = false;
                    disallowReason = "Map loading disabled due to UCI Hide setting.";
                    break;

                case MapperSetting::Order:
                    isAllowed = true;
                    disallowReason = "";
                    break;

                case MapperSetting::Xdd:
                    isAllowed = true;
                    disallowReason = "";
                    break;

                case MapperSetting::Always:
                    isAllowed = true;
                    disallowReason = "";
                    break;

                case MapperSetting::None:
                    isAllowed = true;
                    disallowReason = "";
                    break;

                default:
                    isAllowed = true;
                    disallowReason = "";
                    break;
            }

            // log("MapCommentAllownessCheck: isAllowed set to " + (isAllowed ? "true" : "false"), LogLevel::Info, 200, "OnMapLoad");
        }

        MapperSetting DetermineMapperSetting(CGameCtnChallenge@ map) {
            auto app = cast<CGameManiaPlanet>(GetApp());
            auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
            if (playground is null) {
                return MapperSetting::None;
            }

            uint startOrder = 0;
            for (uint i = 0; i < playground.Arena.MapLandmarks.Length; i++) {
                auto lm = playground.Arena.MapLandmarks[i];
                if (lm.Waypoint is null && lm.Order > 65535) {
                    startOrder = lm.Order;
                    break;
                }
                if (lm.Waypoint is null) continue;
                if (lm.Waypoint.IsMultiLap && lm.Order > 65535) {
                    startOrder = lm.Order;
                }
            }

            MapperSetting setting = MapperSetting::None;

            if (startOrder > 65530) {
                if (startOrder == 65531) {
                    setting = MapperSetting::Hide;
                }
                else if (startOrder == 65537) {
                    setting = MapperSetting::HideUCI;
                }
                else if (startOrder == 65536) {
                    setting = MapperSetting::Order;
                }
                else if (startOrder == 65539) {
                    setting = MapperSetting::Xdd;
                }
            }

            string comment = string(map.Comments).ToLower();

            if (comment.Contains("/arl hide")) {
                setting = MapperSetting::Hide;
            }
            if (comment.Contains("/uci hide")) {
                setting = MapperSetting::HideUCI;
            }
            if (comment.Contains("/uci order")) {
                setting = MapperSetting::Order;
            }
            if (comment.Contains("/uci xdd")) {
                setting = MapperSetting::Xdd;
            }
            if (comment.Contains("/uci always")) {
                setting = MapperSetting::Always;
            }

            // log("MapCommentAllownessCheck: Final MapperSetting determined as " + EnumToString(setting), LogLevel::Info, 258, "OnMapLoad");
            return setting;
        }

        string EnumToString(MapperSetting setting) {
            switch (setting) {
                case MapperSetting::Hide: return "Hide";
                case MapperSetting::HideUCI: return "HideUCI";
                case MapperSetting::Order: return "Order";
                case MapperSetting::Xdd: return "Xdd";
                case MapperSetting::Always: return "Always";
                case MapperSetting::None: return "None";
                default: return "Unknown";
            }
        }
    }

    AllowCheck::IAllownessCheck@ CreateInstance() {
        return MapCommentAllownessCheck();
    }
}