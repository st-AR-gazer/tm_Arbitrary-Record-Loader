// https://patorjk.com/software/taag/#p=display&f=Small

namespace AllowCheck {
    interface IAllownessCheck {
        void Initialize();
        bool IsConditionMet();
        string GetDisallowReason();
        bool IsInitialized();
    }

    array<IAllownessCheck@> allownessModules;
    bool isInitializing = false;

    void InitializeAllowCheck() {
        if (isInitializing) { return; }
        isInitializing = true;

        while (allownessModules.Length > 0) {allownessModules.RemoveLast();}

        // 

        allownessModules.InsertLast(GamemodeAllowness::CreateInstance());
        allownessModules.InsertLast(MapCommentAllowness::CreateInstance());

        // 

        startnew(InitializeAllModules);
    }

    void InitializeAllowCheckWithTimeout(uint timeout) {
        uint startTime = Time::Now;
        AllowCheck::InitializeAllowCheck();
        bool conditionMet = false;
        while (!conditionMet) { 
            if (Time::Now - startTime > timeout) { 
                NotifyWarn("Condition check timed out ("+timeout+" ms was given), assuming invalid state."); 
                break; 
            }
            yield(); 
            conditionMet = AllowCheck::ConditionCheckMet();
        }
    }

    void InitializeAllModules() {
        for (uint i = 0; i < allownessModules.Length; i++) { allownessModules[i].Initialize(); }
        isInitializing = false;
    }

    bool ConditionCheckMet() {
        bool allMet = true;
        for (uint i = 0; i < allownessModules.Length; i++) {
            auto module = allownessModules[i];
            bool initialized = module.IsInitialized();
            bool condition = module.IsConditionMet();
            // log("ConditionCheckMet: Module " + i + " initialized: " + (initialized ? "true" : "false") + ", condition met: " + (condition ? "true" : "false"), LogLevel::Info, 55, "ConditionCheckMet");
            if (!initialized || !condition) { allMet = false; }
        }
        return allMet;
    }

    string DisallowReason() {
        string reason = "";
        for (uint i = 0; i < allownessModules.Length; i++) {
            if (!allownessModules[i].IsConditionMet()) {
                reason += allownessModules[i].GetDisallowReason() + " ";
            }
        }
        return reason.Trim().Length > 0 ? reason.Trim() : "Unknown reason.";
    }
}
