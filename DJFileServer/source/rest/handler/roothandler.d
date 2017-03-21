module rest.handler.roothandler;
import vibe.http.server;

void handleGetRoot(HTTPServerRequest req, HTTPServerResponse res)
{
    res.writeBody("DJFileServer", "text/plain");
}
