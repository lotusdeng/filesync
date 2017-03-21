module syncserver;
import std.array;
import std.path;
import std.experimental.logger;
import std.exception;
import core.thread;
import vibe.http.client;
import vibe.stream.operations;
import syncdir;
import model.file;
import model.appdata;
import model.seqid;

void syncRemoteServerThread(string remoteServer, string localSendDirPath,
        string localReceiveDirPath, string remoteSendDir, string remoteReceiveDir)
{
    localSendDirPath = localSendDirPath.replace("\\", "/");
    localReceiveDirPath = localReceiveDirPath.replace("\\", "/");
    string threadName = "sync_" ~ remoteServer.replace(":", "_");
    while (true)
    {
        scope (exit)
        {
            Thread.sleep(dur!("seconds")(gAppData.syncPeriodBySecond));
        }
        try
        {
            string remoteServerExePath = getRemoteServerExePath("http://" ~ remoteServer
                    ~ "/exepath");
            if (remoteServerExePath.length == 0)
            {
                continue;
            }
            info("remote server exe path:", remoteServerExePath);

            string remoteSendDirPath = dirName(remoteServerExePath) ~ "/data/" ~ remoteSendDir;
            remoteSendDirPath = remoteSendDirPath.replace("\\", "/");

            string remoteReceiveDirPath = dirName(remoteServerExePath) ~ "/data/" ~ remoteReceiveDir;
            remoteReceiveDirPath = remoteReceiveDirPath.replace("\\", "/");

            trace(threadName, " sync once start");
            syncRemoteServer(remoteServer, localSendDirPath,
                    localReceiveDirPath, remoteSendDirPath, remoteReceiveDirPath);
            trace(threadName, " sync once end");
        }
        catch (Exception e)
        {
            warning(threadName, "sync once exception:", e.toString);
        }
    }
}

void syncRemoteServer(string remoteServer, string localSendDirPath,
        string localReceiveDirPath, string remoteSendDirPath, string remoteReceiveDirPath)
{
    {
        info("download dir start, local:", localReceiveDirPath, ", remote:", remoteSendDirPath);
        synDownloadFromRemoteServer(remoteServer, remoteSendDirPath, localReceiveDirPath);
        info("download dir end, local:", localReceiveDirPath, ", remote:", remoteSendDirPath);
    }
    {

        info("upload dir start, local:", localSendDirPath, ", remote:", remoteReceiveDirPath);
        syncUploadToRemoteServer(remoteServer, remoteReceiveDirPath, localSendDirPath);
        info("upload dir end, local:", localSendDirPath, ", remote:", remoteReceiveDirPath);
    }
}

string getRemoteServerExePath(string httpUrl)
{
    string remoteExePath;
    string seqId = getSeqIdStr();
    info("HTTP req, seqid:", seqId, ", url:", httpUrl);

    requestHTTP(httpUrl, (scope req) {
        req.headers["Connection"] = "Keep-Alive";
        req.headers["seqid"] = seqId;
    }, (scope res) {
        info("HHTP res: statusCode:", res.statusCode);
        if (res.statusCode == HTTPStatus.OK && res.headers["seqid"] != seqId)
		{
			warning("HTTP res.seqid not equal req.seqid");
			return;
		}
        if (res.statusCode == HTTPStatus.OK)
        {
            remoteExePath = res.bodyReader.readAllUTF8();
        }

    });
    return remoteExePath;
}
