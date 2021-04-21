using Images
using ImageSegmentation

"""
TODO: LoG with threshold or Gaussian with minima?
"""
function watershedborder(watershed_segments)
    marker_border = BitArray(undef, size(watershed_segments.image_indexmap));
    marker_border .= false
    for label in watershed_segments.segment_labels
        marker_border .|= ((watershed_segments.image_indexmap.==label)
            .⊻ erode(watershed_segments.image_indexmap .==label));
    end
    marker_border;
end

function locate_cell(_img)
    _img_gaussian = imfilter( _img, Kernel.gaussian(12))
    # Extract local minima as watershed markers
    _img_center = Int.(local_minima(opening(closing( .- _img_gaussian ))))
    # remove wrong local minima
    estimated_th = otsu_threshold(_img_gaussian)
    @inbounds for i in eachindex(_img_center)
        now = _img_center[i] 
        if now > 0 
            # remove point which darker than estimated threshold
            if  _img_gaussian[i] < estimated_th
                _img_center[i] = 0
            else
                _img_center[i] = 1
            end
        end
    end
    _img_center = label_components(_img_center)
    # Use watershed to split each cell
    # _img_region= watershed( 1 .- imfilter(_img, Kernel.gaussian(5)), _img_center)
    return _img_center #, labels_map(_img_region)
end

function pickup_cell(_img, _img_center)#, _img_watershed)
    width = 100
    x_len, y_len = size(_img)
    ##!! x length and y length
    mask = zeros(UInt16, size(_img))
    cell_center = component_centroids(_img_center)
    cell_num = length(cell_center) - 1
    cell_info = zeros(cell_num, 5) # [threshold  size intensity]
    #TODO: relabel mask map & only keep one connected component
    @inbounds for cell in 1:cell_num
        #print(cell , " ")
        if (width < cell_center[cell+1][1] < x_len-width) && 
                (width < cell_center[cell+1][2] < y_len-width)
            x0 = Int(floor(cell_center[cell + 1][1] - width/2 + 1))
            y0 = Int(floor(cell_center[cell + 1][2] - width/2 + 1))
            x1 = Int(floor(cell_center[cell + 1][1] + width/2 - 1))
            y1 = Int(floor(cell_center[cell + 1][2] + width/2 - 1)) 
            #println(x0, " ", y0, " ",x1, " ", y1)
            cell_raw = _img[x0:x1, y0:y1]
            mask[x0:x1, y0:y1] = cell_raw .> otsu_threshold(cell_raw)
        end
    end
    region_mask = label_components(mask)
    region_boxes = component_boxes(region_mask)
    region_num = length(region_boxes) - 1
    for region in 1:region_num
        x0, y0 = region_boxes[region+1][1]
        x1, y1 = region_boxes[region+1][2]
        cell_list = []
        for cell in 1:cell_num
            x_now, y_now = cell_center[cell+1]
            if x0<=x_now<=x1 && y0<=y_now<=y1
                push!(cell_list, cell)
            end
        end

        cell_raw = view(_img, x0:x1, y0:y1)
        cell_mask = view(mask, x0:x1, y0:y1)
        if length(cell_list) > 1
            cell_label = view(_img_center, x0:x1, y0:y1)
            region_watershed = labels_map(watershed(1 .- cell_raw, cell_label))
            for idx in eachindex(cell_mask)
                if cell_mask[idx] > 0
                    cell_mask[idx] = region_watershed[idx]
                end
            end
        elseif length(cell_list) == 1
            for idx in eachindex(cell_mask)
                if cell_mask[idx] > 0
                    cell_mask[idx] = cell_list[1]
                end
            end
        else
            #println("no cell found here")
        end
        # save cell location
        for cell in cell_list
            cell_info[cell, 1:2] .= cell_center[cell+1]
        end
    end
    return mask, cell_info
end


function find_your_cell(img)
    img_center = locate_cell(img)         
    cell_mask, cell_info = pickup_cell(img, img_center)
    return cell_mask, cell_info
end
