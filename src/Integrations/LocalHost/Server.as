namespace Server {
    const uint PORT = 29918;
    const string HOSTNAME = "127.0.0.1";

    const string HTTP_BASE_URL = "http://" + HOSTNAME + ":" + PORT + "/";


    const string serverDirectory = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/");
    const string storedFilesDirectory = IO::FromStorageFolder("files/");

    const string serverDirectoryAutoMove = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/AutoMove/");
    
    const string currentMapRecords = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/CurrentMapRecords/");

    const string specificDownloaded = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/Downloaded/");
    const string specificDownloadedJsonFilesDirectory = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/Downloaded/JsonData/");
    const string specificDownloadedCreatedProfilesDirectory = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/Downloaded/CreatedProfiles/");

    const string linksDirectory = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/Links/");

    const string officialInfoFilesDirectory = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/Official/Info/");
    const string officialJsonFilesDirectory = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Server/Official/JsonData/");

    const string replayARL = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/");
    const string replayARLTmp = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Tmp/");
    const string replayARLDummy = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/Dummy/");
    const string replayARLAutoMove = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/AutoMove/");


    HttpServer@ server = null;

    enum ServerState {
        NotStarted,
        Running,
        Shutdown,
        Error
    }

    void StartHttpServer() {
        if (server !is null) return;
        @server = HttpServer(HOSTNAME, PORT);
        @server.RequestHandler = RouteRequests;
        server.StartServer();
    }

    HttpResponse@ RouteRequests(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
        log("Route: " + route, LogLevel::Info, 47, "StartHttpServer");
        log("Data length: " + data.Length, LogLevel::Info, 48, "StartHttpServer");
        if (route.StartsWith('/get_ghost/')) return HandleGetGhost(type, route, headers, data);
        log("Did not find route.", LogLevel::Warning, 50, "StartHttpServer");
        return _404_Response;
    }

    HttpResponse@ HandleGetGhost(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
        if (type != "GET" && type != "HEAD") return HttpResponse(405, "Must be a GET or HEAD request.");
        if (!route.StartsWith("/get_ghost/")) return _404_Response;
        try {
            auto key = Net::UrlDecode(route.Replace("/get_ghost/", ""));
            int q = key.IndexOf("?");
            if (q >= 0) key = key.SubStr(0, q);
            log('loading ghost: ' + key, LogLevel::Info, 61, "StartHttpServer");
            string filePath = serverDirectoryAutoMove + key;
            if (!IO::FileExists(filePath)) {
                auto storedRecord = Services::Storage::FileStore::ResolveManagedRecord(key);
                if (storedRecord !is null) {
                    filePath = storedRecord.storedPath;
                }
            }
            if (!IO::FileExists(filePath)) return _404_Response;

            uint64 fileSize = IO::FileSize(filePath);

            string range = "";
            auto hdrKeys = headers.GetKeys();
            for (uint i = 0; i < hdrKeys.Length; i++) {
                if (hdrKeys[i].ToLower() == "range") {
                    range = string(headers[hdrKeys[i]]).Trim();
                    break;
                }
            }

            bool hasRange = range.Length > 0 && range.ToLower().StartsWith("bytes=");
            uint64 rangeStart = 0;
            uint64 rangeEnd = fileSize > 0 ? (fileSize - 1) : 0;
            bool rangeOk = false;

            if (hasRange && fileSize > 0) {
                string spec = range.SubStr(6).Trim();
                int dash = spec.IndexOf("-");
                if (dash >= 0) {
                    string startStr = spec.SubStr(0, dash).Trim();
                    string endStr = spec.SubStr(dash + 1).Trim();

                    if (startStr.Length == 0 && endStr.Length > 0) {
                        int suffix = Text::ParseInt(endStr);
                        if (suffix > 0) {
                            uint64 suf = uint64(suffix);
                            rangeStart = fileSize > suf ? (fileSize - suf) : 0;
                            rangeEnd = fileSize - 1;
                            rangeOk = rangeStart <= rangeEnd;
                        }
                    } else if (startStr.Length > 0) {
                        int startParsed = Text::ParseInt(startStr);
                        if (startParsed >= 0) {
                            rangeStart = uint64(startParsed);
                            if (endStr.Length > 0) {
                                int endParsed = Text::ParseInt(endStr);
                                if (endParsed >= 0) {
                                    rangeEnd = uint64(endParsed);
                                }
                            } else {
                                rangeEnd = fileSize - 1;
                            }

                            if (rangeStart < fileSize) {
                                if (rangeEnd >= fileSize) rangeEnd = fileSize - 1;
                                rangeOk = rangeStart <= rangeEnd;
                            }
                        }
                    }
                }
            }

            if (type == "HEAD") {
                auto resp = HttpResponse();
                resp.status = rangeOk ? 206 : 200;
                uint64 outLen = rangeOk ? (rangeEnd - rangeStart + 1) : fileSize;
                resp.headers['Content-Length'] = tostring(outLen);
                resp.headers['Content-Type'] = "application/octet-stream";
                if (rangeOk) {
                    resp.headers['Content-Range'] = "bytes " + tostring(rangeStart) + "-" + tostring(rangeEnd) + "/" + tostring(fileSize);
                }
                resp.headers['Accept-Ranges'] = "bytes";
                resp.headers['Cache-Control'] = "no-store, no-cache, must-revalidate";
                resp.headers['Pragma'] = "no-cache";
                resp.headers['Expires'] = "0";
                log('handled HEAD for ghost: ' + key + ' (' + fileSize + ' bytes)', LogLevel::Info, 137, "StartHttpServer");
                return resp;
            }

            IO::File file(filePath, IO::FileMode::Read);

            HttpResponse@ resp = null;
            if (rangeOk) {
                uint64 len = rangeEnd - rangeStart + 1;
                file.SetPos(rangeStart);
                auto buf = file.Read(len);
                file.Close();
                log('got binary buf (range): ' + buf.GetSize(), LogLevel::Info, 149, "StartHttpServer");
                @resp = HttpResponse(206, buf);
                resp.headers['Content-Range'] = "bytes " + tostring(rangeStart) + "-" + tostring(rangeEnd) + "/" + tostring(fileSize);
            } else {
                auto buf = file.Read(fileSize);
                file.Close();
                log('got binary buf: ' + buf.GetSize(), LogLevel::Info, 155, "StartHttpServer");
                @resp = HttpResponse(200, buf);
            }

            resp.headers['Accept-Ranges'] = "bytes";
            resp.headers['Cache-Control'] = "no-store, no-cache, must-revalidate";
            resp.headers['Pragma'] = "no-cache";
            resp.headers['Expires'] = "0";
            return resp;
        } catch {
            log("Exception in HandleGetGhost: " + getExceptionInfo(), LogLevel::Error, 165, "StartHttpServer");
        }
        return HttpResponse(500, "Internal Server Error");
    }

    HttpResponse _404_Response(404, "Not found");

    class HttpResponse {
        int status = 405;
        string _body;
        MemoryBuffer@ _buf;
        dictionary headers;

        string body {
            get { return _body; }
        }

        void set_body(const string &in value) {
            _body = value;
            headers['Content-Length'] = tostring(value.Length);
        }

        HttpResponse() {
            InitHeaders(0);
        }
        HttpResponse(int status, const string &in body = "") {
            InitHeaders(body.Length);
            this.status = status;
            this.body = body;
        }
        HttpResponse(int status, MemoryBuffer@ buf) {
            InitHeaders(buf.GetSize(), "application/octet-stream");
            this.status = status;
            @_buf = buf;
        }

        protected void InitHeaders(uint contentLength, const string &in contentType = "text/plain") {
            headers['Content-Length'] = tostring(contentLength);
            headers['Content-Type'] = contentType;
            headers['Server'] = "AngelScript HttpServer " + Meta::ExecutingPlugin().Version;
            headers['Connection'] = "close";
        }

        const string StatusMsgText() {
            switch (status) {
                case 200: return "OK";
                case 206: return "Partial Content";
                case 404: return "Not Found";
                case 405: return "Method Not Allowed";
                case 500: return "Internal Server Error";
            }
            if (status < 300) return "OK?";
            if (status < 400) return "Redirect?";
            if (status < 500) return "Request Error?";
            return "Server Error?";
        }
    }

    // Returns status
    funcdef HttpResponse@ ReqHandlerFunc(const string &in type, const string &in route, dictionary@ headers, const string &in data);

    /* An http server. Call `.StartServer()` to start listening. Default port is 29805 and default host is localhost. */
    class HttpServer {
        // 29805 = 0x746d = 'tm'
        uint16 port = 29806;
        string host = "localhost";
        protected ServerState state = ServerState::NotStarted;

        HttpServer() {}
        HttpServer(uint16 port) {
            this.port = port;
        }
        HttpServer(const string &in hostname) {
            this.host = hostname;
        }
        HttpServer(const string &in hostname, uint16 port) {
            this.port = port;
            this.host = hostname;
        }

        protected Net::Socket@ socket = null;
        ReqHandlerFunc@ RequestHandler = null;

        void Shutdown() {
            state = ServerState::Shutdown;
            try {
                socket.Close();
            } catch {
                log("Failed to close HTTP server socket during shutdown: " + getExceptionInfo(), LogLevel::Warning, -1, "Shutdown");
            }
            log("Server shut down.", LogLevel::Info, 253, "Shutdown");
        }

        void StartServer() {
            if (RequestHandler is null) {
                throw("Must set .RequestHandler before starting server!");
            }
            if (state != ServerState::NotStarted) {
                throw("Cannot start HTTP server twice.");
            }
            @socket = Net::Socket();
            log("Starting server: " + host + ":" + port, LogLevel::Info, 264, "StartServer");
            if (!socket.Listen(host, port)) {
                SetError("failed to start listening");
                return;
            }
            state = ServerState::Running;
            log("Server running.", LogLevel::Info, 270, "StartServer");
            startnew(CoroutineFunc(this.AcceptConnections));
        }

        protected void SetError(const string &in errMsg) {
            log('HttpServer terminated with error: ' + errMsg, LogLevel::Error, 275, "SetError");
            state = ServerState::Error;
            try {
                socket.Close();
            } catch {
                log("Failed to close HTTP server socket after error: " + getExceptionInfo(), LogLevel::Warning, -1, "SetError");
            };
            @socket = null;
        }

        protected void AcceptConnections() {
            while (state == ServerState::Running) {
                yield();
                auto client = socket.Accept();
                if (client is null) continue;
                log("Accepted new client // Remote: " + client.GetRemoteIP(), LogLevel::Info, 288, "AcceptConnections");
                startnew(CoroutineFuncUserdata(this.RunClient), client);
            }
        }

        protected void RunClient(ref@ clientRef) {
            auto client = cast<Net::Socket>(clientRef);
            if (client is null) return;
            uint clientStarted = Time::Now;
            while (Time::Now - clientStarted < 10000 && client.Available() == 0) yield();
            if (client.Available() == 0) {
                log("Timing out client: " + client.GetRemoteIP(), LogLevel::Info, 299, "RunClient");
                client.Close();
                return;
            }
            RunRequest(client);
            log("Closing client.", LogLevel::Info, 304, "RunClient");
            client.Close();
        }

        protected void RunRequest(Net::Socket@ client) {
            string reqLine;
            if (!client.ReadLine(reqLine)) {
                log("RunRequest: could not read first line!", LogLevel::Warning, 311, "RunRequest");
                return;
            }
            reqLine = reqLine.Trim();
            auto reqParts = reqLine.Split(" ", 3);
            log("RunRequest got first line: " + reqLine + " (parts: " + reqParts.Length + ")", LogLevel::Info, 316, "RunRequest");
            auto headers = ParseHeaders(client);
            log("Got " + headers.GetSize() + " headers.", LogLevel::Info, 318, "RunRequest");
            // auto headerKeys = headers.GetKeys();
            auto reqType = reqParts[0];
            auto reqRoute = reqParts[1];
            auto httpVersion = reqParts[2];
            if (!httpVersion.StartsWith("HTTP/1.")) {
                log("Unsupported HTTP version: " + httpVersion, LogLevel::Warning, 324, "RunRequest");
                return;
            }
            string data;
            if (headers.Exists('Content-Length')) {
                auto len = Text::ParseInt(string(headers['Content-Length']));
                data = client.ReadRaw(len);
            }
            if (client.Available() > 0) {
                log("After reading headers and body there are " + client.Available() + " bytes remaining!", LogLevel::Warning, 333, "RunRequest");
            }
            HttpResponse@ resp = HttpResponse();
            try {
                @resp = RequestHandler(reqType, reqRoute, headers, data);
            } catch {
                log("Exception in RequestHandler: " + getExceptionInfo(), LogLevel::Error, 339, "RunRequest");
                resp.status = 500;
                resp.body = "Exception: " + getExceptionInfo();
            }
            string respHdrsStr = FormatHeaders(resp.headers);
            string fullResponse = httpVersion + " " + resp.status + " " + resp.StatusMsgText() + "\r\n" + respHdrsStr;
            fullResponse += "\r\n\r\n" + resp.body;
            auto respBuf = MemoryBuffer();
            respBuf.Write(fullResponse);
            log("Response: " + fullResponse, LogLevel::Debug, 348, "RunRequest");
            if (resp._buf !is null) {
                resp._buf.Seek(0);
                respBuf.WriteFromBuffer(resp._buf, resp._buf.GetSize());
            }
            // need to use WriteRaw b/c otherwise strings are length prefixed
            // client.WriteRaw(fullResponse);
            respBuf.Seek(0);
            client.Write(respBuf, respBuf.GetSize());
            log("["+Time::Stamp + " | " + client.GetRemoteIP()+"] " + reqType + " " + reqRoute + " " + resp.status, LogLevel::Info, 357, "RunRequest");
            log("Completed request.", LogLevel::Info, 358, "RunRequest");
        }

        protected dictionary@ ParseHeaders(Net::Socket@ client) {
            dictionary headers;
            string nextLine;
            uint started = Time::Now;
            uint lastData = Time::Now;
            bool sawHeader = false;

            while (Time::Now - started < 3000) {
                while (client.Available() == 0) {
                    uint idleMs = Time::Now - lastData;
                    if ((sawHeader && idleMs > 1000) || (!sawHeader && Time::Now - started > 1000)) {
                        log("Header read timed out; proceeding with " + headers.GetSize() + " parsed header(s).", LogLevel::Warning, 372, "RunRequest");
                        return headers;
                    }
                    yield();
                }

                if (!client.ReadLine(nextLine)) {
                    log("Header read stopped before terminator; proceeding with " + headers.GetSize() + " parsed header(s).", LogLevel::Warning, 379, "RunRequest");
                    return headers;
                }

                lastData = Time::Now;
                nextLine = nextLine.Trim();
                if (nextLine.Length > 0) {
                    AddHeader(headers, nextLine);
                    sawHeader = true;
                } else break;
            }
            if (Time::Now - started >= 3000) {
                log("Header read hit hard timeout; proceeding with " + headers.GetSize() + " parsed header(s).", LogLevel::Warning, 391, "RunRequest");
            }
            return headers;
        }

        protected void AddHeader(dictionary@ d, const string &in line) {
            auto parts = line.Split(":", 2);
            if (parts.Length < 2) {
                log("Header line failed to parse: " + line + " // " + parts[0], LogLevel::Warning, 399, "AddHeader");
            } else {
                d[parts[0]] = parts[1];
                if (parts[0].ToLower().Contains("authorization")) {
                    parts[1] = "<auth omitted>";
                }
                log("Parsed header line: " + parts[0] + ": " + parts[1], LogLevel::Info, 405, "AddHeader");
            }
        }
    }

    string FormatHeaders(dictionary@ headers) {
        auto keys = headers.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            if (keys[i].ToLower().Contains("authorization")) {
                keys[i] += ": <auth omitted>";
            } else {
                keys[i] += ": " + string(headers[keys[i]]);
            }
        }
        return Text::Join(keys, "\r\n");
    }
}
