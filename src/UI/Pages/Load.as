void ARL_RenderPage_Load() {
    UI::PushStyleColor(UI::Col::Tab, ARL_HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, ARL_HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, ARL_HeaderActiveBg);

    UI::BeginTabBar("ARL_LoadTabs");

    if (UI::BeginTabItem(Icons::FolderOpen + " Local Files")) {
        EntryPoints::LocalFiles::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Link + " URL")) {
        EntryPoints::Url::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Map + " Map UID + Rank")) {
        EntryPoints::MapUid::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::IdCard + " Player ID")) {
        EntryPoints::PlayerId::Render();
        UI::TextDisabled("Loads this player's record on the current map via Nadeo API.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Globe + " Official")) {
        EntryPoints::Official::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Map + " Current Map")) {
        string _cmMapName = get_CurrentMapName();
        if (_cmMapName.Length > 0) _cmMapName = Text::StripFormatCodes(_cmMapName);
        UI::TextDisabled(Icons::Map + " " + (_cmMapName.Length > 0 ? _cmMapName : "(no map loaded)"));

        if (UI::CollapsingHeader(Icons::Trophy + " Validation Replay")) {
            if (Services::Automation::CurrentMap::ValidationReplay::ValidationReplayExists()) {
                AutomationUI::CurrentMap::RTPart_ValidationReplay();
            } else {
                UI::TextDisabled("No validation replay available for this map.");
            }
        }

        if (UI::CollapsingHeader(Icons::Certificate + " Medal Ghosts")) {
            AutomationUI::CurrentMap::RTPart_MedalTable();
        }
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}
