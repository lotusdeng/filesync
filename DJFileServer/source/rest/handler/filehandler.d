module rest.handler.filehandler;
import std.file;
import std.stdio;
import std.path;
import std.experimental.logger;
import std.algorithm;
import std.string;
import std.array;
import std.exception;
import core.memory;
import vibe.http.server;
import vibe.data.json;
import vibe.data.bson;
import vibe.stream.operations;
import model.file;
import model.win32partition;
import model.appdata;

struct FileHandler
{
    void handleDelete(HTTPServerRequest req, HTTPServerResponse res)
    {
        string itemLocalPath = std.string.chompPrefix(req.path, "/file");
        if (isFile(itemLocalPath))
        {
            info("remote file:", itemLocalPath);
            remove(itemLocalPath);
        }
    }

    void handleGet(HTTPServerRequest req, HTTPServerResponse res)
    {
        string itemLocalPath = std.string.chompPrefix(req.path, "/file");
        version (Windows)
        {
            itemLocalPath = stripLeft(itemLocalPath, '/');
            if (itemLocalPath.length == 0)
            {
                string[] partitions = listPartition();
                FileItem[] fileItems;
                foreach (partition; partitions)
                {
                    FileItem fileItem;
                    fileItem.name = partition[0 .. 2];
                    fileItem.type = "dir";
                    fileItems ~= fileItem;
                }
                writeFileItemsToHTTPResponse(req, res, fileItems);
                return;
            }
        }
        else
        {
            if (itemLocalPath.length == 0)
            {
                itemLocalPath = "/";
            }
        }
        info("itemLocalPath:", itemLocalPath);
        if (exists(itemLocalPath))
        {
            if (isDir(itemLocalPath))
            {
                handleGetDir(req, res, itemLocalPath);
            }
            else
            {
                handleGetFile(req, res, itemLocalPath);
            }
        }
        else
        {
            res.writeBody("not found", HTTPStatus.NotFound, "text/plain");
        }

    }

    void writeFileItemsToHTTPResponse(HTTPServerRequest req,
            HTTPServerResponse res, FileItem[] fileItems)
    {
        if (req.contentType == "application/bson")
        {
            Bson httpResBody = serializeToBson(fileItems);
            res.writeBody(httpResBody.data, "application/bson");

        }
        else
        {
            //application/json
            string httpResBody = serializeToJsonString(fileItems);
            res.writeBody(httpResBody, "application/json");
        }
    }

    
    void handleGetFile(HTTPServerRequest req, HTTPServerResponse res, string fileLocalPath)
    {
        auto pRangeByte = "Range" in req.headers;
        if (pRangeByte)
        {
            info("Range:", *pRangeByte);
        }
        uint rangeOffset = 0;
        uint rangeLength = 0;
        if (pRangeByte && (*pRangeByte).startsWith("bytes"))
        {
            string tmpStr = (*pRangeByte).removechars("bytes=");
            string[] tokens = split(tmpStr, "-");
            if (tokens.sizeof >= 1)
            {
                rangeOffset = to!uint(tokens[0]);
            }
            if (tokens.sizeof >= 2)
            {
                rangeLength = to!uint(tokens[1]);
            }
        }
        
        try
        {
            File file = File(fileLocalPath);
            if (file.size < rangeOffset)
            {
                warning("range.offset:", rangeOffset, " must less than file size:", file.size);
                res.writeVoidBody();
                return;
            }
            uint bufferLen = min(rangeLength, file.size - rangeOffset);
            info("local file size:", file.size, ", this read block size:", bufferLen);
            file.seek(rangeOffset, SEEK_SET);
            
            static ubyte[1024*1024*10] buffer;
            auto data = file.rawRead(buffer);
            res.writeBody(data, "application/octet-stream");
            log("repBody.length:", data.length);
        }
        catch (ErrnoException ex)
        {
            log(ex.toString());
        }
    }

    void handleGetDir(HTTPServerRequest req, HTTPServerResponse res, string dirLocalPath)
    {
        auto pMovePrefix = "moveprefix" in req.query;
        auto pRecursive = "recursive" in req.query;
        info("list dir item, dir:", dirLocalPath, ", recursive:", pRecursive
                ? true : false, ", moveprefix:", pMovePrefix ? true : false);
        FileItem[] fileItems = listChildItem(dirLocalPath, pRecursive ? Flag!("recursive")
                .yes : Flag!("recursive").no, (pMovePrefix
                    ? Flag!("moveprefix").yes : Flag!("moveprefix").no));
        writeFileItemsToHTTPResponse(req, res, fileItems);
    }

    void handlePost(HTTPServerRequest req, HTTPServerResponse res)
    {
        string itemLocalPath = std.string.chompPrefix(req.path, "/file/");
        auto pIsDir = "isdir" in req.query;
        if (pIsDir)
        {
            info("create local dir:", itemLocalPath);
            handlePostDirRequest(req, res, itemLocalPath);
        }
        else
        {
            info("write file:", itemLocalPath);
            handlePostFileRequest(req, res, itemLocalPath);
        }
    }

    void handlePostDirRequest(HTTPServerRequest req, HTTPServerResponse res, string dirPath)
    {
        if (!exists(dirPath) || isFile(dirPath))
        {
            mkdir(dirPath);
        }
        res.writeVoidBody();
    }

    void handlePostFileRequest(HTTPServerRequest req, HTTPServerResponse res, string filePath)
    {
        auto pRangeByte = "Range" in req.headers;
        if (pRangeByte)
        {
            info("Range:", *pRangeByte);
        }
        uint rangeOffset = 0;
        uint rangeLength = 0;
        if (pRangeByte && (*pRangeByte).startsWith("bytes"))
        {
            string tmpStr = (*pRangeByte).removechars("bytes=");
            info(tmpStr);
            string[] tokens = split(tmpStr, "-");
            if (tokens.sizeof >= 1)
            {
                rangeOffset = to!uint(tokens[0]);
            }
            if (tokens.sizeof >= 2)
            {
                rangeLength = to!uint(tokens[1]);
            }
        }
        log("write offset:", rangeOffset, ", length:", rangeLength);
        string parentDir = dirName(filePath);
        if (!exists(parentDir))
        {
            info("create dir:", parentDir);
            mkdirRecurse(parentDir);
        }

        try
        {
            info("append file");
            File file = File(filePath, "a");
            if (rangeOffset != file.size)
            {
                warning("range.offset:", rangeOffset, " must equal than file size:", file.size);
                res.headers["Range"] = "bytes=" ~ to!string(file.size);
                res.writeVoidBody();
                return;
            }
            ubyte[] data = req.bodyReader.readAll();
            scope(exit) GC.free(data.ptr);
            info("append data length:", data.length);
            file.rawWrite(data);
            res.headers["Range"] = "bytes=" ~ to!string(file.size);
            res.writeVoidBody();
        }
        catch (ErrnoException ex)
        {
            log(ex.toString());
        }
    }
}
