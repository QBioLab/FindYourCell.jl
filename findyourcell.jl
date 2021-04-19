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
    _img_region= watershed( 1 .- imfilter(_img, Kernel.gaussian(5)), _img_center)
    return _img_center, labels_map(_img_region)
end

function pickup_cell(_img, _img_center, _img_watershed)
    width = 100
    x_len, y_len = size(_img)
    mask = zeros(UInt16, size(_img))
    cell_num = maximum(_img_center)
    cell_info = zeros(cell_num, 5) # [threshold  size intensity]
    cell_center = component_centroids(_img_center)
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
            cell_raw = view(_img, x0:x1, y0:y1)
            cell_watershed_mask = view(_img_watershed, x0:x1, y0:y1) .== cell
            #TODO: check mask size to avoid single point mask
            cell_single = cell_raw[cell_watershed_mask]
            if length(cell_single) > 441 # check size > 21*21=441
                cell_info[cell, 1] = (x0+x1)/2
                cell_info[cell, 2] = (y0+y1)/2
                cell_info[cell, 3] = otsu_threshold(cell_single)
                cell_mask = view(mask, x0:x1, y0:y1)
                cell_size = 0; 
                cell_intensity = 0;
                @inbounds for j in eachindex( cell_raw )
                    if cell_watershed_mask[j] && cell_raw[j] > 
			    cell_info[cell, 3]
                        cell_mask[j] = cell # assign label to pixel
                        cell_size = cell_size + 1
                        cell_intensity = cell_intensity + cell_raw[j]
                    end
                end
                cell_info[cell, 4] = cell_size
                cell_info[cell, 5] = cell_intensity#/cell_size
            else
            #println("Ignore cell which contacte edge")
            end
        end
    end
    return mask, cell_info
end


function find_your_cell(img)
    img_center, img_region = locate_cell(img)         
    cell_mask, cell_info = pickup_cell(img, img_center, img_region)
    return cell_mask, cell_info
end
