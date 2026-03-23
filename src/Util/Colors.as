string Colorize(const string &in msg, array<string> colors = {"0033CC", "33FFFF"}, colorize::GradientMode mode = colorize::GradientMode::linear, bool useEscapeCharacters = true, bool flipped = false, bool _verbose = false) {
    return colorize::CS(msg, colors, mode, useEscapeCharacters, flipped, _verbose);
}

string Colorize(const array<string> &in msgs, array<string> colors = {"0033CC", "33FFFF"}, colorize::GradientMode mode = colorize::GradientMode::linear, bool useEscapeCharacters = true, bool flipped = false, bool _verbose = false) {
    return colorize::CS(msgs, colors, mode, useEscapeCharacters, flipped, _verbose);
}

namespace colorize {
    enum GradientMode { 
        linear, 
        exponential, 
        cubed,
        quadratic,
        sine,
        back,
        elastic,
        bounce,
        inverseQuadratic,
        smoothstep,
        smootherstep,
        circular
    };

    bool verbose = false;

    string CS(const string &in msg, array<string> colors = {"0033CC", "33FFFF"}, GradientMode mode = GradientMode::linear, bool useEscapeCharacters = true, bool flipped = false, bool _verbose = false) {
        return ColorizeString(msg, colors, mode, useEscapeCharacters, flipped, _verbose);
    }

    string CS(array<string> msgs, array<string> colors = {"0033CC", "33FFFF"}, GradientMode mode = GradientMode::linear, bool useEscapeCharacters = true, bool flipped = false, bool _verbose = false) {
        return ColorizeString(msgs, colors, mode, useEscapeCharacters, flipped, _verbose);
    }

    string ColorizeString(const string &in msg, array<string> colors = {"0033CC", "33FFFF"}, GradientMode mode = GradientMode::linear, bool useEscapeCharacters = true, bool flipped = false, bool _verbose = false) {
        verbose = _verbose;
        if (verbose) log("Starting ColorizeString (single string)", LogLevel::Info, 37, "ColorizeString");
        if (msg == "" || msg.Length == 1) {
            if (verbose) log("Message is empty or single character: " + msg, LogLevel::Info, 39, "ColorizeString");
            return msg;
        }
        return Hidden::ProcessString(msg, colors, mode, useEscapeCharacters, flipped);
    }

    string ColorizeString(const array<string> &in msgs, array<string> colors = {"0033CC", "33FFFF"}, GradientMode mode = GradientMode::linear, bool useEscapeCharacters = true, bool flipped = false, bool _verbose = false) {
        verbose = _verbose;
        if (verbose) log("Starting ColorizeString (array of strings)", LogLevel::Info, 47, "ColorizeString");

        array<string> result;
        for (uint i = 0; i < msgs.Length; ++i) {
            if (msgs[i] == "" || msgs[i].Length == 1) {
                if (verbose) log("Message is empty or single character: " + msgs[i], LogLevel::Info, 52, "ColorizeString");
                result.InsertLast(msgs[i]);
            } else {
                result.InsertLast(Hidden::ProcessString(msgs[i], colors, mode, useEscapeCharacters, flipped));
            }
        }
        return Hidden::JoinArray(result);
    }
    
    namespace Hidden {
        string ProcessString(const string &in msg, array<string> colors, GradientMode mode, bool useEscapeCharacters, bool flipped) {
            if (verbose) log("Processing string: " + msg, LogLevel::Info, 63, "ProcessString");

            array<vec3> colorArray;
            for (uint i = 0; i < colors.Length; ++i) {
                vec3 parsedColor = ParseColor(colors[i]);
                if (verbose) log("Parsed color: " + colors[i] + " -> " + tostring(parsedColor), LogLevel::Info, 68, "ProcessString");
                colorArray.InsertLast(parsedColor);
            }

            if (flipped) {
                if (verbose) log("Flipping color array", LogLevel::Info, 73, "ProcessString");
                colorArray.Reverse();
            }

            string strippedMsg = msg.Trim();
            if (verbose) log("Stripped message: " + strippedMsg, LogLevel::Info, 78, "ProcessString");
            array<string> chars;
            int i = 0;
            while (i < strippedMsg.Length) {
                if ((i + 2 < strippedMsg.Length) && ((strippedMsg[i] & 0xF0) == 0xE0)) {
                    chars.InsertLast(strippedMsg.SubStr(i, 3));
                    i += 3;
                } else {
                    chars.InsertLast(strippedMsg.SubStr(i, 1));
                    i++;
                }
            }

            if (verbose) log("Message split into characters: " + tostring(chars.Length), LogLevel::Info, 91, "ProcessString");
            int charCount = int(chars.Length);
            array<string> coloredChars;

            for (int z = 0; z < charCount; ++z) {
                float position = float(z) / (charCount - 1);
                vec3 interpolatedColor = InterpolateColors(colorArray, position, mode);
                if (verbose) log("Position: " + tostring(position) + " Interpolated Color: " + tostring(interpolatedColor), LogLevel::Info, 98, "ProcessString");
                interpolatedColor = NormalizeColor(interpolatedColor);
                if (verbose) log("Normalized Color: " + tostring(interpolatedColor), LogLevel::Info, 100, "ProcessString");
                string colorCode = Text::FormatGameColor(interpolatedColor);
                if (useEscapeCharacters) {
                    colorCode = "\\" + colorCode;
                } else {
                    colorCode = "$" + colorCode;
                }
                if (verbose) log("Character: " + chars[z] + " Color code: " + colorCode, LogLevel::Info, 107, "ProcessString");
                coloredChars.InsertLast(colorCode + chars[z]);
            }

            string result = JoinArray(coloredChars);
            if (verbose) log("Final processed string: " + result, LogLevel::Info, 112, "ProcessString");
            return result;
        }

        vec3 ParseColor(const string &in color) {
            if (verbose) log("Parsing color: " + color, LogLevel::Info, 117, "ParseColor");
            if (color.StartsWith('#')) {
                return HexToRgb(color.SubStr(1));
            } else if (color.SubStr(0, 4) == "vec3") {
                string vecString = color.SubStr(5, color.Length - 6); // Remove "vec3(" and ")"
                array<string> components = vecString.Split(",");
                return vec3(Text::ParseFloat(components[0]), Text::ParseFloat(components[1]), Text::ParseFloat(components[2]));
            } else {
                return HexToRgb(color);
            }
        }

        vec3 HexToRgb(const string &in hex) {
            if (verbose) log("Converting hex: " + hex + " to RGB", LogLevel::Info, 130, "HexToRgb");
            if (hex.Length == 3) {
                vec3 x = vec3(
                    Text::ParseInt(hex.SubStr(0, 1) + hex.SubStr(0, 1), 16),
                    Text::ParseInt(hex.SubStr(1, 1) + hex.SubStr(1, 1), 16),
                    Text::ParseInt(hex.SubStr(2, 1) + hex.SubStr(2, 1), 16)
                );
                return x;
            } else if (hex.Length == 6){
                vec3 x = vec3(
                    Text::ParseInt(hex.SubStr(0, 2), 16),
                    Text::ParseInt(hex.SubStr(2, 2), 16),
                    Text::ParseInt(hex.SubStr(4, 2), 16)
                );
                return x;
            } else {
                if (verbose) log("Invalid hex color: " + hex, LogLevel::Error, 146, "HexToRgb");
                return vec3(255, 255, 255);
            }
        }

        vec3 NormalizeColor(const vec3 &in color) {
            vec3 normalizedColor;
            normalizedColor.x = color.x / 255.0;
            normalizedColor.y = color.y / 255.0;
            normalizedColor.z = color.z / 255.0;
            if (verbose) log("Normalized color: " + tostring(normalizedColor), LogLevel::Info, 156, "NormalizeColor");
            return normalizedColor;
        }

        vec3 InterpolateColors(const array<vec3> &in colors, float position, GradientMode mode) {
            if (verbose) log("Interpolating colors at position: " + tostring(position) + " with mode: " + tostring(mode), LogLevel::Info, 161, "InterpolateColors");
            float p;
            if (mode == linear) {
                p = position;
            } else if (mode == exponential) {
                p = Math::Pow(position, 2);
            } else if (mode == cubed) {
                p = Math::Pow(position, 3);
            } else if (mode == quadratic) {
                p = Math::Pow(position, 0.5);
            } else if (mode == sine) {
                p = Math::Sin(position * Math::PI / 2);
            } else if (mode == back) {
                p = Math::Pow(position, 2) * ((1.70158 + 1) * position - 1.70158);
            } else if (mode == elastic) {
                p = Math::Pow(2, 10 * (position - 1)) * Math::Sin((position - 1.075) * (2 * Math::PI) / 0.3);
            } else if (mode == bounce) {
                p = 1 - Math::Abs(Math::Cos(position * Math::PI * 4) * (1 - position));
            } else if (mode == inverseQuadratic) {
                p = 1 - Math::Pow(1 - position, 2);
            } else if (mode == smoothstep) {
                p = Math::Pow(position, 2) * (3 - 2 * position);
            } else if (mode == smootherstep) {
                p = Math::Pow(position, 3) * (position * (position * 6 - 15) + 10);
            } else if (mode == circular) {
                p = 1 - Math::Sqrt(1 - Math::Pow(position, 2));
            } else {
                p = position;
            }
            
            if (verbose) log("Position: " + tostring(position) + " P: " + tostring(p), LogLevel::Info, 191, "InterpolateColors");
            uint startIdx = uint(Math::Floor(p * (colors.Length - 1)));
            uint endIdx = Math::Min(startIdx + 1, colors.Length - 1);
            float localPos = (p * (colors.Length - 1)) - startIdx;
            if (verbose) log("StartIdx: " + tostring(startIdx) + " EndIdx: " + tostring(endIdx) + " LocalPos: " + tostring(localPos), LogLevel::Info, 195, "InterpolateColors");
            return Mix(colors[startIdx], colors[endIdx], localPos);
        }

        vec3 Mix(const vec3 &in a, const vec3 &in b, float t) {
            return vec3(
                a.x + (b.x - a.x) * t,
                a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t
            );
        }

        string JoinArray(array<string> &in arr) {
            if (verbose) log("Joining array of strings with length: " + tostring(arr.Length), LogLevel::Info, 208, "JoinArray");
            string result = "";
            for (uint i = 0; i < arr.Length; ++i) {
                if (verbose) log("Appending: " + arr[i], LogLevel::Info, 211, "JoinArray");
                result += arr[i];
            }
            return result;
        }
    } // end of namespace Hidden

} // end of namespace colorize