namespace EntryPoints {
namespace CurrentMap {
namespace GPS {
    class GhostTrackInfo {
        string clipName;
        string trackName;
        uint blockCount = 0;
        bool looksLikeGps = false;

        GhostTrackInfo() {}
        GhostTrackInfo(const string &in clipName, const string &in trackName, uint blockCount, bool looksLikeGps) {
            this.clipName = clipName;
            this.trackName = trackName;
            this.blockCount = blockCount;
            this.looksLikeGps = looksLikeGps;
        }
    }

    string g_CachedMapUid = "";
    array<GhostTrackInfo@> g_CachedTracks;

    void OnMapLoad() {
        g_CachedMapUid = "";
        g_CachedTracks.RemoveRange(0, g_CachedTracks.Length);
    }

    array<GhostTrackInfo@>@ GetGhostTracks() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) {
            g_CachedMapUid = "";
            g_CachedTracks.RemoveRange(0, g_CachedTracks.Length);
            return g_CachedTracks;
        }

        if (g_CachedMapUid == mapUid) {
            return g_CachedTracks;
        }

        g_CachedMapUid = mapUid;
        g_CachedTracks.RemoveRange(0, g_CachedTracks.Length);

        auto root = GetApp().RootMap;
        if (root is null || root.ClipGroupInGame is null) return g_CachedTracks;

        for (uint ci = 0; ci < root.ClipGroupInGame.Clips.Length; ci++) {
            auto clip = root.ClipGroupInGame.Clips[ci];
            if (clip is null) continue;

            string clipName = clip.Name;

            for (uint ti = 0; ti < clip.Tracks.Length; ti++) {
                auto track = clip.Tracks[ti];
                if (track is null) continue;

                string trackName = track.Name;
                string lower = trackName.ToLower();
                bool looksLikeGhost = trackName.StartsWith("Ghost:");
                bool looksLikeGps = lower.Contains("gps");
                if (!looksLikeGhost && !looksLikeGps) continue;

                g_CachedTracks.InsertLast(GhostTrackInfo(clipName, trackName, track.Blocks.Length, looksLikeGps));
            }
        }

        return g_CachedTracks;
    }

    bool HasGhostTracks() {
        return GetGhostTracks().Length > 0;
    }

    void CopyDebugSummary() {
        auto tracks = GetGhostTracks();
        if (tracks.Length == 0) {
            IO::SetClipboard("Current map contains no detected GPS/ghost mediatracker tracks.");
            return;
        }

        string summary = "Current map GPS/ghost track summary\n";
        summary += "Map: " + get_CurrentMapName() + "\n";
        summary += "MapUid: " + CurrentMap::GetMapUid() + "\n";
        summary += "Tracks: " + tracks.Length + "\n";

        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            if (track is null) continue;
            summary += "\n[" + (i + 1) + "] " + track.trackName;
            if (track.clipName.Length > 0) summary += " | Clip: " + track.clipName;
            summary += " | Blocks: " + track.blockCount;
            if (track.looksLikeGps) summary += " | gps";
        }

        IO::SetClipboard(summary);
    }

    void RequestExtract() {
        NotifyWarning("GPS extraction is not implemented yet. Track discovery and inspection are ready for the next pass.");
    }
}
}
}
