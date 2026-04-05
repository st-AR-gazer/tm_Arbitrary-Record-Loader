namespace RequestThrottle {
    const uint MIN_REQUEST_GAP_MS = 1000;

    uint g_NextRequestSlotAt = 0;
    bool g_RequestSlotLocked = false;

    void WaitForSlot(const string &in reason = "") {
        while (g_RequestSlotLocked) { yield(); }
        g_RequestSlotLocked = true;

        uint now = Time::Now;
        uint slotAt = now;
        if (g_NextRequestSlotAt > now) {
            slotAt = g_NextRequestSlotAt;
        }
        g_NextRequestSlotAt = slotAt + MIN_REQUEST_GAP_MS;

        g_RequestSlotLocked = false;

        while (Time::Now < slotAt) { yield(); }
    }
}
