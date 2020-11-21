local Q7Util = require 'gridstep/lib/Q7Util'
local UI = require 'gridstep/lib/Q7UI'

local Q7GraphicPageOptions = {}

Q7GraphicPageOptions.__index = Q7GraphicPageOptions

Q7GraphicPageOptions.type_value_box = 1
Q7GraphicPageOptions.type_value_box_outlined = 2
Q7GraphicPageOptions.type_slider = 3
Q7GraphicPageOptions.type_dial = 4
Q7GraphicPageOptions.type_dial_centered = 5



function Q7GraphicPageOptions.new(x, y, width, height)
    local r = setmetatable({}, Q7GraphicPageOptions)

    r.x = x or 0
    r.y = y or 0
    r.width = width or 128
    r.height = height or 64

    r.selection = 1
    r.selection_d = 0
    r.enc3_d = 0
    r.options = {}

    r.display_num = 5
    r.start_y = 2

    r.redraw_func = nil

    -- -- x, y, width, height, value, min_value, max_value, markers, direction
    -- r.slider = UI.Slider.new(10, 20, 10, 20, 0.5, 0, 1)

    -- -- x, y, size, value, min_value, max_value, rounding, start_value, markers, units, title
    -- r.dial = UI.Dial.new(30,30,15,0.5,0,1, 0.01, 0.5, {}, "db", "Foobar")

    -- r.dial:set_marker_position(1,0)
    -- r.dial:set_marker_position(2,0.25)
    -- r.dial:set_marker_position(3,0.5)
    -- r.dial:set_marker_position(4,0.75)
    -- r.dial:set_marker_position(5,1)


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

function Q7GraphicPageOptions:reset_options()
    self.options = {}
    self.selection = 1
    self.selection_d = 0
    self.enc3_d = 0
end

function Q7GraphicPageOptions:add_option(name, display_type, min_value, max_value, stringFormat, units, get_value_func, delta_func, key_func)
    local option = {}
    option.name = name
    option.get = get_value_func
    option.delta = delta_func
    option.key = key_func
    option.display_type = display_type or 1
    option.min_value = min_value or 0
    option.max_value = max_value or 1
    option.stringFormat = stringFormat or ""
    -- option.rounding = rounding or 0.01
    option.units = units or ""
    option.slider = {}
    option.dial = {}
    option.showValueOnLabel = false
    option._showValue = false
    option._clockId = nil
    if option.get ~= nil then
        option._prevV = option.get()
    else
        option._prevV = 0
    end

    option._prevV = 0

    if display_type == Q7GraphicPageOptions.type_value_box or display_type == Q7GraphicPageOptions.type_value_box_outlined then
        -- x, y, width, height, value, min_value, max_value
        option.valueBox = UI.ValueBox.new(name)
        option.valueBox.outline = display_type == Q7GraphicPageOptions.type_value_box_outlined
        option.valueBox.min_value = option.min_value
        option.valueBox.max_value = option.max_value
    elseif display_type == Q7GraphicPageOptions.type_slider then
        option.showValueOnLabel = true
        -- x, y, width, height, value, min_value, max_value
        option.slider = UI.Slider.new(name)
        option.slider.min_value = option.min_value
        option.slider.max_value = option.max_value
    elseif display_type == Q7GraphicPageOptions.type_dial then
        option.showValueOnLabel = true
        option.dial = UI.Dial.new(name)
        option.dial:set_range(option.min_value, option.max_value)
    elseif display_type == Q7GraphicPageOptions.type_dial_centered then
        option.showValueOnLabel = true
        option.dial = UI.Dial.new(name)
        option.dial:set_range(option.min_value, option.max_value, util.linlin( 0, 1, option.min_value, option.max_value, 0.5))
    end

    table.insert(self.options, option)

    return option
end

function Q7GraphicPageOptions:key(n,z)
    local option = self.options[self.selection]

    if option.key ~= nil then
        option.key(n, z)
    end
end

function Q7GraphicPageOptions:enc(n,d, ignoreSelectionKnob)
    ignoreSelectionKnob = ignoreSelectionKnob == nil and false or ignoreSelectionKnob

    if n == 2 and ignoreSelectionKnob == false then
        -- self.dial:set_value_delta(d * 0.05)
        local prevSelection = self.selection
        self.selection_d, self.selection = Q7Util.enc_delta_slow(d, self.selection_d, 1, #self.options)

        if prevSelection ~= self.selection then
            self.enc3_d = 0
        end
    elseif n == 3 then
        -- slows selection without needing a bunch of delta variables
        self.enc3_d = util.clamp(self.enc3_d + util.clamp(d,-1, 1) * 0.15,-1,1)
        local enc3_d = (self.enc3_d == 1 or self.enc3_d == -1) and self.enc3_d or 0

        local option = self.options[self.selection]

        if option.delta ~= nil then
            option.delta(enc3_d, d)
        end

        -- if d ~= 0 and option.showValueOnLabel and option.get ~= nil then
        --     -- local prevVal = option.get()
        --     if option.delta ~= nil then
        --         option.delta(enc3_d, d)
        --     end

        --     if option._clockId then
        --         clock.cancel(option._clockId)
        --     end

        --     option._clockId = clock.run(
        --         function()
        --             option._showValue = true
        --             clock.sleep(2)
        --             option._showValue = false
        --         end
        --     )

        --     -- if prevVal ~= option.get
        -- else
        --     if option.delta ~= nil then
        --         option.delta(enc3_d, d)
        --     end
        -- end

        if enc3_d ~= 0 then self.enc3_d = 0 end -- reset to 0 everytime it's -1 or 1
    end

    -- if self.redraw_func ~= nil then
    --     self.redraw_func()
    -- end
end

-- function Q7GraphicPageOptions.get_value_label(option)
--     -- "%.2f"
--     local v, dv = option.get()

--     if dv ~= nil then return dv end
    
--     if option.stringFormat == "" then
--         return v
--     else
--         return string.format(option.stringFormat, v)..option.units
--     end
-- end

function Q7GraphicPageOptions:redraw()

    for i = 1, math.min(#self.options, 8) do
        local o = self.options[i]

        local v, dv = 0, 0

        if o.get ~= nil then
            v, dv = o.get()

            -- print("v = "..v.. " prevV = ".. o._prevV)

            if o.showValueOnLabel and v ~= o._prevV then -- show value on label if changed
                if o._clockId then
                    clock.cancel(o._clockId)
                end

                self.options[i]._clockId = clock.run(
                    function()
                        self.options[i]._showValue = true
                        clock.sleep(2)
                        self.options[i]._showValue = false
                    end
                )
            end

            self.options[i]._prevV = v
        end

        if dv == nil then -- set display value string if no dv from get()
            if o.stringFormat == "" then
                dv = v
            else
                dv = string.format(o.stringFormat, v)..o.units
            end
        end

        -- 25 is width needed for single element
        -- 128 / 4 == 32
        local xOff = util.round(self.width / math.min(#self.options, 4))

        local centerX = util.round(((xOff - 24) / 2))

        -- centerX = 4

        local xPos = self.x + ((i - 1) * xOff) + centerX
        local yPos = self.y

        if i > 4 then
            xPos = self.x + ((i-4-1) * xOff) + centerX
            yPos = self.y + math.floor(self.height / 2)
        end

        if o.display_type == Q7GraphicPageOptions.type_value_box or o.display_type == Q7GraphicPageOptions.type_value_box_outlined then
            if i == self.selection then
                o.valueBox.selected = true
            else
                o.valueBox.selected = false
            end
            if o.get ~= nil then
                o.valueBox.value = dv
            end
            o.valueBox.x = xPos
            o.valueBox.y = yPos
            o.valueBox:redraw()
        elseif o.display_type == Q7GraphicPageOptions.type_slider then
            o.slider.label = o._showValue and dv or o.name

            if i == self.selection then
                o.slider.selected = true
            else
                o.slider.selected = false
            end
            if o.get ~= nil then
                o.slider.value = o.get()
            end
            o.slider.x = xPos
            o.slider.y = yPos
            o.slider:redraw()
        elseif o.display_type == Q7GraphicPageOptions.type_dial or o.display_type == Q7GraphicPageOptions.type_dial_centered then
            o.dial.label = o._showValue and dv or o.name

            if i == self.selection then
                o.dial.selected = true
            else
                o.dial.selected = false
            end
            if o.get ~= nil then
                o.dial.value = o.get()
            end
            o.dial.x = xPos
            o.dial.y = yPos
            o.dial:redraw()
        end
    end

    Q7Util.draw_reset_font()

    -- self.slider:redraw()
    -- self.dial:redraw()
end

-- function Q7GraphicPageOptions:redraw()
--     -- screen.clear()
--     screen.move(0,0)

--     local displayText = {}

--     for i = 1,self.display_num do
--         displayText[i] = {}
--         displayText[i].header = ""
--         displayText[i].value = ""
--         displayText[i].selected = false
--     end

--     local y = 1

--     if #self.options > self.display_num then
--         y = math.max(self.selection - 2, 1)
--     end

--     for i = 1,self.display_num do
--         if y <= #self.options then
--             displayText[i].header = self.options[y].name

--             if self.options[y].get ~= nil then
--                 displayText[i].value = self.options[y].get()
--             end
--             displayText[i].selected = y == self.selection
--         end

--         y = y + 1
--     end

--     local yOff = self.start_y

--     for i = 1, #displayText do
--         screen.level(displayText[i].selected and 15 or 2)
--         screen.move(0,(i+1)*10 + yOff)
--         screen.text(displayText[i].header)
--         screen.move(127,(i+1)*10 + yOff)
--         screen.text_right(displayText[i].value)
--     end
-- end

return Q7GraphicPageOptions