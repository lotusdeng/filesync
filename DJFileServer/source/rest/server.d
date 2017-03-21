module rest.server;
import std.concurrency;
import std.conv;
import std.experimental.logger;
import std.functional;
import std.array;
import vibe.http.server;
import vibe.http.router;
import vibe.core.core;
import rest.handler.roothandler;
import rest.handler.oshandler;
import rest.handler.taskhandler;
import rest.handler.filehandler;
import model.appdata;

alias void delegate(HTTPServerRequest req, HTTPServerResponse res) RequestHandler;

void logRequest(HTTPServerRequest req, HTTPServerResponse res)
{
	info("+++++++++++++++++++++++++++++++++++++++++++++++++");

	string[] msgs;
	auto pSeqId = "seqid" in req.headers;
	if (pSeqId)
	{
		msgs ~= ("sedid:" ~ *pSeqId);
		res.headers["seqid"] = *pSeqId;
	}
	msgs ~= to!string(req.method);
	msgs ~= req.requestURL;
	msgs ~= req.peer;

	info(join(msgs, " "));
}

void logResponse(HTTPServerResponse res)
{
	string[] msgs;
	auto pSeqId = "seqid" in res.headers;
	if (pSeqId)
	{
		msgs ~= ("sedid:" ~ *pSeqId);
	}
	msgs ~= ("statusCode:" ~ to!string(res.statusCode));

	info(join(msgs, " "));
	info("-------------------------------------------------");
}

void startRESTServer(ushort listenPort)
{
	auto settings = new HTTPServerSettings;
	settings.port = listenPort;
	settings.maxRequestSize = 1024 * 1024 * 10;
	info("http server settings.maxRequestSize:", settings.maxRequestSize);
	version (OSX)
	{
		info("osx os");
	}
	else version (Windows)
	{
		info("windows os");
	}
	else
	{
		log("linux os");
	}
	auto router = new URLRouter;

	router.get("/", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		handleGetRoot(req, res);
		logResponse(res);
	});

	OSHandler osHandler;
	router.get("/os", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		osHandler.handleGet(req, res);
		logResponse(res);
	});

	TaskHandler taskHandler;
	router.get("/task", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		taskHandler.handleGet(req, res);
		logResponse(res);
	});
	router.post("/task", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		taskHandler.handleGet(req, res);
		logResponse(res);
	});

	FileHandler fileHandler;
	router.get("/file", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		fileHandler.handleGet(req, res);
		logResponse(res);
	});
	router.get("/file/*", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		fileHandler.handleGet(req, res);
		logResponse(res);
	});
	router.post("/file/*", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		fileHandler.handlePost(req, res);
		logResponse(res);
	});
	router.delete_("/file/*", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		fileHandler.handleDelete(req, res);
		logResponse(res);
	});
	router.get("/quit", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		res.writeBody("ok", "text/plain");
		logResponse(res);
		stopRESTServer();
	});
	router.get("/exepath", delegate(HTTPServerRequest req, HTTPServerResponse res) {
		logRequest(req, res);
		res.writeBody(gAppData.exePath, "text/plain");
		logResponse(res);
	});
	listenHTTP(settings, router);

	log("listen url:", "http://*:" ~ to!string(listenPort));
	info("runEventLoop start");
	int ret = runEventLoop();
	info("runEventLoop end, ret:", ret);
}

void stopRESTServer()
{
	exitEventLoop();
}
