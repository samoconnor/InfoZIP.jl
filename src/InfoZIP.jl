__precompile__()


module InfoZIP

export open_zip, create_zip

using Compat.readstring
using Compat.read
using Compat.write
if VERSION < v"0.5.0-dev+2228"
Base.read(cmd::Cmd) = readbytes(cmd)
end


have_infozip = false
try
    if ismatch(r"^UnZip.*by Info-ZIP.", readstring(`unzip`))
        have_infozip = true
    end
catch
end


if have_infozip
    include("info_zip.jl")
else
    include("zip_file.jl")
end



end # module
