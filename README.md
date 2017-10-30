## Overview 

This module provides support for reading and writing ZIP archives in Julia.

[![Build Status](https://travis-ci.org/samoconnor/InfoZIP.jl.png)](https://travis-ci.org/samoconnor/InfoZIP.jl)

## Installation

Install via the Julia package manager, `Pkg.add("InfoZIP")`.

Depends on the [Info ZIP](http://www.info-zip.org) `zip` and `uzip` tools.
If these are not installed the [ZipFile.jl](https://github.com/fhs/ZipFile.jl)
library is used instead.


## unzip

`InfoZIP.unzip(archive, [outputdir])` extracts an archive to files in "outputdir" (or in the current directory by default).

```julia
InfoZIP.unzip("foo.zip", "/tmp/")

InfoZIP.unzip(http_get("http://foo.com/foo.zip", "/tmp/"))
```


## High level interface

Use `open_zip` open a ZIP Archive for read and/or write.

Use `create_zip` to create a new ZIP Archive in one step.

A ZIP Archive can be either a `.ZIP` file or an `Array{UInt8,1}`.


## open_zip

The result of `open_zip(archive)` is iterable and can be accessed as an
Associative collection.

```julia
# Print size of each file in "foo.zip"...
for (filename, data) in open_zip("foo.zip")
    println("$filename has $(length(data)) bytes")
end


# Read contents of "bar.csv" from "foo.zip"...
data = open_zip("foo.zip")["foo/bar.csv"]


# Read "foo.zip" from in-memory ZIP archive...
zip_data = http_get("http://foo.com/foo.zip")
csv_data = open_zip(zip_data)["bar.csv"]


# Create a Dict from a ZIP archive...
Dict(open_zip("foo.zip"))
Dict{AbstractString,Any} with 2 entries:
  "hello.txt"    => "Hello!\n"
  "foo/text.txt" => "text\n"


# Create "foo.zip" with two files...
open_zip("foo.zip", "w") do z
    z["hello.txt"] = "Hello!\n"
    z["bar.csv"] = "1,2,3\n"
end


# Create in-memory ZIP archive in "buf"...
buf = UInt8[]
open_zip(buf) do z
    z["hello.txt"] = "Hello!\n"
    z["bar.csv"] = "1,2,3\n"
end
http_put("http://foo.com/foo.zip", buf)


# Add a new file to an existing archive"...
open_zip("foo.zip", "r+") do z
    z["newfile.csv"] = "1,2,3\n"
end


# Update an existing file in an archive"...
open_zip("foo.zip", "r+") do z
    z["newfile.csv"] = lowercase(z["newfile.csv"])
end

```


## create_zip

`create_zip([destination], content)` creates a ZIP archive from "content' in a single step. If "destination" is omitted the archive is returned as `Array{UInt8}`.

```julia

# Create archive from Dict...
create_zip("foo.zip", Dict("hello.txt" => "Hello!\n",
                           "bar.csv" => "1,2,3\n"))


# Create archive from Pairs...
create_zip("foo.zip", "hello.txt" => "Hello!\n",
                      "bar.csv" => "1,2,3\n"))


# Create archive from Tuples...
zip_data = create_zip([("hello.txt", "Hello!\n"),
                       ("bar.csv" => "1,2,3\n")])


# Create archive from filenames array and data array...
zip_data = create_zip(["hello.txt", "bar.csv"],
                      ["Hello!\n",  "1,2,3\n"])

# Create archive from names of files in the current directory...
create_zip("foo.zip", ["hello.txt", "bar.csv"])
or
zip_data = create_zip(["hello.txt", "bar.csv"])
```


*Based on [fhs/ZipFile.jl#16](https://github.com/fhs/ZipFile.jl/pull/16), thanks @timholy*
