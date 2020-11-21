local Q7UI = {}
Q7UI.__index = Q7UI

Q7UI.ValueBox = {}
Q7UI.ValueBox.__index = Q7UI.ValueBox

function Q7UI.ValueBox.new(label, x, y, value, outline, fill_selected)
    local valueBox = {
        label = label or "",
        x = x or 0,
        y = y or 0,
        value = value or 0,
        active = true,
        selected = false,
        fill_selected = false,
        outline = outline or false
    }

    setmetatable(Q7UI.ValueBox, {__index = Q7UI})
    setmetatable(valueBox, Q7UI.ValueBox)
    return valueBox
end

function Q7UI.ValueBox:redraw()

    local x = self.x
    local y = self.y
    local w = 24
    local h = 17

    
    if self.selected and self.fill_selected then
        screen.line_width(1)
        screen.level(10)

        screen.rect(x, y, w, h - 1) 
        screen.fill()
    end

    if self.outline then
        screen.line_width(1)
        screen.level(self.selected and 10 or 4)

        screen.rect(x, y, w, h - 1) 
        screen.stroke()
    end
    
    if self.fill_selected then
        screen.level(self.selected and 0 or 2)
    else
        screen.level(self.selected and 10 or 2)
    end

    screen.font_face(1)
    screen.font_size(8)
    screen.move(x+(w/2),y+(h/2)+2)
    screen.text_center(self.value)

    screen.level(self.selected and 15 or 2)
    screen.font_face(1)
    screen.font_size(8)
    screen.move(x+(w/2),y+h+6)
    screen.text_center(self.label)
end

Q7UI.Slider = {}
Q7UI.Slider.__index = Q7UI.Slider

function Q7UI.Slider.new(label, x, y, value, min_value, max_value)
    local slider = {
        label = label or "",
        x = x or 0,
        y = y or 0,
        value = value or 0,
        min_value = min_value or 0,
        max_value = max_value or 1,
        active = true,
        selected = false
    }
    -- local acceptableDirections = {"up","down","left","right"}
    
    -- if (acceptableDirections[direction] == nil) then direction = acceptableDirections[1] end

    setmetatable(Q7UI.Slider, {__index = Q7UI})
    setmetatable(slider, Q7UI.Slider)
    return slider
end

function Q7UI.Slider:redraw()

    local x = self.x
    local y = self.y
    local w = 24
    local h = 17
    local barW = 8
    local barX = x + w/2 - barW/2 + 1

    screen.line_width(1)
    screen.level(self.selected and 10 or 4)

    screen.rect(barX, y, 8, h - 1) 
    -- screen.rect(x + 5, y, 8, 18)
    screen.stroke()

    screen.level(1)
    for i = 0,6 do
        screen.move(barX + 1, y + 2 + i * 2)
        screen.line(barX + barW - 2, y + 2 + i * 2)
        screen.stroke()
    end

    screen.level(15)

    filled_amount = util.round(util.linlin(self.min_value, self.max_value, 0, h-2, self.value))
    screen.rect(barX, y + h - filled_amount - 2, barW-1, filled_amount)

    -- local barOffset = math.floor(util.linlin(self.max_value, self.min_value, 0, 17, self.value))

    -- screen.rect(x + 5, y + barOffset, 7, 17)
    screen.fill()

    screen.level(self.selected and 15 or 2)
    screen.font_face(1)
    screen.font_size(8)
    screen.move(x+12,y+h+6)
    screen.text_center(self.label)
    
    -- --draws the perimeter 
    -- if (self.direction == "up" or self.direction == "down") then
    --   screen.rect(self.x + 0.5, self.y + 0.5, self.width - 1, self.height - 1) 
    -- elseif (self.direction == "left" or self.direction == "right") then
    --   screen.rect(self.x + 0.5, self.y + 0.5, self.width - 1, self.height - 1)
    -- end 
      
    -- screen.stroke()
    
    -- --draws the markers
    -- for _, v in pairs(self.markers) do
    --   if self.direction == "up" then
    --     screen.rect(self.x - 2, util.round(self.y + util.linlin(self.min_value, self.max_value, self.height - 1, 0, v)), self.width + 4, 1) --original
    --   elseif self.direction == "down" then
    --     screen.rect(self.x - 2, util.round(self.y + util.linlin(self.min_value, self.max_value, 0,self.height - 1, v)), self.width + 4, 1)
    --   elseif self.direction == "left" then
    --     screen.rect(util.round(self.x + util.linlin(self.min_value, self.max_value, self.width - 1, 0, v)), self.y - 2, 1, self.height +4)
    --   elseif self.direction == "right" then
    --     screen.rect(util.round(self.x + util.linlin(self.min_value, self.max_value, 0, self.width - 1, v)), self.y - 2, 1, self.height +4)
    --   end
    -- end
    -- screen.fill()
    
    -- --draws the value
    -- --local filled_height = util.round(util.linlin(self.min_value, self.max_value, 0, self.height, self.value))
    -- --screen.rect(self.x, self.y + self.height - filled_height, self.width, filled_height)
    
    -- local filled_amount --sometimes width now
    -- if self.direction == "up" then
    --     filled_amount = util.round(util.linlin(self.min_value, self.max_value, 0, self.height, self.value))
    --     screen.rect(self.x, self.y + self.height - filled_amount, self.width, filled_amount)
    --   elseif self.direction == "down" then
    --     filled_amount = util.round(util.linlin(self.min_value, self.max_value, 0, self.height, self.value)) --same as up
    --     screen.rect(self.x, self.y, self.width, filled_amount)
    --   elseif self.direction == "left" then
    --     filled_amount = util.round(util.linlin(self.min_value, self.max_value, 0, self.width, self.value))
    --     screen.rect(self.x + self.width - filled_amount, self.y, filled_amount, self.height)
    --   elseif self.direction == "right" then
    --     filled_amount = util.round(util.linlin(self.min_value, self.max_value, 0, self.width, self.value))
    --     screen.rect(self.x, self.y, filled_amount, self.height)
    -- end
      
    -- if self.active then screen.level(15) else screen.level(5) end
    -- screen.fill()
end

Q7UI.TimeSlider = {}
Q7UI.TimeSlider.__index = Q7UI.TimeSlider

-- Q7UI.TimeSlider.normal_value_labels = {"ON GRID", "1/128T", "2/128T", "1/64", "4/128T", "5/128T", "1/32", "7/128T", "8/128T", "3/64", "10/128T", "11/128T","1/16"}

function Q7UI.TimeSlider.new(label, x, y, width, height, value, min_value, max_value, active, selected, substep_count, value_labels)
    local slider = {
        label = label or "",
        x = x or 0,
        y = y or 0,
        width = width or 24,
        height = height or 24,
        value = value or 0,
        min_value = min_value or 0,
        max_value = max_value or 1,
        active = active == nil and true or active,
        selected = selected == nil and false or selected,
        substep_count = substep_count or 12,
        value_labels = value_labels or {}
    }

    setmetatable(Q7UI.TimeSlider, {__index = Q7UI})
    setmetatable(slider, Q7UI.TimeSlider)
    return slider
end

function Q7UI.TimeSlider:redraw()
    local x = self.x
    local y = self.y
    local w = self.width
    local h = self.height

    screen.level((self.active and self.selected) and 15 or 4)
    screen.line_width(1)

    local offset = math.floor(w/2)

    -- main step lines
    for i = 0,2 do
        screen.move(x + i*offset, y)
        screen.line(x + i*offset, y+h)
        screen.stroke()
    end

    offset = w/2/(self.substep_count+1)
    local startY = y + h*0.8

    for i = self.min_value+1,self.max_value-1 do
        local xPos = math.floor(util.linlin(self.min_value,self.max_value,x,x+w,i))

        if (math.abs(i) % (self.substep_count / 2)) == 0 then
            screen.level((self.active and self.selected) and 15 or 4)
            screen.move(xPos, y + h*0.3)
            screen.line(xPos, y+h)
            screen.stroke()
        elseif (math.abs(i) % (self.substep_count / 4)) == 0 then
            screen.level((self.active and self.selected) and 12 or 3)
            screen.move(xPos, y + h*0.6)
            screen.line(xPos, y+h)
            screen.stroke()
        else
            screen.level((self.active and self.selected) and 6 or 2)
            screen.move(xPos, startY)
            screen.line(xPos, y+h)
            screen.stroke()
        end
    end

    screen.level((self.active and self.selected) and 15 or 4)
    screen.move(x,y+h)
    screen.line(x+w,y+h)
    screen.stroke()

    screen.level((self.active and self.selected) and 15 or (self.selected and 12 or 4))

    local markerPos = math.floor(util.linlin(self.min_value,self.max_value,x,x+w,self.value))

    screen.move(markerPos, y+h+1)
    screen.line(markerPos, y+h+6)
    screen.stroke()
    screen.move(markerPos+1, y+h+2)
    screen.line(markerPos+1, y+h+6)
    screen.stroke()
    screen.move(markerPos-1, y+h+2)
    screen.line(markerPos-1, y+h+6)
    screen.stroke()

    local valueLabel = self.value

    if self.value_labels[math.floor(math.abs(self.value))+1] ~= nil then
        valueLabel = self.value_labels[math.floor(math.abs(self.value))+1]
    end

    if self.value > 0 then
        valueLabel = "+"..valueLabel
    elseif self.value < 0 then
        valueLabel = "-"..valueLabel
    end

    if self.value >= 0 then
        screen.move(markerPos - 4, y+h+6)
        screen.text_right(valueLabel)
    else
        screen.move(markerPos + 4, y+h+6)
        screen.text(valueLabel)
    end



    -- screen.move(markerPos, y+h+2)
    -- screen.line(markerPos+2, y+h+4)
    -- screen.line(markerPos+2, y+h+7)
    -- screen.line(markerPos-2, y+h+7)
    -- screen.line(markerPos-2, y+h+4)
    -- screen.fill()
    -- screen.line(markerPos, y+h+6)
    -- screen.stroke()

    

end


Q7UI.Dial = {}
Q7UI.Dial.__index = Q7UI.Dial

function Q7UI.Dial.new(label, x, y, value, min_value, max_value, start_value)
    local dial = {
        label = label or "",
        x = x or 0,
        y = y or 0,
        value = value or 0,
        min_value = min_value or 0,
        max_value = max_value or 1,
        start_value = start_value or 0,
        active = true,
        selected = false,
        _start_angle = math.pi * 0.7,
        _end_angle = math.pi * 2.3,
    }
    -- local acceptableDirections = {"up","down","left","right"}
    
    -- if (acceptableDirections[direction] == nil) then direction = acceptableDirections[1] end

    setmetatable(Q7UI.Dial, {__index = Q7UI})
    setmetatable(dial, Q7UI.Dial)
    return dial
end

function Q7UI.Dial:set_range(min_value, max_value, start_value)
    self.min_value = min_value or 0
    self.max_value = max_value or 1
    self.start_value = start_value or self.min_value
end

function Q7UI.Dial:redraw()

    local x = self.x
    local y = self.y
    local w = 24
    local h = 17
    local cx = w/2
    local cy = h/2


    screen.level(0)
    screen.fill() -- WTF? Arc will draw a line to end of previous drawing command if I don't do this

    screen.line_width(1)
    screen.level(self.selected and 2 or 2)

    screen.arc(x + cx, y + cy, cy, self._start_angle, self._end_angle)
    screen.stroke()


    local fill_start_angle = util.linlin(self.min_value, self.max_value, self._start_angle, self._end_angle, self.start_value)
    local fill_end_angle = util.linlin(self.min_value, self.max_value, self._start_angle, self._end_angle, self.value)
    
    -- if fill_end_angle < fill_start_angle then
    --     local temp_angle = fill_start_angle
    --     fill_start_angle = fill_end_angle
    --     fill_end_angle = temp_angle
    -- end


    screen.level(self.selected and 15 or 7)
    screen.line_width(1)
    -- screen.move(x + 9, y + 9)
    if fill_end_angle < fill_start_angle then
        screen.line(x + cx, y + cy)
        screen.arc(x + cx, y + cy, cy, fill_end_angle, fill_start_angle)
    else
        screen.arc(x + cx, y + cy, cy, fill_start_angle, fill_end_angle)
        screen.line(x + cx, y + cy)
    end
    screen.stroke()
    screen.line_width(1)



    -- screen.rect(x + 5, y, w - 1, h - 1) 
    -- -- screen.rect(x + 5, y, 8, 18)
    -- screen.stroke()

    -- screen.level(1)
    -- for i = 0,7 do
    --     screen.move(x + 6, y + 2 + i * 2)
    --     screen.line(x + 11, y + 2 + i * 2)
    --     screen.stroke()
    -- end

    -- screen.level(15)

    -- filled_amount = util.round(util.linlin(self.min_value, self.max_value, 0, h-2, self.value))
    -- screen.rect(x + 5, y + h - filled_amount - 2, w-2, filled_amount)

    -- -- local barOffset = math.floor(util.linlin(self.max_value, self.min_value, 0, 17, self.value))

    -- -- screen.rect(x + 5, y + barOffset, 7, 17)
    -- screen.fill()

    screen.level(self.selected and 15 or 2)
    screen.font_face(1)
    screen.font_size(8)
    screen.move(x+cx,y+h+6)
    screen.text_center(self.label)
end

return Q7UI