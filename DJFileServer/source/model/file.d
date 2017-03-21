module model.file;
import std.file;
import std.array;
import std.typecons;
import std.string;

version (Windows)
{
    import model.win32partition;
}

struct FileItem
{
    string name; //move parent dir path prefix in local path
    string localPath;
    string type; //"partition|dir|file",
    ulong size;
}

FileItem[] listChildItem(string dirPath, Flag!("recursive") recursive,
        Flag!("moveprefix") movePrefix)
{

    FileItem[] fileItems;
    version (Windows)
    {
        if (dirPath.length == 0)
        {
            string[] parititions = listPartition();
            foreach (partition; parititions)
            {
                FileItem fileItem;
                fileItem.type = "dir";
                fileItem.name = partition;
                fileItem.localPath = partition;
                fileItems ~= fileItem;
            }
        }
        else
        {
            foreach (dirItem; dirEntries(dirPath, recursive ? SpanMode.breadth : SpanMode.shallow))
            {
                FileItem fileItem;
                fileItem.localPath = dirItem.name.replace("\\", "/");
                if (movePrefix)
                {
                    fileItem.name = fileItem.localPath.chompPrefix(dirPath ~ "/");
                }
                else
                {
                    fileItem.name = fileItem.localPath;
                }
                fileItem.size = dirItem.size;
                fileItem.type = dirItem.isDir ? "dir" : "file";
                fileItems ~= fileItem;
            }
        }
    }
    else
    {
        foreach (dirItem; dirEntries(dirPath, recursive ? SpanMode.breadth : SpanMode.shallow))
        {
            FileItem fileItem;
            fileItem.localPath = dirItem.name.replace("\\", "/");
            if (movePrefix)
            {
                fileItem.name = fileItem.localPath.chompPrefix(dirPath ~ "/");
            }
            else
            {
                fileItem.name = fileItem.localPath;
            }
            fileItem.size = dirItem.size;
            fileItem.type = dirItem.isDir ? "dir" : "file";
            fileItems ~= fileItem;
        }
    }

    return fileItems;

}
