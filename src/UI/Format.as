string Pad(uint value, uint length) {
    string s = "" + value;
    while (uint(s.Length) < length) s = "0" + s;
    return s;
}

string FormatMs(int ms) {
    if (ms < 0) return "-";
    uint ums = uint(ms);
    uint minutes = ums / 60000;
    uint seconds = (ums % 60000) / 1000;
    uint milliseconds = ums % 1000;
    return Pad(minutes, 2) + ":" + Pad(seconds, 2) + "." + Pad(milliseconds, 3);
}

string FormatTimeAgo(uint loadedAt) {
    uint now = Time::Now;
    if (now <= loadedAt) return "just now";
    uint diff = now - loadedAt;
    uint secs = diff / 1000;
    if (secs < 60) return "" + secs + "s ago";
    uint mins = secs / 60;
    if (mins < 60) return "" + mins + "m ago";
    uint hrs = mins / 60;
    if (hrs < 24) return "" + hrs + "h " + (mins % 60) + "m ago";
    uint days = hrs / 24;
    return "" + days + "d " + (hrs % 24) + "h ago";
}

string ShortPath(const string &in s, uint maxLen = 64) {
    if (uint(s.Length) <= maxLen) return s;
    uint keep = maxLen / 2;
    return s.SubStr(0, keep) + "..." + s.SubStr(uint(s.Length) - keep);
}

