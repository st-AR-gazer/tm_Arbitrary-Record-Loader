namespace Features {
namespace LRBasedOnCurrentMap {
namespace Medals {

    /** Adding a Medal
        * 
        * Go to: 
        * 
        * ///////////////////////// _medal_ MEDALS //////////////////////////
        #if DEPENDENCY_medal_
                namespace _medal_Medal { _medal_Medal medal; }
        #endif
                class _medal_Medal : Medal {
                    uint GetMedalTime() override {
                        int x = -1;
        #if DEPENDENCY_medalhere
                        x = medal_Medals::Get_medal_Time();
        #endif
                        return x;
                    }
                }
        * 
        * And replace the _medal_ with the medal you want to add, e.g "Champion" or "Warrior".
        * 
        * Then add `startnew(CoroutineFunc(_medal_.OnMapLoad));` to the `OnMapLoad` function.
        * 
        * And you are done :PauseChamp: , very easy.
        * 
        */

    void OnMapLoad() {
        startnew(CoroutineFunc(champMedal.OnMapLoad));
        startnew(CoroutineFunc(warriorMedal.OnMapLoad));
        startnew(CoroutineFunc(sbVilleMedal.OnMapLoad));
        startnew(CoroutineFunc(authorMedal.OnMapLoad));
        startnew(CoroutineFunc(goldMedal.OnMapLoad));
        startnew(CoroutineFunc(silverMedal.OnMapLoad));
        startnew(CoroutineFunc(bronzeMedal.OnMapLoad));
    }

    class Medal {
        bool medalExists = false;
        uint currentMapMedalTime = 0;
        int timeDifference = 0;

        string displaySavePath = "";
        uint displayTimeDifference = 0;

        bool medalHasExactMatch = false;
        bool reqForCurrentMapFinished = false;

        CGameCtnChallenge@ rootMap = null;

        void AddMedal() {
            if (medalExists) {
                startnew(CoroutineFunc(FetchSurroundingRecords));
            }
        }

        void OnMapLoad() {
            if (MedalExists()) {
                ResetState();
                medalExists = true;
                FetchMedalTime();
            } else {
                medalExists = false;
            }
            return;
        }

        void ResetState() {
            medalExists = false;
            currentMapMedalTime = 0;
            timeDifference = 0;
            displaySavePath = "";
            displayTimeDifference = 0;
            medalHasExactMatch = false;
            reqForCurrentMapFinished = false;
        }

        bool MedalExists() {
            int startTime = Time::Now;
            while (Time::Now - startTime < 2000 || GetMedalTime() == 0) { yield(); }
            log("Medal time is: " + GetMedalTime(), LogLevel::Info, 86, "MedalExists");
            return GetMedalTime() > 0;
        }

        void FetchMedalTime() {
            if (medalExists) {
                currentMapMedalTime = GetMedalTime();
            }
        }

        void FetchSurroundingRecords() {
            if (!medalExists) return;

            string url = "https://live-services.trackmania.nadeo.live/api/token/leaderboard/group/Personal_Best/map/" + get_CurrentMapUID() + "/surround/1/1?score=" + currentMapMedalTime;
            auto req = NadeoServices::Get("NadeoLiveServices", url);
            req.Start();

            while (!req.Finished()) { yield(); }

            if (req.ResponseCode() != 200) {
                log("Failed to fetch surrounding records, response code: " + req.ResponseCode(), LogLevel::Error, 106, "FetchSurroundingRecords");
                return;
            }

            Json::Value data = Json::Parse(req.String());
            if (data.GetType() == Json::Type::Null) {
                log("Failed to parse response for surrounding records.", LogLevel::Error, 112, "FetchSurroundingRecords");
                return;
            }

            Json::Value tops = data["tops"];
            if (tops.GetType() != Json::Type::Array || tops.Length == 0) {
                log("Invalid tops data in response.", LogLevel::Error, 118, "FetchSurroundingRecords");
                return;
            }

            Json::Value top = tops[0]["top"];
            if (top.GetType() != Json::Type::Array || top.Length == 0) {
                log("Invalid top data in response.", LogLevel::Error, 124, "FetchSurroundingRecords");
                return;
            }

            uint closestScore = 0;
            int smallestDifference = int(0x7FFFFFFF);
            string closestAccountId;
            int closestPosition = -1;
            bool exactMatchFound = false;

            for (uint i = 0; i < top.Length; i++) {
                if (i == top.Length / 2) continue;

                uint score = top[i]["score"];
                string accountId = top[i]["accountId"];
                int position = top[i]["position"];
                int difference = int(currentMapMedalTime) - int(score);

                log("Found surrounding record: score = " + score + ", accountId = " + accountId + ", position = " + position + ", difference = " + difference, LogLevel::Info, 142, "FetchSurroundingRecords");

                if (difference == 0) {
                    closestScore = score;
                    closestAccountId = accountId;
                    closestPosition = position;
                    smallestDifference = difference;
                    exactMatchFound = true;
                    break;
                } else if (difference > 0 && difference < smallestDifference) {
                    closestScore = score;
                    closestAccountId = accountId;
                    closestPosition = position;
                    smallestDifference = difference;
                }
            }

            if (closestAccountId != "") {
                timeDifference = smallestDifference;
                medalHasExactMatch = exactMatchFound;

                log("Closest record found: score = " + closestScore + ", accountId = " + closestAccountId + ", position = " + closestPosition + ", difference = " + timeDifference, LogLevel::Info, 163, "FetchSurroundingRecords");
                loadRecord.LoadRecordFromMapUid(get_CurrentMapUID(), tostring(closestPosition - 1), "Medal", closestAccountId);
            }

            reqForCurrentMapFinished = true;
        }

        uint GetMedalTime() { return 0; }
    }


///////////////////////// CHAMPION MEDALS //////////////////////////
#if DEPENDENCY_CHAMPIONMEDALS
    namespace ChampMedal { ChampionMedal medal; }
#endif
    class ChampionMedal : Medal {
        uint GetMedalTime() override {
            int x = -1;
#if DEPENDENCY_CHAMPIONMEDALS
            x = ChampionMedals::GetCMTime();
#endif
            return x;
        }
    }

///////////////////////// WARRIOR MEDALS //////////////////////////
#if DEPENDENCY_WARRIORMEDALS
    namespace WarriorMedal { WarriorMedal medal; }
#endif
    class WarriorMedal : Medal {
        uint GetMedalTime() override {
            int x = -1;
#if DEPENDENCY_WARRIORMEDALS
            x = WarriorMedals::GetWMTime();
#endif
            return x;
        }
    }

///////////////////////// SBVILLE MEDALS //////////////////////////
#if DEPENDENCY_SBVILLECAMPAIGNCHALLENGES
    namespace SBVilleMedal { SBVilleMedal medal; }
#endif
    class SBVilleMedal : Medal {
        uint GetMedalTime() override {
            int x = -1;
#if DEPENDENCY_SBVILLECAMPAIGNCHALLENGES
            x = SBVilleCampaignChallenges::getChallengeTime();
#endif
            return x;
        }
    }

///////////////////////// AUTHOR MEDALS //////////////////////////
// #if DEPENDENCY_AUHTORMEDALS
    namespace AuthorMedal { AuthorMedal medal; }
// #endif
    class AuthorMedal : Medal {
        uint GetMedalTime() override {
            int x = -1;
// #if DEPENDENCY_AUHTORMEDALS
            x = GetApp().RootMap.ChallengeParameters.AuthorTime;
// #endif
            return x;
        }
    }

///////////////////////// GOLD MEDALS //////////////////////////
// #if DEPENDENCY_GOLDMEDALS
    namespace GoldMedal { GoldMedal medal; }
// #endif
    class GoldMedal : Medal {
        uint GetMedalTime() override {
            int x = -1;
// #if DEPENDENCY_AUHTORMEDALS
            x = GetApp().RootMap.ChallengeParameters.GoldTime;
// #endif
            return x;
        }
    }

///////////////////////// SILVER MEDALS //////////////////////////
// #if DEPENDENCY_SILVERMEDALS
    namespace SilverMedal { SilverMedal medal; }
// #endif
    class SilverMedal : Medal {
        uint GetMedalTime() override {
            int x = -1;
// #if DEPENDENCY_AUHTORMEDALS
            x = GetApp().RootMap.ChallengeParameters.SilverTime;
// #endif
            return x;
        }
    }

///////////////////////// BRONZE MEDALS //////////////////////////
// #if DEPENDENCY_BRONZEMEDALS
    namespace BronzeMedal { BronzeMedal medal; }
// #endif
    class BronzeMedal : Medal {
        uint GetMedalTime() override {
            int x = -1;
// #if DEPENDENCY_AUHTORMEDALS
            x = GetApp().RootMap.ChallengeParameters.BronzeTime;
// #endif
            return x;
        }
    }
}
}
}