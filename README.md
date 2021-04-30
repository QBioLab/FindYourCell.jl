# FindYourCell.jl
Cell Segementation and Tracking

We search and filter local maximal in blurred image as seed, then apply 
watershed
algorithm to split individual cell. Nucleus is extracted by Otsu-threshold
in each split region.

## Data Structure
cell_info=[x, y, threshold, cell_size, cell_intensity]

## Compressed tiff
http://www.graphicsmagick.org/api/types.html#compressiontype
http://www.graphicsmagick.org/wand/magick_wand.html#magicksetimagecompression
https://github.com/ImageMagick/ImageMagick/blob/2747ccfc1044fc3da6d32ff1ebbca5e926fcf602/MagickCore/compress.h
https://github.com/ImageMagick/ImageMagick/blob/2747ccfc1044fc3da6d32ff1ebbca5e926fcf602/Magick%2B%2B/lib/Magick%2B%2B/Include.h
Why enum number are wrong?

```julia
# hack ImageMagick
function writeimage(wand::MagickWand, filename::AbstractString)
    setimagecompression(wand, 13) # lzw compression
    status = ccall((:MagickWriteImages, libwand), Cint, (Ptr{Cvoid}, Ptr{UInt8}, Cint), wand, filename, true)
    status == 0 && error(wand)
    nothing
end
```
