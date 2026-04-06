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
        EntryPoints::CurrentMap::Render();
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}
