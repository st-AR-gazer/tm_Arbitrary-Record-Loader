enum LoadPageTab {
    LocalFiles = 0,
    Url,
    MapUid,
    Official,
    CurrentMap
}

LoadPageTab g_LoadPageTab = LoadPageTab::LocalFiles;
bool g_LoadPageTabSelectRequested = false;

void RequestLoadPageTab(LoadPageTab tab) {
    g_LoadPageTab = tab;
    g_LoadPageTabSelectRequested = true;
}

int LoadPageTabFlags(LoadPageTab tab) {
    return g_LoadPageTabSelectRequested && g_LoadPageTab == tab ? UI::TabItemFlags::SetSelected : UI::TabItemFlags::None;
}

void RenderPageLoad() {
    UI::PushStyleColor(UI::Col::Tab, HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, HeaderActiveBg);

    UI::BeginTabBar("LoadTabs");

    if (UI::BeginTabItem(Icons::FolderOpen + " Local Files", LoadPageTabFlags(LoadPageTab::LocalFiles))) {
        g_LoadPageTab = LoadPageTab::LocalFiles;
        EntryPoints::LocalFiles::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Link + " URL", LoadPageTabFlags(LoadPageTab::Url))) {
        g_LoadPageTab = LoadPageTab::Url;
        EntryPoints::Url::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Map + " Map UID + Rank", LoadPageTabFlags(LoadPageTab::MapUid))) {
        g_LoadPageTab = LoadPageTab::MapUid;
        EntryPoints::MapUid::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Globe + " Official", LoadPageTabFlags(LoadPageTab::Official))) {
        g_LoadPageTab = LoadPageTab::Official;
        EntryPoints::Official::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Map + " Current Map", LoadPageTabFlags(LoadPageTab::CurrentMap))) {
        g_LoadPageTab = LoadPageTab::CurrentMap;
        EntryPoints::CurrentMap::Render();
        UI::EndTabItem();
    }

    UI::EndTabBar();
    g_LoadPageTabSelectRequested = false;

    UI::PopStyleColor(3);
}
