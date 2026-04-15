void RenderPageLibrary() {
    UI::PushStyleColor(UI::Col::Tab, HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, HeaderActiveBg);

    UI::BeginTabBar("LibraryTabs");

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
