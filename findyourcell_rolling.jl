using FileIO
using TiffImages
using MAT
using Dates
using ProgressMeter
include("findyourcell.jl")
"""
Rolling cell segmentation during capturing
v0.1.0 hf 04202021

"""

DATA_DIR = "../0417-22-processed-stack-noRball/2021041720-preprocess"
RET_DIR = "../0417-22-processed-stack-noRball/result"

stack_list= filter(x->occursin(r"G-stack.tiff$", x), readdir(DATA_DIR))
unfinished = true
while unfinished
    for idx in 1:length(stack_list)
        raw_name = stack_list[idx]
        if time() - stat("$DATA_DIR/$raw_name").mtime > 180 # be careful 
            img = try
                load("$DATA_DIR/$raw_name")#, mmap=true)
				#TiffImages.load("$DATA_DIR/$raw_name")#, mmap=true)
            catch e
                @warn "Failed to load $raw_name, skip to next stack"
                continue #TODO: or wait util tiff is free to read
            end
            mask_name = "$RET_DIR/$(raw_name[1:end-4])_mask.tiff"
            info_name = "$RET_DIR/$(raw_name[1:end-4])_info.mat"
            raw_frame_num = size(img, 3)
	    	if isfile(info_name) #TODO: && time() - stat(info_name).mtime > 400
	            prev_info = matread(info_name)["info"]           
	            prev_frame_num = length(prev_info)
            	append_num = raw_frame_num - prev_frame_num
	            # only process the new coming frames
	            if append_num > 0
	                println("Appending $raw_name:$(prev_frame_num+1) $raw_frame_num, $(Dates.now())")
	                prev_mask = try
	                    reinterpret(UInt16, TiffImages.load(mask_name))
	                catch
	                    @warn "Failed to load mask $mask_name, skip to next stack"
	                    continue 	                
					end
	                mask_patch = Array{UInt16}(undef, size(img, 1), size(img,2), append_num)
	                new_mask = cat(prev_mask, mask_patch, dims=3)
	                info_patch = Array{Any}(undef, append_num)
	                new_info = cat(prev_info, info_patch, dims=1)
					p = Progress(append_num, 1, "Appending")
	                @time Threads.@threads for t in prev_frame_num+1:raw_frame_num
	                    #print("*")
	                    new_mask[:, :, t], new_info[t] = find_your_cell(img[:, :, t])
						next!(p)
	                end
				else
					continue
				end
			else  # start from 0
	            println("Processing $raw_name: 1:$raw_frame_num, $(Dates.now())")
    			new_mask = Array{UInt16}(undef, size(img))
    			new_info = Array{Any}(undef, raw_frame_num)
				slices_num = Threads.nthreads() - 2
				p = Progress(raw_frame_num, 1, "Processing")
				@time for t_start in 1:slices_num:raw_frame_num
					t_end = t_start + slices_num - 1
					if t_end > raw_frame_num
						t_end = raw_frame_num
					end
    				Threads.@threads for t in t_start:t_end
        				#print("*")
        				new_mask[:, :, t], new_info[t] = find_your_cell(img[:, :, t])
						next!(p)
    				end
				end
			end
			println("Writing")
			#save(mask_name, new_mask) 
			TiffImages.save(mask_name, reinterpret(Gray{N0f16}, new_mask))
	        matwrite(info_name, Dict("info"=>new_info))
	        println("Done! $(Dates.now())")
			GC.gc()
        end
    end
    sleep(1)   
end
