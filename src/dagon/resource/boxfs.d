/*
Copyright (c) 2017-2018 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.resource.boxfs;

import std.stdio;
import std.datetime;
import std.algorithm;

import dlib.core.memory;
import dlib.core.stream;
import dlib.filesystem.filesystem;
import dlib.container.dict;
import dlib.container.array;
import dlib.text.utils;

struct BoxEntry
{
    ulong offset;
    ulong size;
}

class UnmanagedArrayStream: ArrayStream
{
    ubyte[] buffer;

    this(ubyte[] data)
    {
        super(data, data.length);
        buffer = data;
    }

    ~this()
    {
        Delete(buffer);
    }
}

class BoxFileSystem: ReadOnlyFileSystem
{
    InputStream boxStrm;
    string rootDir = "";
    Dict!(BoxEntry, string) files;
    DynamicArray!string filenames;
    bool deleteStream = false;
    
    this(ReadOnlyFileSystem fs, string filename, string rootDir = "")
    {        
        this(fs.openForInput(filename), true, rootDir);
    }

    this(InputStream istrm, bool deleteStream = false, string rootDir = "")
    {
        this.deleteStream = deleteStream;
        this.rootDir = rootDir;
        this.boxStrm = istrm;

        ubyte[4] magic;
        boxStrm.fillArray(magic);
        assert(magic == "BOXF");

        ulong numFiles;
        boxStrm.readLE(&numFiles);

        files = New!(Dict!(BoxEntry, string));

        string rootDirWithSeparator;
        if (rootDir.length)
            rootDirWithSeparator = catStr(rootDir, "/");

        foreach(i; 0..numFiles)
        {
            uint filenameSize;
            boxStrm.readLE(&filenameSize);
            ubyte[] filenameBytes = New!(ubyte[])(filenameSize);
            boxStrm.fillArray(filenameBytes);
            string filename = cast(string)filenameBytes;
            ulong offset, size;
            boxStrm.readLE(&offset);
            boxStrm.readLE(&size);

            if (rootDirWithSeparator.length)
            {
                if (filename.startsWith(rootDirWithSeparator))
                {
                    string newFilename = filename[rootDirWithSeparator.length..$];
                    filenames.append(filename);
                    files[newFilename] = BoxEntry(offset, size);
                }
                else
                    Delete(filenameBytes);
            }
            else
            {
                filenames.append(filename);
                files[filename] = BoxEntry(offset, size);
            }
        }

        if (rootDirWithSeparator.length)
            Delete(rootDirWithSeparator);
    }

    bool stat(string filename, out FileStat stat)
    {
        if (filename in files)
        {
            stat.isFile = true;
            stat.isDirectory = false;
            stat.sizeInBytes = files[filename].size;
            stat.creationTimestamp = SysTime.init;
            stat.modificationTimestamp = SysTime.init;

            return true;
        }
        else
            return false;
    }

    InputStream openForInput(string filename)
    {
        if (filename in files)
        {
            BoxEntry file = files[filename];
            ubyte[] buffer = New!(ubyte[])(cast(size_t)file.size);
            boxStrm.position = file.offset;
            boxStrm.fillArray(buffer);
            return New!UnmanagedArrayStream(buffer);
        }
        else
            return null;
    }

    Directory openDir(string dir)
    {
        // TODO
        return null;
    }

    ~this()
    {
        foreach(f; filenames)
            Delete(f);
        filenames.free();
        Delete(files);
        if (deleteStream)
            Delete(boxStrm);
    }
}

