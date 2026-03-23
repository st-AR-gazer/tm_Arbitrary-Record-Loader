string pluginName = Meta::ExecutingPlugin().Name;

void NotifyDebug(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(.5, .5, .5, .3), time);
}
void NotifyInfo(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(.2, .8, .5, .3), time);
}
void NotifyNotice(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(.2, .8, .5, .3), time);
}
void NotifyWarn(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(1, .5, .1, .5), time);
}
void NotifyError(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(1, .2, .2, .3), time);
}
void NotifyCritical(const string &in msg = "", const string &in overwritePluginName = pluginName, int time = 6000) {
    UI::ShowNotification(overwritePluginName, msg, vec4(1, .2, .2, .3), time);
}

enum LogLevel {
    Debug,
    Info,
    Notice,
    Warn,
    Error,
    Critical
};

namespace DEV {
    [SettingsTab name="Logs" icon="DevTo" order="99999999999999999999999999999999999999999999999999"]
    void RT_LOGs() {
        if (UI::BeginChild("Logging Settings", vec2(0, 0), true)) {
            UI::Text("Logging Options");
            UI::Separator();

            S_showDefaultLogs = UI::Checkbox("Show default OP logs", S_showDefaultLogs);
            DEV_S_sDebug = UI::Checkbox("Show Debug logs", DEV_S_sDebug);
            DEV_S_sInfo = UI::Checkbox("Show Info logs (INFO)", DEV_S_sInfo);
            DEV_S_sNotice = UI::Checkbox("Show InfoG logs (INFO-G)", DEV_S_sNotice);
            DEV_S_sWarn = UI::Checkbox("Show Warn logs (WARN)", DEV_S_sWarn);
            DEV_S_sError = UI::Checkbox("Show Error logs (ERROR)", DEV_S_sError);
            DEV_S_sCritical = UI::Checkbox("Show Test logs (TEST)", DEV_S_sCritical);

            UI::Separator();
            UI::Text("Function Name Settings");

            S_showFunctionNameInLogs = UI::Checkbox("Show function name in logs", S_showFunctionNameInLogs);
            S_maxFunctionNameLength = UI::SliderInt("Set max function name length in logs", S_maxFunctionNameLength, 0, 50);

            UI::EndChild();
        }
    }
}

// ********** Hidden Settings **********

//////////// CHANGE TO "true" ON RELEASE  ////////////
[Setting category="z~DEV" name="Show default OP logs" hidden]
bool S_showDefaultLogs = true;
//////////////////////////////////////////////////////

[Setting category="z~DEV" name="Show Debug logs" hidden]
bool DEV_S_sDebug = true;
[Setting category="z~DEV" name="Show Info logs (INFO)" hidden]
bool DEV_S_sInfo = true;
[Setting category="z~DEV" name="Show InfoG logs (INFO-G)" hidden]
bool DEV_S_sNotice = true;
[Setting category="z~DEV" name="Show Warn logs (WARN)" hidden]
bool DEV_S_sWarn = true;
[Setting category="z~DEV" name="Show Error logs (ERROR)" hidden]
bool DEV_S_sError = true;
[Setting category="z~DEV" name="Show Test logs (TEST)" hidden]
bool DEV_S_sCritical = true;

[Setting category="z~DEV" name="Show function name in logs" hidden]
bool S_showFunctionNameInLogs = true;
[Setting category="z~DEV" name="Set max function name length in logs" min="0" max="50" hidden]
int S_maxFunctionNameLength = 15;

// ********** Logging Function **********

void log(const string &in msg, LogLevel level = LogLevel::Info, int line = -1, string _functionName = "") {
    string lineInfo = line >= 0 ? " " + tostring(line) : "";
    int lineLength = lineInfo.Length - 1;
    string extraSpaces = "";
    if (lineLength == 1) {        // 1 character
        extraSpaces = "   ";      // Three extra spaces
    } else if (lineLength == 2) { // 2 characters
        extraSpaces = "  ";       // Two extra spaces
    } else if (lineLength == 3) { // 3 characters
        extraSpaces = " ";        // One extra space
    }
    lineInfo += extraSpaces;

    if (_functionName.Length > S_maxFunctionNameLength) {
        _functionName = _functionName.SubStr(0, S_maxFunctionNameLength);
    }
    int functionNameLength = _functionName.Length;
    if (functionNameLength < S_maxFunctionNameLength) {
        int numSpacesToAdd = S_maxFunctionNameLength - functionNameLength;
        for (int i = 0; i < numSpacesToAdd; i++) {
            _functionName += " ";
        }
    }

    bool doLog = false;
    switch(level) {
        case LogLevel::Debug:    doLog = DEV_S_sDebug;       break;
        case LogLevel::Info:     doLog = DEV_S_sInfo;        break;
        case LogLevel::Notice:   doLog = DEV_S_sNotice;      break;
        case LogLevel::Warn:     doLog = DEV_S_sWarn;        break;
        case LogLevel::Error:    doLog = DEV_S_sError;       break;
        case LogLevel::Critical: doLog = DEV_S_sCritical;    break;
    }

    if (!S_showDefaultLogs) return;
    if (!S_showFunctionNameInLogs) {_functionName = "";}

    if (doLog) {
        switch(level) {
            case LogLevel::Debug:    if(!S_showDefaultLogs) { print("\\$0ff[DEBUG]  " +               "\\$z" + "\\$0cc" +             lineInfo + " : " + _functionName + " : \\$z" + msg); } else { trace(msg); } break;
            case LogLevel::Info:     if(!S_showDefaultLogs) { print("\\$0f0[INFO]   " +               "\\$z" + "\\$0c0" +             lineInfo + " : " + _functionName + " : \\$z" + msg); } else { trace(msg); } break;
            case LogLevel::Notice:   if(!S_showDefaultLogs) { print("\\$0ff[NOTICE] " +               "\\$z" + "\\$0cc" +             lineInfo + " : " + _functionName + " : \\$z" + msg); } else { trace(msg); } break;
            case LogLevel::Warn:     if(!S_showDefaultLogs) { print("\\$ff0[WARN]   " +               "\\$z" + "\\$cc0" +             lineInfo + " : " + _functionName + " : \\$z" + msg); } else { warn(msg);  } break;
            case LogLevel::Error:    if(!S_showDefaultLogs) { print("\\$f00[ERROR]  " +               "\\$z" + "\\$c00" +             lineInfo + " : " + _functionName + " : \\$z" + msg); } else { error(msg); } break;
            case LogLevel::Critical: if(!S_showDefaultLogs) { print("\\$f00\\$o\\$i\\$w[CRITICAL] " + "\\$z" + "\\$f00\\$o\\$i\\$w" + lineInfo + " : " + _functionName + " : \\$z" + msg); } else { error("\\$f00\\$o\\$i\\$w" + msg); } break;
        }
    }
}