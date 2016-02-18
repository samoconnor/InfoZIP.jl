__precompile__()


module InfoZIP

export open_zip, create_zip


have_infozip = false
try
    if ismatch(r"^UnZip.*by Info-ZIP.", readall(`unzip`))
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
