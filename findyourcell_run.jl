using FileIO
using TiffImages
using MAT
include("findyourcell.jl")

#data_dir = ARGS[1]
#data_dir = "../2021032423-preprocess"
data_dir = "../0417-22-processed-stack-noRball/2021041720-preprocess"
#ret_dir = ARGS[2]
ret_dir = "../0417-22-processed-stack-noRball/result"

file_list = filter(x->occursin(r"G-stack.tiff$", x), readdir( data_dir))

#for i in length(file_list):-1:parse(Int, ARGS[1])
for i in parse(Int, ARGS[1]):2:parse(Int, ARGS[2]) #length(file_list)
    print(i)
    #img = load("$data_dir/$(file_list[i])")
    print("$data_dir/$(file_list[i])")
    img = TiffImages.load("$data_dir/$(file_list[i])")
    t_len = size(img, 3)
    cell_mask = Array{UInt16}(undef, size(img))
    cell_info = Array{Any}(undef, t_len)
    @time @inbounds Threads.@threads for t in 1:t_len
        print("*")
        cell_mask[:, :, t], cell_info[t] = find_your_cell(img[:, :, t])
    end
    println("")
    TiffImages.save(mask_name, reinterpret(Gray{N0f16}, new_mask))
    matwrite("$ret_dir/$(file_list[i][1:end-4])_info.mat", Dict("info"=>cell_info))
end
