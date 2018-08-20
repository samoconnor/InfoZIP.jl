using ZipFile

mutable struct Archive <: AbstractDict{AbstractString,Any}
    io::IO
    reader
    writer
    cache::Dict
    cache_is_active::Bool
end


# Create Archive interface for "io".
# Try to create a Reader, but don't read anything yet.
# If the archive is being newly created, "reader" will be "nothing".

function Archive(io::IO)

    reader = nothing
    cache = Dict()
    try
        reader = ZipFile.Reader(io, false)  
        cache = Dict([Pair(f.name, "") for f in reader.files])
    catch ex
    end
    Archive(io, reader, nothing, cache, false)
end


# Open a ZIP Archive from io, buffer or file.

open_zip(io::IO) = Archive(io)
open_zip(data::Array{UInt8,1}) = Archive(IOBuffer(data, read=true, write=true))
open_zip(filename::AbstractString) = Archive(Base.open(filename, "a+"))
open_zip(f::Function, args...) = with_close(f, open_zip(args...))

with_close(f::Function, io) = try f(io) finally close(io) end


function Base.close(z::Archive)

    # Write out cached files...
    if z.cache_is_active
        z.cache_is_active = false
        for (n,v) in z.cache
            z[n] = v
        end
    end

    # Close reader, writer and io...
    z.reader == nothing || close(z.reader)
    z.writer == nothing || close(z.writer)
    close(z.io)
end


# Read file from ZIP using AbstractDict syntax: data = z[filename].

function Base.get(z::Archive, filename::AbstractString, default=nothing)

    # In read/write mode, read from cache...
    if z.cache_is_active
        return get(z.cache, filename, default)
    end

    # Reading with no Reader!
    # Close the Writer and create a new Reader...
    if z.reader == nothing
        @assert z.writer != nothing
        close(z.writer)
        z.writer = nothing
        seek(z.io,0)
        z.reader = ZipFile.Reader(z.io, false)  
    end

    # Search Reader file list for "filename"...
    for f in z.reader.files
        if f.name == filename
            rewind(f)
            return readfile(f)
        end
    end

    return default
end


function rewind(f::ZipFile.ReadableFile)
    f._datapos = -1
    f._currentcrc32 = 0
    f._pos = 0
    f._zpos = 0
end


# Add files to ZIP using AbstractDict syntax: z[filename] = data.

function Base.setindex!(z::Archive, data, filename::AbstractString)

    # If there is an active reader, then setindex!() is writing to a
    # ZIP Archive that already has content.
    # Load all the existsing content into the cache then close the Reader.
    # The cached content will be written out to the new file later in close().
    if z.reader != nothing
        @assert z.writer == nothing
        z.cache = Dict(collect(z))
        z.cache_is_active = true
        close(z.reader)
        z.reader = nothing
        truncate(z.io, 0)
    end
        
    # In read/write mode, write to the cache...
    if z.cache_is_active
        return setindex!(z.cache, data, filename)
    end

    # Create a writer as needed...
    if z.writer == nothing
        z.writer = ZipFile.Writer(z.io, false)
    end

    # Write "data" for "filename" to Zip Archive...
    with_close(ZipFile.addfile(z.writer, filename, method=ZipFile.Deflate)) do io
        write(io, data)
    end

    # Store "filename" in cache so that keys() always has a full list of
    # the ZIP Archive's content...
    setindex!(z.cache, "", filename)

    return data
end



# Read files from ZIP using iterator syntax.
# The iterator wraps the z.cache iterator. However, unless mixed read/write
# calls have occured, the cache holds only filenames, so get(z, filename) is
# called to read the data from the archive.

Base.eltype(::Type{Archive}) = 
    Tuple{AbstractString,Union{String,Vector{UInt8},AbstractString}}

Base.keys(z::Archive) = keys(z.cache)
Base.length(z::Archive) = length(z.cache)

function Base.iterate(z::Archive, state = nothing)
    i = state == nothing ? iterate(z.cache) :
                           iterate(z.cache, state)
    if i == nothing
        return nothing
    end
    ((filename, data), state) = i
    if basename(filename) == ""
        return iterate(z, state)
    end
    if data == ""
        data = get(z, filename)
    end
    ((filename, data), state)
end


# Read entire file...

function readfile(io::ZipFile.ReadableFile)
     b = read(io)
     return isvalid(String, b)  ? String(b)  : b
end


# Extract ZIP archive to "outputpath".
# Based on fhs/ZipFile.jl#16, thanks @timholy.

function unzip(archive, outputpath::AbstractString=pwd())
    open_zip(archive) do file
        for (filename, data) in file
            filename = joinpath(outputpath, filename)
            mkpath_write(filename, data)
        end
    end
end


# Write "data" to "filename" (creating path as needed).
function mkpath_write(filename::AbstractString, data)
    mkpath(dirname(filename))
    write(filename, data)
end



# Write content of "dict" to "io" in ZIP format.

function create_zip(io::IO, dict::T) where T <: AbstractDict

    open_zip(io) do z
        for (filename, data) in dict
            z[string(filename)] = data
        end
    end
    nothing
end


# Write to ZIP format from (filename, data) tuples.

create_zip(io::IO, files::Array{T}) where T <: Tuple = create_zip(io, files...)


# Write "files" and "data" to ZIP format.

create_zip(io::IO, files::Array, data::Array) = create_zip(io, zip(files, data)...)


# Write to ZIP format from filenames.

function create_zip(io::IO, files::Array)
    create_zip(io::IO, files, map(read, files))
end


# Write to ZIP format from filename => data pairs.

create_zip(io::IO, args...) = create_zip(io::IO, Dict(args))


# Write ZIP Archive to "filename".

function create_zip(filename::AbstractString, args...)
    create_zip(Base.open(filename, "w"), args...)
end


# Use temporary memory buffer if "filename" or "io" are not provided.

function create_zip(arg, args...)

    buf = UInt8[]
    with_close(IOBuffer(buf, read=true, write=true)) do io
        create_zip(io, arg, args...)
    end
    buf
end
