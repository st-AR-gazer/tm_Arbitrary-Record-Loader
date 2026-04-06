void ARL_RenderPage_Library() {
    UI::PushStyleColor(UI::Col::Tab, ARL_HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, ARL_HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, ARL_HeaderActiveBg);

    UI::BeginTabBar("ARL_LibraryTabs");

    if (UI::BeginTabItem(Icons::Kenney::Save + " Saved")) {
        EntryPoints::Saved::Render();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::File + " Profiles (JSON)")) {
        EntryPoints::Profile::Render();
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}
