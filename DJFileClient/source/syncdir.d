module syncdir;
import std.stdio;
import std.file;
import std.path;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.format;
import std.exception;
import std.experimental.logger;
import std.typecons;
import core.time;
import core.thread;
import core.memory;
import vibe.data.json;
import vibe.http.client;
import vibe.textfilter.urlencode;
import vibe.stream.operations;
import model.file;
import model.seqid;

//fileItemPath is like c:/dddd or /home
string buildHTTPUrl(string httpUrlPrefix, string fileItemPath)
{
	string[] filePathTokens = split(fileItemPath, "/");
	string[] encodeFilePathTokens;
	foreach (filePathToken; filePathTokens)
	{
		encodeFilePathTokens ~= urlEncode(filePathToken);
		//encodeFilePathTokens ~= filePathToken.replace(" ", "%20");
	}
	version (Windows)
	{
		return httpUrlPrefix ~ "/" ~ join(encodeFilePathTokens, "/");
	}
	else
	{
		return httpUrlPrefix ~ join(encodeFilePathTokens, "/");
	}
}

void syncUploadToRemoteServer(string remoteServer, string remoteDirPath, string localDirPath)
{
	string remoteDirUrl = buildHTTPUrl("http://" ~ remoteServer ~ "/file", remoteDirPath);
	info("get remote dir's child item, url:", remoteDirUrl);
	FileItem[] remoteFileItems = listRemoteDirItem(remoteDirUrl,
			Flag!("recursive").yes, Flag!("moveprefix").yes);
	FileItem[string] remoteFileItemMap = fromDirItemSet(remoteFileItems);

	FileItem[] localFileItems = listChildItem(localDirPath, Flag!("recursive")
			.yes, Flag!("moveprefix").yes);
	FileItem[string] localFileItemMap = fromDirItemSet(localFileItems);

	info("local file count:", localFileItems.length, ", remote file count:",
			remoteFileItems.length);
	foreach (localFileItem; localFileItems)
	{
		string remoteFilePath = buildPath(remoteDirPath, localFileItem.name);
		remoteFilePath = remoteFilePath.replace("\\", "/");
		string remoteFileUrl = buildHTTPUrl("http://" ~ remoteServer ~ "/file", remoteFilePath);
		info("remote encode url:", remoteFileUrl);

		if (localFileItem.type == "dir")
		{
			info("local dir:", localFileItem.name, ", remote httpURL:", remoteFileUrl);
			if (localFileItem.name !in remoteFileItemMap)
			{
				info("local dir:", localFileItem.name, ", remote dir not exist, create it");
				createDirInRemote(remoteFileUrl);
			}
			else
			{
				info("local dir:", localFileItem.name, ", remote dir exist");
			}
		}
		else
		{
			info("local file:", localFileItem.name, ", remote httpURL:", remoteFileUrl);
			ulong remoteFileItemSize = 0;
			if (localFileItem.name in remoteFileItemMap)
			{
				remoteFileItemSize = remoteFileItemMap[localFileItem.name].size;
				if (localFileItem.size == remoteFileItemSize)
				{
					info("local file:", localFileItem.name,
							", file size equal remote, not upload");
					continue;
				}
				else if (localFileItem.size < remoteFileItemSize)
				{
					info("local file:", localFileItem.name,
							", file size less than remote, first delete remote, then upload");
					deleteRemoteFile(remoteFileUrl);

				}
				else
				{
					info("local file:", localFileItem.name,
							", file size large than remote, then upload");
					bool uploadSuccess = uploadFile(remoteFileUrl,
							remoteFileItemSize, localFileItem.localPath);
				}
			}
			else
			{
				info("local file:", localFileItem.name, ", remote not exist");
				bool uploadSuccess = uploadFile(remoteFileUrl,
						remoteFileItemSize, localFileItem.localPath);
			}

		}
	}
}

void synDownloadFromRemoteServer(string remoteServer, string remoteDirPath, string localDirPath)
{
	string remoteDirUrl = buildHTTPUrl("http://" ~ remoteServer ~ "/file", remoteDirPath);
	info("get remote dir's child item, url:", remoteDirUrl);
	FileItem[] remoteFileItems = listRemoteDirItem(remoteDirUrl,
			Flag!("recursive").yes, Flag!("moveprefix").yes);
	info("remote file count:", remoteFileItems.length);
	foreach (remoteFileItem; remoteFileItems)
	{
		string remoteFilePath = buildPath(remoteDirPath, remoteFileItem.name);
		remoteFilePath = remoteFilePath.replace("\\", "/");
		string remoteFileUrl = buildHTTPUrl("http://" ~ remoteServer ~ "/file", remoteFilePath);
		info("remote url:", remoteFileUrl);

		string localFilePath = localDirPath ~ "/" ~ remoteFileItem.name;

		if (remoteFileItem.type == "dir")
		{
			if (!exists(localFilePath) || isFile(localFilePath))
			{
				info("remote dir:", remoteFileItem.name, ", local dir not exist, create it");
				mkdirRecurse(localFilePath);
			}
			else
			{
				info("remote dir:", remoteFileItem.name, ", local dir exist");
			}
		}
		else
		{
			string parentDir = dirName(localFilePath);
			if (!exists(parentDir) || isFile(parentDir))
			{
				info("local file parent dir not exist, create it:", parentDir);
				mkdirRecurse(parentDir);
			}

			long localFileSize = 0;
			if (exists(localFilePath) && isFile(localFilePath))
			{
				auto file = DirEntry(localFilePath);
				localFileSize = file.size;
				if (localFileSize == remoteFileItem.size)
				{
					info("remote file:", remoteFileItem.name,
							", local file size equal remote, not download");
				}
				else if (localFileSize > remoteFileItem.size)
				{
					info("remote file:", remoteFileItem.name,
							", local file size large remote, first remote local, then download");
					remove(localFilePath);
					localFileSize = 0;
					bool downloadSuccess = downloadFile(remoteFileUrl,
							remoteFileItem.size, localFilePath);
					if (!downloadSuccess)
					{
						error("remote file:", remoteFileItem.name, ", download fail, break");
						break;
					}
				}
				else
				{
					info("remote file:", remoteFileItem.name,
							", local file size less than remote, download");
					bool downloadSuccess = downloadFile(remoteFileUrl,
							remoteFileItem.size, localFilePath);
					if (!downloadSuccess)
					{
						error("remote file:", remoteFileItem.name, ", download fail, break");
						break;
					}
				}
			}
			else
			{
				info("remote file:", remoteFileItem.name, ", local file not exist, download it");
				bool downloadSuccess = downloadFile(remoteFileUrl,
						remoteFileItem.size, localFilePath);
				if (!downloadSuccess)
				{
					error("remote file:", remoteFileItem.name, ", download fail, break");
					break;
				}
			}

		}

	}
}

FileItem[] listRemoteDirItem(string httpDirUrl, Flag!("recursive") recursive,
		Flag!("moveprefix") moveprefix)
{
	FileItem[] fileItems;
	string[] querys;
	if (recursive)
	{
		querys ~= "recursive=true";
	}
	if (moveprefix)
	{
		querys ~= "moveprefix=true";
	}
	if (querys.length != 0)
	{
		httpDirUrl ~= ("?" ~ querys.join("&&"));
	}
	string seqId = getSeqIdStr();
	info("HTTP Req seqid:", seqId, ", url:", httpDirUrl);

	requestHTTP(httpDirUrl, (scope req) {
		req.headers["content-type"] = "application/json";
		req.headers["Connection"] = "Keep-Alive";
		req.headers["seqid"] = seqId;
	}, (scope res) {
		if (res.statusCode == HTTPStatus.OK && res.headers["seqid"] != seqId)
		{
			warning("HTTP res.seqid not equal req.seqid");
			return;
		}
		string repBody = res.bodyReader.readAllUTF8();
		info("HTTP Res, statusCode:", res.statusCode, " body:", repBody);
		if (res.statusCode == HTTPStatus.OK)
		{
			try
			{
				Json json = parseJsonString(repBody);
				fileItems = deserializeJson!(FileItem[])(json);
			}
			catch (Exception e)
			{
				error("unpack FileItem[] from json str fail");
			}
		}

	});
	return fileItems;
}

bool downloadFile(string httpUrl, long fileTotalSize, string localPath)
{
	string fileName = baseName(localPath);
	info("file download start, file:", fileName, ", remoteURL:", httpUrl);
	long totalDownloadSize = 0;
	long downloadBeginTime = MonoTime.currTime().ticks();
	scope (exit)
	{
		long now = MonoTime.currTime().ticks();
		if (now == downloadBeginTime)
		{
			now = downloadBeginTime + 1;
		}
		double usedSecond = ticksToNSecs(now - downloadBeginTime) * 1.0 / 1000_000_000;
		double speedMBPerSecond = totalDownloadSize / usedSecond * 1000_000_000 / 1024 / 1024;
		auto speedMBPerSecondStr = appender!string();
		speedMBPerSecondStr.formattedWrite("%.4g", speedMBPerSecond);
		info("file download end, file:", baseName(localPath), ", total download size:", totalDownloadSize,
				", use second:", usedSecond, ", speed:", speedMBPerSecondStr.data, "MB/S");
	}
	ulong offset = 0;
	File file;
	try
	{
		 file = File(localPath, "a");
	}
	catch(ErrnoException e)
	{
		error("open local file fail, error:", e.toString());
		return false;
	}
	offset = file.size;
	
	bool httpRequestSuccess = true;
	long length = 1024 * 1024 * 5;
	while (offset < fileTotalSize)
	{
		if (!httpRequestSuccess)
		{
			break;
		}
		string seqId = getSeqIdStr();
		info("file:", fileName, ", download chunk, offset:", offset, ", length:", length);
		info("HTTP req, seqid:", seqId, ", url:", httpUrl);
		requestHTTP(httpUrl, (scope req) {
			req.headers["Range"] = ("bytes=" ~ to!string(offset) ~ "-" ~ to!string(length));
			req.headers["Connection"] = "Keep-Alive";
			req.headers["seqid"] = seqId;
		}, (scope res) {
			info("file:", fileName, ", download chunk, statusCode:", res.statusCode);
			if (res.statusCode == HTTPStatus.OK && res.headers["seqid"] != seqId)
			{
				warning("HTTP res.seqid not equal req.seqid");
				return;
			}
			if (res.statusCode != HTTPStatus.OK)
			{
				error("file:", fileName, ", download chunk fail");
				httpRequestSuccess = false;
				return;
			}
			else
			{
				httpRequestSuccess = true;
				ubyte[] repBody = res.bodyReader.readAll();
				scope(exit) GC.free(repBody.ptr);
				info("file:", fileName, ", write local file, data length:", repBody.length);
				if (repBody.length > 0)
				{
					totalDownloadSize += repBody.length;
					file.rawWrite(repBody);
					offset += repBody.length;
				}
			}
		});
	}

	if (exists(localPath) && DirEntry(localPath).size == fileTotalSize)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool createDirInRemote(string httpUrl)
{
	httpUrl ~= "?isdir=true";

	bool createSuccess = true;
	string seqId = getSeqIdStr();
	info("HTTP req, seqid:", seqId, ", url:", httpUrl);
	requestHTTP(httpUrl, (scope req) {
		req.method = HTTPMethod.POST;
		req.headers["Connection"] = "Keep-Alive";
		req.headers["seqid"] = seqId;
	}, (scope res) {
		if (res.statusCode == HTTPStatus.OK && res.headers["seqid"] != seqId)
		{
			warning("HTTP res.seqid not equal req.seqid");
			return;
		}
		info("HTTP Res: statusCode:", res.statusCode);
		createSuccess = res.statusCode == HTTPStatus.OK ? true : false;
	});
	return true;
}

bool uploadFile(string httpUrl, long remoteFileSize, string localFilePath)
{
	static ubyte[1024 * 1024 * 5] buffer;
	
	string fileName = baseName(localFilePath);
	info("file upload start, file:", fileName, ", remoteURL:", httpUrl);
	long totalUploadSize = 0;
	long uploadBeginTime = MonoTime.currTime().ticks();
	scope (exit)
	{
		long now = MonoTime.currTime().ticks();
		if (now == uploadBeginTime)
		{
			now = uploadBeginTime + 1;
		}
		double usedSecond = ticksToNSecs(now - uploadBeginTime) * 1.0 / 1000_000_000;
		double speedMBPerSecond = totalUploadSize / usedSecond * 1000_000_000 / 1024 / 1024;
		auto speedMBPerSecondStr = appender!string();
		speedMBPerSecondStr.formattedWrite("%.4g", speedMBPerSecond);

		info("file upload end, file:", fileName, ", total upload size:", totalUploadSize,
				", use time:", usedSecond, "seconds, speed:", speedMBPerSecondStr.data, "MB/S");
	}
	bool httpRequestSuccess = true;

	auto file = File(localFilePath);
	info("file local size:", file.size, ", remote size:", remoteFileSize);
	file.seek(remoteFileSize);
	ulong offset = remoteFileSize;
	ulong length = 0;
	while (file.tell() < file.size)
	{
		file.seek(offset);
		auto data = file.rawRead(buffer);
		length = data.length;
		totalUploadSize += length;
		string seqId = getSeqIdStr();
		info("file:", baseName(localFilePath), " upload chunk, offset:",
				offset, ", length:", length);
		info("HTTP req, seqid:", seqId, ", url:", httpUrl);
		requestHTTP(httpUrl, (scope req) {
			req.method = HTTPMethod.POST;
			req.headers["seqid"] = seqId;
			req.headers["Range"] = "bytes=" ~ to!string(offset) ~ "-" ~ to!string(length);
			req.headers["Connection"] = "Keep-Alive";
			req.headers["Content-Length"] = to!string(data.length);
			req.contentType = "application/octet-stream";
			req.bodyWriter.write(data);

		}, (scope res) {
			if (res.statusCode == HTTPStatus.OK && res.headers["seqid"] != seqId)
			{
				warning("HTTP res.seqid not equal req.seqid");
				return;
			}
			if (res.statusCode != HTTPStatus.OK)
			{
				httpRequestSuccess = false;
				return;
			}
			auto pRangeByte = "Range" in res.headers;
			if (pRangeByte)
			{
				info("remote file size:", *pRangeByte);
			}
			uint rangeOffset = 0;
			uint rangeLength = 0;
			if (pRangeByte && (*pRangeByte).startsWith("bytes"))
			{
				string tmpStr = (*pRangeByte).removechars("bytes=");
				rangeOffset = to!uint(tmpStr);
			}
			offset = rangeOffset;
		});
	}

	// Seek 10 bytes from the begining of the file.

	return httpRequestSuccess;
}

bool deleteRemoteFile(string httpUrl)
{
	string seqId = getSeqIdStr();
	info("HTTP req, seqid:", seqId, ", url:", httpUrl);
	bool deleteSuccess;

	requestHTTP(httpUrl, (scope req) {
		req.headers["seqid"] = seqId;
		req.headers["Connection"] = "Keep-Alive";
	}, (scope res) {
		info("HTTP Res: statusCode: ", res.statusCode);
		if (res.statusCode == HTTPStatus.OK && res.headers["seqid"] != seqId)
		{
			warning("HTTP res.seqid not equal req.seqid");
			return;
		}
		deleteSuccess = res.statusCode == HTTPStatus.OK ? true : false;
	});
	return deleteSuccess;
}

FileItem[string] fromDirItemSet(FileItem[] fileItems)
{
	FileItem[string] ret;
	foreach (fileItem; fileItems)
	{
		ret[fileItem.name] = fileItem;
	}
	return ret;
}
