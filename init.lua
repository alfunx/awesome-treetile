
--[[

     Licensed under GNU General Public License v2
      * (c) 2019, Alphonse Mariyagnanaseelan



    treetile: Binary Tree-based tiling layout for Awesome 3

    URL:     https://github.com/alfunx/treetile
    Fork of: https://github.com/RobSis/treesome
             https://github.com/guotsuan/treetile



    Because the the split of space is depending on the parent node, which is
    current focused client.  Therefore it is necessary to set the correct
    focus option, "treetile.focusnew".

    If the new created client will automatically gain the focus, for exmaple
    in rc.lua with the settings:

    ...
    awful.rules.rules = {
        { rule = { },
          properties = { focus = awful.client.focus.filter,
    ...

    You need to set "treetile.focusnew = true"
    Otherwise, set "treetile.focusnew = false"

--]]

local awful        = require("awful")
local beautiful    = require("beautiful")
local debug        = require("gears.debug")
local naughty      = require("naughty")

local bintree      = require("treetile/bintree")
local os           = os
local math         = math
local ipairs       = ipairs
local pairs        = pairs
local table        = table
local tonumber     = tonumber
local tostring     = tostring
local type         = type

local capi         = {
    client         = client,
    tag            = tag,
    mouse          = mouse,
    screen         = screen,
    mousegrabber   = mousegrabber
}

local treetile     = {
    focusnew       = true,
    name           = "treetile",
    direction      = "right" -- the newly created client
                             -- on the RIGHT or LEFT side of current focus?
}

-- Globals
local force_split = nil
local layout_switch = false
local trees = {}

-- TODO
-- Layout icon
beautiful.layout_treetile = os.getenv("HOME") .. "/.config/awesome/treetile/layout_icon.png"

capi.tag.connect_signal("property::layout", function() layout_switch = true end)

local function debug_info(message)
    if type(message) == "table" then
        for k,v in pairs(message) do
            naughty.notify { text = table.concat {"key: ",k," value: ",tostring(v)} }
        end
    else
        naughty.notify { text = tostring(message) }
    end
end

-- get an unique identifier of a window
local function hash(client)
    if client then
        return client.window
    else
        return nil
    end
end

function bintree:update_nodes_geo(parent_geo, geo_table)
    local left_node_geo = nil
    local right_node_geo = nil

    if type(self.data) == 'number' then
        -- This sibling node is a client.
        -- Just need to resize this client to the size of its geometry of parent
        -- node (the empty work area left by the killed client together with
        -- original area occupied by this sibling client).

        if type(parent_geo) == "table" then
            geo_table[self.data] = awful.util.table.clone(parent_geo)
        else
            debug.print_error('geometry table error errors')
        end

        return
    end

    if type(self.data) == 'table' then
        -- the sibling is another table, need to update the geometry of all descendants.
        local now_geo = awful.util.table.clone(self.data)
        self.data = awful.util.table.clone(parent_geo)

        if type(self.left.data) == 'number'  then
            left_node_geo = awful.util.table.clone(geo_table[self.left.data])
        end

        if type(self.right.data) == 'number'  then
            right_node_geo = awful.util.table.clone(geo_table[self.right.data])
        end

        if type(self.left.data) == 'table' then
            left_node_geo = awful.util.table.clone(self.left.data)
        end

        if type(self.right.data) == 'table' then
            right_node_geo = awful.util.table.clone(self.right.data)
        end

        -- {{{ vertical split
        if math.abs(left_node_geo.x - right_node_geo.x) < 0.2 then
            -- Nodes are split in vertical way
            if math.abs(parent_geo.width - now_geo.width ) > 0.2 then
                left_node_geo.width = parent_geo.width
                right_node_geo.width = parent_geo.width

                local new_x = parent_geo.x

                left_node_geo.x = new_x
                right_node_geo.x = new_x
            end

            if math.abs(parent_geo.height - now_geo.height ) > 0.2 then
                if treetile.direction == 'left' then
                    left_node_geo, right_node_geo = right_node_geo, left_node_geo
                end

                local new_y = parent_geo.y
                local r_l_ratio = left_node_geo.height / now_geo.height

                left_node_geo.height = parent_geo.height * r_l_ratio
                right_node_geo.height = parent_geo.height - left_node_geo.height

                left_node_geo.y = new_y
                right_node_geo.y = new_y + left_node_geo.height
            end
        end
        -- }}}

        -- {{{ horizontal split
        if math.abs(left_node_geo.y - right_node_geo.y) < 0.2 then
            -- Nodes are split in horizontal way
            if math.abs(parent_geo.height - now_geo.height) > 0.2 then
                left_node_geo.height = parent_geo.height
                right_node_geo.height = parent_geo.height

                local new_y = parent_geo.y

                left_node_geo.y = new_y
                right_node_geo.y = new_y
            end

            if math.abs(parent_geo.width - now_geo.width) > 0.2 then
                if treetile.direction == 'left' then
                    left_node_geo, right_node_geo = right_node_geo, left_node_geo
                end

                local new_x =  parent_geo.x
                local r_l_ratio = left_node_geo.width / now_geo.width

                left_node_geo.width = parent_geo.width * r_l_ratio
                right_node_geo.width = parent_geo.width - left_node_geo.width

                left_node_geo.x = new_x
                right_node_geo.x = new_x + left_node_geo.width
            end
        end
        -- }}}

        if type(self.left.data) == 'number' then
            geo_table[self.left.data].x = left_node_geo.x
            geo_table[self.left.data].y = left_node_geo.y
            geo_table[self.left.data].height = left_node_geo.height
            geo_table[self.left.data].width = left_node_geo.width
        end

        if type(self.right.data) == 'number' then
            geo_table[self.right.data].x = right_node_geo.x
            geo_table[self.right.data].y = right_node_geo.y
            geo_table[self.right.data].height = right_node_geo.height
            geo_table[self.right.data].width = right_node_geo.width
        end

        if type(self.left.data) == 'table' then
           self.left:update_nodes_geo(left_node_geo, geo_table)
        end

        if type(self.right.data) == 'table' then
           self.right:update_nodes_geo(right_node_geo, geo_table)
        end
    end
end

local function table_find(tbl, item)
    for key, value in pairs(tbl) do
        if value == item then return key end
    end
    return false
end

local function table_diff(table1, table2)
    local diff_list = {}
    for i,v in ipairs(table1) do
        if table2[i] ~= v then
            table.insert(diff_list, v)
        end
    end
    if #diff_list == 0 then
        diff_list = nil
    end
    return diff_list
end

-- get ancestors of node with given data
function bintree:trace(data, path, dir)
    if path then
        table.insert(path, {split=self.data, direction=dir})
    end

    if data == self.data then
        return path
    end

    if type(self.left) == "table" then
        if (self.left:trace(data, path, "left")) then
            return true
        end
    end

    if type(self.right) == "table" then
        if (self.right:trace(data, path, "right")) then
            return true
        end
    end

    if path then
        table.remove(path)
    end
end

-- remove all leaves with data that don't appear in given table
-- and only remove clients
function bintree:filter_clients(node, clients)
    if node then
        if node.data and not table_find(clients, node.data) and
            type(node.data) == 'number' then
            self:remove_leaf(node.data)
        end

        if node.left then
            self:filter_clients(node.left, clients)
        end

        if node.right then
            self:filter_clients(node.right, clients)
        end
    end
end

function treetile.horizontal()
    force_split = "horizontal"
    debug_info('Next split is horizontal.')
end

function treetile.vertical()
    force_split = "vertical"
    debug_info('Next split is vertical.')
end

local function do_treetile(p)
    local area = p.workarea
    local n = #p.clients
    local focus

    local tag = tostring(p.tag or capi.screen[p.screen].selected_tag
                         or awful.tag.selected(capi.mouse.screen))

    if not trees[tag] then
        trees[tag] = {
            t = nil,
            last_focus = nil,
            clients = nil,
            geo_t = nil,
            geo = nil,
            n = 0
        }
    end

    -- t is tree structure to record all the clients and the way of splitting
    -- geo_t is the tree structure to record the geometry of all nodes/clients
    -- of the parent nodes (the over-all geometry of all siblings together)

    if trees[tag] ~= nil then
        -- should find a better to handle this
        if treetile.focusnew then
            focus = awful.client.focus.history.get(p.screen,1)
        else
            focus = capi.client.focus
        end

        if focus ~= nil then
            local isfloat
            if type(focus.floating) == 'boolean' then
                isfloat = focus.floating
            else
                isfloat = awful.client.floating.get(focus)
            end

            if isfloat then
                focus = nil
            else
                trees[tag].last_focus = focus
            end
        end
    end

    -- rearange only on change
    local changed = 0
    local update = false

    if trees[tag].n ~= n then
        if not trees[tag].n or n > trees[tag].n then
            changed = 1
        else
            changed = -1
        end
        trees[tag].n = n
    else
        if trees[tag].clients then
            local diff = table_diff(p.clients, trees[tag].clients)
            if diff and #diff == 2 then
                trees[tag].t:swap_leaves(hash(diff[1]), hash(diff[2]))
                trees[tag].geo_t:swap_leaves(hash(diff[1]), hash(diff[2]))
                trees[tag].geo[hash(diff[1])], trees[tag].geo[hash(diff[2])]
                    = trees[tag].geo[hash(diff[2])], trees[tag].geo[hash(diff[1])]
                update=true
            end
        end
    end

    trees[tag].clients = p.clients

    -- some client removed. update the trees
    if changed < 0 then
        if n > 0 then
            local tokens = {}
            for i, c in ipairs(p.clients) do
                tokens[i] = hash(c)
            end

            for clid, _ in pairs(trees[tag].geo) do
                if awful.util.table.hasitem(tokens, clid) == nil then
                    -- update the size of clients left, fill the empty space left by the killed client

                    local sib_node = trees[tag].geo_t:get_sibling(clid)
                    local parent = trees[tag].geo_t:get_parent(clid)
                    local parent_geo = nil

                    if parent then
                        parent_geo = parent.data
                    end

                    if sib_node ~= nil then
                        sib_node:update_nodes_geo(parent_geo, trees[tag].geo)
                    end

                    local pos = awful.util.table.hasitem(trees[tag].geo, clid)
                    table.remove(trees[tag].geo, pos)
                end
            end

            trees[tag].geo_t:filter_clients(trees[tag].geo_t, tokens)
            trees[tag].t:filter_clients(trees[tag].t, tokens)

            --awful.client.jumpto(trees[tag].last_focus)
        else
            trees[tag] = nil
        end
    end

    -- one or more clients are added. Put them in the tree.
    local prev_client = nil
    local next_split = 0

    if changed > 0 then
        for _, c in ipairs(p.clients) do
            if not trees[tag].t or not trees[tag].t:find(hash(c)) then
                if focus == nil then
                    focus = trees[tag].last_focus
                end

                local focus_node = nil
                local focus_geometry = nil
                local focus_node_geo_t = nil
                local focus_id = nil

                if trees[tag].t and focus and hash(c) ~= hash(focus) and not layout_switch then
                    -- Find the parent node for splitting
                    focus_node = trees[tag].t:find(hash(focus))
                    focus_node_geo_t = trees[tag].geo_t:find(hash(focus))
                    focus_geometry = focus:geometry()
                    focus_id = hash(focus)
                else
                    -- the layout was switched with more clients to order at once
                    if prev_client then
                        focus_node = trees[tag].t:find(hash(prev_client))
                        focus_node_geo_t = trees[tag].geo_t:find(hash(prev_client))
                        next_split = (next_split + 1) % 2
                        focus_geometry = trees[tag].geo[hash(prev_client)]
                        focus_id = hash(prev_client)
                    else
                        if not trees[tag].t then
                            -- create a new root
                            trees[tag].t = bintree.new(hash(c))
                            focus_geometry = {
                                width = 0,
                                height = 0
                            }
                            trees[tag].geo_t = bintree.new(hash(c))
                            trees[tag].geo = {}
                            trees[tag].geo[hash(c)] = awful.util.table.clone(area)
                            focus_id = hash(c)
                            --focus_node = trees[tag].t:find(hash(c))
                            --focus_node_geo_t = trees[tag].geo_t:find(hash(c))
                        end
                    end
                end

                -- {{{ if focus_node exists
                if focus_node then
                    if focus_geometry == nil then
                        local splits = {"horizontal", "vertical"}
                        focus_node.data = splits[next_split + 1]
                    else
                        if (force_split ~= nil) then
                            focus_node.data = force_split
                        else
                            if (focus_geometry.width <= focus_geometry.height) then
                                focus_node.data = "vertical"
                            else
                                focus_node.data = "horizontal"
                            end
                        end
                    end

                    if treetile.direction == 'right' then
                        focus_node:set_new_left(focus_id)
                        focus_node_geo_t:set_new_left(focus_id)
                        focus_node:set_new_right(hash(c))
                        focus_node_geo_t:set_new_right(hash(c))
                    else
                        focus_node:set_new_right(focus_id)
                        focus_node_geo_t:set_new_right(focus_id)
                        focus_node:set_new_left(hash(c))
                        focus_node_geo_t:set_new_left(hash(c))
                    end

                    local useless_gap = tag.gap or tonumber(beautiful.useless_gap)
                    if useless_gap == nil then
                        useless_gap = 0
                    else
                        useless_gap = useless_gap * 2.0
                    end

                    local avail_geo

                    if focus_geometry then
                        if focus_geometry.height == 0 and focus_geometry.width == 0 then
                            avail_geo = area
                        else
                            avail_geo = focus_geometry
                        end
                    else
                        avail_geo = area
                    end

                    local new_c = {}
                    local old_focus_c = {}

                    -- put the geometry of parament node into table too
                    focus_node_geo_t.data = awful.util.table.clone(avail_geo)

                    if focus_node.data == "horizontal" then
                        new_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                        new_c.height = avail_geo.height
                        old_focus_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                        old_focus_c.height = avail_geo.height
                        old_focus_c.y = avail_geo.y
                        new_c.y = avail_geo.y

                        if treetile.direction == "right" then
                            new_c.x = avail_geo.x + new_c.width + useless_gap
                            old_focus_c.x = avail_geo.x
                        else
                            new_c.x = avail_geo.x
                            old_focus_c.x = avail_geo.x + new_c.width - useless_gap
                        end

                    elseif focus_node.data == "vertical" then
                        new_c.height = math.floor((avail_geo.height - useless_gap) / 2.0 )
                        new_c.width = avail_geo.width
                        old_focus_c.height = math.floor((avail_geo.height - useless_gap) / 2.0 )
                        old_focus_c.width = avail_geo.width
                        old_focus_c.x = avail_geo.x
                        new_c.x = avail_geo.x

                        if  treetile.direction == "right" then
                            new_c.y = avail_geo.y + new_c.height + useless_gap
                            old_focus_c.y = avail_geo.y
                        else
                            new_c.y = avail_geo.y
                            old_focus_c.y =avail_geo.y + new_c.height - useless_gap
                        end

                    end

                    -- put geometry of clients into tables
                    if focus_id then
                        trees[tag].geo[focus_id] = old_focus_c
                        trees[tag].geo[hash(c)] = new_c
                    end
                end
            end
            -- }}}

            prev_client = c
        end
        force_split = nil
    end

    -- update the geometries of all clients
    if changed ~= 0 or layout_switch or update then

        if n >= 1 then
            for _, c in ipairs(p.clients) do
                local geo = trees[tag].geo[hash(c)]
                if type(geo) == 'table' then
                    c:geometry(geo)
                else
                    debug.print_error("wrong geometry in treetile/init.lua")
                end
            end
        end

        layout_switch = false
    end
end

local function clip(v, min, max)
    return math.max(math.min(v,max), min)
end

function treetile.resize_client(inc)
    -- inc: percentage of change: 0.01, 0.99 with +/-
    local focus_c = capi.client.focus
    local g = focus_c:geometry()

    local tag = tostring(focus_c.screen.selected_tag or awful.tag.selected(focus_c.screen))

    local parent_node = trees[tag].geo_t:get_parent(hash(focus_c))
    local parent_c = trees[tag].t:get_parent(hash(focus_c))
    local sib_node = trees[tag].geo_t:get_sibling(hash(focus_c))
    local sib_node_geo
    if type(sib_node.data) == "number" then
        sib_node_geo = trees[tag].geo[sib_node.data]
    else
        sib_node_geo = sib_node.data
    end

    local parent_geo

    if parent_node then
        parent_geo = parent_node.data
    else
        return
    end

    local new_geo = {}
    local new_sib = {}

    local min_y = 20.0
    local min_x = 20.0

    local useless_gap = tag.gap or tonumber(beautiful.useless_gap)
    if useless_gap == nil then
        useless_gap = 0
    else
        useless_gap = useless_gap * 2.0
    end

    new_geo.x = g.x
    new_geo.y = g.y
    new_geo.width = g.width
    new_geo.height = g.height

    local fact_y
    local fact_x

    if parent_c.data =='vertical' then
        fact_y =  math.ceil(clip(g.height * clip(math.abs(inc), 0.01, 0.99), 5, 30))
        if inc < 0 then
            fact_y = -fact_y
        end
    end

    if parent_c.data =='horizontal' then
        fact_x =  math.ceil(clip(g.width * clip(math.abs(inc), 0.01, 0.99), 5, 30))
        if inc < 0 then
            fact_x = - fact_x
        end
    end

    if parent_c.data =='vertical' then
        -- determine which is on the right side
        if g.y  > sib_node_geo.y  then
            new_geo.height = clip(g.height - fact_y, min_y, parent_geo.height - min_y)
            new_geo.y = parent_geo.y + parent_geo.height - new_geo.height

            new_sib.x = parent_geo.x
            new_sib.y = parent_geo.y
            new_sib.width = parent_geo.width
            new_sib.height = parent_geo.height - new_geo.height - useless_gap
        else
            new_geo.y = g.y
            new_geo.height = clip(g.height + fact_y, min_y, parent_geo.height - min_y)

            new_sib.x = new_geo.x
            new_sib.y = new_geo.y + new_geo.height + useless_gap
            new_sib.width = parent_geo.width
            new_sib.height = parent_geo.height - new_geo.height - useless_gap
        end
    end

    if parent_c.data =='horizontal' then
        -- determine which is on the top side
        if g.x  > sib_node_geo.x  then
            new_geo.width = clip(g.width - fact_x, min_x, parent_geo.width - min_x)
            new_geo.x = parent_geo.x + parent_geo.width - new_geo.width

            new_sib.y = parent_geo.y
            new_sib.x = parent_geo.x
            new_sib.height = parent_geo.height
            new_sib.width = parent_geo.width - new_geo.width - useless_gap
        else
            new_geo.x = g.x
            new_geo.width = clip(g.width + fact_x, min_x, parent_geo.width - min_x)

            new_sib.y = parent_geo.y
            new_sib.x = parent_geo.x + new_geo.width + useless_gap
            new_sib.height = parent_geo.height
            new_sib.width = parent_geo.width - new_geo.width - useless_gap
        end
    end

    trees[tag].geo[hash(focus_c)] = new_geo

    if sib_node ~= nil then
        sib_node:update_nodes_geo(new_sib, trees[tag].geo)
    end

    for _, c in ipairs(trees[tag].clients) do
        local geo = trees[tag].geo[hash(c)]
        if type(geo) == 'table' then
            c:geometry(geo)
        else
            debug.print_error("wrong geometry in init.lua")
        end
    end
end

function treetile.arrange(p)
    return do_treetile(p)
end

-- TODO
-- no implimented yet, do not use it!
-- resizing should only happen between the siblings? I guess so
local function mouse_resize_handler(c, _, _, _)
    local tag = tostring(c.screen.selected_tag or awful.tag.selected(c.screen))
    local cursor
    local g = c:geometry()
    local corner_coords

    local parent_c = trees[tag].t:get_parent(hash(c))

    local parent_node = trees[tag].geo_t:get_parent(hash(c))
    local parent_geo

    local new_y = nil
    local new_x = nil

    local sib_node = trees[tag].geo_t:get_sibling(hash(c))
    local sib_node_geo
    if type(sib_node.data) == "number" then
        sib_node_geo = trees[tag].geo[sib_node.data]
    else
        sib_node_geo = sib_node.data
    end

    if parent_node then
        parent_geo = parent_node.data
    else
        return
    end

    if parent_c then
        if parent_c.data =='vertical' then
            cursor = "sb_v_double_arrow"
            new_y = math.max(g.y, sib_node_geo.y)
            new_x = g.x + g.width / 2
        end

        if parent_c.data =='horizontal' then
            cursor = "sb_h_double_arrow"
            new_x = math.max(g.x, sib_node_geo.x)
            new_y = g.y + g.height / 2
        end
    end

    corner_coords = { x = new_x, y = new_y }

    capi.mouse.coords(corner_coords)

    local prev_coords = {}
    capi.mousegrabber.run(function (_mouse)
                              for _, v in ipairs(_mouse.buttons) do
                                  if v then
                                      prev_coords = { x =_mouse.x, y = _mouse.y }
                                      local fact_x = (_mouse.x - corner_coords.x)
                                      local fact_y = (_mouse.y - corner_coords.y)

                                      local new_geo = {}
                                      local new_sib = {}

                                      local min_x = 15.0
                                      local min_y = 15.0

                                      new_geo.x = g.x
                                      new_geo.y = g.y
                                      new_geo.width = g.width
                                      new_geo.height = g.height

                                      if parent_c.data =='vertical' then
                                          if g.y > sib_node_geo.y then
                                              new_geo.height = clip(g.height - fact_y, min_y, parent_geo.height - min_y)
                                              new_geo.y= clip(_mouse.y, sib_node_geo.y + min_y, parent_geo.y + parent_geo.height - min_y)

                                              new_sib.x = parent_geo.x
                                              new_sib.y = parent_geo.y
                                              new_sib.width = parent_geo.width
                                              new_sib.height = parent_geo.height - new_geo.height
                                          else
                                              new_geo.y = g.y
                                              new_geo.height = clip(g.height + fact_y,  min_y, parent_geo.height - min_y)

                                              new_sib.x = new_geo.x
                                              new_sib.y = new_geo.y + new_geo.height
                                              new_sib.width = parent_geo.width
                                              new_sib.height = parent_geo.height - new_geo.height
                                          end
                                      end

                                      if parent_c.data =='horizontal' then
                                          if g.x  > sib_node_geo.x  then
                                              new_geo.width = clip(g.width - fact_x, min_x, parent_geo.width - min_x)
                                              new_geo.x = clip(_mouse.x, sib_node_geo.x + min_x, parent_geo.x + parent_geo.width - min_x)

                                              new_sib.y = parent_geo.y
                                              new_sib.x = parent_geo.x
                                              new_sib.height = parent_geo.height
                                              new_sib.width = parent_geo.width - new_geo.width
                                          else
                                              new_geo.x = g.x
                                              new_geo.width = clip(g.width + fact_x, min_x, parent_geo.width - min_x)

                                              new_sib.y = parent_geo.y
                                              new_sib.x = parent_geo.x + new_geo.width
                                              new_sib.height = parent_geo.height
                                              new_sib.width = parent_geo.width - new_geo.width
                                          end
                                      end

                                      trees[tag].geo[hash(c)] = new_geo

                                      if sib_node ~= nil then
                                          sib_node:update_nodes_geo(new_sib, trees[tag].geo)
                                      end

                                      for _, cl in ipairs(trees[tag].clients) do
                                          local geo = trees[tag].geo[hash(cl)]
                                          if type(geo) == 'table' then
                                              cl:geometry(geo)
                                          else
                                              debug.print_error ("wrong geometry in init.lua")
                                          end
                                      end
                                      return true
                                  end
                              end
                              return prev_coords.x == _mouse.x and prev_coords.y == _mouse.y
                          end, cursor)
end

function treetile.mouse_resize_handler(c, corner, x, y)
    mouse_resize_handler(c, corner,x,y)
end

return treetile
