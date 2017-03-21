module rest.handler.oshandler;
import std.experimental.logger;
import vibe.http.server;
import vibe.data.json;


struct OS
{
    string type; // = "windows|linux|osx";
    string release;
}

struct OSHandler
{
    void writeHTTPResponse(HTTPServerRequest req, HTTPServerResponse res, OS os)
    {
        if (req.contentType == "")
        {
            string repBody;
            repBody = "type:" ~ os.type ~ ", release:" ~ os.release;
            res.writeBody(repBody, "text/plain");
        }
        else
        {
            res.writeBody(os.serializeToJsonString(), "application/json");
        }
        
    }

    void handleGet(HTTPServerRequest req, HTTPServerResponse res)
    {
        OS os;
        version (Windows)
        {
            os.type = "windows";
        }
        else version (linux)
        {
            os.type = "linux";
        }
        else version (OSX)
        {
            os.type = "osx";
        }
        writeHTTPResponse(req, res, os);
    }

}
