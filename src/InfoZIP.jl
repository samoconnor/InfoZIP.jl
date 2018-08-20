module InfoZIP

export open_zip, create_zip


have_infozip() = haskey(ENV, "HAVE_INFOZIP") || try
    occursin(r"^Copyright.* Info-ZIP", read(`zip -h`, String)) &&
    occursin(r"^UnZip.*by Info-ZIP", read(`unzip -h`, String))
catch ex
    if ex isa Base.IOError ex.code == Base.UV_ENOENT
        return false
    end
    rethrow(ex)
end


if have_infozip()
    include("info_zip.jl")
else
    @warn "InfoZIP falling back to ZipFile.jl backend!"
    include("zip_file.jl")
end



end # module
