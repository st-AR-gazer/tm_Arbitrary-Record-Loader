void RenderPageLoad() {
    UI::PushStyleColor(UI::Col::Tab, HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, HeaderActiveBg);

    UI::BeginTabBar("LoadTabs");

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
