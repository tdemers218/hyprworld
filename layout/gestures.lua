-- Geometry shared by pointer dragging and its drop preview. No compositor I/O.
local M = {}
local function contains(b, x, y)
    return x >= b.x and y >= b.y and x <= b.x+b.w and y <= b.y+b.h
end
function M.hit(tiles, x, y)
    for _, tile in ipairs(tiles) do
        if contains(tile.box, x, y) then return tile end
    end
end
local function nearest(centers, sizes, default, gap, value)
    local first, last, best, distance
    for index, center in pairs(centers) do
        first, last = math.min(first or index, index), math.max(last or index, index)
        if not distance or math.abs(value-center) < distance then
            best, distance = index, math.abs(value-center)
        end
    end
    if not best then return 0, value, default end
    for _, sign in ipairs({-1, 1}) do
        local edge = sign == -1 and first or last
        local nextCenter = centers[edge] + sign*((sizes[edge]+default)/2+gap)
        local steps = math.max(0, math.floor(sign*(value-nextCenter)/(default+gap)+0.5))
        local candidate = nextCenter + sign*steps*(default+gap)
        if math.abs(value-candidate) < distance then
            best, distance = edge+sign*(steps+1), math.abs(value-candidate)
        end
    end
    if centers[best] then return best, centers[best], sizes[best] end
    local edge, sign = best < first and first or last, best < first and -1 or 1
    return best, centers[edge]+sign*((sizes[edge]+default)/2+gap+(math.abs(best-edge)-1)*(default+gap)), default
end
function M.destination(tiles, grid, source, x, y)
    local hit = M.hit(tiles, x, y)
    if hit then
        if hit.col == source.col and hit.row == source.row then
            if hit.address == source.address then return nil end
            return {col=hit.col,row=hit.row,box=hit.box,swapAddress=hit.address,label="Swap positions in group"}
        end
        local count = hit.part and hit.part.count or 1
        return {col=hit.col, row=hit.row, box=hit.box,
            label=count == 4 and "Swap full group" or count == 1 and "Create group · 2 windows" or "Add to group · " .. (count+1) .. " windows"}
    end
    local col, cx, w = nearest(grid.columns, grid.widths, grid.defaultWidth, grid.gapX, x)
    local row, cy, h = nearest(grid.rows, grid.heights, grid.defaultHeight, grid.gapY, y)
    if math.abs(col)>10000 or math.abs(row)>10000 then return nil end
    -- Gaps around occupied tiles are not grouping targets.
    for _, tile in ipairs(tiles) do if tile.col == col and tile.row == row then return nil end end
    return {col=col,row=row,box={x=cx-w/2,y=cy-h/2,w=w,h=h},label="Move here"}
end
return M
