local M = {}

local DIRECTIONS = {
    left = { dc = -1, dr = 0 },
    right = { dc = 1, dr = 0 },
    up = { dc = 0, dr = -1 },
    down = { dc = 0, dr = 1 },
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function contains(values, wanted)
    for _, value in ipairs(values or {}) do
        if value == wanted then
            return true
        end
    end
    return false
end

local function position_key(col, row)
    return tostring(col) .. ":" .. tostring(row)
end

local function occupied_positions(state, except_id)
    local occupied = {}
    for id, position in pairs(state.positions) do
        if id ~= except_id then
            occupied[position_key(position.col, position.row)] = id
        end
    end
    return occupied
end

local function find_open_right(state, anchor)
    local occupied = occupied_positions(state)
    local col = anchor.col + 1
    while occupied[position_key(col, anchor.row)] do
        col = col + 1
    end
    return { col = col, row = anchor.row }
end

local function first_id(state)
    return state.ids[1]
end

function M.new_state()
    return {
        ids = {},
        positions = {},
        width_step_by_id = {},
        height_step_by_id = {},
        align_x_by_id = {},
        align_y_by_id = {},
        zoom_step = nil,
        overview = false,
        focused_id = nil,
        observed_active_id = nil,
        camera = { col = 0, row = 0 },
    }
end

-- Groups are layout cells, not compositor tab groups. Slots preserve insertion
-- order even when Hyprland changes the order of its target list.
function M.members(state, id)
    local origin = state.positions[id]
    local members = {}
    if not origin then return members end
    for other, pos in pairs(state.positions) do
        if pos.col == origin.col and pos.row == origin.row then members[#members + 1] = other end
    end
    table.sort(members, function(a, b)
        local sa, sb = state.positions[a].slot or 1, state.positions[b].slot or 1
        if sa ~= sb then return sa < sb end
        return tostring(a) < tostring(b)
    end)
    return members
end

function M.part(state, id, members)
    members = members or M.members(state, id)
    local index = 1
    for i, member in ipairs(members) do if member == id then index = i end end
    local parts = {
        [1] = { {0, 0, 1, 1} },
        [2] = { {0, 0, .5, 1}, {.5, 0, .5, 1} },
        [3] = { {0, 0, .5, 1}, {.5, 0, .5, .5}, {.5, .5, .5, .5} },
        [4] = { {0, 0, .5, .5}, {.5, 0, .5, .5}, {.5, .5, .5, .5}, {0, .5, .5, .5} },
    }
    local p = (parts[#members] or parts[1])[index] or parts[1][1]
    return { x = p[1], y = p[2], w = p[3], h = p[4], index = index, count = #members }
end

function M.sync(state, ids, active_id, config)
    if not state.zoom_step then state.zoom_step = config.default_zoom_step or 1 end

    local present = {}
    local unique_ids = {}

    for _, id in ipairs(ids or {}) do
        if not present[id] then
            present[id] = true
            table.insert(unique_ids, id)
        end
    end

    for id in pairs(state.positions) do
        if not present[id] then
            state.positions[id] = nil
            state.width_step_by_id[id] = nil
            state.height_step_by_id[id] = nil
            state.align_x_by_id[id] = nil
            state.align_y_by_id[id] = nil
        end
    end

    state.ids = unique_ids

    for _, id in ipairs(unique_ids) do
        if not state.positions[id] then
            local anchor_id = active_id and state.positions[active_id] and active_id
                or state.focused_id and state.positions[state.focused_id] and state.focused_id
                or first_id(state)
            local anchor = anchor_id and state.positions[anchor_id]

            if anchor then
                state.positions[id] = find_open_right(state, anchor)
            else
                state.positions[id] = { col = 0, row = 0 }
            end

            state.width_step_by_id[id] = config.default_width_step
            state.height_step_by_id[id] = config.default_height_step
        end
    end

    local focus_changed = false
    if (state.overview or state.pending_focus_id) and present[state.focused_id] then
        -- An exclusive overview layer keeps the compositor's old active
        -- window. It must not overwrite the user's overview selection.
    elseif active_id and present[active_id] then
        focus_changed = state.observed_active_id ~= active_id
        state.observed_active_id = active_id
        state.focused_id = active_id
    elseif not state.focused_id or not present[state.focused_id] then
        state.focused_id = unique_ids[1]
        state.observed_active_id = state.focused_id
        focus_changed = state.focused_id ~= nil
    end
    if state.pending_focus_id and not present[state.pending_focus_id] then
        state.pending_focus_id = state.focused_id
    end

    if focus_changed and not state.defer_active_camera and state.focused_id and state.positions[state.focused_id] then
        local focused = state.positions[state.focused_id]
        state.camera.col = focused.col
        state.camera.row = focused.row
    end
end

function M.observe_focus(state, id)
    if not id or not state.positions[id] then return end
    state.observed_active_id = id
    state.focused_id = id
end

local function directional_metrics(origin, candidate, direction)
    local dc = candidate.col - origin.col
    local dr = candidate.row - origin.row

    if direction == "left" and dc >= 0 then return nil end
    if direction == "right" and dc <= 0 then return nil end
    if direction == "up" and dr >= 0 then return nil end
    if direction == "down" and dr <= 0 then return nil end

    local along = (direction == "left" or direction == "right") and math.abs(dc) or math.abs(dr)
    local across = (direction == "left" or direction == "right") and math.abs(dr) or math.abs(dc)

    return {
        aligned = across == 0 and 0 or 1,
        across = across,
        along = along,
        distance = math.abs(dc) + math.abs(dr),
    }
end

local function metrics_less(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.aligned ~= b.aligned then return a.aligned < b.aligned end
    if a.across ~= b.across then return a.across < b.across end
    if a.along ~= b.along then return a.along < b.along end
    if a.distance ~= b.distance then return a.distance < b.distance end
    return tostring(a.id) < tostring(b.id)
end

function M.focus(state, direction)
    if not DIRECTIONS[direction] or not state.focused_id then
        return nil
    end

    local function center(id)
        local position = state.positions[id]
        if not position then return nil end
        local part = M.part(state, id)
        return { col = position.col + (part.x + part.w / 2 - .5) * .8,
            row = position.row + (part.y + part.h / 2 - .5) * .8 }
    end
    local origin = center(state.focused_id)
    if not origin then return nil end

    local candidates = {}
    for id, position in pairs(state.positions) do
        if id ~= state.focused_id then
            local metrics = directional_metrics(origin, center(id), direction)
            if metrics then
                local from = state.positions[state.focused_id]
                metrics.group = position.col == from.col and position.row == from.row and 0 or 1
                metrics.id = id
                table.insert(candidates, metrics)
            end
        end
    end

    table.sort(candidates, metrics_less)
    local target = candidates[1]
    if not target then return nil end

    return target.id
end

-- Connect occupied cells without merging groups or changing their internal slots.
function M.compact(state)
    local cells, by_key = {}, {}
    for _, id in ipairs(state.ids) do
        local p = state.positions[id]
        local key = position_key(p.col, p.row)
        if not by_key[key] then
            local cell = {col=p.col, row=p.row, ids={}}
            by_key[key]=cell
            cells[#cells+1]=cell
        end
        table.insert(by_key[key].ids,id)
    end
    local directions = {{1,0},{0,1},{-1,0},{0,-1}}
    local seen, largest = {}, {}
    for _, cell in ipairs(cells) do
        if not seen[cell] then
            local component = {cell}; seen[cell]=true
            local i=1
            while i<=#component do
                local c=component[i]; i=i+1
                for _, d in ipairs(directions) do
                    local neighbor=by_key[position_key(c.col+d[1],c.row+d[2])]
                    if neighbor and not seen[neighbor] then
                        seen[neighbor]=true; component[#component+1]=neighbor
                    end
                end
            end
            if #component>#largest then largest=component end
        end
    end
    local connected={}
    for _, cell in ipairs(largest) do connected[cell]=true end
    while #largest<#cells do
        -- Absorb any cells already sharing an edge with the growing layout.
        local i=1
        while i<=#largest do
            local c=largest[i]; i=i+1
            for _, d in ipairs(directions) do
                local neighbor=by_key[position_key(c.col+d[1],c.row+d[2])]
                if neighbor and not connected[neighbor] then
                    connected[neighbor]=true; largest[#largest+1]=neighbor
                end
            end
        end
        local best
        for _, cell in ipairs(cells) do
            if not connected[cell] then
                for _, anchor in ipairs(largest) do
                    for _, d in ipairs(directions) do
                        local col,row=anchor.col+d[1],anchor.row+d[2]
                        local distance=(col-cell.col)^2+(row-cell.row)^2
                        if not by_key[position_key(col,row)] and (not best or distance<best.distance) then
                            best={cell=cell,col=col,row=row,distance=distance}
                        end
                    end
                end
            end
        end
        if not best then break end
        local c=best.cell
        by_key[position_key(c.col,c.row)]=nil
        c.col,c.row=best.col,best.row
        by_key[position_key(c.col,c.row)]=c
        for _, id in ipairs(c.ids) do state.positions[id].col,state.positions[id].row=c.col,c.row end
        connected[c]=true; largest[#largest+1]=c
    end
end

function M.move_to(state, destination_col, destination_row)
    local focused_id = state.focused_id
    local focused = focused_id and state.positions[focused_id]
    if not focused or destination_col % 1 ~= 0 or destination_row % 1 ~= 0 then return false end
    if focused.col == destination_col and focused.row == destination_row then return false end
    local destination_id = occupied_positions(state, focused_id)[position_key(destination_col, destination_row)]

    if destination_id then
        local destination = M.members(state, destination_id)
        if #destination < 4 then
            local anchor = destination[1]
            for i, id in ipairs(destination) do state.positions[id].slot = i end
            focused.col, focused.row, focused.slot = destination_col, destination_row, #destination + 1
            for _, map in ipairs({state.width_step_by_id, state.height_step_by_id, state.align_x_by_id, state.align_y_by_id}) do
                map[focused_id] = map[anchor]
            end
        else
            -- A full target swaps with the entire source cell. This also
            -- preserves both groups when moving a member of another group.
            local source = M.members(state, focused_id)
            local col, row = focused.col, focused.row
            for _, id in ipairs(destination) do state.positions[id].col, state.positions[id].row = col, row end
            for _, id in ipairs(source) do state.positions[id].col, state.positions[id].row = destination_col, destination_row end
        end
    else
        focused.col = destination_col
        focused.row = destination_row
        focused.slot = 1
    end

    if state.on_move then state.on_move()
    elseif state.keep_connected then M.compact(state) end
    M.follow(state)
    return true
end

function M.swap_members(state, first, second)
    local a, b = state.positions[first], state.positions[second]
    if first == second or not a or not b or a.col ~= b.col or a.row ~= b.row then return false end
    -- Normalize slots first, including groups whose previous members closed.
    for i, id in ipairs(M.members(state, first)) do state.positions[id].slot = i end
    a.slot, b.slot = b.slot, a.slot
    if state.on_move then state.on_move() end
    return true
end

function M.move(state, direction)
    local vector = DIRECTIONS[direction]
    local focused = state.positions[state.focused_id]
    if not vector or not focused then return false end
    local neighbor = M.focus(state, direction)
    if neighbor and M.swap_members(state, state.focused_id, neighbor) then return true end
    return M.move_to(state, focused.col + vector.dc, focused.row + vector.dr)
end

function M.follow(state)
    local focused = state.focused_id and state.positions[state.focused_id]
    if not focused then return false end
    state.camera.col = focused.col
    state.camera.row = focused.row
    state.camera.x, state.camera.y = 0, 0
    return true
end

function M.pan(state, direction)
    local vector = DIRECTIONS[direction]
    if not vector then return false end
    state.camera.col = state.camera.col + vector.dc
    state.camera.row = state.camera.row + vector.dr
    return true
end

local function resize_step(state, map, steps, delta)
    local id = state.focused_id
    if not id or not state.positions[id] then return false end
    local current = map[id] or #steps
    local next_step = clamp(current + delta, 1, #steps)
    for _, member in ipairs(M.members(state, id)) do map[member] = next_step end
    return next_step ~= current
end

function M.resize_width(state, config, delta)
    return resize_step(state, state.width_step_by_id, config.width_steps, delta)
end

function M.resize_height(state, config, delta)
    return resize_step(state, state.height_step_by_id, config.height_steps, delta)
end

function M.resize_direction(state, config, direction)
    local id = state.focused_id
    if not id or not state.positions[id] then return false end

    if direction == "right" then
        state.align_x_by_id[id] = -1
        M.resize_width(state, config, 1)
    elseif direction == "down" then
        state.align_y_by_id[id] = -1
        M.resize_height(state, config, 1)
    elseif direction == "left" then
        state.align_x_by_id[id] = 1
        M.resize_width(state, config, -1)
    elseif direction == "up" then
        state.align_y_by_id[id] = 1
        M.resize_height(state, config, -1)
    else
        return false
    end
    for _, member in ipairs(M.members(state, id)) do
        state.align_x_by_id[member] = state.align_x_by_id[id]
        state.align_y_by_id[member] = state.align_y_by_id[id]
    end
    return true
end

function M.zoom(state, config, delta)
    local steps = config.zoom_steps or { 1 }
    local current = clamp(state.zoom_step or config.default_zoom_step or 1, 1, #steps)
    if state.zoom_value then
        local value = state.zoom_value
        current = delta > 0 and #steps or 1
        if delta > 0 then
            for i, step in ipairs(steps) do if step > value+0.0001 then current=i-1; break end end
        else
            for i=#steps,1,-1 do if steps[i] < value-0.0001 then current=i+1; break end end
        end
        state.zoom_value, state.zoom_target, state.zoom_overview = nil, nil, nil
    end
    if state.overview then
        if delta > 0 then state.overview = false; state.zoom_step = 1; return true end
        return false
    end
    if current == 1 and delta < 0 then state.overview = true; return true end
    state.zoom_step = clamp(current + delta, 1, #steps)
    return state.zoom_step ~= current
end

function M.zoom_value(state, config)
    return state.zoom_value or config.zoom_steps[state.zoom_step or config.default_zoom_step]
end

function M.wheel_zoom(state, config, direction)
    local low, high = config.zoom_steps[1], config.zoom_steps[#config.zoom_steps]
    if state.overview then
        if direction < 0 then return false end
        state.overview, state.zoom_value, state.zoom_target = false, low, low
        state.zoom_overview = nil
        return true
    end
    state.zoom_value = M.zoom_value(state, config)
    local target = state.zoom_target or state.zoom_value
    state.zoom_overview = direction < 0 and target <= low+0.0001 or nil
    state.zoom_target = clamp(target * (1.08 ^ direction), low, high)
    return true
end

function M.advance_zoom(state)
    if not state.zoom_target then return false end
    local difference = state.zoom_target-state.zoom_value
    if math.abs(difference) < 0.0005 then
        state.zoom_value = state.zoom_target
        state.zoom_target = nil
        if state.zoom_overview then state.overview = true end
        state.zoom_overview = nil
        return false
    end
    state.zoom_value = state.zoom_value+difference*0.25
    return true
end

function M.toggle_maximize(state, config)
    local id = state.focused_id
    if not id or not state.positions[id] then return false end

    local width = state.width_step_by_id[id] or config.default_width_step
    local height = state.height_step_by_id[id] or config.default_height_step
    if width == #config.width_steps and height == #config.height_steps then
        state.width_step_by_id[id] = config.default_width_step
        state.height_step_by_id[id] = config.default_height_step
    else
        state.width_step_by_id[id] = #config.width_steps
        state.height_step_by_id[id] = #config.height_steps
    end
    state.align_x_by_id[id] = 0
    state.align_y_by_id[id] = 0
    for _, member in ipairs(M.members(state, id)) do
        state.width_step_by_id[member] = state.width_step_by_id[id]
        state.height_step_by_id[member] = state.height_step_by_id[id]
        state.align_x_by_id[member], state.align_y_by_id[member] = 0, 0
    end
    return true
end

function M.placements(state, area, config)
    -- Build membership once per placement pass instead of scanning all windows
    -- for every dimension, alignment, partition and preview card.
    local groups, members_by_id, parts = {}, {}, {}
    for id, position in pairs(state.positions) do
        local key=position_key(position.col,position.row)
        groups[key]=groups[key] or {}
        table.insert(groups[key],id)
    end
    for _, members in pairs(groups) do
        table.sort(members,function(a,b)
            local sa,sb=state.positions[a].slot or 1,state.positions[b].slot or 1
            if sa~=sb then return sa<sb end
            return tostring(a)<tostring(b)
        end)
        for _, id in ipairs(members) do
            members_by_id[id]=members
            parts[id]=M.part(state,id,members)
        end
    end
    local peek_x = clamp(config.peek_x or 0, 0, math.max(0, (area.w - 1) / 2))
    local peek_y = clamp(config.peek_y or 0, 0, math.max(0, (area.h - 1) / 2))
    local maximum_width = math.max(1, area.w - (peek_x * 2))
    local maximum_height = math.max(1, area.h - (peek_y * 2))
    local gap_x = math.max(0, config.gap_x or 0)
    local gap_y = math.max(0, config.gap_y or 0)
    local zoom_steps = config.zoom_steps or { 1 }
    local zoom = M.zoom_value(state, config)
    local max_zoom_margin = math.max(0, config.max_zoom_margin or 0)
    local default_width_at_one = maximum_width * config.width_steps[config.default_width_step]
    local default_height_at_one = maximum_height * config.height_steps[config.default_height_step]
    local max_zoom = math.min(
        (area.w - max_zoom_margin * 2) / default_width_at_one,
        (area.h - max_zoom_margin * 2) / default_height_at_one
    )
    zoom = math.min(zoom, math.max(1, max_zoom))
    gap_x = gap_x * zoom
    gap_y = gap_y * zoom
    local center_x = area.x + (area.w / 2) + (state.camera.x or 0)
    local center_y = area.y + (area.h / 2) + (state.camera.y or 0)
    local placements = {}
    local dimensions = {}
    local column_widths = {}
    local row_heights = {}
    local min_col, max_col = state.camera.col, state.camera.col
    local min_row, max_row = state.camera.row, state.camera.row

    for id, position in pairs(state.positions) do
        local anchor = members_by_id[id][1]
        local width_step = clamp(state.width_step_by_id[anchor] or config.default_width_step, 1, #config.width_steps)
        local height_step = clamp(state.height_step_by_id[anchor] or config.default_height_step, 1, #config.height_steps)
        local width = maximum_width * config.width_steps[width_step] * zoom
        local height = maximum_height * config.height_steps[height_step] * zoom

        dimensions[id] = { w = width, h = height }
        column_widths[position.col] = math.max(column_widths[position.col] or 0, width)
        row_heights[position.row] = math.max(row_heights[position.row] or 0, height)
        min_col = math.min(min_col, position.col)
        max_col = math.max(max_col, position.col)
        min_row = math.min(min_row, position.row)
        max_row = math.max(max_row, position.row)
    end

    local default_width = maximum_width * config.width_steps[config.default_width_step] * zoom
    local default_height = maximum_height * config.height_steps[config.default_height_step] * zoom
    for col = min_col, max_col do
        column_widths[col] = column_widths[col] or default_width
    end
    for row = min_row, max_row do
        row_heights[row] = row_heights[row] or default_height
    end

    local column_centers = { [state.camera.col] = center_x }
    for col = state.camera.col + 1, max_col do
        column_centers[col] = column_centers[col - 1]
            + (column_widths[col - 1] / 2) + gap_x + (column_widths[col] / 2)
    end
    for col = state.camera.col - 1, min_col, -1 do
        column_centers[col] = column_centers[col + 1]
            - (column_widths[col + 1] / 2) - gap_x - (column_widths[col] / 2)
    end

    local row_centers = { [state.camera.row] = center_y }
    for row = state.camera.row + 1, max_row do
        row_centers[row] = row_centers[row - 1]
            + (row_heights[row - 1] / 2) + gap_y + (row_heights[row] / 2)
    end
    for row = state.camera.row - 1, min_row, -1 do
        row_centers[row] = row_centers[row + 1]
            - (row_heights[row + 1] / 2) - gap_y - (row_heights[row] / 2)
    end

    for id, position in pairs(state.positions) do
        local size = dimensions[id]
        local anchor = members_by_id[id][1]
        local align_x = state.align_x_by_id[anchor] or 0
        local align_y = state.align_y_by_id[anchor] or 0
        local cell_width = column_widths[position.col]
        local cell_height = row_heights[position.row]

        placements[id] = {
            x = column_centers[position.col] - (size.w / 2) + align_x * (cell_width - size.w) / 2,
            y = row_centers[position.row] - (size.h / 2) + align_y * (cell_height - size.h) / 2,
            w = size.w,
            h = size.h,
        }
        local box, part = placements[id], parts[id]
        local inner_x, inner_y = math.min(gap_x, box.w / 4), math.min(gap_y, box.h / 4)
        local left = part.x > 0 and inner_x / 2 or 0
        local right = part.x + part.w < 1 and inner_x / 2 or 0
        local top = part.y > 0 and inner_y / 2 or 0
        local bottom = part.y + part.h < 1 and inner_y / 2 or 0
        box.x, box.y = box.x + part.x * box.w + left, box.y + part.y * box.h + top
        box.w, box.h = math.max(1, box.w * part.w - left - right), math.max(1, box.h * part.h - top - bottom)
    end

    return placements, {columns = column_centers, rows = row_centers,
        widths = column_widths, heights = row_heights, gapX = gap_x, gapY = gap_y,
        defaultWidth = default_width, defaultHeight = default_height}, parts
end

function M.position_of(state, id)
    return state.positions[id]
end

function M.size_steps_of(state, id)
    return state.width_step_by_id[id], state.height_step_by_id[id]
end

function M.has_id(state, id)
    return contains(state.ids, id)
end

return M
