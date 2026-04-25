auto hotkeys_initializer = startnew(Hotkeys::InitHotkeys);

namespace Hotkeys {
    const string LOG_CONTEXT = "Hotkeys";
    const string LOG_CONTEXT_COLOR = "\\$f80";

    interface IHotkeyModule {
        string GetId();
        array<string> GetAvailableActions();
        string GetActionDescription(const string &in actionId);
        bool ExecuteAction(const string &in actionId, Hotkey@ hk);
    }

    class Hotkey {
        string pluginId;
        string modId;
        string actId;
        string desc;
        Expr@ expr;
        bool active = false;
    }

    interface Expr {
        bool Eval(const KeyboardState &in kbd, const GamepadState &in gpad, bool edge);
        void Reset();
    }

    array<Hotkey@> hotkeys;
    dictionary modules;

    const string CFG = "Hotkeys.cfg";
    bool cfgLoaded = false;

    string GetConfigPath() {
        return IO::FromDataFolder(CFG);
    }

    void RegisterModule(const string &in pluginId, IHotkeyModule@ module) {
        if (module is null) return;
        string key = (pluginId + "." + module.GetId()).ToLower();
        modules[key] = @module;
    }

    void UnregisterModule(const string &in pluginId, IHotkeyModule@ module) {
        if (module is null) return;
        string key = (pluginId + "." + module.GetId()).ToLower();
        if (modules.Exists(key)) modules.Delete(key);
    }

    UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
        kbd.UpdateEdge(key, down);
        return UI::InputBlocking::DoNothing;
    }

    void Poll() {
        EnsureLoaded();
        gpad.Poll();

        for (uint i = 0; i < hotkeys.Length; i++) {
            auto hk = hotkeys[i];
            if (hk is null || hk.expr is null) continue;

            bool edgeNow = hk.expr.Eval(kbd, gpad, true);
            bool holdNow = hk.expr.Eval(kbd, gpad, false);
            bool isDown = edgeNow || holdNow;

            if (!hk.active && isDown) {
                Trigger(hk);
            }

            hk.active = isDown;
            if (!isDown) hk.expr.Reset();
        }

        kbd.FlushFrame();
    }

    void InitHotkeys() {
        while (true) {
            Poll();
            yield();
        }
    }

    void EnsureLoaded() {
        logging::RegisterContextColor(LOG_CONTEXT, LOG_CONTEXT_COLOR);
        if (cfgLoaded) return;
        cfgLoaded = true;
        LoadBindings();
    }

    void ReloadBindings() {
        cfgLoaded = true;
        LoadBindings();
    }

    class KeyboardState {
        dictionary down;
        dictionary edge;

        void UpdateEdge(VirtualKey vk, bool now) {
            string key = "" + vk;
            bool was = down.Exists(key);
            if (now && !was) edge[key] = true;
            if (now) down[key] = true;
            else if (down.Exists(key)) down.Delete(key);
        }

        void FlushFrame() {
            edge.DeleteAll();
        }

        bool IsDown(int vk) const {
            return down.Exists("" + vk);
        }

        bool IsPressed(int vk) const {
            return edge.Exists("" + vk);
        }
    }

    class GamepadState {
        dictionary held;
        dictionary edge;
        float threshold = 0.5f;

        void Poll() {
            held.DeleteAll();
            edge.DeleteAll();

            auto app = GetApp();
            if (app is null || app.InputPort is null) return;
            auto inputPort = app.InputPort;

            for (uint i = 0; i < inputPort.Script_Pads.Length; i++) {
                auto pad = inputPort.Script_Pads[i];
                if (pad is null) continue;
                if (pad.Type == CInputScriptPad::EPadType::Keyboard
#if !TURBO
                    || pad.Type == CInputScriptPad::EPadType::Mouse
#endif
                ) {
                    continue;
                }

                StoreHeldButtons(pad);
                for (uint b = 0; b < pad.ButtonEvents.Length; b++) {
                    edge["" + int(pad.ButtonEvents[b])] = true;
                }
            }
        }

        void StoreHeld(bool condition, CInputScriptPad::EButton button) {
            if (condition) held["" + int(button)] = true;
        }

        void StoreHeldButtons(CInputScriptPad@ pad) {
            StoreHeld(pad.A != 0, CInputScriptPad::EButton::A);
            StoreHeld(pad.B != 0, CInputScriptPad::EButton::B);
            StoreHeld(pad.X != 0, CInputScriptPad::EButton::X);
            StoreHeld(pad.Y != 0, CInputScriptPad::EButton::Y);
            StoreHeld(pad.L1 != 0, CInputScriptPad::EButton::L1);
            StoreHeld(pad.R1 != 0, CInputScriptPad::EButton::R1);
            StoreHeld(pad.LeftStickBut != 0, CInputScriptPad::EButton::LeftStick);
            StoreHeld(pad.RightStickBut != 0, CInputScriptPad::EButton::RightStick);
            StoreHeld(pad.Menu != 0, CInputScriptPad::EButton::Menu);
            StoreHeld(pad.View != 0, CInputScriptPad::EButton::View);
            StoreHeld(pad.Up != 0, CInputScriptPad::EButton::Up);
            StoreHeld(pad.Down != 0, CInputScriptPad::EButton::Down);
            StoreHeld(pad.Left != 0, CInputScriptPad::EButton::Left);
            StoreHeld(pad.Right != 0, CInputScriptPad::EButton::Right);
            StoreHeld(pad.L2 > threshold, CInputScriptPad::EButton::L2);
            StoreHeld(pad.R2 > threshold, CInputScriptPad::EButton::R2);
        }

        bool IsDown(int button) const {
            return held.Exists("" + button);
        }

        bool IsPressed(int button) const {
            return edge.Exists("" + button);
        }
    }

    KeyboardState kbd;
    GamepadState gpad;

    class KeyNode : Expr {
        int vk;

        KeyNode(int value) {
            vk = value;
        }

        bool Eval(const KeyboardState &in k, const GamepadState &in, bool edgeMode) {
            return edgeMode ? k.IsPressed(vk) : k.IsDown(vk);
        }

        void Reset() {}
    }

    class GPNode : Expr {
        int button;

        GPNode(int value) {
            button = value;
        }

        bool Eval(const KeyboardState &in, const GamepadState &in g, bool edgeMode) {
            return edgeMode ? g.IsPressed(button) : g.IsDown(button);
        }

        void Reset() {}
    }

    class OrNode : Expr {
        array<Expr@> nodes;

        bool Eval(const KeyboardState &in k, const GamepadState &in g, bool edgeMode) {
            for (uint i = 0; i < nodes.Length; i++) {
                if (nodes[i] is null) continue;
                if (nodes[i].Eval(k, g, edgeMode)) return true;
            }
            return false;
        }

        void Reset() {
            for (uint i = 0; i < nodes.Length; i++) {
                if (nodes[i] !is null) nodes[i].Reset();
            }
        }
    }

    class AndNode : Expr {
        array<Expr@> nodes;

        bool Eval(const KeyboardState &in k, const GamepadState &in g, bool edgeMode) {
            for (uint i = 0; i < nodes.Length; i++) {
                if (nodes[i] is null) return false;
                if (!nodes[i].Eval(k, g, edgeMode)) return false;
            }
            return true;
        }

        void Reset() {
            for (uint i = 0; i < nodes.Length; i++) {
                if (nodes[i] !is null) nodes[i].Reset();
            }
        }
    }

    class SeqNode : Expr {
        array<Expr@> steps;
        uint idx = 0;
        bool active = false;

        bool Eval(const KeyboardState &in k, const GamepadState &in g, bool edgeMode) {
            if (steps.Length == 0) return false;

            if (active) {
                for (uint i = 0; i < steps.Length; i++) {
                    if (steps[i] is null || !steps[i].Eval(k, g, false)) {
                        Reset();
                        return false;
                    }
                }
                return true;
            }

            if (idx > 0) {
                if (steps[idx - 1] is null || !steps[idx - 1].Eval(k, g, false)) {
                    Reset();
                    return false;
                }
            }

            if (edgeMode && steps[idx] !is null && steps[idx].Eval(k, g, true)) {
                idx++;
                if (idx >= steps.Length) {
                    active = true;
                    return true;
                }
            }

            return false;
        }

        void Reset() {
            idx = 0;
            active = false;
            for (uint i = 0; i < steps.Length; i++) {
                if (steps[i] !is null) steps[i].Reset();
            }
        }
    }

    class Parser {
        string text;
        uint pos = 0;

        Parser(const string &in src) {
            text = src;
        }

        Expr@ Parse() {
            Expr@ node = ParseExpr();
            SkipWs();
            if (int(pos) != text.Length) return null;
            return node;
        }

        Expr@ ParseExpr() {
            Expr@ left = ParseTerm();
            while (true) {
                SkipWs();
                if (!Match("|")) break;

                OrNode@ orNode = OrNode();
                orNode.nodes.InsertLast(left);
                do {
                    orNode.nodes.InsertLast(ParseTerm());
                    SkipWs();
                } while (Match("|"));
                @left = orNode;
            }
            return left;
        }

        Expr@ ParseTerm() {
            array<Expr@> parts;
            parts.InsertLast(ParseFactor());
            while (true) {
                SkipWs();
                if (!Match("+")) break;
                parts.InsertLast(ParseFactor());
            }
            if (parts.Length == 1) return parts[0];
            AndNode@ andNode = AndNode();
            andNode.nodes = parts;
            return andNode;
        }

        Expr@ ParseFactor() {
            SkipWs();
            if (Match("(")) {
                Expr@ node = ParseExpr();
                Expect(")");
                return node;
            }
            return ParseSequence();
        }

        Expr@ ParseSequence() {
            array<Expr@> steps;
            steps.InsertLast(ParseItem());
            while (true) {
                SkipWs();
                uint save = pos;
                if (Match("&") && Match(">")) {
                    steps.InsertLast(ParseItem());
                } else {
                    pos = save;
                    break;
                }
            }
            if (steps.Length == 1) return steps[0];
            SeqNode@ seq = SeqNode();
            seq.steps = steps;
            return seq;
        }

        Expr@ ParseItem() {
            SkipWs();
            string ident;
            while (int(pos) < text.Length) {
                string ch = text.SubStr(pos, 1);
                if (!IsIdentChar(ch)) break;
                ident += ch;
                pos++;
            }

            if (ident.Length == 0) return null;

            int vk = ResolveVK(ident);
            if (vk >= 0) return KeyNode(vk);

            int gp = ResolveGP(ident);
            if (gp >= 0) return GPNode(gp);

            int literal;
            if (Text::TryParseInt(ident, literal, 0)) {
                return KeyNode(literal);
            }

            return null;
        }

        bool Match(const string &in token) {
            if (token.Length == 0) return false;
            if (int(pos) < text.Length && text.SubStr(pos, 1) == token) {
                pos++;
                return true;
            }
            return false;
        }

        void Expect(const string &in token) {
            if (!Match(token)) {
                log("Hotkeys parser expected '" + token + "' at " + pos, LogLevel::Warning, 409, "Expect", LOG_CONTEXT);
            }
        }

        void SkipWs() {
            while (int(pos) < text.Length) {
                string ch = text.SubStr(pos, 1);
                if (ch != " " && ch != "\t") break;
                pos++;
            }
        }

        bool IsIdentChar(const string &in ch) const {
            if (ch.Length == 0) return false;
            uint8 c = uint8(ch[0]);
            return (c >= 65 && c <= 90)
                || (c >= 97 && c <= 122)
                || (c >= 48 && c <= 57)
                || c == 95;
        }
    }

    int ResolveVK(const string &in name) {
        string lowered = name.ToLower();
        if (lowered == "ctrl" || lowered == "control") return int(VirtualKey::Control);
        if (lowered == "shift") return int(VirtualKey::Shift);
        if (lowered == "alt") return int(VirtualKey::Menu);

        if (lowered.Length == 1) {
            uint8 c = uint8(lowered[0]);
            if (c >= 97 && c <= 122) return int(VirtualKey::A) + (c - 97);
        }

        for (int i = 0; i <= 254; i++) {
            if (tostring(VirtualKey(i)).ToLower() == lowered) return i;
        }

        return -1;
    }

    int ResolveGP(const string &in raw) {
        string key = raw.ToLower();
        if (key == "gp_a") return int(CInputScriptPad::EButton::A);
        if (key == "gp_b") return int(CInputScriptPad::EButton::B);
        if (key == "gp_x") return int(CInputScriptPad::EButton::X);
        if (key == "gp_y") return int(CInputScriptPad::EButton::Y);
        if (key == "gp_lb") return int(CInputScriptPad::EButton::L1);
        if (key == "gp_rb") return int(CInputScriptPad::EButton::R1);
        if (key == "gp_lthumb") return int(CInputScriptPad::EButton::LeftStick);
        if (key == "gp_rthumb") return int(CInputScriptPad::EButton::RightStick);
        if (key == "gp_back") return int(CInputScriptPad::EButton::View);
        if (key == "gp_start") return int(CInputScriptPad::EButton::Menu);
        if (key == "gp_dpadup") return int(CInputScriptPad::EButton::Up);
        if (key == "gp_dpaddown") return int(CInputScriptPad::EButton::Down);
        if (key == "gp_dpadleft") return int(CInputScriptPad::EButton::Left);
        if (key == "gp_dpadright") return int(CInputScriptPad::EButton::Right);
        if (key == "gp_lt") return int(CInputScriptPad::EButton::L2);
        if (key == "gp_rt") return int(CInputScriptPad::EButton::R2);
        return -1;
    }

    void LoadBindings() {
        hotkeys.RemoveRange(0, hotkeys.Length);

        string path = GetConfigPath();
        if (!IO::FileExists(path)) return;

        IO::File file(path, IO::FileMode::Read);
        auto lines = file.ReadToEnd().Split("\n");
        file.Close();

        for (uint i = 0; i < lines.Length; i++) {
            string line = lines[i].Trim();
            if (line.Length == 0 || line.StartsWith("#")) continue;

            int eq = line.IndexOf("=");
            if (eq < 0) continue;

            string lhs = line.SubStr(0, eq).Trim();
            string rhs = line.SubStr(eq + 1).Trim();

            string desc;
            int sc = rhs.IndexOf(";");
            if (sc >= 0) {
                desc = rhs.SubStr(sc + 1).Trim();
                rhs = rhs.SubStr(0, sc).Trim();
            }

            bool enabled = true;
            if (rhs.StartsWith("!")) {
                enabled = false;
                rhs = rhs.SubStr(1).Trim();
            }
            if (!enabled) continue;

            int firstDot = lhs.IndexOf(".");
            int lastDot = lhs.LastIndexOf(".");
            if (firstDot < 0 || lastDot <= firstDot) continue;

            string plugin = lhs.SubStr(0, firstDot).Trim().ToLower();
            string mod = lhs.SubStr(firstDot + 1, lastDot - firstDot - 1).Trim().ToLower();
            string act = lhs.SubStr(lastDot + 1).Trim();

            Parser parser(rhs);
            Expr@ root = parser.Parse();
            if (root is null) continue;

            Hotkey@ hk = Hotkey();
            hk.pluginId = plugin;
            hk.modId = mod;
            hk.actId = act;
            hk.desc = desc;
            @hk.expr = root;
            hotkeys.InsertLast(hk);
        }
    }

    void Trigger(Hotkey@ hk) {
        if (hk is null) return;
        string key = hk.pluginId + "." + hk.modId;
        IHotkeyModule@ module;
        if (!modules.Get(key, @module) || module is null) {
            if (hk.modId == "window") {
                modules.Get(hk.pluginId + ".ui", @module);
            } else if (hk.modId == "current map") {
                modules.Get(hk.pluginId + ".loading", @module);
            }
        }
        if (module is null) return;
        module.ExecuteAction(hk.actId, hk);
    }
}

UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    HotkeyUI::OnKeyPress(down, key);
    Hotkeys::OnKeyPress(down, key);
    return UI::InputBlocking::DoNothing;
}
