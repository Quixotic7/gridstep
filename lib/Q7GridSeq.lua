-- step sequencer for Q7GridKeys

local music = require 'musicutil'
local beatclock = require 'beatclock'

local Q7GridSeq = {}
Q7GridSeq.__index = Q7GridSeq

Q7GridSeq.gridKeys = {}

Q7GridSeq.trigConditions = {"Percent", "Pre", "!Pre","First","!First", 
"1:2", "2:2", 
"1:3", "2:3", "3:3", 
"1:4", "2:4", "3:4", "4:4", 
"1:5", "2:5", "3:5", "4:5", "5:5",
"1:6", "2:6", "3:6", "4:6", "5:6", "6:6",
"1:7", "2:7", "3:7", "4:7", "5:7", "6:7", "7:7",
"1:8", "2:8", "3:8", "4:8", "5:8", "6:8", "7:8", "8:8",}

Q7GridSeq.trigConditionsAB ={
    { a = 1, b = 2}, { a = 2, b = 2},
    { a = 1, b = 3}, { a = 2, b = 3}, { a = 3, b = 3},
    { a = 1, b = 4}, { a = 2, b = 4}, { a = 3, b = 4}, { a = 4, b = 4},
    { a = 1, b = 5}, { a = 2, b = 5}, { a = 3, b = 5}, { a = 4, b = 5}, { a = 5, b = 5},
    { a = 1, b = 6}, { a = 2, b = 6}, { a = 3, b = 6}, { a = 4, b = 6}, { a = 5, b = 6}, { a = 6, b = 6},
    { a = 1, b = 7}, { a = 2, b = 7}, { a = 3, b = 7}, { a = 4, b = 7}, { a = 5, b = 7}, { a = 6, b = 7}, { a = 7, b = 7},
    { a = 1, b = 8}, { a = 2, b = 8}, { a = 3, b = 8}, { a = 4, b = 8}, { a = 5, b = 8}, { a = 6, b = 8}, { a = 7, b = 8}, { a = 8, b = 8},
}

function Q7GridSeq.new(gridKeys)
    -- constants
    seqmode_select = 0
    seqmode_delete = 1
    seqmode_cut = 2
    seqmode_copy = 3
    seqmode_paste = 4

    local seq = setmetatable({}, Q7GridSeq)

    seq.name = ""

    seq.gridKeys = gridKeys
    seq.on_new_step = nil

    seq.current_step = 1 -- step that is currently selected for editing
    -- 1 x x x 2 x x x 3 x x x
    -- 1 2 3 4 5 6 7 8 9 10 11 12
    -- stepIndex = (x - 1) * 4 + 1
    seq.selected_bar = 1 -- bar that is currently selected for editing
    seq.selected_pattern = 1 -- pattern that is selected for editing

    seq.next_pattern_at_end = false -- if true, the next pattern will load at the end of the pattern, if false, the next pattern will load at the end of current bar

    seq.position = 1 -- position in bar
    seq.play_bar_position = 1 -- which bar is playing
    seq.active_pattern = 1 -- which pattern is playing

    seq.mute_seq = false


    seq.last_16th_time = 0 -- last 16th in beat time
    seq.last_16th_index = 1
    -- seq.time_between_16ths = 1

    seq.elapsed_steps = 1 -- how much time in step space has elapsed since playback started
    seq.sub_step_counter = 0
    seq.sub_steps = {}
    seq.sub_steps2 = {} -- notes offset negatively get placed in this array
    seq.is_playing = false
    seq.play_clock_id = 0
    seq.step_edit = false
    seq.record = false
    seq.prev_trig_true = false
    seq.pattern_count = 0 -- how many times pattern has looped

    seq.substep_count = 12
    seq.step_count = 16
    seq.triplet_step_count = 12
    -- seq.triplet_mode = false
    seq.triplet_substep_count = 16
    seq.sync_time = 1/48

    -- Edit mode
    -- 0: off
    -- 1: delete
    -- 2: cut
    -- 3: copy
    -- 4: paste
    seq.edit_mode = 0

    seq.active_notes = {}
    seq.note_offs = {}

    seq.record_keys = {}

    seq.patterns = {}

    seq.patterns[1] = seq:create_new_pattern()

    seq.bars = seq.patterns[1].bars
    seq.bar_length = seq.patterns[1].bar_length
    seq.num_bars = seq.patterns[1].num_bars
    seq.total_step_count = seq.bar_length * seq.num_bars -- a 16 step bar is actually 64 steps

    seq.steps = seq.bars[seq.selected_bar]

    seq.clipboard_step = {}
    seq.clipboard_bar = {}

    return seq
end

function Q7GridSeq:play()
    if self.is_playing then
        self:play_stop()
    else
        self:play_start()
    end
end

function Q7GridSeq:reset_counters(patIndex)
    if self.patterns[patIndex] == nil then return end

    for bar = 1, self.patterns[patIndex].num_bars do
        for i = 1, 16 do
            self.patterns[patIndex].bars[bar][i].count = 0
        end
    end
end

function Q7GridSeq:play_start()
    self.position = 0

    self.last_16th_time = clock.get_beats()
    self.last_16th_index = 1
    self.play_bar_position = 1
    self.active_pattern = self.selected_pattern
    self.is_playing = true
    self.prev_trig_true = false
    self.pattern_count = 0 
    self.sub_step_counter = 0
    self.sub_steps = {}
    self.sub_steps2 = {}
    self.play_clock_id = clock.run(function() Q7GridSeq.play_sequence(self) end)

    self:reset_counters(self.active_pattern)
end

function Q7GridSeq:play_stop()
    if self.is_playing then
        self.is_playing = false
        clock.cancel(self.play_clock_id)

        -- stop all active notes
        for i,e in pairs(self.active_notes) do
            self.gridKeys:key_note_off(self.active_notes[i])
            self.active_notes[i] = nil
            self.note_offs[i] = nil
        end
    end
end

function Q7GridSeq:play_sequence()
    clock.get_beats()
    while self.is_playing do
        self:clock_step16()

        -- clock.sync(1/24) -- 6 substeps
        clock.sync(1/48) -- 12 substeps

        -- clock.sync(1/64) -- 16 substeps
        -- clock.sync(1/128) -- 32 substeps

        -- clock.sync(1/4) -- 1/16 for 64 steps
    end
end

function Q7GridSeq:get_selected_pattern()
    return self.patterns[self.selected_pattern]
end

function Q7GridSeq:get_active_pattern()
    return self.patterns[self.active_pattern]
end

function Q7GridSeq:create_new_step()
    local step = {}

    step.keys = {}
    step.cond = 1 -- step condition
    step.count = 0 -- used for A:B conditions
    step.mute = false
    step.vel = 100
    step.length = 1
    step.offset = 0 -- microtimings!

    return step
end

function Q7GridSeq:clone_step(step)
    local newStep = {}

    newStep.keys = {}

    for i,e in pairs(step.keys) do
        newStep.keys[i] = Q7GridSeq.clone_noteEvent(e)
    end

    newStep.cond = step.cond
    newStep.count = step.count
    newStep.mute = step.mute
    newStep.vel = step.vel
    newStep.length = step.length
    newStep.offset = step.offset

    return newStep
end

function Q7GridSeq:create_new_bar()
    local bar = {}

    for i = 1, 16 do
        bar[i] = self:create_new_step()
    end

    return bar
end

function Q7GridSeq:clone_bar(bar)
    local newBar = {}

    for i = 1, 16 do
        newBar[i] = self:clone_step(bar[i])
    end

    return newBar
end

function Q7GridSeq:create_new_pattern(barLength, numBars)
    barLength = barLength or 16
    numBars = numBars or 1

    local pattern = {}
    pattern.bars = {}
    pattern.bar_length = barLength
    pattern.num_bars = numBars
    pattern.triplet_mode = false

    for bar = 1, pattern.num_bars do
        pattern.bars[bar] = self:create_new_bar()
    end

    return pattern
end

function Q7GridSeq:clone_pattern(pat)
    if pat == nil then return nil end

    local clonedPat = {}

    clonedPat.bar_length = pat.bar_length
    clonedPat.num_bars = pat.num_bars
    clonedPat.triplet_mode = pat.triplet_mode
    
    clonedPat.bars = {}

    for bar = 1, clonedPat.num_bars do
        clonedPat.bars[bar] = self:clone_bar(pat.bars[bar])
    end

    return clonedPat
end

function Q7GridSeq:change_selected_pattern(newPatIndex)
    if newPatIndex < 1 or newPatIndex > 16 or newPatIndex == self.selected_pattern then return false end

    -- no pattern found, create new one
    if self.patterns[newPatIndex] == nil then
        self.patterns[newPatIndex] = self:create_new_pattern()
    end

    self.selected_pattern = newPatIndex

    local pat = self:get_selected_pattern()

    self.current_step = 1 -- step that is currently selected for editing
    self.selected_bar = 1 -- bar that is currently selected for editing

    self.bars = self.patterns[newPatIndex].bars
    self.bar_length = self.patterns[newPatIndex].bar_length
    self.num_bars = self.patterns[newPatIndex].num_bars
    self.total_step_count = self.bar_length * self.num_bars

    self:change_selected_bar(1) -- will update active bar and step

    return true
end

function Q7GridSeq:get_length()
    return self.bar_length, self.num_bars
end

function Q7GridSeq:set_length(bar_length, num_bars)
    if bar_length < 1 or bar_length > 16 or num_bars < 1 or num_bars > 16 then return false end
    -- local prev_num_bars = self.num_bars

    local pat = self:get_selected_pattern()
    if pat == nil then 
        print("Pattern is nil")
        return false 
    end

    -- self.bar_length = bar_length
    -- self.num_bars = num_bars
    -- self.total_step_count = self.bar_length * 4 * self.num_bars

    -- more bars are needed
    if num_bars > pat.num_bars then
        for i = pat.num_bars + 1, num_bars do
            if pat.bars[i] == nil then -- create new bar as neccessarily, thus existing bars stay alive
                pat.bars[i] = self:create_new_bar()
            end
        end
    end

    if Q7GridSeq.stepIndex_to_stepId(self.current_step) > pat.bar_length then
        self:change_selected_stepId(pat.bar_length)
    end


    if self.selected_bar >= pat.num_bars then
        self.selected_bar = pat.num_bars
    end

    self.bars = pat.bars

    pat.bar_length = bar_length
    pat.num_bars = num_bars

    self.bar_length = bar_length
    self.num_bars = num_bars
    self.total_step_count = self.bar_length * 4 * self.num_bars

    self:change_selected_bar(self.selected_bar)

    -- local pat = self:get_selected_pattern()
    -- if pat ~= nil then 
    --     pat.bar_length = self.bar_length
    --     pat.num_bars = self.num_bars
    -- end

    return true
    -- should I clear existing bars if the bar length becomes shorter?
    -- Undecided, theres benefits to keeping the bars
    -- Then to delete unused bars, clearing the sequence will kill them
end

function Q7GridSeq.stepId_to_stepIndex(stepId)
    -- 1 x x x 2 x x x 3 x x x
    -- 1 2 3 4 5 6 7 8 9 10 11 12
    -- return (stepId - 1) * 4 + 1 -- changed from 64 to 16 steps to support microtiming
    return stepId
end

-- turns an index between 1-64 to stepId between 1-16
function Q7GridSeq.stepIndex_to_stepId(stepIndex)
    -- StepIndex: 1 2 3 4 5 6 7 8 9 10 11 12
    -- StepId:    1 x x x 2 x x x 3 x  x  x

    -- return math.floor((stepIndex - 1) / 4) + 1 -- changed from 64 to 16 steps to support microtiming

    return stepIndex
end

function Q7GridSeq:evaluate_step(step)
    -- probabilities are currently set per step, but evaluating per key event for possible future upgrade
    local shouldTrigger = true
    local cond = step.cond

    step.count = step.count + 1

    if cond ~= 1 then -- evaluate trigger
        if cond >= 0 and cond <= 1 then 
            shouldTrigger = math.random() <= cond
        elseif cond == 2 then -- trigger if prev trigger was true
            shouldTrigger = self.prev_trig_true
        elseif cond == 3 then -- trigger if prev trigger was false
            shouldTrigger = not self.prev_trig_true
        elseif cond == 4 then -- trigger if first time pattern is played
            shouldTrigger = self.pattern_count == 0
        elseif cond == 5 then -- trigger if not first time pattern is played
            shouldTrigger = self.pattern_count ~= 0
        else -- A:B trigger
            -- local count = count + 1

            local a = Q7GridSeq.trigConditionsAB[cond - 5].a
            local b = Q7GridSeq.trigConditionsAB[cond - 5].b

            if step.count == a then
                shouldTrigger = true
            else
                shouldTrigger = false
            end

            if step.count >= b then
                step.count = 0
            end
        end

        self.prev_trig_true = shouldTrigger
    end

    return shouldTrigger
end

function Q7GridSeq:get_substep_count()
    local pat = self:get_selected_pattern()
    if pat == nil then return self.substep_count end

    return pat.triplet_mode and self.triplet_substep_count or self.substep_count
end

function Q7GridSeq:get_substep_count_active()
    local pat = self:get_active_pattern()
    if pat == nil then return self.substep_count end

    return pat.triplet_mode and self.triplet_substep_count or self.substep_count
end

function Q7GridSeq:trigger_step(step)
    if self.mute_seq then return end
    
    for i,e in pairs(step.keys) do
        -- send note offs if note is already active
        if self.active_notes[e.id] ~= nil then
            self.gridKeys:key_note_off(self.active_notes[i])
            self.active_notes[i] = nil
        end

        e.vel = step.vel

        self.gridKeys:key_note_on(e)

        e.note_off_time = self.elapsed_steps + step.length

        self.active_notes[i] = e
    end
end

function Q7GridSeq:clock_step16()
    -- turn off notes once enough steps have elapsed
    for i,e in pairs(self.active_notes) do
        if e.note_off_time <= self.elapsed_steps then
            self.gridKeys:key_note_off(self.active_notes[i])
            self.active_notes[i] = nil
        end
    end

    local substep_count = self:get_substep_count_active()

    -- trigger substep if available
    local subStepIndex = self.sub_step_counter + 1

    -- substeps from previous 16th
    if self.sub_steps[subStepIndex] ~= nil then
        self:trigger_step(self.sub_steps[subStepIndex])
    end

    -- 16th step
    if self.sub_step_counter == 0 then 
        local stepIndex = self.position + 1

        self.sub_steps = {}
        self.sub_steps2 = {}
        self.last_16th_index = stepIndex
        self.last_16th_time = clock.get_beats()

        local pat = self:get_active_pattern()
        if pat ~= nil then 

            if self.play_bar_position > pat.num_bars then -- protect against pasting a new pattern
                self.play_bar_position = 1
            end

            local step = pat.bars[self.play_bar_position][stepIndex] -- error ? 

            -- step.offset = 0.5

            if step.mute == false and self:does_step_have_notes_internal(step) then
                if step.offset == 0 and self:evaluate_step(step) then -- no offset and trig evaluation is true, trigger note
                    self:trigger_step(step)
                elseif step.offset > 0 and self:evaluate_step(step) then -- has offset and trig evaluation is true, add to substep to be played later
                    local subStepIndex = (step.offset % substep_count) + 1
                    self.sub_steps[subStepIndex] = step
                end
            end


            local nextStep = nil
            local nextStepIndex = (stepIndex % pat.bar_length) + 1

            if nextStepIndex == 1 and self.active_pattern == self.selected_pattern then -- only grab note at next bar if there's not a pattern change
                local nextBarIndex = (self.play_bar_position % pat.num_bars) + 1
                nextStep = pat.bars[nextBarIndex][nextStepIndex]
            elseif nextStepIndex > 1 then -- next step is in the bar
                nextStep = pat.bars[self.play_bar_position][nextStepIndex]
            end

            -- nextStep should always be evaluated after this step
            if nextStep ~= nil then
                if nextStep.mute == false and self:does_step_have_notes_internal(nextStep) then
                    if nextStep.offset < 0 and self:evaluate_step(nextStep) then -- has offset and trig evaluation is true, add to substep to be played later or this step for full offset
                        -- with offset < 0, step won't be evaluated next 16th
                        local subStepIndex = (substep_count + nextStep.offset) + 1 -- step.offset is negative
                        self.sub_steps2[subStepIndex] = nextStep
                    end
                end
            end

            -- substeps from next 16th that are offset by full 16th
            if self.sub_steps2[subStepIndex] ~= nil then
                self:trigger_step(self.sub_steps2[subStepIndex])
            end

            self.position = self.position + 1

            -- goto next bar once reached end of bar
            if self.position >= pat.bar_length then
                if self.selected_pattern ~= self.active_pattern then -- new pattern selected
                    if self.next_pattern_at_end then -- wait til end of pattern to switch
                        self.play_bar_position = self.play_bar_position + 1
                        self.position = 0

                        if self.play_bar_position > pat.num_bars then
                            self.pattern_count = 0 
                            self.play_bar_position = 1
                            self.active_pattern = self.selected_pattern
                            self:reset_counters(self.active_pattern)
                        end
                    else -- switch pattern on next bar
                        self.pattern_count = 0 
                        self.position = 0
                        self.play_bar_position = 1
                        self.active_pattern = self.selected_pattern
                        self:reset_counters(self.active_pattern)
                    end
                else -- keep on cycling to 1st bar of same pattern
                    self.play_bar_position = self.play_bar_position + 1
                    self.position = 0

                    if self.play_bar_position > pat.num_bars then --  end of pattern increment pattern count
                        self.pattern_count = self.pattern_count + 1
                        self.play_bar_position = 1
                    end
                end
            end
        end
    else
        -- substeps from next 16th
        if self.sub_steps2[subStepIndex] ~= nil then
            self:trigger_step(self.sub_steps2[subStepIndex])
        end
    end

    -- local subStepIndex = self.sub_step_counter + 1

    -- local subStep = self.sub_steps[subStepIndex]

    -- if subStep ~= nil then
    --     for i,e in pairs(subStep.keys) do
    --         -- send note offs if note is already active
    --         if self.active_notes[e.id] ~= nil then
    --             self.gridKeys:key_note_off(self.active_notes[i])
    --             self.active_notes[i] = nil
    --         end

    --         e.vel = subStep.vel

    --         self.gridKeys:key_note_on(e)

    --         e.note_off_time = self.elapsed_steps + subStep.length

    --         self.active_notes[i] = e
    --     end
    -- end

    -- updates 4x faster than step time
    -- self.elapsed_steps = self.elapsed_steps + 1/8


    self.elapsed_steps = self.elapsed_steps + 1/substep_count

    self.sub_step_counter = (self.sub_step_counter + 1) % substep_count

    -- if self.sub_step_counter == 0 then
    --     self.sub_steps = {}
    --     -- self.sub_steps2 = {}
    -- end
end

-- updates 4x faster than 16, beat synced to 1/16
-- currently editing is limited to 16th notes, but could later be
-- expanded to 64th notes
-- changed from 64 to 16 steps to support microtiming
function Q7GridSeq:clock_step64()
    -- turn off notes once enough steps have elapsed
    for i,e in pairs(self.active_notes) do
        if e.note_off_time <= self.elapsed_steps then
            self.gridKeys:key_note_off(self.active_notes[i])
            self.active_notes[i] = nil
        end
    end

    local stepIndex = self.position + 1

    if (self.position % 4) == 0 then
        self.last_16th_index = stepIndex
        self.last_16th_time = clock.get_beats()
        -- print("Last 16th: " .. self.last_16th_index.. " Time: " .. self.last_16th_time)
    end

    local pat = self:get_active_pattern()
    if pat ~= nil then 

        if self.play_bar_position > pat.num_bars then -- protect against pasting a new pattern
            self.play_bar_position = 1
        end

        -- if pat.bars == nil then
        --     print("pat.bars is nil")
        -- end

        -- if pat.bars[self.play_bar_position] == nil then
        --     print("pat.bars at "..self.play_bar_position.." is nil")
        -- end

        -- if pat.bars[self.play_bar_position][stepIndex] == nil then
        --     print("pat.bars at "..self.play_bar_position.." "..stepIndex.." is nil")
        -- end

        -- local step = self.steps[self.position]
        local step = pat.bars[self.play_bar_position][stepIndex] -- error ? 

        if step.mute == false and self:does_step_have_notes_internal(step) then
            -- probabilities are currently set per step, but evaluating per key event for possible future upgrade
            local shouldTrigger = true

            -- local cond = self:get_step_cond(stepIndex)

            local cond = step.cond

            step.count = step.count + 1

            if cond ~= 1 then -- evaluate trigger
                if cond >= 0 and cond <= 1 then 
                    shouldTrigger = math.random() <= cond
                elseif cond == 2 then -- trigger if prev trigger was true
                    shouldTrigger = self.prev_trig_true
                elseif cond == 3 then -- trigger if prev trigger was false
                    shouldTrigger = not self.prev_trig_true
                elseif cond == 4 then -- trigger if first time pattern is played
                    shouldTrigger = self.pattern_count == 0
                elseif cond == 5 then -- trigger if not first time pattern is played
                    shouldTrigger = self.pattern_count ~= 0
                else -- A:B trigger
                    -- local count = count + 1

                    local a = Q7GridSeq.trigConditionsAB[cond - 5].a
                    local b = Q7GridSeq.trigConditionsAB[cond - 5].b

                    if step.count == a then
                        shouldTrigger = true
                    else
                        shouldTrigger = false
                    end

                    if step.count >= b then
                        step.count = 0
                    end
                end

                self.prev_trig_true = shouldTrigger
            end

            if shouldTrigger then 
                for i,e in pairs(step.keys) do
                    -- send note offs if note is already active
                    if self.active_notes[e.id] ~= nil then
                        self.gridKeys:key_note_off(self.active_notes[i])
                        self.active_notes[i] = nil
                    end

                    e.vel = step.vel

                    self.gridKeys:key_note_on(e)

                    e.note_off_time = self.elapsed_steps + step.length

                    self.active_notes[i] = e
                end
            end
        end

        -- if self.on_new_step ~= nil then self.on_new_step() end -- no longer needed, caused too many grid refreshes with multiple tracks

        -- self.position = (self.position % (self.bar_length * 4)) + 1

        self.position = self.position + 1

        -- goto next bar once reached end of bar
        if self.position >= pat.bar_length * 4 then
            if self.selected_pattern ~= self.active_pattern then -- new pattern selected
                if self.next_pattern_at_end then -- wait til end of pattern to switch
                    self.play_bar_position = self.play_bar_position + 1
                    self.position = 0

                    if self.play_bar_position > pat.num_bars then
                        self.pattern_count = 0 
                        self.play_bar_position = 1
                        self.active_pattern = self.selected_pattern
                        self:reset_counters(self.active_pattern)
                    end
                else -- switch pattern on next bar
                    self.pattern_count = 0 
                    self.position = 0
                    self.play_bar_position = 1
                    self.active_pattern = self.selected_pattern
                    self:reset_counters(self.active_pattern)
                end
            else -- keep on cycling to 1st bar of same pattern
                self.play_bar_position = self.play_bar_position + 1
                self.position = 0

                if self.play_bar_position > pat.num_bars then --  end of pattern increment pattern count
                    self.pattern_count = self.pattern_count + 1
                    self.play_bar_position = 1
                end

                -- self.play_bar_position = (self.play_bar_position % pat.num_bars) + 1
                -- self.position = 0
            end
        end
    end

    -- updates 4x faster than step time
    self.elapsed_steps = self.elapsed_steps + (1/4)
end

function Q7GridSeq:clear_edit_mode(editMode)
    if self.edit_mode == editMode then
        self.edit_mode = seqmode_select
        return true
    end
    return false
end

function Q7GridSeq:clear_step_edit()
    self.gridKeys.lit_keys = {}
end

-- function clock.transport.start()
--     print("we begin")
--     sequence_position = 1
--     sequence_playing = true
--     play_sequence_clock_id = clock.run(play_sequence)
-- end
  
-- function clock.transport.stop()
--     sequence_playing = false
--     clock.cancel(play_sequence_clock_id)
-- end

function Q7GridSeq:select_next_step()
    local stepId = self:get_current_stepId()

    stepId = stepId + 1

    if stepId > 16 then
        stepId = 1
        self:select_next_bar()
    end
    -- stepId = (stepId % self.bar_length) + 1

    self:change_selected_stepId(stepId)
end

function Q7GridSeq:select_prev_step()
    local stepId = self:get_current_stepId()

    stepId = stepId - 1

    if stepId < 1 then
        stepId = 16
        self:select_prev_bar()
    end

    self:change_selected_stepId(stepId)
end

function Q7GridSeq:select_stepId(stepId)
    self:select_step(Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:select_step(stepIndex)
    if self.step_edit then
        if self.edit_mode == 0 then -- select
            self:change_selected_step(stepIndex)
        elseif self.edit_mode == 1 then -- delete
            self:delete_step(stepIndex)
        elseif self.edit_mode == 2 then -- cut
            if self:does_step_have_notes(stepIndex) then
                self:copy_step(stepIndex)
                self:delete_step(stepIndex)
            else
                self:paste_step(stepIndex)
            end
        elseif self.edit_mode == 3 then -- copy
            if self:does_step_have_notes(stepIndex) then
                self:copy_step(stepIndex)
            else
                self:paste_step(stepIndex)
            end
        elseif self.edit_mode == 4 then -- paste
            self:paste_step(stepIndex)
        end
    end
end

function Q7GridSeq:get_current_step_index()
    return self.current_step
end

function Q7GridSeq:get_current_stepId()
    return Q7GridSeq.stepIndex_to_stepId(self.current_step)
end

function Q7GridSeq:change_velocity_stepId(velLevel, stepId)
    self:change_velocity(velLevel, Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:change_velocity(velLevel, stepIndex)
    stepIndex = stepIndex or self:get_current_step_index()

    self.steps[stepIndex].vel = velLevel
end


function Q7GridSeq:get_cloned_patern_at_index(newPatIndex)
    if newPatIndex < 1 or newPatIndex > 16 then return nil end

    return self:clone_pattern(self.patterns[newPatIndex])
end

function Q7GridSeq:paste_pattern_to_index(newPattern, newPatIndex)
    if newPatIndex < 1 or newPatIndex > 16 then return false end

    self.patterns[newPatIndex] = self:clone_pattern(newPattern)

    if newPatIndex == self.selected_pattern then
        self.current_step = 1 -- step that is currently selected for editing
        self.selected_bar = 1 -- bar that is currently selected for editing

        self.bars = self.patterns[newPatIndex].bars
        self.bar_length = self.patterns[newPatIndex].bar_length
        self.num_bars = self.patterns[newPatIndex].num_bars
        self.total_step_count = self.bar_length * self.num_bars -- a 16 step bar is actually 64 steps

        self:change_selected_bar(1) -- will update active bar and step
    end
    return true
end

function Q7GridSeq:clear_pattern_at_index(patIndex)
    if patIndex < 1 or patIndex > 16 then return false end

    if patIndex == self.selected_pattern then
        self:clear_pattern() -- Keep patern, clear notes
    else
        self.patterns[patIndex] = nil
    end

    return true
end

function Q7GridSeq:get_current_step_velocity()
    return(self:get_step_velocity(self:get_current_step_index()))
end

function Q7GridSeq:get_stepId_velocity(stepId)
    return self:get_step_velocity(Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:get_step_velocity(stepIndex)
    return self.steps[stepIndex].vel

    -- local step = self.steps[stepIndex]

    -- local velSum = 0
    -- local count = 0

    -- for i,e in pairs(step.keys) do
    --     velSum = velSum + e.vel
    --     count = count + 1
    -- end

    -- if count > 0 then
    --     return velSum / count
    -- end

    -- return 0
end

function Q7GridSeq:get_stepId_cond(stepId)
    return self:get_step_cond(Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:get_step_cond(stepIndex)
    return self.steps[stepIndex].cond
    -- local step = self.steps[stepIndex]

    -- local pSum = 0
    -- local count = 0

    -- for i,e in pairs(step) do
    --     pSum = pSum + e.probability
    --     count = count + 1
    -- end

    -- if count > 0 then
    --     return pSum / count
    -- end

    -- return 1
end

function Q7GridSeq:get_stepId_mute(stepId)
    return self.steps[stepId].mute
end

function Q7GridSeq:set_stepId_mute(stepId, mute)
    -- if self:does_stepId_have_notes(stepId) == false then return false end
    mute = mute or not self:get_stepId_mute(stepId)
    self.steps[stepId].mute = mute
    return true
end

function Q7GridSeq:get_stepId_offset(stepId)
    stepId = stepId or self:get_current_step_index()

    local subStepCount = self:get_substep_count()

    return util.clamp(self.steps[stepId].offset, -subStepCount, subStepCount)
end

function Q7GridSeq:set_stepId_offset(stepId, offset)
    stepId = stepId or self:get_current_step_index()

    local subStepCount = self:get_substep_count()

    offset = offset or 0
    offset = util.clamp(offset, -subStepCount, subStepCount)
    self.steps[stepId].offset = offset
end

function Q7GridSeq:get_triplet_mode()
    local pat = self:get_selected_pattern()
    if pat == nil then return false end

    return pat.triplet_mode
end

function Q7GridSeq:set_triplet_mode(enable_triplet_mode)
    local pat = self:get_selected_pattern()
    if pat == nil then return false end

    pat.triplet_mode = enable_triplet_mode

    return true
end

function Q7GridSeq:change_cond_stepId(cond, stepId)
    self:change_cond(cond, Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:change_cond(cond, stepIndex)
    stepIndex = stepIndex or self:get_current_step_index()

    self.steps[stepIndex].cond = cond

    -- print("Change Prob "..probability)

    -- local step = self.steps[stepIndex]

    -- for i,e in pairs(step) do
    --     self.steps[stepIndex][i].probability = probability
    -- end
end

function Q7GridSeq:change_noteLength_stepId(noteLength, stepId)
    self:change_noteLength(noteLength, Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:change_noteLength(noteLength, stepIndex)
    stepIndex = stepIndex or self:get_current_step_index()

    self.steps[stepIndex].length = noteLength

    -- local step = self.steps[stepIndex]

    -- for i,e in pairs(step.keys) do
    --     self.steps[stepIndex].keys[i].note_length = noteLength
    -- end
end

function Q7GridSeq:get_current_step_note_length()
    return self:get_step_note_length()
end

function Q7GridSeq:get_stepId_note_length(stepId)
    return self:get_step_note_length(Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:get_step_note_length(stepIndex)
    stepIndex = stepIndex or self:get_current_step_index()

    return self.steps[stepIndex].length

    -- stepIndex = stepIndex or self:get_current_step_index()

    -- local step = self.steps[stepIndex]

    -- local lengthSum = 0
    -- local count = 0

    -- for i,e in pairs(step.keys) do
    --     lengthSum = lengthSum + e.note_length
    --     count = count + 1
    -- end

    -- if count > 0 then
    --     return lengthSum / count
    -- end

    -- return 0
end

function Q7GridSeq:clear_all()
    self.patterns[self.selected_pattern] = self:create_new_pattern(self.bar_length, self.num_bars)

    self.bars = self.patterns[self.selected_pattern].bars
    self.bar_length = self.patterns[self.selected_pattern].bar_length
    self.num_bars = self.patterns[self.selected_pattern].num_bars
    self.total_step_count = self.bar_length * self.num_bars -- a 16 step bar is actually 64 steps

    self.steps = self.bars[self.selected_bar]
    

    -- stop all active notes if playing
    if self.is_playing then
        for i,e in pairs(self.active_notes) do
            self.gridKeys:key_note_off(self.active_notes[i])
            self.active_notes[i] = nil
        end
    end

    self.gridKeys.lit_keys = {}

    self:change_selected_bar(self.selected_bar) -- recopy bar steps to self.steps and select it
end

function Q7GridSeq:clear_pattern()
    local pat = self:get_selected_pattern()
    if pat == nil then return false end

    -- stop all active notes if playing
    if self.is_playing then
        for i,e in pairs(self.active_notes) do
            self.gridKeys:key_note_off(self.active_notes[i])
            self.active_notes[i] = nil
        end
    end

    self.gridKeys.lit_keys = {}

    pat.bars = {}

    for bar = 1, pat.num_bars do
        pat.bars[bar] = self:create_new_bar()
    end

    self.current_step = 1 -- step that is currently selected for editing
    self.selected_bar = 1 -- bar that is currently selected for editing

    self.bars = self.patterns[self.selected_pattern].bars
    self.bar_length = self.patterns[self.selected_pattern].bar_length
    self.num_bars = self.patterns[self.selected_pattern].num_bars
    self.total_step_count = self.bar_length * self.num_bars -- a 16 step bar is actually 64 steps

    self:change_selected_bar(self.selected_bar) -- recopy bar steps to self.steps and select it
end

-- returns a serialized version for saving
function Q7GridSeq:get_serialized()
    local d = {}
    d.name = self.name
    d.patterns = {}

    for i,p in pairs(self.patterns) do
        d.patterns[i] = self:clone_pattern(p)
    end

    d.current_step = self.current_step
    d.selected_bar = self.selected_bar 
    d.selected_pattern =  self.selected_pattern 
    d.next_pattern_at_end = self.next_pattern_at_end

    d.mute_seq = self.mute_seq 
    d.substep_count = self.substep_count 
    d.step_count = self.step_count 
    d.triplet_step_count = self.triplet_step_count
    -- d.triplet_mode = self.triplet_mode 
    d.triplet_substep_count = self.triplet_substep_count 
    d.sync_time = self.sync_time 

    return d
end

-- clones settings from another gridSeq that will work while playing
function Q7GridSeq:paste_gridSeq(otherSeq)
    self.name = otherSeq.name

    self.current_step = otherSeq.name.current_step
    self.selected_bar = otherSeq.selected_bar
    self.selected_pattern = otherSeq.selected_pattern

    self.next_pattern_at_end = otherSeq.next_pattern_at_end

    self.position = otherSeq.position
    self.play_bar_position = otherSeq.play_bar_position
    self.active_pattern = otherSeq.active_pattern

    self.mute_seq = otherSeq.mute_seq


    self.last_16th_time = otherSeq.last_16th_time
    self.last_16th_index = otherSeq.last_16th_index

    self.elapsed_steps = otherSeq.elapsed_steps
    self.sub_step_counter = otherSeq.sub_step_counter
    -- seq.sub_steps = {}
    -- seq.sub_steps2 = {} -- notes offset negatively get placed in this array
    -- seq.is_playing = otherSeq.
    -- seq.play_clock_id = 0
    -- seq.step_edit = false
    self.record = otherSeq.record
    self.prev_trig_true = otherSeq.prev_trig_true
    self.pattern_count = otherSeq.pattern_count

    self.substep_count = otherSeq.substep_count
    self.step_count = otherSeq.step_count
    self.triplet_step_count = otherSeq.triplet_step_count
    -- self.triplet_mode = otherSeq.triplet_mode
    self.triplet_substep_count = otherSeq.triplet_substep_count
    self.sync_time = otherSeq.sync_time


    self.patterns = {}

    for i,p in pairs(otherSeq.patterns) do
        self.patterns[i] = self:clone_pattern(p)
    end

    self.bars = self.patterns[self.selected_pattern].bars
    self.bar_length = self.patterns[self.selected_pattern].bar_length
    self.num_bars = self.patterns[self.selected_pattern].num_bars
    self.total_step_count = self.bar_length * self.num_bars -- a 16 step bar is actually 64 steps

    self.steps = self.bars[self.selected_bar]

    self.clipboard_step = {}
    self.clipboard_bar = {}
end

function Q7GridSeq:load_serialized(data)

    self.name = data.name
    self.patterns = {}

    for i,p in pairs(data.patterns) do
        self.patterns[i] = self:clone_pattern(p)
    end

    self.current_step = data.current_step
    self.selected_bar = data.selected_bar 
    self.selected_pattern =  data.selected_pattern 
    self.next_pattern_at_end = data.next_pattern_at_end

    self.mute_seq = data.mute_seq 
    self.substep_count = data.substep_count 
    self.step_count = data.step_count 
    self.triplet_step_count = data.triplet_step_count
    -- self.triplet_mode = data.triplet_mode 
    self.triplet_substep_count = data.triplet_substep_count 
    self.sync_time = data.sync_time 

    -- self.name = data.name

    -- if data.patterns ~= nil then
    --     self.patterns = data.patterns
    -- elseif data.bars ~= nil then -- old 1 pattern format, load pattern into pattern 1
    --     self.patterns = {}

    --     local pattern = self:create_new_pattern(data.bar_length, data.num_bars)

    --     for bar = 1, pattern.num_bars do
    --         for i = 1, 16 do -- a 16 step bar is actually 64 steps
    --             pattern.bars[bar][i].keys = data.bars[bar][i]
    --         end
    --     end

    --     -- local pattern = {}
    --     -- pattern.bars = data.bars
    --     -- pattern.bar_length = data.bar_length
    --     -- pattern.num_bars = data.num_bars

    --     self.patterns[1] = pattern
    
    --     self.bars = self.patterns[1].bars
    --     self.bar_length = self.patterns[1].bar_length
    --     self.num_bars = self.patterns[1].num_bars
    --     self.total_step_count = self.bar_length * self.num_bars -- a 16 step bar is actually 64 steps
    -- end

    -- self.current_step = 1
    -- self.selected_bar = 1
    self.active_pattern = self.selected_pattern

    -- self.position = 1
    -- self.play_bar_position = 1
    self:change_selected_bar(self.selected_bar) -- will update active bar and step
end

function Q7GridSeq:save_seq(filename)
    filename = filename or "track"
    local path = _path.data .."q7gridseq/"..filename..".txt"

    local d = self:get_serialized()
    tab.save(d, path)
    print("track saved to: " .. path)
end

function Q7GridSeq:load_seq(filename)
    filename = filename or "track"
    local path = _path.data .."q7gridseq/"..filename..".txt"
    local d = tab.load(path)
    if d ~= nil then
        self:load_serialized(d)
    end

    print("track loaded from: " .. path)
end

function Q7GridSeq:change_selected_bar(newBar)
    if newBar < 1 or newBar > self.num_bars then return false end -- sanity check

    self.selected_bar = newBar
    self.steps = self.bars[self.selected_bar]

    self:change_selected_step(self.current_step)

    return true
end

function Q7GridSeq:select_next_bar()
    self.selected_bar = (self.selected_bar % self.num_bars) + 1
    self.steps = self.bars[self.selected_bar]

    self:change_selected_step(self.current_step)

    return true
end

function Q7GridSeq:select_prev_bar()

    self.selected_bar = ((self.num_bars + self.selected_bar - 2) % self.num_bars) + 1
    self.steps = self.bars[self.selected_bar]

    self:change_selected_step(self.current_step)

    return true
end

function Q7GridSeq.clone_noteEvent(e)
    local e2 = {}
    
    e2.id = e.id
    e2.x = e.x
    e2.y = e.y
    e2.vel = e.vel
    e2.state = e.state
    e2.probability = e.probability
    e2.anim_step = 0
    e2.note_off_time = 0
    e2.note_length = e.note_length

    return e2
end

-- cuts the selected bar
function Q7GridSeq:cut_bar(barIndex)
    barIndex = barIndex or self.selected_bar
    if barIndex < 1 or barIndex > self.num_bars then return false end
    
    self:copy_bar(barIndex)
    self:clear_bar(barIndex)

    return true
end

function Q7GridSeq:copy_bar(barIndex)
    barIndex = barIndex or self.selected_bar
    if barIndex < 1 or barIndex > self.num_bars then return false end

    self.clipboard_bar = self:clone_bar(self.patterns[self.selected_pattern].bars[barIndex])

    return true
end

function Q7GridSeq:paste_bar(barIndex)
    barIndex = barIndex or self.selected_bar
    if barIndex < 1 or barIndex > self.num_bars or self.clipboard_bar == nil then return false end

    self.patterns[self.selected_pattern].bars[barIndex] = self:clone_bar(self.clipboard_bar)

    self:change_selected_bar(barIndex) -- causes bar to be copied to steps

    return true
end

function Q7GridSeq:clear_bar(barIndex)
    barIndex = barIndex or self.selected_bar
    if barIndex < 1 or barIndex > #self.bars then return false end

    self.patterns[self.selected_pattern].bars[barIndex] = self:create_new_bar()

    self:change_selected_bar(barIndex) -- causes bar to be copied to steps

    return true
end

function Q7GridSeq:shift_notes_left()
    local pat = self:get_selected_pattern()
    if pat == nil then return false end

    local tempPattern = self:create_new_pattern(pat.bar_length, pat.num_bars)

    for barIndex = 1, tempPattern.num_bars do
        for i = 1, 16 do
            local stepIndex = Q7GridSeq.stepId_to_stepIndex(i)
            
            if i == 16 then
                local bar = (barIndex % pat.num_bars) + 1
                tempPattern.bars[barIndex][stepIndex] = pat.bars[bar][Q7GridSeq.stepId_to_stepIndex(1)]
            else
                local nextStepIndex = Q7GridSeq.stepId_to_stepIndex(i + 1)
                tempPattern.bars[barIndex][stepIndex] = pat.bars[barIndex][nextStepIndex]
            end
        end
    end

    self.patterns[self.selected_pattern] = tempPattern

    self.bars = self.patterns[self.selected_pattern].bars
    self.bar_length = self.patterns[self.selected_pattern].bar_length
    self.num_bars = self.patterns[self.selected_pattern].num_bars
    self.total_step_count = self.bar_length * self.num_bars -- a 16 step bar is actually 64 steps

    print("Shifted notes left")

    self:change_selected_bar(self.selected_bar) -- causes bar to be copied to steps

    return true
end

function Q7GridSeq:shift_notes_right()
    local pat = self:get_selected_pattern()
    if pat == nil then return false end

    local tempPattern = self:create_new_pattern(pat.bar_length, pat.num_bars)

    for barIndex = 1, tempPattern.num_bars do
        for i = 1, 16 do
            local stepIndex = Q7GridSeq.stepId_to_stepIndex(i)
            
            if i == 16 then
                local bar = (barIndex % pat.num_bars) + 1
                tempPattern.bars[bar][Q7GridSeq.stepId_to_stepIndex(1)] = pat.bars[barIndex][stepIndex]
            else
                local nextStepIndex = Q7GridSeq.stepId_to_stepIndex(i + 1)
                tempPattern.bars[barIndex][nextStepIndex] = pat.bars[barIndex][stepIndex]
            end
        end
    end

    self.patterns[self.selected_pattern] = tempPattern

    self.bars = self.patterns[self.selected_pattern].bars
    self.bar_length = self.patterns[self.selected_pattern].bar_length
    self.num_bars = self.patterns[self.selected_pattern].num_bars
    self.total_step_count = self.bar_length * self.num_bars -- a 16 step bar is actually 64 steps

    print("Shifted notes right")

    self:change_selected_bar(self.selected_bar) -- causes bar to be copied to steps

    return true
end


function Q7GridSeq:change_selected_stepId(stepId)
    self:change_selected_step(Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:change_selected_step(stepIndex)
    -- local stepIndex = self:get_current_step_index()

    if stepIndex < 1 or stepIndex > self.bar_length then return end

    self.current_step = stepIndex

    local step = self.steps[stepIndex]

    print("Current Step: "..self.current_step)
    -- tab.print(step)

    self.gridKeys.lit_keys = {}
    for i,e in pairs(step.keys) do
        self.gridKeys.lit_keys[i] = e
    end
end

function Q7GridSeq:copy_step(stepIndex)
    self.clipboard_step = self:clone_step(self.steps[stepIndex])

    -- local stepIndex = stepId

    -- self.clipboard_step = {}
    -- self.clipboard_step.keys = {}
    -- self.clipboard_step.cond = self.steps[stepIndex].cond -- step condition
    -- self.clipboard_step.count = self.steps[stepIndex].count -- used for A:B conditions


    -- for i,e in pairs(self.steps[stepIndex].keys) do
    --     -- local e2 = {}

    --     -- e2.id = e.id
    --     -- e2.x = e.x
    --     -- e2.y = e.y
    --     -- e2.vel = e.vel
    --     -- e2.state = e.state
    --     -- e2.anim_step = 0
    --     -- e2.note_off_time = 0
    --     -- e2.note_length = e.note_length

    --     self.clipboard_step.keys[i] = Q7GridSeq.clone_noteEvent(e)
    -- end

    -- self.clipboard_step = self.steps[stepIndex]
end

function Q7GridSeq:paste_step(stepIndex)
    if self.clipboard_step == nil then return end
    -- local stepIndex = stepId

    self.steps[stepIndex] = self:clone_step(self.clipboard_step)

    -- self.steps[stepIndex] = {}
    -- self.steps[stepIndex].keys = {}
    -- self.steps[stepIndex].cond = self.clipboard_step.cond -- step condition
    -- self.steps[stepIndex].count = self.clipboard_step.count -- used for A:B conditions


    -- for i,e in pairs(self.clipboard_step.keys) do
    --     self.steps[stepIndex].keys[i] = Q7GridSeq.clone_noteEvent(e)
    -- end

    if self.current_step == stepIndex then
        self:change_selected_step(stepIndex)
    end
end

function Q7GridSeq:delete_stepId(stepId)
    self:delete_step(Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:delete_step(stepIndex)
    if stepId == self.current_step then
        self.gridKeys.lit_keys = {}
    end

    self.steps[stepIndex] = self:create_new_step()
    -- self.steps[stepIndex].keys = {}
    -- self.steps[stepIndex].cond = 1 -- step condition
    -- self.steps[stepIndex].count = 0 -- used for A:B conditions

    if self.current_step == stepIndex then
        self:change_selected_step(stepIndex)
    end
end

function Q7GridSeq:does_stepId_have_notes(stepId)
    stepId = stepId or self:get_current_stepId()
    return self:does_step_have_notes(Q7GridSeq.stepId_to_stepIndex(stepId))
end

function Q7GridSeq:does_step_have_notes(stepIndex)
    local step = self.steps[stepIndex]

    for i,e in pairs(step.keys) do
        return true
    end

    return false
end

function Q7GridSeq:does_step_have_notes_internal(step)
    if step == nil then 
        print("step is nil")
        return false end

    for i,e in pairs(step.keys) do
        return true
    end

    return false
end

function Q7GridSeq:does_bar_have_notes_internal(bar)
    if bar == nil then return false end

    for i = 1, 16 do
        if self:does_step_have_notes_internal(bar[i]) then
            return true
        end
    end

    return false
end

function Q7GridSeq:does_bar_have_notes(barIndex)
    if barIndex < 1 or barIndex > #self.bars then return false end

    local pat = self.patterns[self.selected_pattern]
    if pat == nil then return false end

    if pat.bars[barIndex] == nil then return false end

    return self:does_bar_have_notes_internal(pat.bars[barIndex])
end

function Q7GridSeq:does_pattern_have_notes_internal(pattern)
    for barIndex = 1, pattern.num_bars do
        if self:does_bar_have_notes_internal(pattern.bars[barIndex]) then
            return true
        end
    end

    return false
end

function Q7GridSeq:does_pattern_have_notes(patternIndex)
    if patternIndex < 1 or patternIndex > 16 then return false end

    if self.patterns[patternIndex] == nil then return false end

    return self:does_pattern_have_notes_internal(self.patterns[patternIndex])
end

function Q7GridSeq:does_pattern_exist(patternIndex)
    if patternIndex < 1 or patternIndex > 16 then return false end

    return self.patterns[patternIndex] ~= nil
end

function Q7GridSeq:key_on(e)
    -- print("key_on id: "..e.id.." yID: " ..e.y)

    -- print(self.name)

    local stepIndex = self:get_current_step_index()

    if self.step_edit then
        if self.gridKeys.lit_keys[e.id] == nil then
            if self:does_step_have_notes(stepIndex) then
                e.vel = self:get_step_velocity(stepIndex)
                e.note_length = self:get_step_note_length(stepIndex)
                -- e.probability = self:get_step_probability(stepIndex)
                e.probability = 1 -- replaced by .cond on step
            end

            self.gridKeys.lit_keys[e.id] = e

            self.steps[stepIndex].keys[e.id] = e
        else
            self.gridKeys.lit_keys[e.id] = nil

            self.steps[stepIndex].keys[e.id] = nil

        end

        -- local step = self.steps[stepIndex]

        -- tab.print(step)
    elseif self.is_playing and self.record then

        local pat = self:get_active_pattern()
        if pat ~= nil then 
            self.record_keys[e.id] = e

            -- quantize to nearest 16th
            -- local next_16th_time = self.last_16th_time + 0.25
            -- if clock.get_beats() < (self.last_16th_time + ((next_16th_time - self.last_16th_time) * 0.5)) then

            -- if clock.
            -- self.sub_step_counter 

            local substep_count = self:get_substep_count()

            -- e.record_start = self.last_16th_index
            -- e.record_bar = self.play_bar_position
            -- e.record_offset = self.sub_step_counter


            if self.sub_step_counter <= substep_count / 2 then
                e.record_start = self.last_16th_index
                e.record_bar = self.play_bar_position
                e.record_offset = self.sub_step_counter
            else
                e.record_start = self.last_16th_index + 1
                e.record_bar = self.play_bar_position
                
                e.record_offset = 0 - (substep_count - self.sub_step_counter)

                if e.record_start > pat.bar_length then
                    e.record_start = 1
                    e.record_bar = (self.play_bar_position % pat.num_bars) + 1
                end
            end

            print("Record_start "..e.record_start.." bar "..e.record_bar.." Record offset "..e.record_offset)


            -- if clock.get_beats() < (self.last_16th_time + 0.1875) then
            --     e.record_start = self.last_16th_index
            --     e.record_bar = self.play_bar_position
            -- else
            --     e.record_start = self.last_16th_index
            --     e.record_bar = self.play_bar_position

            --     if e.record_start > 16 then
            --         e.record_start = 1
            --         e.record_bar = (self.play_bar_position % self.num_bars) + 1
            --     end
            -- end

            -- print("tempo: " .. clock.get_tempo())
            -- print("beats: " .. clock.get_beats())
            -- print("beat_sec: " .. clock.get_beat_sec())

            -- local bpm = clock.get_beat_sec()

            -- params:string("clock_tempo")

            -- local interval_16 = 60 / 


            -- self.last_16th_time

            -- e.record_start = self.position
            -- e.record_bar = self.play_bar_position
            e.elapsed_steps = self.elapsed_steps
        end
    end

    if not self.is_playing then
        
    end
end

function Q7GridSeq:key_off(e)
    -- print("key_off id: "..e.id.." yID: " ..e.y)
    -- print(self.name)

    if self.is_playing and self.record then

        if not self.step_edit and self.record_keys[e.id] ~= nil then
            local pat = self:get_active_pattern()
            if pat ~= nil then 
                local record_note = self.record_keys[e.id]
                record_note.note_length = self.elapsed_steps - record_note.elapsed_steps

                local step = pat.bars[record_note.record_bar][record_note.record_start]

                if self:does_step_have_notes_internal(step) == false then
                    pat.bars[record_note.record_bar][record_note.record_start].length = record_note.note_length
                    pat.bars[record_note.record_bar][record_note.record_start].offset = record_note.record_offset
                end

                pat.bars[record_note.record_bar][record_note.record_start].keys[e.id] = record_note
                self.record_keys[e.id] = nil

                -- 1 x x x 1 x x x 1 x  x  x
                -- 1 2 3 4 5 6 7 8 9 10 11 12
                -- x N x x x - put note on step 1
                -- x x x N x - put note on step 5
                -- x x N x x - put step on 1 or 5? hmm, maybe put on 1 for now. 
                -- though we could record time every step is triggered then record it's time offset

                -- local floor_16th = 

                -- local mod = record_note.record_start % 4
                -- local step_index = record_note.record_start - mod


                -- if mod >= 2 then
                --     step_index = step_index + 4
                -- end

                -- if step_index > 64 then
                --     step_index = step_index - 64
                -- elseif step_index < 1 then
                --     step_index = step_index + 64
                -- end

                -- self.steps[step_index][e.id] = record_note

                -- local step = self.bars[self.play_bar_position][stepIndex]

                
            end
        end
    end
end

function Q7GridSeq:set_record_state(newRecordState)
    self.record = newRecordState
    self.record_keys = {}
end

return Q7GridSeq