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

    void RenderOverviewTab() {
        SectionTitle(Icons::QuestionCircle + " Overview");
        HelpItem("Arbitrary Record Loader", "Load ghosts and replays into Trackmania from local files, URLs, official sources, ranked leaderboards, and current-map tooling.");

        SectionTitle(Icons::List + " Main Pages");
        HelpItem(Icons::Download + " Load", "Bring in ghosts or replays from all supported sources.");
        HelpItem(Icons::List + " Loaded", "See everything ARL is tracking right now, hide or show ghosts, save them to the library, and forget entries you no longer need.");
        HelpItem(Icons::FolderOpen + " Library", "Manage saved files and JSON profiles for reuse later.");
    }

    void RenderLoadTab() {
        SectionTitle(Icons::Download + " Load Tabs");
        HelpItem(Icons::FolderOpen + " Local Files", "Queue replay or ghost files from disk, load them all at once, and browse recent or common folders.");
        HelpItem(Icons::Link + " URL", "Load a direct .Ghost.Gbx or .Replay.Gbx link from sites like TMX, Trackmania.io, or any direct file share.");
        HelpItem(Icons::Map + " Map UID + Rank", "Load a specific leaderboard rank for any map UID, and browse leaderboard pages before loading.");
        HelpItem(Icons::Globe + " Official", "Load records from seasonal, discovery, or weekly official campaign maps.");
        HelpItem(Icons::Map + " Current Map", "Use current-map-specific sources like validation replay, medal ghosts, player lookups for the current map, and GPS / Clip-To-Ghost tools.");
    }

    void RenderCurrentMapTab() {
        SectionTitle(Icons::Map + " Current Map Tabs");
        HelpItem(Icons::Trophy + " Validation Replay", "Load the author / validation replay embedded in the current map when one exists.");
        HelpItem(Icons::Certificate + " Medal Ghosts", "Load the leaderboard ghosts closest to each medal time on the current map.");
        HelpItem(Icons::IdCard + " Player ID", "Find a player and load that player's record for the current map.");
        HelpItem(Icons::Crosshairs + " GPS", "Inspect mediatracker ghost tracks and export GPS ghosts via Clip-To-Ghost.");
    }

    void RenderLibraryTab() {
        SectionTitle(Icons::FolderOpen + " Library Tabs");
        HelpItem(Icons::Kenney::Save + " Saved", "Reload files you already saved into ARL's managed store.");
        HelpItem(Icons::File + " Profiles (JSON)", "Keep reusable map lists and batch-load the same rank across those maps.");
    }

    void RenderNotesTab() {
        SectionTitle(Icons::QuestionCircle + " URL Notes");
        HelpItem(Icons::SnapchatGhost + " .Ghost.Gbx", "A single ghost recording.");
        HelpItem(Icons::Film + " .Replay.Gbx", "A replay file that may contain one or more ghosts.");
        HelpItem(Icons::Globe + " Direct File Links", "The URL field expects a direct file download, not a normal webpage.");
    }

    void Render() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::BeginTabBar("HelpTabs");

        if (UI::BeginTabItem(Icons::QuestionCircle + " Overview")) {
            RenderOverviewTab();
            UI::EndTabItem();
        }

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

        if (UI::BeginTabItem(Icons::InfoCircle + " Notes")) {
            RenderNotesTab();
            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::PopStyleVar();
    }
}
}
