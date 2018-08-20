mutable struct Archive <: AbstractDict{AbstractString,Any}
    filename::AbstractString
    bytes
    keys::Array{AbstractString,1}
    tempdir::AbstractString
    modified::Bool
end


function Archive(filename::AbstractString, bytes=nothing)

    # The command-line "zip" tool exepcts a file extension.
    @assert length(split(basename(filename),".")) > 1

    # Get list of files from archive...
    if isfile(filename)
        keys = [chomp(f) for f in readlines(`unzip -Z1 $filename`)]
        keys = filter(k->basename(k) != "", keys)
    else
        keys = AbstractString[]
    end

    Archive(filename, bytes, keys, mktempdir(), false)
end



# Open ZIP Archive from "filename".

open_zip(filename::AbstractString) = Archive(abspath(filename))
with_close(f::Function, io) = try f(io) finally close(io) end


# Open ZIP Archive from "bytes".

function open_zip(bytes::Array{UInt8,1})

    # Copy "bytes" into temporary .ZIP file...
    if !isempty(bytes)
        tmp, io = mktemp()
        write(io, bytes)
        close(io)
        filename = tmp * ".zip"
        mv(tmp, filename)
    else
        filename = tempname() * ".zip"
    end
    Archive(abspath(filename), bytes)
end


# "open_zip(archive) do..." syntax for exception safety.
open_zip(f::Function, archive) = with_close(f, open_zip(archive))


# Save changes to ZIP Archive.

function Base.close(z::Archive)

    # Add files from tempdir to the archive...
    if !isempty(readdir(z.tempdir))
        run(Cmd(`zip -q -r $(z.filename) .`, dir=z.tempdir))
        z.modified = true
    end

    # Write temporary file back to "bytes" array...
    if z.modified && z.bytes != nothing
        open(z.filename, "r") do io
            readbytes!(io, z.bytes, filesize(z.filename))
        end
        rm(z.filename)
    end

    rm(z.tempdir, recursive=true)
end



# Extract file from archive using AbstractDict syntax: data = z[filename].

function Base.get(z::Archive, filename::AbstractString, default=nothing)

    @assert !occursin(r"^/", filename)

    if !haskey(z, filename)
        return default
    end

    f = joinpath(z.tempdir, filename)
    if isfile(f)
        b = read(f)
    else 
        b = read(`unzip -qc $(z.filename) $filename`)
    end
    return isvalid(String, b)  ? String(b)  : b
end


# Add file to archive using AbstractDict syntax: z[filename] = data.

function Base.setindex!(z::Archive, data, filename::AbstractString)

    @assert !occursin(r"^/", filename)

    # Write file to tempdir...
    mkpath(joinpath(z.tempdir, dirname(filename)))
    write(joinpath(z.tempdir, filename), data)

    # Add filename to "keys"...
    if !(filename in z.keys)
        push!(z.keys, filename)
    end

    return data
end


# Add contents of "dict" to archive.

function Base.merge!(z::Archive, dict::T) where T <: AbstractDict
    for (filename, data) in dict
        z[filename] = data
    end
end



# Read files from ZIP using iterator syntax.

Base.eltype(::Type{Archive}) = 
    Tuple{AbstractString,Union{String,Vector{UInt8},AbstractString}}

Base.keys(z::Archive) =   z.keys
Base.length(z::Archive) = length(z.keys)

function Base.iterate(z::Archive, state = nothing)
    i = state == nothing ? iterate(z.keys) :
                           iterate(z.keys, state)
    if i == nothing
        return nothing
    end
    (filename, state) = i
    return ((filename, get(z, filename)), state)
end



const FileOrBytes = Union{AbstractString,Vector{UInt8}}

# Extract ZIP archive to "outputpath".
# Based on fhs/ZipFile.jl#16, thanks @timholy.

function unzip(archive::FileOrBytes, outputpath::AbstractString=pwd())
    open_zip(archive) do z
        run(Cmd(`unzip -qo $(z.filename)`, dir = outputpath))
    end
end


rm_archive(a::Array{UInt8,1}) = nothing
rm_archive(f::AbstractString) = !isfile(f) || rm(f)

# Create archive from filenames.

function create_zip(archive::FileOrBytes, files::Array)

    rm_archive(archive)
    open_zip(archive) do z
        run(`zip -q $(z.filename) $files`)
        z.modified = true
    end
end


# Create archive from "dict".

function create_zip(archive::FileOrBytes, dict::T) where T <: AbstractDict

    rm_archive(archive)
    open_zip(archive) do z
        for (filename, data) in dict
            z[filename] = data
        end
    end
end


# Create archive from (filename, data) tuples.

create_zip(a::FileOrBytes, files::Array{T}) where T <: Tuple =
    create_zip(a, files...)


# Create archive from "files" and "data".

create_zip(a::FileOrBytes, files::Array, data::Array) = create_zip(a, zip(files, data)...)


# Create archive from filename => data pairs.

create_zip(archive::FileOrBytes, args...) = create_zip(archive, Dict(args))


# Use temporary memory buffer if "filename" or "io" are not provided.

function create_zip(arg, args...)

    buf = UInt8[]
    create_zip(buf, arg, args...)
    return buf
end
