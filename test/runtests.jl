using InfoZIP
using Test


# Command line "unzip" interface.

function unzip_tool_is_missing()
    try
        read(`unzip`, String)
        return false
    catch
        println("WARNING: unzip tool not found!")
        return true
    end
end

# Unzip file to dict using external "unzip" tool.

function test_unzip_file(z)
    r = Dict()
    for f in readlines(`unzip -Z1 $z`)
        f = chomp(f)
        if basename(f) != ""
            r[f] = read(`unzip -qc $z $f`, String)
        end
    end
    return r
end


# Unzip zip data to dict using external "unzip" tool.

function test_unzip(zip)
    mktemp((tmp,io)-> begin
        write(io, zip)
        close(io)
        return test_unzip_file(tmp)
    end)
end


dict = Dict("hello.txt"     => "Hello!\n",
            "foo/text.txt"  => "text\n")

# In memory ZIP from Dict...
@test dict == test_unzip(create_zip(dict))

@test dict == Dict(open_zip(create_zip(dict)))

@test open_zip(create_zip(dict))["hello.txt"] == "Hello!\n"

@test open_zip(create_zip("empty" => ""))["empty"] == ""

# In memory ZIP from pairs...
@test dict == test_unzip(create_zip("hello.txt"     => "Hello!\n",
                                   "foo/text.txt"  => "text\n"))

# In memory ZIP from tuples...
@test dict == test_unzip(create_zip(("hello.txt",     "Hello!\n"),
                                    ("foo/text.txt",  "text\n")))

# In memory ZIP from tuples...
@test dict == test_unzip(create_zip([("hello.txt",     "Hello!\n"),
                                    ("foo/text.txt",  "text\n")]))

# In memory ZIP from arrays...
@test dict == test_unzip(create_zip(["hello.txt", "foo/text.txt"],
                                    ["Hello!\n", "text\n"]))

# In memory ZIP using "do"...
zip_data = UInt8[]
open_zip(zip_data) do z
    z["hello.txt"] = "Hello!\n"
    z["foo/text.txt"] = "text\n"
end
@test dict == Dict(open_zip(zip_data))
 

# ZIP to file from Dict...
unzip_dict = ""
z = tempname() * ".zip"
#try
    create_zip(z, dict)

    @test unzip_tool_is_missing() || dict == test_unzip_file(z)

    @test open_zip(z)["hello.txt"] == "Hello!\n"

    @test dict == Dict(open_zip(z))

    create_zip(z, "foo" => "bar")

    @test open_zip(z)["foo"] == "bar"
    @test !haskey(open_zip(z), "hello.txt")

#finally
#    rm(z)
##end


# ZIP to file from Pairs...
unzip_dict = ""
z = tempname() * ".zip"
try
    create_zip(z, "hello.txt"     => "Hello!\n",
                  "foo/text.txt"  => "text\n")
    @test unzip_tool_is_missing() || dict == test_unzip_file(z)
    @test open_zip(z)["foo/text.txt"] == "text\n"
finally
    rm(z)
end

# Incremental ZIP to file...

f = tempname() * ".zip"
try
    open_zip(f) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
    end
    @test dict == Dict(open_zip(f))
    open_zip(f) do z
        @test z["hello.txt"] == "Hello!\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo/text.txt"] == "text\n" # read again
    end

    # Add one file...
    open_zip(f) do z
        z["newfile"] = "new!\n"
    end
    open_zip(f) do z
        @test z["hello.txt"] == "Hello!\n"
        @test z["newfile"] == "new!\n"
        @test z["foo/text.txt"] == "text\n"
    end

    # Read and write (read first)...
    open_zip(f) do z
        z["hello.txt"] *= "World!\n"
        z["foo/bar.txt"] = "bar\n"
        z["foo/text.txt.copy"] = z["foo/text.txt"] * "Copy\n"
    end
    open_zip(f) do z
        @test z["hello.txt"] == "Hello!\nWorld!\n"
        @test z["foo/bar.txt"] == "bar\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo/text.txt.copy"] == "text\nCopy\n"
        @test z["foo/text.txt.copy"] == "text\nCopy\n" # read again
        @test z["newfile"] == "new!\n"
    end

    # Read and write (write first)...
    open_zip(f) do z
        z["foo/bar.txt"] = "bar\n"
        z["foo/text.txt.copy"] = z["foo/text.txt"] * "Copy\n"
    end
    open_zip(f) do z
        @test z["hello.txt"] == "Hello!\nWorld!\n"
        @test z["foo/bar.txt"] == "bar\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo/text.txt.copy"] == "text\nCopy\n"
        @test z["newfile"] == "new!\n"
    end

finally
    rm(f)
end

# Write new file, then read...
f = tempname() * ".zip"
try
    open_zip(f) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
        @test z["hello.txt"] == "Hello!\n"
    end
    @test dict == Dict(open_zip(f))

finally
    rm(f)
end


# Write new file, then iterate...
f = tempname() * ".zip"
try
    open_zip(f) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
        @test [(n,v) for (n,v) in z] == [("hello.txt","Hello!\n"),("foo/text.txt","text\n")]
    end
    @test dict == Dict(open_zip(f))

finally
    rm(f)
end


# Write new file, then read and write...
f = tempname() * ".zip"
try
    open_zip(f) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["hello.txt"] == "Hello!\n"
        z["foo2/text.txt"] = "text\n"
    end
    open_zip(f) do z
        @test z["hello.txt"] == "Hello!\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo2/text.txt"] == "text\n"
        @test_throws KeyError z["foo3/text.txt"]
    end

finally
    rm(f)
end



# Incremental ZIP to buffer...

buf = UInt8[]

    open_zip(buf) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
    end
    @test dict == Dict(open_zip(buf))
    open_zip(buf) do z
        @test z["hello.txt"] == "Hello!\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo/text.txt"] == "text\n" # read again
    end

    # Add one file...
    open_zip(buf) do z
        z["newfile"] = "new!\n"
    end
    open_zip(buf) do z
        @test z["hello.txt"] == "Hello!\n"
        @test z["newfile"] == "new!\n"
        @test z["foo/text.txt"] == "text\n"
    end

    # Read and write (read first)...
    open_zip(buf) do z
        z["hello.txt"] *= "World!\n"
        z["foo/bar.txt"] = "bar\n"
        z["foo/text.txt.copy"] = z["foo/text.txt"] * "Copy\n"
    end
    open_zip(buf) do z
        @test z["hello.txt"] == "Hello!\nWorld!\n"
        @test z["foo/bar.txt"] == "bar\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo/text.txt.copy"] == "text\nCopy\n"
        @test z["foo/text.txt.copy"] == "text\nCopy\n" # read again
        @test z["newfile"] == "new!\n"
    end

    # Read and write (write first)...
    open_zip(buf) do z
        z["foo/bar.txt"] = "bar\n"
        z["foo/text.txt.copy"] = z["foo/text.txt"] * "Copy\n"
    end
    open_zip(buf) do z
        @test z["hello.txt"] == "Hello!\nWorld!\n"
        @test z["foo/bar.txt"] == "bar\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo/text.txt.copy"] == "text\nCopy\n"
        @test z["newfile"] == "new!\n"
    end


# Write new buffer, then read...
buf = UInt8[]

    open_zip(buf) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
        @test z["hello.txt"] == "Hello!\n"
    end
    @test dict == Dict(open_zip(buf))



# Write new buffer, then iterate...
buf = UInt8[]

    open_zip(buf) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
        @test [(n,v) for (n,v) in z] == [("hello.txt","Hello!\n"),("foo/text.txt","text\n")]
    end
    @test dict == Dict(open_zip(buf))



# Write new buffer, then read and write...
buf = UInt8[]

    open_zip(buf) do z
        z["hello.txt"] = "Hello!\n"
        z["foo/text.txt"] = "text\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["hello.txt"] == "Hello!\n"
        z["foo2/text.txt"] = "text\n"
    end
    open_zip(buf) do z
        @test z["hello.txt"] == "Hello!\n"
        @test z["foo/text.txt"] == "text\n"
        @test z["foo2/text.txt"] == "text\n"
    end



# Unzip file created by command-line "zip" tool...

testzip = joinpath(dirname(pathof(InfoZIP)),"..","test","test.zip")
d = Dict(open_zip(testzip))
@test sum(d["test.png"]) == 462242
delete!(d, "test.png")
@test dict == d


# unzip()...

mktempdir() do d
    InfoZIP.unzip(testzip, d)
    @test read(joinpath(d, "hello.txt"), String) == "Hello!\n"
    @test read(joinpath(d, "foo/text.txt"), String) == "text\n"
end

mktempdir() do d
    InfoZIP.unzip(create_zip(dict), d)
    @test read(joinpath(d, "hello.txt"), String) == "Hello!\n"
    @test read(joinpath(d, "foo/text.txt"), String) == "text\n"
end


mktempdir() do d
    cd(d) do
        write("hello.txt", "Hello!\n")
        mkdir("foo")
        write("foo/text.txt", "text\n")
        @test dict == Dict(open_zip(create_zip(["hello.txt", "foo/text.txt"])))
    end
end
