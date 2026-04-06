namespace EntryPoints {
namespace CurrentMap {
namespace Medals {
    ChampionMedal champMedal;
    WarriorMedal warriorMedal;
    SBVilleMedal sbVilleMedal;
    AuthorMedal authorMedal;
    GoldMedal goldMedal;
    SilverMedal silverMedal;
    BronzeMedal bronzeMedal;

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
        bool medalHasExactMatch = false;
        bool reqForCurrentMapFinished = false;

        void AddMedal() {
            if (medalExists) startnew(CoroutineFunc(FetchSurroundingRecords));
        }

        void OnMapLoad() {
            ResetState();
            if (!WaitForMedalTime()) return;
            medalExists = true;
            currentMapMedalTime = GetMedalTime();
        }

        void ResetState() {
            medalExists = false;
            currentMapMedalTime = 0;
            timeDifference = 0;
            medalHasExactMatch = false;
            reqForCurrentMapFinished = false;
        }

        bool WaitForMedalTime() {
            int startTime = Time::Now;
            while (Time::Now - startTime < 2000 || GetMedalTime() == 0) { yield(); }
            return GetMedalTime() > 0;
        }

        void FetchSurroundingRecords() {
            if (!medalExists) return;

            string mapUid = CurrentMap::GetMapUid();
            if (mapUid.Length == 0) return;

            string url = "https://live-services.trackmania.nadeo.live/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/surround/1/1?score=" + currentMapMedalTime;
            RequestThrottle::WaitForSlot("Surrounding records");
            auto req = NadeoServices::Get("NadeoLiveServices", url);
            req.Start();

            while (!req.Finished()) { yield(); }
            if (req.ResponseCode() != 200) return;

            Json::Value data = Json::Parse(req.String());
            if (data.GetType() == Json::Type::Null) return;

            auto tops = data["tops"];
            if (tops.GetType() != Json::Type::Array || tops.Length == 0) return;
            auto top = tops[0]["top"];
            if (top.GetType() != Json::Type::Array || top.Length == 0) return;

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

                if (difference == 0) {
                    closestAccountId = accountId;
                    closestPosition = position;
                    smallestDifference = difference;
                    exactMatchFound = true;
                    break;
                } else if (difference > 0 && difference < smallestDifference) {
                    closestAccountId = accountId;
                    closestPosition = position;
                    smallestDifference = difference;
                }
            }

            if (closestAccountId.Length > 0) {
                timeDifference = smallestDifference;
                medalHasExactMatch = exactMatchFound;
                loadRecord.LoadRecordFromMapUid(mapUid, tostring(closestPosition - 1), "Medal", closestAccountId);
            }

            reqForCurrentMapFinished = true;
        }

        uint GetMedalTime() { return 0; }
    }

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

    namespace AuthorMedal { AuthorMedal medal; }
    class AuthorMedal : Medal {
        uint GetMedalTime() override {
            return GetApp().RootMap.ChallengeParameters.AuthorTime;
        }
    }

    namespace GoldMedal { GoldMedal medal; }
    class GoldMedal : Medal {
        uint GetMedalTime() override {
            return GetApp().RootMap.ChallengeParameters.GoldTime;
        }
    }

    namespace SilverMedal { SilverMedal medal; }
    class SilverMedal : Medal {
        uint GetMedalTime() override {
            return GetApp().RootMap.ChallengeParameters.SilverTime;
        }
    }

    namespace BronzeMedal { BronzeMedal medal; }
    class BronzeMedal : Medal {
        uint GetMedalTime() override {
            return GetApp().RootMap.ChallengeParameters.BronzeTime;
        }
    }
}
}
}
