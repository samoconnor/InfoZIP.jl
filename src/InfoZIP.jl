__precompile__()


module InfoZIP

export open_zip, create_zip

using Compat.readstring
using Compat.read
using Compat.write
if VERSION < v"0.5.0-dev+2228"
Base.read(cmd::Cmd) = readbytes(cmd)
end


have_infozip() = haskey(ENV, "HAVE_INFOZIP") || try
    ismatch(r"^UnZip.*by Info-ZIP.", readstring(`unzip`))
catch ex
    if isa(ex, Base.UVError) && ex.code == Base.UV_ENOENT
        return false
    end
    rethrow(ex)
end


if have_infozip()
    include("info_zip.jl")
else
    warn("InfoZIP falling back to ZipFile.jl backend!")
    include("zip_file.jl")
end



end # module
