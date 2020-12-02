-- local Q7Util = require 'gridstep/lib/Q7Util'
local Q7Util = include("gridstep/lib/Q7Util")


local ParamListUtil = {}

ParamListUtil.__index = ParamListUtil

function ParamListUtil.new()
    local r = setmetatable({}, ParamListUtil)

    r.selection = 1
    r.selection_d = 0
    r.scroll_offset = 2
    r.delta_speed = 0.15
    r.enc3_d = 0
    r.options = {}

    r.display_num = 5
    r.start_y = 2

    r.redraw_func = nil

    -- r.options[1] = {}
    -- r.options[1].name = "Option 1"
    -- r.options[1].get = nil
    -- r.options[1].delta = nil
    -- r.options[2] = {}
    -- r.options[2].name = "Option 2"
    -- r.options[2].get = nil
    -- r.options[2].delta = nil

    return r
end

function ParamListUtil:reset_options()
    self.options = {}
    self.selection = 1
    self.selection_d = 0
    self.enc3_d = 0
end

function ParamListUtil:add_option(name, get_func, delta_func, key_func)
    local option = {}
    option.name = name
    option.get = get_func
    option.delta = delta_func
    option.key = key_func
    table.insert(self.options, option)
end

function ParamListUtil:key(n,z)
    if #self.options == 0 then return end

    local option = self.options[self.selection]

    if option.key ~= nil then
        option.key(n, z)
    end
end

function ParamListUtil:enc(n,d)
    if #self.options == 0 then return end

    if n == 2 then
        local prevSelection = self.selection
        self.selection_d, self.selection = Q7Util.enc_delta_slow(d, self.selection_d, 1, #self.options)

        if prevSelection ~= self.selection then
            self.enc3_d = 0
        end
    elseif n == 3 then
        -- slows selection without needing a bunch of delta variables
        self.enc3_d = util.clamp(self.enc3_d + util.clamp(d,-1, 1) * self.delta_speed,-1,1)
        local enc3_d = (self.enc3_d == 1 or self.enc3_d == -1) and self.enc3_d or 0

        local option = self.options[self.selection]

        if option.delta ~= nil then
            option.delta(enc3_d, d)
        end

        if enc3_d ~= 0 then self.enc3_d = 0 end -- reset to 0 everytime it's -1 or 1
    end

    -- if self.redraw_func ~= nil then
    --     self.redraw_func()
    -- end
end

function ParamListUtil:redraw()
    if #self.options == 0 then return end

    -- screen.clear()
    screen.move(0,0)

    local displayText = {}

    for i = 1,self.display_num do
        displayText[i] = {}
        displayText[i].header = ""
        displayText[i].value = ""
        displayText[i].selected = false
    end

    local y = 1

    if #self.options > self.display_num then
        y = math.max(self.selection - self.scroll_offset, 1)
    end

    for i = 1,self.display_num do
        if y <= #self.options then
            displayText[i].header = self.options[y].name

            if self.options[y].get ~= nil then
                displayText[i].value = self.options[y].get()
            end
            displayText[i].selected = y == self.selection
        end

        y = y + 1
    end

    local yOff = self.start_y

    for i = 1, #displayText do
        screen.level(displayText[i].selected and 15 or 2)
        screen.move(0,(i+1)*10 + yOff)
        screen.text(displayText[i].header)
        screen.move(127,(i+1)*10 + yOff)
        screen.text_right(displayText[i].value)
    end
end

return ParamListUtil