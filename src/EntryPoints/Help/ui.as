namespace EntryPoints {
namespace Help {
    void SectionTitle(const string &in title) {
        UI::Dummy(vec2(0, 4));
        UI::Text("\\$fff" + title);
        UI::Dummy(vec2(0, 2));
    }

    void HelpItem(const string &in label, const string &in body) {
        UI::Text(label);
        UI::PushTextWrapPos();
        UI::TextDisabled(body);
        UI::PopTextWrapPos();
        UI::Dummy(vec2(0, 4));
    }

    void RenderLoadTab() {
        SectionTitle(Icons::Download + " Load Tabs");
        HelpItem(Icons::FolderOpen + " Local Files", "Browse local runs through Quick Browser and Direct Files. When Archivist is installed, ARL also exposes an Archivist view for those replay folders.");
        HelpItem(Icons::Link + " URL", "Load a direct .Ghost.Gbx or .Replay.Gbx link from sites like TMX, Trackmania.io, or any direct file share.");
        HelpItem(Icons::Map + " Map UID + Rank", "Load a specific leaderboard rank for any map UID, and browse leaderboard pages before loading.");
        HelpItem(Icons::Globe + " Official", "Load records from seasonal, discovery, or weekly official campaign maps.");
        HelpItem(Icons::Map + " Current Map", "Use current-map-specific sources like validation replay, medal ghosts, player lookups for the current map, and GPS / Clip-To-Ghost tools.");
    }

    void RenderCurrentMapTab() {
        SectionTitle(Icons::Map + " Current Map Tabs");
        HelpItem(Icons::Trophy + " Validation Replay", "Load the author / validation replay embedded in the current map when one exists.");
        HelpItem(Icons::Certificate + " Medal Ghosts", "Load the leaderboard ghosts closest to each medal time on the current map.");
        HelpItem(Icons::Trophy + " Map Leaderboard", "Browse current-map leaderboard ghosts through MLHook and find a specific player to load their current-map record.");
        HelpItem(Icons::Crosshairs + " GPS", "Inspect mediatracker ghost tracks and export GPS ghosts via Clip-To-Ghost.");
    }

    void RenderLibraryTab() {
        SectionTitle(Icons::FolderOpen + " Library Tabs");
        HelpItem(Icons::Kenney::Save + " Saved", "Reload files you already saved into ARL's managed store.");
        HelpItem(Icons::File + " Profiles (JSON)", "Keep reusable map lists and batch-load the same rank across those maps.");
    }

    void RenderIntegrationsTab() {
        SectionTitle(Icons::FolderOpen + " Local Files");
        HelpItem("Archivist", "Adds the Archivist tab inside Local Files and enables current-map picks from the Archivist replay tree. If Archivist is not installed, that tab is hidden.");
        HelpItem("BetterReplaysFolder", "Pending deeper integration. For now ARL may expose convenience access to the offloaded replay folder when it is available.");

        SectionTitle(Icons::Certificate + " Medal Sources");
        HelpItem("Champion / Warrior / s314ke / SBVille / Adept / Milk / Player / Glacial / CCM / PVM / Custom Medals", "When installed, these plugins add their medal targets to Current Map medal tooling so ARL can fetch nearby leaderboard ghosts.");
    }

    void Render() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::BeginTabBar("HelpTabs");

        if (UI::BeginTabItem(Icons::Download + " Load")) {
            RenderLoadTab();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::Map + " Current Map")) {
            RenderCurrentMapTab();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::FolderOpen + " Library")) {
            RenderLibraryTab();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::Exchange + " Integrations")) {
            RenderIntegrationsTab();
            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::PopStyleVar();
    }
}
}
