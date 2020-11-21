-- q7grid keys
-- turns the grid into a keyboard

local music = require 'musicutil'
local beatclock = require 'beatclock'

local Q7GridKeys = {}
Q7GridKeys.__index = Q7GridKeys

-- Q7GridKeys.anim = {
--     step = 1
-- }

local ripple_anim = {
    {{1,0},{0,1}},
    {{1,0},{1,1},{0,1}},
    {{2,0},{2,1},{1,2},{0,2}},
    {{3,0},{3,1},{2,2},{1,3},{0,3}},
    {{4,0},{4,1},{3,2},{2,3},{1,4},{0,4}},
    {{5,0},{5,1},{5,2},{4,3},{3,4},{2,5},{1,5},{0,5}},
    {{6,0},{6,1},{6,2},{5,3},{4,4},{3,5},{2,6},{1,6},{0,6}},
    {{6,0},{6,1},{6,2},{5,3},{4,4},{3,5},{2,6},{1,6},{0,6}},
    {{6,0},{6,1},{6,2},{5,3},{4,4},{3,5},{2,6},{1,6},{0,6}},
    {{6,0},{6,1},{6,2},{5,3},{4,4},{3,5},{2,6},{1,6},{0,6}},
    {{0,0}},
    {{0,0}},
    {{0,0}},
    {{0,0}},
}

Q7GridKeys.layout_names = {"Chromatic", "Scale"}

function Q7GridKeys.new(width,height)
    local gk = setmetatable({}, Q7GridKeys)

    gk.id = 1
    gk.midi_device = 1
    gk.midi_channel = 1
    gk.sound_mode = 1 -- 1 = internal, 2 = external


    gk.layout_mode = 1
    gk.vertical_offset = 3
    gk.highlight_selected_notes = false
    gk.grid_x = 1
    gk.grid_y = 1
    gk.grid_width = width or 16
    gk.grid_height = height or 8

    gk.note_on = nil -- event callback
    gk.note_off = nil -- event callback

    gk.key_on = nil -- event callback for GridSeq
    gk.key_off = nil -- event callback for GridSeq

    gk.gridSeq = nil

    gk.enable_note_highlighting = true
    gk.enable_key_playback = true

    gk.lit_keys = {}

    gk.note_velocity = 100

    gk.selected_notes = {}

    for i = 1,12 do
        gk.selected_notes[i] = 0
    end

    -- gk.root_note = 1
    -- gk.scale_mode = 1
    -- gk.scale = music.generate_scale_of_length(60,music.SCALES[gk.scale_mode].name,127) -- 60 = C3
    -- gk.selected_keys = {}
    -- gk.anim_keys = {} -- leds to be lit up
    -- gk.active_anim_keys = {} -- keys that are active in animation
    -- gk.anim_steps = {} -- each key will have it's own anim steps
    

    -- for x = 1,gk.grid_width do
    --     gk.selected_keys[x] = {}
    --     gk.anim_keys[x] = {}
    --     gk.active_anim_keys[x] = {}
    --     gk.anim_steps[x] = {}
    --     for y = 1,gk.grid_height do
    --         gk.selected_keys[x][y] = 0
    --         gk.anim_keys[x][y] = 0
    --         gk.active_anim_keys[x][y] = 0
    --         gk.anim_steps[x][y] = 0
    --     end
    -- end

    -- gk.note_in_scale = {}
    gk:resize_grid(gk.grid_x,gk.grid_y ,gk.grid_width,gk.grid_height)
    gk:change_scale(1, 1)
    return gk
end

-- returns a serialized version for saving
function Q7GridKeys:get_serialized()
    local d = {}

    d.id = self.id
    d.midi_device = self.midi_device
    d.midi_channel = self.midi_channel
    d.sound_mode = self.sound_mode

    d.layout_mode = self.layout_mode
    d.vertical_offset = self.vertical_offset
    -- d.highlight_selected_notes = false
    -- d.enable_note_highlighting = true
    d.note_velocity = self.note_velocity

    return d
end

function Q7GridKeys:load_serialized(data)
    -- if data.id ~= nil then -- not saved in older versions
    --     self.id = data.id
    --     self.midi_device = data.midi_device
    --     self.midi_channel = data.midi_channel
    --     self.sound_mode = data.sound_mode
    -- end

    self.id = data.id
    self.midi_device = data.midi_device
    self.midi_channel = data.midi_channel
    self.sound_mode = data.sound_mode

    self.layout_mode = data.layout_mode
    self.vertical_offset = data.vertical_offset
    self.note_velocity = data.note_velocity
end

function Q7GridKeys:resize_grid(x,y,width,height)
    self.grid_x = x
    self.grid_y = y
    self.grid_width = width
    self.grid_height = height

    self.selected_keys = {}
    self.anim_keys = {}
    self.active_anim_keys = {} 
    self.anim_steps = {} 
    self.grid_seq_keys = {} -- notes played by sequencer
    self.grid_seq_anim_keys = {} -- tracks which keys are being animated from sequencer

    for x = 1,self.grid_width do
        self.selected_keys[x] = {}
        self.anim_keys[x] = {}
        self.active_anim_keys[x] = {}
        self.anim_steps[x] = {}
        for y = 1,self.grid_height do
            self.selected_keys[x][y] = 0
            self.anim_keys[x][y] = 0
            self.active_anim_keys[x][y] = 0
            self.anim_steps[x][y] = 0
        end
    end
end

function Q7GridKeys:change_scale(new_root_note, new_scale_mode)
    self.root_note = new_root_note
    self.scale_mode = new_scale_mode
    self.scale = music.generate_scale_of_length(self.root_note - 1,music.SCALES[self.scale_mode].name,127) -- 60 = C3
    self.note_in_scale = {}

    for i=1,127 do
        table.insert(self.note_in_scale,0)
    end

    for i = 1,#self.scale do
        self.note_in_scale[self.scale[i]] = 1
    end
end

function Q7GridKeys:grid_to_note(x,y)
    if self.layout_mode == 1 then -- Chromatic mode
        return (self.vertical_offset * 5) + (x-1) + (5 * (self.grid_height-y))
    elseif self.layout_mode == 2 then
        local yOffset = 3 * (self.grid_height-y) + self.vertical_offset * 3
        local note_index = x + yOffset
        if note_index <= 127 then 
            local note_interval = self.scale[note_index]
            return note_interval and note_interval or nil
        end
    end
    return nil
end

function Q7GridKeys:scroll_up()
    self.vertical_offset = util.clamp(self.vertical_offset + 1, 0, 128)

    print("vertical_offset: " .. self.vertical_offset)
end

function Q7GridKeys:scroll_down()
    self.vertical_offset = util.clamp(self.vertical_offset - 1, 0, 128)

    print("vertical_offset: " .. self.vertical_offset)
end



function Q7GridKeys:animate()
    -- local animOff = self.anim.step - 1

    local grid_dirty = false

    for x = 1,self.grid_width do
        for y = 1,self.grid_height do
            self.anim_keys[x][y] = 0
        end
    end

    for x = 1,self.grid_width do
        for y = 1,self.grid_height do

            local id = self:get_key_id(x,y)

            if self.grid_seq_anim_keys ~= nil and self.grid_seq_anim_keys[id] ~= nil then
                if self.grid_seq_keys ~= nil and self.grid_seq_keys[id] ~= nil then -- key is down
                    self.grid_seq_anim_keys[id].anim_step = (self.grid_seq_anim_keys[id].anim_step % 6) + 1
                    self:anim_set_leds(self.grid_seq_anim_keys[id].anim_step, x, y)
                else -- key not down, ring out animation
                    self.grid_seq_anim_keys[id].anim_step = self.grid_seq_anim_keys[id].anim_step + 1
                    
                    if self.grid_seq_anim_keys[id].anim_step > 7 then
                        self.grid_seq_anim_keys[id] = nil
                    else
                        self:anim_set_leds(self.grid_seq_anim_keys[id].anim_step, x, y)
                    end
                end

                
                grid_dirty = true
            end


            -- if self.grid_seq_keys ~= nil and self.grid_seq_keys[id] ~= nil then
            --     self.grid_seq_keys[id].anim_step = (self.grid_seq_keys[id].anim_step % 6) + 1
                
            --     self:anim_set_leds(self.grid_seq_keys[id].anim_step, x, y)

            --     grid_dirty = true
            -- end

            -- keys pressed by user
            if self.active_anim_keys[x][y] == 1 then
                if self.selected_keys[x][y] == 1 then
                    self.anim_steps[x][y] = (self.anim_steps[x][y] % 6) + 1
                else
                    self.anim_steps[x][y] = self.anim_steps[x][y] + 1
                    if self.anim_steps[x][y] > 7 then
                        self.active_anim_keys[x][y] = 0
                    end
                end

                if self.active_anim_keys[x][y] ~= 0 then
                    self:anim_set_leds(self.anim_steps[x][y], x, y)
                end

                -- local pixels = ripple_anim[self.anim_steps[x][y]]

                -- -- print("Pixels length: "..#pixels)

                -- -- tab.print(pixels)

                -- local brightness = math.floor(util.linlin(1,8,5,1,self.anim_steps[x][y]))

                -- -- local brightness = 16 - anim_steps[x][y]


                -- for i=1,#pixels do
                --     local pixel = pixels[i]
                --     self:set_anim_grid(x + pixel[1], y + pixel[2], brightness)
                --     self:set_anim_grid(x - pixel[1], y + pixel[2], brightness)
                --     self:set_anim_grid(x - pixel[1], y - pixel[2], brightness)
                --     self:set_anim_grid(x + pixel[1], y - pixel[2], brightness)
                -- end

                -- draw_circle(x, y, anim_steps[x][y]-1)
                grid_dirty = true

                -- set_anim_grid(noteX + animOff, noteY)
                -- set_anim_grid(noteX - animOff, noteY)
                -- set_anim_grid(noteX, noteY + animOff)
                -- set_anim_grid(noteX, noteY - animOff)
            end
        end
    end


    -- for i,e in pairs(self.grid_seq_keys) do




    -- end
    
    -- if grid_dirty then
    --     grid_redraw()
    -- end

    -- if grid_dirty then
    --     grid_redraw()
    -- end
    -- if animStep < 17 then
    -- end

    return grid_dirty
end

function Q7GridKeys:anim_set_leds(step_position, x, y)
    local pixels = ripple_anim[step_position]
    local brightness = math.floor(util.linlin(1,8,5,1,step_position))

    for i=1,#pixels do
        local pixel = pixels[i]
        self:set_anim_grid(x + pixel[1], y + pixel[2], brightness)
        self:set_anim_grid(x - pixel[1], y + pixel[2], brightness)
        self:set_anim_grid(x - pixel[1], y - pixel[2], brightness)
        self:set_anim_grid(x + pixel[1], y - pixel[2], brightness)
    end
end

function Q7GridKeys:set_anim_grid(x,y,z)
    z = z or 10
    if x < 1 or x > self.grid_width then return end
    if y < 1 or y > self.grid_height then return end

    self.anim_keys[x][y] = z
end

function Q7GridKeys:get_key_id(x,y)
    local yId = (self.grid_height - y) + 1 + self.vertical_offset
    return x + ((yId - 1) * 16), yId
end

function Q7GridKeys:grid_event_to_note(x,y)
    if self.layout_mode == 1 then -- Chromatic mode
        return (x-1) + (5 * (y-1))
    elseif self.layout_mode == 2 then
        local note_index = x + 3 * (y-1)
        if note_index <= 127 then 
            local note_interval = self.scale[note_index]
            return note_interval and note_interval or nil
        end
    end
    return nil
end

function Q7GridKeys:key_note_on(e)
    local noteNum = self:grid_event_to_note(e.x, e.y)
    if noteNum ~= nil then
        -- print("Key Note On " ..noteNum .. " " ..e.id)
        if self.note_on ~= nil then self.note_on(self, noteNum, e.vel) end

        e.anim_step = 0
        self.grid_seq_keys[e.id] = e
        self.grid_seq_anim_keys[e.id] = e
    end
end

function Q7GridKeys:key_note_off(e)
    -- print("Note Off " ..e.id)
    local noteNum = self:grid_event_to_note(e.x, e.y)
    if noteNum ~= nil then
        if self.note_off ~= nil then self.note_off(self, noteNum) end

        self.grid_seq_keys[e.id] = nil
    end
end

function Q7GridKeys:grid_key(x,y,z)

    x = (x - self.grid_x) + 1
    y = (y - self.grid_y) + 1

    if x < 1 or x > self.grid_width then return false end
    if y < 1 or y > self.grid_height then return false end

    local grid_dirty = false
    if z == 1 then
        local noteNum = self:grid_to_note(x,y)
        if noteNum ~= nil then
            if self.enable_key_playback then
                self.selected_keys[x][y] = 1

                self.selected_notes[noteNum % 12 + 1] = self.selected_notes[noteNum % 12 + 1] + 1

                grid_dirty = true;

                if self.note_on ~= nil then self.note_on(self, noteNum, self.note_velocity) end

                self.active_anim_keys[x][y] = 1
                self.anim_steps[x][y] = 0
            else
                self.selected_keys[x][y] = 1
                self.selected_notes[noteNum % 12 + 1] = self.selected_notes[noteNum % 12 + 1] + 1

                grid_dirty = true;
            end

            if self.gridSeq ~= nil then
                local e = {}

                local id, yId = self:get_key_id(x,y)
                
                e.id = id
                e.x = x
                e.y = yId
                e.vel = 100
                e.state = z
                e.note_off_time = 0
                -- e.note_length = math.random(1,16)
                e.note_length = 1
                e.anim_step = 0
                e.probability = 1

                self.gridSeq:key_on(e) -- why does this pass nil?

                -- self:test_key_on(e)

                -- self.gridSeq.key_on(e)

                -- self:key_on(e)
            end



            -- active_anim_grid_keys[x][y] = 1
            -- anim_steps[x][y] = 0
            -- note_on(noteNum)
            -- add_note(noteNum)

            -- if sequence_playing then
            --     if tab.contains(sequence[sequence_position], noteNum) == false then
            --         table.insert(sequence[sequence_position], noteNum)
            --     end
            -- end

            -- selected_notes[noteNum % 12 + 1] = selected_notes[noteNum % 12 + 1] + 1

            -- -- engine.hz(music.note_num_to_freq(noteNum))
            -- print("Note: " .. noteNum .. " " .. music.note_num_to_name(noteNum))
        end
    elseif z == 0 then
        if self.selected_keys[x][y] == 1 then
            self.selected_keys[x][y] = 0

            grid_dirty = true;

            local noteNum = self:grid_to_note(x,y)
            if noteNum ~= nil then
                self.selected_notes[noteNum % 12 + 1] = math.max(self.selected_notes[noteNum % 12 + 1] - 1, 0)
                if self.note_off ~= nil then self.note_off(self, noteNum) end
                -- selected_notes[noteNum % 12 + 1] = math.max(selected_notes[noteNum % 12 + 1] - 1, 0)
                -- note_off(noteNum)
                -- remove_note(noteNum)

                if self.gridSeq ~= nil then

                    local e = {}

                    local id, yId = self:get_key_id(x,y)
                    
                    e.id = id
                    e.x = x
                    e.y = yId
                    e.vel = 0
                    e.state = z
                    e.note_off_time = 0
                    e.note_length = 1
                    e.anim_step = 0
                    e.probability = 1

                    self.gridSeq:key_off(e) 

                    -- self.gridSeq.key_off(e)

                    -- self:key_off(e)
                end
            end
        end
    end

    return grid_dirty
end

-- function Q7GridKeys:test_key_on(e)

--     self.gridSeq:key_on(e)


--     -- print("key_on id: "..e.id.." yID: " ..e.y)

--     -- print(self.name)

--     -- if self.gridKeys.lit_keys[e.id] == nil then
--     --     self.gridKeys.lit_keys[e.id] = e
--     -- else
--     --     self.gridKeys.lit_keys[e.id] = nil
--     -- end
-- end

function Q7GridKeys:is_note_in_scale(noteNum)
    return self.note_in_scale[noteNum] == 1
end

function Q7GridKeys:draw_grid(grid)

    local xOff = self.grid_x - 1
    local yOff = self.grid_y - 1

    for x = 1,self.grid_width do
        for y = 1,self.grid_height do
            local noteNum = self:grid_to_note(x,y)
            if noteNum ~= nil then

                local id = self:get_key_id(x,y)

                if self.grid_seq_keys ~= nil and self.grid_seq_keys[id] ~= nil then
                    grid:led(x + xOff, y + yOff, 15)
                elseif self.lit_keys ~= nil and self.lit_keys[id] ~= nil then
                    grid:led(x + xOff, y + yOff, 15)
                elseif self.enable_note_highlighting then
                    -- local current_step = sequence[sequence_position]

                    -- if sequence_playing and tab.contains(sequence[sequence_position], noteNum) then
                    --     g:led(x,y,15)
                    local noteName = music.note_num_to_name(noteNum, false)

                    -- print("root note: " .. self.root_note)

                    local selectedOff = 0
                    if self.highlight_selected_notes then
                        selectedOff = self.selected_notes[noteNum % 12 + 1] >= 1 and 4 or 0 -- highlight other notes matching selection
                    end

                    local animOff = self.anim_keys[x][y]

                    if self.selected_keys[x][y] == 1 then
                        grid:led(x + xOff, y + yOff, 15)
                    elseif noteName == music.NOTE_NAMES[self.root_note] then
                        grid:led(x + xOff, y + yOff, 6 + selectedOff + animOff)
                    elseif self.note_in_scale[noteNum] == 1 then
                        if self.layout_mode == 1 then -- Chromatic mode
                            grid:led(x + xOff, y + yOff, 3 + selectedOff + animOff)
                        elseif self.layout_mode == 2 then
                            grid:led(x + xOff, y + yOff, selectedOff + animOff)
                        end
                    elseif animOff >= 1 or selectedOff >=1 then
                        grid:led(x + xOff, y + yOff, 2 + selectedOff + animOff)
                    end
                else
                    local selectedOff = 0
                    if self.highlight_selected_notes then
                        selectedOff = self.selected_notes[noteNum % 12 + 1] >= 1 and 4 or 0 -- highlight other notes matching selection
                    end

                    local animOff = self.anim_keys[x][y]

                    if self.selected_keys[x][y] == 1 then
                        grid:led(x + xOff, y + yOff, 15)
                    elseif animOff >= 1 or selectedOff >=1 then
                        grid:led(x + xOff, y + yOff, 2 + selectedOff + animOff)
                    end
                end
            end
        end
    end
end

return Q7GridKeys