-- gridstep
--
-- a polyphonic, isomorphic 
-- grid keyboard sequencer

local _MOLLY_ENGINE = false
local _TIMBER_ENGINE = true

local MollyThePoly = nil
if _MOLLY_ENGINE then
    MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
    engine.name = "MollyThePoly"
end

local Timber = nil
local NUM_SAMPLES = 16

if _TIMBER_ENGINE then
    Timber = include("timber/lib/timber_engine")
    engine.name = "Timber"
end

local music = require 'musicutil'
local beatclock = require 'beatclock'

_GRID_CAPTURE = false

local gcap = nil

if _GRID_CAPTURE then
    gcap = require 'GridCapture/GridCapture'
end

local Q7Util = require 'gridstep/lib/Q7Util'
local UI = require 'gridstep/lib/Q7UI'
local Q7GridKeys = require 'gridstep/lib/Q7GridKeys'
local Q7GridSeq = require 'gridstep/lib/Q7GridSeq'
local ParamListUtil = require 'gridstep/lib/Q7ParamListUtil'
local GraphicPageOptions = require 'gridstep/lib/Q7GraphicPageOptions'

local fileselect = require 'fileselect'
local textentry = require 'textentry'

local version_number = "1.2.1"

local g = grid.connect()

local gridType_none = 0
local gridType_128 = 1
local gridType_64 = 2
local gridType = 1

local gridKeys = {}
local gridSeq = {} 

local midi_1 = midi.connect(1)
local midi_2 = midi.connect(2)
local midi_3 = midi.connect(3)
local midi_4 = midi.connect(4)

local midi_devices = {midi_1, midi_2, midi_3, midi_4}

local active_midi_notes = {}

local active_internal_notes = {}


local SoundModes = {"Internal", "External"}

local all_gridKeys = {}
local all_gridSeqs = {}

local config = {
    page_index = 1,
    grid_page_index = 1,
    root_note = 1,
    scale_mode = 1,
    note_velocity = 100,
    header_img = 1,
    ui_anim_step = 0,
    header_notification_y = -10,
}

-- for changing values with encoders nicely
local enc_d = {
    page_index = 1,
    root_note = 1,
    scale_mode = 1
}

local data_path = _path.data.."gridstep/"
local params_path = _path.data.."gridstep/params/"
local screenshot_path = _path.data.."gridstep/screenshots/"
local img_path = _path.code.."gridstep/img/"

local project_name = ""

local fileselect_active = false
local textentry_active = false

local PageTest = {}
local PageScale = {}
local PageSound = {}
local PageTrack = {}
local PageClock = {}
local PageSaveLoad = {}
local PageQ7 = {}

local PageTrig = {} -- shown when step key is held
local PageMicroTiming = {}
local showTrigPage = false

local current_page = {}

local pages = {PageScale, PageSound, PageClock, PageTrack, PageTrig, PageMicroTiming, PageSaveLoad, PageQ7}
local page_titles = {"Scale", "Sound", "Clock", "Track", "Trig", "Step Time", "Save / Load", "Credits"}

local header_height = 12

local GridPlay = {}
local GridSeq = {}
local GridSeqVel = {}
local GridSeqNoteLengths = {}
local GridPatLaunch = {}

local current_grid_page = {}

local grid_pages = {GridPlay, GridPatLaunch, GridSeq, GridSeqVel, GridSeqNoteLengths}
local grid_page_names = {"GridPlay", "GridPatLaunch", "GridSeq", "GridSeqVel", "GridSeqNoteLengths"}


local gridSeqConfig = {
    step_counter = {}
}
local patLaunchConfig = {
    edit_mode = 1,
    clipboard_pattern = nil,
    clipboard_gridSeq = nil,
    clipboard_gridKeys = nil,
    track_paste_mode, -- determines whether to paste gridSeq or gridKeys
    y_offset = 0
}

local whiteKeys = {1,0,1,0,1,1,0,1,0,1,0,1}
local pattern_num_to_letter = {"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P"}

local held_step = 0
local grid_dirty = false

GridPatLaunch.edit_mode = seqmode_select
GridPatLaunch.clipboard_pattern = nil

local seq_noteLengths = {1, 2, 4, 8, 16, 32}

-- local seq_active = false

-- local seq_delete = false
local seq_cut = false
local seq_copy = false
local seq_paste = false

local mode_off_brightness = 6
local mode_on_brightness = 12

local shift_brightness = 7

local shift_down = false

local track = 1

local is_playing = false

local edit_steps_9_16 = false -- for 64x64 grids

local blink_on = false -- used to blink keys
local blink_fade = 1
local blink_fade_t1 = 1
local blink_fade_t2 = 0
local blink_fade_d = 0.25
local blink_fade_p = 0.25
local blink_counter = 0

local confirm_delete = false

local gridImage_x = {
    {1,1},{2,2},{3,3},{4,4},{5,5},
    {1,5},{2,4},{4,2},{5,1},
}

local gridImage_cut = {
    {8,3},{9,3},
}

local gridImage_copy = {
    {4,2},{5,2},{6,2},{11,2},{12,2},{13,2},
    {4,3},{8,3},{9,3},{13,3},
    {4,4},{5,4},{6,4},{11,4},{12,4},{13,4}
}

local gridImage_paste = {
    {4,2},{5,2},{6,2},{7,2},{8,2},{9,2},{10,2},{11,2},{12,2},{13,2},
    {4,3},{13,3},
    {4,4},{5,4},{6,4},{7,4},{8,4},{9,4},{10,4},{11,4},{12,4},{13,4}
}

local notification_clockId = 0
local display_notification = false
local temp_notification = false
local notification_text = "none"

-- init
function init()
    if g.cols == 16 and g.rows == 8 then
        print("grid 128 detected")
        gridType = gridType_128
    elseif g.cols == 8 and g.rows == 8 then
        print("grid 64 detected")
        gridType = gridType_64
    else
        gridType = gridType_none
    end

    -- gridType = gridType_64 -- uncomment to fake 8x8 grid


    current_page = pages[config.page_index]
    current_grid_page = grid_pages[config.grid_page_index]

    if _MOLLY_ENGINE then
        MollyThePoly.add_params()
        MollyThePoly.randomize_params("lead")
    end

    if _TIMBER_ENGINE then
        Timber.sample_changed_callback = function(id)
            if Timber.samples_meta[id].manual_load then
                -- Set our own loop point defaults
                params:set("loop_start_frame_" .. id, util.round(Timber.samples_meta[id].num_frames * 0.2))
                params:set("loop_end_frame_" .. id, util.round(Timber.samples_meta[id].num_frames * 0.4))
                
                -- Set env defaults
                params:set("amp_env_attack_" .. id, 0.01)
                params:set("amp_env_sustain_" .. id, 0.8)
                params:set("amp_env_release_" .. id, 0.4)
            end
            -- callback_set_screen_dirty(id)
        end

        Timber.add_params()
        params:add_separator()
        for i = 0, NUM_SAMPLES - 1 do
            Timber.add_sample_params(i)
            Timber.load_sample(i, _path.code .. "/timber/audio/piano-c.wav")
        end

    end

    -- param_list_util = ParamListUtil.new()
    -- param_list_util.redraw_func = redraw

    gridKeys = {}
    gridSeq = {}

    for i = 1,16 do
        all_gridKeys[i] = Q7GridKeys.new(16,8)

        all_gridKeys[i].id = i
        all_gridKeys[i].midi_device = 1
        all_gridKeys[i].midi_channel = i
        all_gridKeys[i].sound_mode = 1

        all_gridKeys[i].note_on = grid_note_on
        all_gridKeys[i].note_off = grid_note_off

        all_gridSeqs[i] = Q7GridSeq.new(all_gridKeys[i])

        all_gridKeys[i].gridSeq = all_gridSeqs[i]
        -- all_gridSeqs[i].on_new_step = seq_newStep
    end

    gridKeys = all_gridKeys[track]
    gridSeq = all_gridSeqs[track]
    
    for d = 1,4 do
        active_midi_notes[d] = {}

        for i = 1, 16 do
            active_midi_notes[d][i] = {}
        end
    end

    -- gridKeys = Q7GridKeys.new(16,8)

    -- gridKeys.note_on = grid_note_on
    -- gridKeys.note_off = grid_note_off

    -- for i = 1,16 do
    --     gridSeqs[i] = Q7GridSeq.new(gridKeys)
    -- end

    -- gridSeq = Q7GridSeq.new(gridKeys)


    

    -- gridKeys.key_on = function(e) grid_key_on(e) end
    -- gridKeys.key_off = function(e) grid_key_off(e) end

    -- gridKeys:resize_grid(1,1,16,7)
    -- gridKeys:change_scale(config.root_note, config.scale_mode)

    -- gridKeys.highlight_selected_notes = false
    -- gridKeys.layout_mode = 2

    for i,gk in pairs(all_gridKeys) do
        gk:resize_grid(1,1,16,7)
        gk:change_scale(config.root_note, config.scale_mode)
        gk.highlight_selected_notes = false
        gk.layout_mode = 2
    end

    -- local note = gridKeys:grid_to_note(10,4)
    -- print("note = "..note)

    -- print("gridKeys.layout_mode = "..gridKeys.layout_mode)
    -- print("gridKeys2.layout_mode = "..gridKeys2.layout_mode)

    for i,p in pairs(pages) do
        if p.init ~= nil then p.init() end
    end

    PageTrig.init()
    change_grid_page("GridPlay")

    -- if current_page.init ~= nil then current_page.init() end

    grid_redraw()

    if _GRID_CAPTURE then
        gcap:set_grid(g)
        -- gcap:set_theme("bw")
    end

    clock.run(screen_redraw_clock)
    clock.run(grid_redraw_clock) -- start the grid redraw clock
end

function create_new_project()
    if is_playing then
        clock.transport.stop()
    end
    all_midi_notes_off()
    all_engine_notes_off()

    config = {
        page_index = 1,
        grid_page_index = 1,
        root_note = 1,
        scale_mode = 1,
        note_velocity = 100,
        header_img = 1,
        ui_anim_step = 0,
        header_notification_y = -10,
    }

    gridSeqConfig = {
        step_counter = {}
    }
    
    patLaunchConfig = {
        edit_mode = 1,
        clipboard_pattern = nil,
        clipboard_gridSeq = nil,
        clipboard_gridKeys = nil,
        track_paste_mode, -- determines whether to paste gridSeq or gridKeys
        y_offset = 0
    }

    held_step = 0

    GridPatLaunch.edit_mode = seqmode_select
    GridPatLaunch.clipboard_pattern = nil

    seq_cut = false
    seq_copy = false
    seq_paste = false

    shift_down = false

    track = 1

    is_playing = false

    confirm_delete = false

    current_page = pages[config.page_index]
    current_grid_page = grid_pages[config.grid_page_index]

    if _MOLLY_ENGINE then
        MollyThePoly.randomize_params("lead")
    end

    gridKeys = {}
    gridSeq = {}

    for i = 1,16 do
        all_gridKeys[i] = Q7GridKeys.new(16,8)

        all_gridKeys[i].id = i
        all_gridKeys[i].midi_device = 1
        all_gridKeys[i].midi_channel = i
        all_gridKeys[i].sound_mode = 1

        all_gridKeys[i].note_on = grid_note_on
        all_gridKeys[i].note_off = grid_note_off

        all_gridSeqs[i] = Q7GridSeq.new(all_gridKeys[i])

        all_gridKeys[i].gridSeq = all_gridSeqs[i]
        -- all_gridSeqs[i].on_new_step = seq_newStep
    end

    gridKeys = all_gridKeys[track]
    gridSeq = all_gridSeqs[track]
    
    for d = 1,4 do
        active_midi_notes[d] = {}

        for i = 1, 16 do
            active_midi_notes[d][i] = {}
        end
    end

    for i,gk in pairs(all_gridKeys) do
        gk:resize_grid(1,1,16,7)
        gk:change_scale(config.root_note, config.scale_mode)
        gk.highlight_selected_notes = false
        gk.layout_mode = 2
    end
   
    for i,p in pairs(pages) do
        if p.init ~= nil then p.init() end
    end

    PageTrig.init()
    change_grid_page("GridPlay")

    grid_redraw()

    show_temporary_notification("New Project Created")

    -- clock.run(screen_redraw_clock)
    -- clock.run(grid_redraw_clock) -- start the grid redraw clock
end

function kill_all_notes()
    if is_playing then
        clock.transport.stop()
    end
    all_midi_notes_off()

    if _TIMBER_ENGINE then
        engine.noteKillAll()
    end

    if _MOLLY_ENGINE then
        all_engine_notes_off()
    end
end

function stop()
    print("stop")
end

function screen_redraw_clock()
    while true do
        clock.sleep(1/15)
        redraw()
    end
end

function grid_redraw_clock() -- our grid redraw clock
    while true do -- while it's running...
        clock.sync(1/8)
        --   clock.sleep(1/15) -- refresh at 30fps.

        blink_counter = (blink_counter + 1) % 2

        if blink_counter == 0 then
            blink_on = not blink_on
        end


        -- triangle wave fade
        blink_fade_p = blink_fade_p + blink_fade_d

        if blink_fade_p > 1 then
            blink_fade_p = 0

            if blink_fade_t1 == 1 then
                blink_fade_t1 = 0
                blink_fade_t2 = 1
            else
                blink_fade_t1 = 1
                blink_fade_t2 = 0
            end
        end

        blink_fade = util.linlin(0,1, blink_fade_t1, blink_fade_t2, blink_fade_p)

        -- blink_fade = util.linlin(-1,1,0,1, math.sin(clock.get_beats() * 1.57 * 2 ))

        -- print("Blink_fade: "..blink_fade)

        if gridKeys:animate() or is_playing or gridSeq.record then
            grid_redraw()
        end

        config.ui_anim_step = config.ui_anim_step + 1

        if config.ui_anim_step > 2 then
            config.ui_anim_step = 1

            if is_playing then
                config.header_img = (config.header_img % 4) + 1
            end
        end


        -- redraw()
    end
end

function toggle_playback()
    if is_playing then
        clock.transport.stop()
        all_midi_notes_off()
        show_temporary_notification("Stop")
    else
        clock.transport.start()
        show_temporary_notification("Play")
    end
end

function clock.transport.start()
    -- print("we begin")
    -- position = 16
    -- id = clock.run(count)
    active_internal_notes = {}

    for i,seq in pairs(all_gridSeqs) do
        seq:play_start()
    end

    if not is_playing then
        is_playing = true
        play_clock_id = clock.run(play_sequence)
    end
end
  
function clock.transport.stop()
    -- clock.cancel(id)
    for i,seq in pairs(all_gridSeqs) do
        seq:play_stop()
    end
    -- gridSeq:play_stop()
    

    if is_playing then
        clock.cancel(play_clock_id)
        is_playing = false

        all_engine_notes_off()
    end
end

function play_sequence()

    -- local beats = clock.get_beats()
    -- local beat_int = math.floor(beats)
    -- local beat_frac = beats % beat_int
    -- local next_16th = beat_int

    -- if beat_frac < 0.25 then
    --     next_16th = beat_int + 0.25
    -- elseif beat_frac < 0.5 then
    --     next_16th = beat_int + 0.5
    -- elseif beat_frac < 0.75 then
    --     next_16th = beat_int + 0.75
    -- else
    --     next_16th = beat_int + 1
    -- end

    -- clock.sync(next_16th - beats) -- sleep until clock is on next 16th for perfect sync
    -- might want to do this every step, we'll see

    while is_playing do
        -- print("beats: " .. clock.get_beats())

        -- self:clock_step16()

        for i,seq in pairs(all_gridSeqs) do
            seq:clock_step16()
        end

        active_internal_notes = {} -- prevents notes from playing on top of each other in a step

        -- clock.sync(1/24) -- 6 substeps
        clock.sync(1/48) -- 12 substeps

        -- grid_redraw()

        -- clock.sync(1/16)
    end
end

-- function grid_key_on(e)
--     if e ~= nil then
--         print("e not nil")
--     else
--         print("e is nil")
--     end

--     print("key_on id: "..e.id.." yID: " ..e.y)
--     gridSeq:key_on(e)
-- end

-- function grid_key_off(noteNum)
--     gridSeq:key_off(e)
-- end

function change_track(newTrack)
    if newTrack == track or newTrack < 1 or newTrack > 16 then
        return false
    end

    track = newTrack

    local prevGridKeys = gridKeys
    local prevGridSeq = gridSeq

    gridKeys = all_gridKeys[track]
    gridSeq = all_gridSeqs[track]

    gridSeq.step_edit = prevGridSeq.step_edit
    gridKeys:resize_grid(prevGridKeys.grid_x, prevGridKeys.grid_y, prevGridKeys.grid_width, prevGridKeys.grid_height)
    gridSeq:select_step(prevGridSeq.current_step)
    gridKeys.enable_key_playback = prevGridKeys.enable_key_playback
    gridSeq.edit_mode = prevGridSeq.edit_mode

    -- PageTrack.init()
    return true
end

function change_gridKey_layout()
    gridKeys.layout_mode = (gridKeys.layout_mode == 1) and 2 or 1

    if gridKeys.sound_mode == 1 then
        all_engine_notes_off()
    else
        all_midi_notes_off(gridKeys.midi_device)
    end

    show_temporary_notification("Grid Layout = "..Q7GridKeys.layout_names[gridKeys.layout_mode])
end

function change_grid_page(newMode)
    showTrigPage = false -- hide trig page

    held_step = 0

    -- GridPlay, GridSeq, GridSeqVel, GridSeqNoteLengths
    if newMode == "GridPlay" then
        config.grid_page_index = 1
        current_grid_page = grid_pages[config.grid_page_index]
        gridSeq.step_edit = false
        if gridType == gridType_64 then
            gridKeys:resize_grid(1,1,8,7)
        else
            gridKeys:resize_grid(1,1,16,7)
        end
        gridSeq:clear_step_edit()
        gridSeq.edit_mode = seqmode_select
        gridKeys.enable_key_playback = true

        show_temporary_notification("Grid Play")
    elseif newMode == "GridPatLaunch" then
        config.grid_page_index = 2
        current_grid_page = grid_pages[config.grid_page_index]
        gridSeq.step_edit = false
        -- gridKeys:resize_grid(1,2,14,6)
        gridSeq:clear_step_edit()
        gridSeq.edit_mode = seqmode_select
        gridKeys.enable_key_playback = false
        gridSeq:select_step(gridSeq.current_step)
        show_temporary_notification("Pattern Launch")
    elseif newMode == "GridSeq" then
        config.grid_page_index = 3
        current_grid_page = grid_pages[config.grid_page_index]
        gridSeq.step_edit = true
        if gridType == gridType_64 then
            gridKeys:resize_grid(1,2,8,6)
        else
            gridKeys:resize_grid(1,2,14,6)
        end
        
        gridSeq:select_step(gridSeq.current_step)

        if gridSeq.is_playing then
            gridKeys.enable_key_playback = false
        end

        show_temporary_notification("Edit Seq")
    elseif newMode == "GridSeqVel" then
        config.grid_page_index = 4
        current_grid_page = grid_pages[config.grid_page_index]
        gridSeq.step_edit = true
        gridSeq:clear_step_edit()
        gridSeq.edit_mode = seqmode_select
        gridKeys.enable_key_playback = false

        show_temporary_notification("Edit Vel")
    elseif newMode == "GridSeqNoteLengths" then
        config.grid_page_index = 5
        current_grid_page = grid_pages[config.grid_page_index]
        gridSeq.step_edit = true
        gridSeq:clear_step_edit()
        gridSeq.edit_mode = seqmode_select
        gridKeys.enable_key_playback = false
        show_temporary_notification("Edit Note Length")

    end
end

function screenshot()
    if not util.file_exists(screenshot_path) then
        util.make_dir(screenshot_path)
    end

    local screenNumber = 1
    local screenPath = screenshot_path.."screenshot_"..screenNumber..".png"

    while util.file_exists(screenPath) do
        screenNumber = screenNumber + 1
        screenPath = screenshot_path.."screenshot_"..screenNumber..".png"
    end

    _norns.screen_export_png(screenPath)
    show_temporary_notification("Screenshot saved")
end

function grid_screenshot()
    if _GRID_CAPTURE then
        if not util.file_exists(screenshot_path) then
            util.make_dir(screenshot_path)
        end

        local screenNumber = 1
        local screenPath = screenshot_path.."grid_screenshot_"..screenNumber..".png"

        while util.file_exists(screenPath) do
            screenNumber = screenNumber + 1
            screenPath = screenshot_path.."grid_screenshot_"..screenNumber..".png"
        end

        gcap:screenshot(screenPath)

        show_temporary_notification("Screenshot saved")
    end
end

function grid_record()
    if _GRID_CAPTURE then
        if not util.file_exists(screenshot_path) then
            util.make_dir(screenshot_path)
        end

        local screenNumber = 1
        local screenPath = screenshot_path.."grid_record_"..screenNumber..".gif"

        while util.file_exists(screenPath) do
            screenNumber = screenNumber + 1
            screenPath = screenshot_path.."grid_record_"..screenNumber..".gif"
        end

        gcap:record(24, 5, screenPath)

        show_temporary_notification("Gif saved")
    end
end

function grid_note_on(gKeys, noteNum, vel)
    vel = vel or 100 
    -- print("Note On: " .. noteNum.. " " .. vel .. " " .. music.note_num_to_name(noteNum))

    if gKeys.sound_mode == 1 then

        if active_internal_notes[noteNum] == nil then -- prevent the same note from playing on top of itself
            local n = {}
            n.noteNum = noteNum
            n.vel = vel
            n.channel = gKeys.midi_channel

            active_internal_notes[noteNum] = n

            if _MOLLY_ENGINE then
                engine.noteOn(noteNum, music.note_num_to_freq(noteNum), vel / 127)
            end

            if _TIMBER_ENGINE then
                local sample_id = gKeys.midi_channel - 1
                local voice_id = sample_id * 128 + noteNum

                engine.noteOn(voice_id, music.note_num_to_freq(noteNum), vel / 127, sample_id)
            end
        end

        -- if is_playing then
            
        -- else
        --     engine.noteOn(noteNum, music.note_num_to_freq(noteNum), vel / 127)
        -- end
    elseif gKeys.sound_mode == 2 then -- midi out
        local m = midi_devices[gKeys.midi_device]

        if m ~= nil then
            m:note_on(noteNum, vel, gKeys.midi_channel)

            local n = {}
            n.noteNum = noteNum
            n.vel = vel
            n.channel = gKeys.midi_channel

            active_midi_notes[gKeys.midi_device][gKeys.midi_channel][noteNum] = n
        end
    end
end

function grid_note_off(gKeys, noteNum)
    -- print("Note Off: " .. noteNum .. " " .. music.note_num_to_name(noteNum))

    if gKeys.sound_mode == 1 then
        if not is_playing and active_internal_notes[noteNum] ~= nil then -- prevent the same note from playing on top of itself
            active_internal_notes[noteNum] = nil
        end

        if _MOLLY_ENGINE then
            engine.noteOff(noteNum)
        end

        if _TIMBER_ENGINE then
            local sample_id = gKeys.midi_channel - 1
            local voice_id = sample_id * 128 + noteNum

            engine.noteOff(voice_id)
        end
    elseif gKeys.sound_mode == 2 then
        local m = midi_devices[gKeys.midi_device]

        if m ~= nil then
            m:note_off(noteNum, 0, gKeys.midi_channel)
            active_midi_notes[gKeys.midi_device][gKeys.midi_channel][noteNum] = nil
        end
        
    end
end

function all_engine_notes_off()
    if _MOLLY_ENGINE then
        engine.noteOffAll()
    end

    if _TIMBER_ENGINE then
        engine.noteOffAll()
    end
end

function all_midi_notes_off(deviceId)
    -- active_internal_notes = {}

    if deviceId == nil then
        for d = 1,4 do
            local m = midi_devices[d]

            if m ~= nil then
                for c = 1,16 do
                    for i,n in pairs(active_midi_notes[d][c]) do
                        m:note_off(n.noteNum, 0, c)
                    end

                    active_midi_notes[d][c] = {}
                end
            end
        end
    else
        local m = midi_devices[deviceId]

        if m ~= nil then
            for c = 1,16 do
                for i,n in pairs(active_midi_notes[d][c]) do
                    m:note_off(n.noteNum, 0, c)
                end

                active_midi_notes[d][c] = {}
            end
        end
    end
end

g.key = function(x,y,z)
    grid_dirty = false
    current_grid_page.grid_key(x,y,z)

    if grid_dirty then
        grid_redraw()
    end
end

function grid_key_toolbar( x, y, z)
    if gridType == gridType_128 then
        grid_key_toolbar_128(x,y,z)
    elseif gridType == gridType_64 then
        grid_key_toolbar_64(x,y,z)
    end
end

function grid_key_toolbar_128( x, y, z)
    if not shift_down then
        if z == 1 then -- key pressed
            if y == 8 then
                if x == 1 then -- Toggle playback
                    toggle_playback()
                    grid_dirty = true
                elseif x == 2 then -- shift
                    shift_down = true
                    show_temporary_notification("Shift")
                    grid_dirty = true
                elseif x == 3 then -- change to play mode
                    if config.grid_page_index ~= 1 then
                        change_grid_page("GridPlay")
                        grid_dirty = true
                    end
                elseif x == 4 then -- change to pat launch mode
                    if config.grid_page_index ~= 2 then
                        change_grid_page("GridPatLaunch")
                        grid_dirty = true
                    end
                elseif x == 5 then -- switch to seq edit mode
                    if config.grid_page_index ~= 3 then
                        change_grid_page("GridSeq")
                        grid_dirty = true
                    end
                end
            end
        else  -- key released
        end
    elseif shift_down then -- Shift Mode
        if z == 1 then -- key pressed
        else  -- key released
            if y == 8 then
                if x == 2 then -- shift
                    shift_down = false
                    gridSeq.edit_mode = seqmode_select
                    grid_dirty = true
                end
            end
        end
    end
end

function grid_key_toolbar_64( x, y, z)
    if not shift_down then
        if z == 1 then -- key pressed
            if y == 8 then
                if x == 1 then -- Toggle playback
                    toggle_playback()
                    grid_dirty = true
                elseif x == 2 then -- shift
                    shift_down = true
                    show_temporary_notification("Shift")
                    grid_dirty = true
                elseif x == 3 then -- change mode
                    local new_page = (config.grid_page_index % 3) + 1
                    change_grid_page(grid_page_names[new_page])
                    grid_dirty = true
                elseif x == 7 then -- edit steps 1-8
                    edit_steps_9_16 = false
                    show_temporary_notification("Edit 1-8")
                    grid_dirty = true
                elseif x == 8 then -- edit steps 9-16
                    edit_steps_9_16 = true
                    show_temporary_notification("Edit 9-16")
                    grid_dirty = true
                end
            end
        else  -- key released
        end
    elseif shift_down then -- Shift Mode
        if z == 1 then -- key pressed
            if y == 8 then
                if x == 7 then -- edit steps 1-8
                    edit_steps_9_16 = false
                    show_temporary_notification("Edit 1-8")
                    grid_dirty = true
                elseif x == 8 then -- edit steps 9-16
                    edit_steps_9_16 = true
                    show_temporary_notification("Edit 9-16")
                    grid_dirty = true
                end
            end
        else  -- key released
            if y == 8 then
                if x == 2 then -- shift
                    shift_down = false
                    gridSeq.edit_mode = seqmode_select
                    grid_dirty = true
                end
            end
        end
    end
end

function grid_key_shift( x, y, z)
    if shift_down then
        if gridType == gridType_128 then
            grid_key_shift_128(x,y,z)
        elseif gridType == gridType_64 then
            grid_key_shift_64(x,y,z)
        end
    end
end

function grid_key_shift_128( x, y, z)
    if z == 1 then -- key pressed Shift Mode
        if y == 1 then -- mute step
            if gridSeq:set_stepId_mute(x) then
                show_temporary_notification("Mute: "..x.." "..(gridSeq:get_stepId_mute(x) and "true" or "false" ))
                grid_dirty = true
            end
        elseif y == 2 then -- change bar length
            gridSeq:set_length(x, gridSeq.num_bars)
            show_temporary_notification("Bar Length: "..gridSeq.bar_length)
            grid_dirty = true
        elseif y == 3 then -- change number of bars
            gridSeq:set_length(gridSeq.bar_length, x)
            show_temporary_notification("Bar Count: "..gridSeq.num_bars)
            grid_dirty = true
        elseif y == 4 then -- select bar
            if gridSeq:change_selected_bar(x) then
                show_temporary_notification("Bar: "..gridSeq.selected_bar)
            end
            grid_dirty = true
        elseif y == 5 then -- select pattern
            if gridSeq:change_selected_pattern(x) then
                show_temporary_notification("Pattern: "..get_pattern_letter())
            end
            grid_dirty = true
        elseif y == 7 then -- change track
            change_track(x)
            show_temporary_notification("Track: "..track)
            grid_dirty = true
        end
    else -- key released Shift Mode
    end
end

function grid_key_shift_64(x,y,z)

    local xOff = edit_steps_9_16 and 8 or 0
    x = x + xOff

    if z == 1 then -- key pressed Shift Mode
        if y == 1 then -- mute step
            if gridSeq:set_stepId_mute(x) then
                show_temporary_notification("Mute: "..x.." "..(gridSeq:get_stepId_mute(x) and "true" or "false" ))
                grid_dirty = true
            end
        elseif y == 2 then -- change bar length
            gridSeq:set_length(x, gridSeq.num_bars)
            show_temporary_notification("Bar Length: "..gridSeq.bar_length)
            grid_dirty = true
        elseif y == 3 then -- change number of bars
            gridSeq:set_length(gridSeq.bar_length, x)
            show_temporary_notification("Bar Count: "..gridSeq.num_bars)
            grid_dirty = true
        elseif y == 4 then -- select bar
            if gridSeq:change_selected_bar(x) then
                show_temporary_notification("Bar: "..gridSeq.selected_bar)
            end
            grid_dirty = true
        elseif y == 5 then -- select pattern
            if gridSeq:change_selected_pattern(x) then
                show_temporary_notification("Pattern: "..get_pattern_letter())
            end
            grid_dirty = true
        elseif y == 7 then -- change track
            change_track(x)
            show_temporary_notification("Track: "..track)
            grid_dirty = true
        end
    else -- key released Shift Mode
    end
end


function GridPlay.grid_key(x,y,z)
    if not shift_down then
        if gridType == gridType_128 then
            grid_dirty = gridKeys:grid_key(x,y,z)
        elseif gridType == gridType_64 then
            if (y == 7 and x == 7) or (y == 7 and x == 8) then
            else
                grid_dirty = gridKeys:grid_key(x,y,z)
            end
        end
    end

    if not shift_down then
        if z == 1 then -- key pressed
            if gridType == gridType_128 then
                if y == 8 then
                    if x == 13 then -- change keyboard layout to in-scale
                        change_gridKey_layout()
                        grid_dirty = true
                    elseif x == 14 then -- enable highlighted notes
                        gridKeys.enable_note_highlighting = not gridKeys.enable_note_highlighting
                        show_temporary_notification(gridKeys.enable_note_highlighting and "Show notes" or "Hide notes")
                        grid_dirty = true
                    elseif x == 15 then -- scroll grid keyboard down
                        gridKeys:scroll_down()
                        grid_dirty = true
                    elseif x == 16 then -- scroll grid keyboard up
                        gridKeys:scroll_up()
                        grid_dirty = true
                    end
                end
            elseif gridType == gridType_64 then
                if y == 7 then
                    if x == 7 then -- scroll grid keyboard down
                        gridKeys:scroll_down()
                        grid_dirty = true
                    elseif x == 8 then -- scroll grid keyboard up
                        gridKeys:scroll_up()
                        grid_dirty = true
                    end
                elseif y == 8 then
                    if x == 5 then -- change keyboard layout to in-scale
                        change_gridKey_layout()
                        grid_dirty = true
                    elseif x == 6 then -- enable highlighted notes
                        gridKeys.enable_note_highlighting = not gridKeys.enable_note_highlighting
                        show_temporary_notification(gridKeys.enable_note_highlighting and "Show notes" or "Hide notes")
                        grid_dirty = true
                    end
                end
            end
        else  -- key released
        end
    elseif shift_down then -- Shift Mode
        if z == 1 then -- key pressed
            if y == 8 then -- Tool bar
                if confirm_delete and x ~= 5 then
                    confirm_delete = false
                    clear_notification()
                end

                if x == 1 then
                    gridSeq:set_record_state(not gridSeq.record)
                    show_temporary_notification("Record "..(gridSeq.record and "Enabled" or "Disabled"))
                    grid_dirty = true
                elseif x == 5 then -- clear sequence
                    if confirm_delete then
                        gridSeq:clear_pattern()
                        all_engine_notes_off()
                        confirm_delete = false
                        clear_notification()
                        show_temporary_notification("Pattern cleared.")
                    else
                        confirm_delete = true
                        show_notification("Clear Pattern?")
                    end
                    grid_dirty = true
                end
            end
        else  -- key released
            if y == 8 then
                if x == 2 then -- shift
                    -- shift_down = false
                    -- gridSeq.edit_mode = seqmode_select

                    confirm_delete = false
                    clear_notification()
                    grid_dirty = true
                end
            end
        end
    end

    grid_key_toolbar(x,y,z)
    grid_key_shift(x,y,z)
end

-- GridSeq.held_step = 0

GridSeq.show_step_edit = false

function GridSeq.grid_key(x,y,z)
    if not GridSeq.show_step_edit and not shift_down and gridSeq.edit_mode == seqmode_select then
        if gridType == gridType_128 then
            grid_dirty = gridKeys:grid_key(x,y,z)
        elseif gridType == gridType_64 then
            if (y == 7 and x == 7) or (y == 7 and x == 8) then
            else
                grid_dirty = gridKeys:grid_key(x,y,z)
            end
        end
    end

    local xOff = 0
    local xCut = 9
    local xCopy = 10
    local xPaste = 11
    local ignoreToolbar = false -- needed if switching to velocity edit or note edit mode

    if gridType == gridType_64 then
        xCut = 4
        xCopy = 5
        xPaste = 6

        if edit_steps_9_16 then
            xOff = 8
        end
    end

    if GridSeq.show_step_edit then
        if grid_key_step_edit(x,y,z) then
            grid_dirty = true
        end

        if z == 1 then -- key pressed
            if y == 1 then
                if x+xOff ~= held_step then
                    gridSeq:copy_step(held_step)
                    gridSeq:paste_step(x+xOff)
                    show_temporary_notification("Copy Step "..held_step.." to "..(x+xOff))
                    grid_dirty = true;
                end
            end
        else -- key released
            -- release held step when releasing key
            -- if x == held_step then
            --     held_step = 0
            --     GridSeq.show_step_edit = false
            --     showTrigPage = false
            --     grid_dirty = true
            -- end
        end
    elseif gridSeq.edit_mode == seqmode_select and not shift_down then
        if z == 1 then -- key pressed
            if gridType == gridType_128 then
                if x == 15 and y >= 2 and y <= 7 then -- change velocity
                    local vel = 7 - y
                    local velLevel = util.round(util.linlin(0,5,0,127,vel))
                    gridSeq:change_velocity(velLevel)
                    print("Velocity: " .. velLevel)
                    grid_dirty = true;
                elseif x == 16 and y >= 2 and y <= 7 then -- change note length
                    local yVal = 7 - y
                    noteLength = seq_noteLengths[8-y]
                    gridSeq:change_noteLength(noteLength)
                    print("NoteLength: " .. noteLength)
                    grid_dirty = true;
                end
            end

            if y == 1 then
                if held_step > 0 and x+xOff ~= held_step then
                    gridSeq:copy_step(held_step)
                    gridSeq:paste_step(x+xOff)
                    show_temporary_notification("Copy Step "..held_step.." to "..(x+xOff))
                    grid_dirty = true;
                else
                    held_step = x+xOff
                    gridSeq:select_stepId(x+xOff)
                    gridSeqConfig.step_counter[x] = clock.run(function(stepId)
                        clock.sleep(0.25)
                        if gridSeq:get_current_stepId() == stepId then
                            showTrigPage = true
                            GridSeq.show_step_edit = true
                            grid_redraw()
                        end
                        gridSeqConfig.step_counter[x] = nil
                    end,x+xOff)

                    grid_dirty = true;
                end
            elseif y == 7 then
                if gridType == gridType_64 then
                    if x == 7 then -- scroll grid keyboard down
                        gridKeys:scroll_down()
                        grid_dirty = true
                    elseif x == 8 then -- scroll grid keyboard up
                        gridKeys:scroll_up()
                        grid_dirty = true
                    end
                end
            elseif y == 8 then
                if x == xCut then -- cut
                    -- GridSeq.show_step_edit = false
                    gridSeq.edit_mode = seqmode_cut 
                    show_temporary_notification("Cut")
                    grid_dirty = true
                elseif x == xCopy then -- copy
                    gridSeq.edit_mode = seqmode_copy 
                    show_temporary_notification("Copy")
                    grid_dirty = true
                elseif x == xPaste then -- paste
                    gridSeq.edit_mode = seqmode_paste 
                    show_temporary_notification("Paste")
                    grid_dirty = true
                end

                if gridType == gridType_128 then
                    if x == 13 then -- prev step
                        gridSeq:select_prev_step()
                        grid_dirty = true
                    elseif x == 14 then -- next step
                        gridSeq:select_next_step()
                        grid_dirty = true
                    elseif x == 15 then -- scroll grid keyboard down
                        gridKeys:scroll_down()
                        grid_dirty = true
                    elseif x == 16 then -- scroll grid keyboard up
                        gridKeys:scroll_up()
                        grid_dirty = true
                    end
                end
            end
        else -- key released
            if y == 8 then
                if x == xCut then -- cut
                    gridSeq:clear_edit_mode(seqmode_cut)
                    grid_dirty = true
                elseif x == xCopy then -- copy
                    gridSeq:clear_edit_mode(seqmode_copy)
                    grid_dirty = true
                elseif x == xPaste then -- paste
                    gridSeq:clear_edit_mode(seqmode_paste)
                    grid_dirty = true
                end
            end
        end
    elseif gridSeq.edit_mode == seqmode_select and shift_down then -- Shift Mode
        if z == 1 then -- key pressed Shift Mode
            if y == 8 then -- Tool bar
                if confirm_delete and x ~= 5 then
                    confirm_delete = false
                    clear_notification()
                end

                if x == 3 then -- vel edit
                    change_grid_page("GridSeqVel")
                    ignoreToolbar = true
                    shift_down = false
                    grid_dirty = true
                elseif x == 4 then -- level edit
                    change_grid_page("GridSeqNoteLengths")
                    ignoreToolbar = true
                    shift_down = false
                    grid_dirty = true
                elseif x == 5 then -- clear sequence
                    if confirm_delete then
                        gridSeq:clear_pattern()
                        all_engine_notes_off()
                        confirm_delete = false
                        clear_notification()
                        show_temporary_notification("Pattern cleared.")
                    else
                        confirm_delete = true
                        show_notification("Clear Pattern?")
                    end
                    grid_dirty = true
                end

                if gridType == gridType_128 then
                    if x == 13 then -- shift notes left
                        show_temporary_notification("Shift Left")
                        gridSeq:shift_notes_left()
                        grid_dirty = true
                    elseif x == 14 then -- shift notes right
                        show_temporary_notification("Shift Right")
                        gridSeq:shift_notes_right()
                        grid_dirty = true
                    elseif x == 15 then -- prev bar
                        gridSeq:select_prev_bar()
                        show_temporary_notification("Bar " ..gridSeq.selected_bar)
                        grid_dirty = true
                    elseif x == 16 then -- next bar
                        gridSeq:select_next_bar()
                        show_temporary_notification("Bar " ..gridSeq.selected_bar)
                        grid_dirty = true
                    end
                end
            end
        else -- key released Shift Mode
            if y == 8 then
                if x == 2 then -- shift
                    -- shift_down = false
                    -- gridSeq.edit_mode = seqmode_select
                    confirm_delete = false
                    clear_notification()
                    grid_dirty = true
                end

                if x == xCut then -- cut
                    gridSeq:clear_edit_mode(seqmode_cut)
                    grid_dirty = true
                elseif x == xCopy then -- copy
                    gridSeq:clear_edit_mode(seqmode_copy)
                    grid_dirty = true
                elseif x == xPaste then -- paste
                    gridSeq:clear_edit_mode(seqmode_paste)
                    grid_dirty = true
                end
            end
        end
    elseif gridSeq.edit_mode == seqmode_cut then
        if z == 1 then -- key pressed
            if y == 1 then
                gridSeq:select_stepId(x+xOff)
                grid_dirty = true;
            elseif y == 3 or y == 4 then
                if x+xOff > gridSeq.num_bars then -- increase num of bars and paste
                    gridSeq:set_length(gridSeq.bar_length, x+xOff)
                    if gridSeq:paste_bar(x+xOff) then
                        show_temporary_notification("Paste bar: "..(x+xOff))
                        grid_dirty = true
                    end
                else
                    if gridSeq:does_bar_have_notes(x+xOff) then
                        if gridSeq:cut_bar(x+xOff) then
                            show_temporary_notification("Cut bar: "..(x+xOff))
                            grid_dirty = true
                        end
                    else
                        if gridSeq:paste_bar(x+xOff) then
                            show_temporary_notification("Paste bar: "..(x+xOff))
                            grid_dirty = true
                        end
                    end
                end
            elseif y == 5 then
                if gridSeq:does_pattern_have_notes(x+xOff) then
                    patLaunchConfig.clipboard_pattern = gridSeq:get_cloned_patern_at_index(x+xOff)
                    gridSeq:clear_pattern_at_index(x+xOff)

                    if patLaunchConfig.clipboard_pattern ~= nil then
                        show_temporary_notification("Pat "..get_pattern_letter(x+xOff).." cut")
                        grid_dirty = true
                    end
                else
                    if patLaunchConfig.clipboard_pattern ~= nil then
                        if gridSeq:paste_pattern_to_index(patLaunchConfig.clipboard_pattern, x+xOff) then
                            -- all_gridSeqs[x]:change_selected_pattern(patIndex)
                            show_temporary_notification("Paste to "..get_pattern_letter(x+xOff))
                            grid_dirty = true
                        end
                    end
                end
            end
        else -- key released
            if y == 8 then
                if x == xCut then -- cut
                    gridSeq:clear_edit_mode(seqmode_cut)
                    grid_dirty = true
                end
            end
        end
    elseif gridSeq.edit_mode == seqmode_copy then
        if z == 1 then -- key pressed
            if y == 1 then
                gridSeq:select_stepId(x+xOff)
                grid_dirty = true;
            elseif y == 3 or y == 4 then
                if x+xOff > gridSeq.num_bars then -- increase num of bars and paste
                    gridSeq:set_length(gridSeq.bar_length, x+xOff)
                    if gridSeq:paste_bar(x+xOff) then
                        show_temporary_notification("Paste bar: "..(x+xOff))
                        grid_dirty = true
                    end
                else
                    if gridSeq:does_bar_have_notes(x+xOff) then
                        if gridSeq:copy_bar(x+xOff) then
                            show_temporary_notification("Copy bar: "..(x+xOff))
                            grid_dirty = true
                        end
                    else
                        if gridSeq:paste_bar(x+xOff) then
                            show_temporary_notification("Paste bar: "..(x+xOff))
                            grid_dirty = true
                        end
                    end
                end
            elseif y == 5 then -- copy pattern
                if gridSeq:does_pattern_have_notes(x+xOff) then
                    patLaunchConfig.clipboard_pattern = gridSeq:get_cloned_patern_at_index(x+xOff)

                    if patLaunchConfig.clipboard_pattern ~= nil then
                        show_temporary_notification("Pat "..get_pattern_letter(x+xOff).." copy")
                        grid_dirty = true
                    end
                else
                    if patLaunchConfig.clipboard_pattern ~= nil then
                        if gridSeq:paste_pattern_to_index(patLaunchConfig.clipboard_pattern, x+xOff) then
                            show_temporary_notification("Paste to "..get_pattern_letter(x+xOff))
                            grid_dirty = true
                        end
                    end
                end
            end
        else -- key released
            if y == 8 then
                if x == xCopy then -- copy
                    gridSeq:clear_edit_mode(seqmode_copy)
                    grid_dirty = true
                end
            end
        end
    elseif gridSeq.edit_mode == seqmode_paste then
        if z == 1 then -- key pressed
            if y == 1 then
                gridSeq:select_stepId(x+xOff)
                grid_dirty = true;
            elseif y == 3 or y == 4 then
                if x+xOff > gridSeq.num_bars then -- increase num of bars and paste
                    gridSeq:set_length(gridSeq.bar_length, x+xOff)
                end

                if gridSeq:paste_bar(x+xOff) then
                    show_temporary_notification("Paste bar: "..(x+xOff))
                    grid_dirty = true
                end
            elseif y == 5 then
                if patLaunchConfig.clipboard_pattern ~= nil then
                    if gridSeq:paste_pattern_to_index(patLaunchConfig.clipboard_pattern, x+xOff) then
                        -- all_gridSeqs[x]:change_selected_pattern(patIndex)
                        show_temporary_notification("Paste to "..get_pattern_letter(x+xOff))
                        grid_dirty = true
                    end
                end
            end
        else -- key released
            if y == 8 then
                if x == xPaste then -- paste
                    gridSeq:clear_edit_mode(seqmode_paste)
                    grid_dirty = true
                end
            end
        end
    end

    -- release held step when releasing key
    if held_step > 0 and y == 1 and z == 0 then
        if gridType == gridType_128 then
            if x == held_step then
                if gridSeqConfig.step_counter[x] then -- if the long press counter is still active...
                    clock.cancel(gridSeqConfig.step_counter[x]) -- kill the long press counter,
                    gridSeqConfig.step_counter[x] = nil
                    -- short_press(x,y) -- because it's a short press.
                else -- if there was a long press...
                    -- if gridSeq:get_current_stepId() == x then
                    --     showTrigPage = false -- hide trig page
                    --     -- long_release(x,y) -- release the long press.
                    -- end
                end
    
                held_step = 0
                showTrigPage = false
                GridSeq.show_step_edit = false
                grid_dirty = true
            end
        elseif gridType == gridType_64 then
            if x == held_step or x + 8 == held_step then
                if gridSeqConfig.step_counter[x] then -- if the long press counter is still active...
                    clock.cancel(gridSeqConfig.step_counter[x]) -- kill the long press counter,
                    gridSeqConfig.step_counter[x] = nil
                    -- short_press(x,y) -- because it's a short press.
                else -- if there was a long press...
                    -- if gridSeq:get_current_stepId() == x then
                    --     showTrigPage = false -- hide trig page
                    --     -- long_release(x,y) -- release the long press.
                    -- end
                end
    
                held_step = 0
                showTrigPage = false
                GridSeq.show_step_edit = false
                grid_dirty = true
            end
        end
    end

    if not ignoreToolbar then
        grid_key_toolbar(x,y,z)
        grid_key_shift(x,y,z)
    end

    -- disable key playback while playing
    for i,gKey in pairs(all_gridKeys) do
        gKey.enable_key_playback = not is_playing
    end
end

-- edit_type
-- 1 = velocity
-- 2 = note length
function grid_key_param_edit(x,y,z,edit_type)
    local xOff = 0
    local xCut = 9
    local xCopy = 10
    local xPaste = 11

    if gridType == gridType_64 then
        xCut = 4
        xCopy = 5
        xPaste = 6

        if edit_steps_9_16 then
            xOff = 8
        end
    end

    if z == 1 then -- key pressed
        if y == 1 then
            gridSeq:select_stepId(x+xOff)
            grid_dirty = true;
        elseif y > 1 and y < 8 then
            if edit_type == 1 then -- velocity
                local vel = 7 - y
                local velLevel = util.round(util.linlin(0,5,0,127,vel))
                gridSeq:change_velocity_stepId(velLevel, x+xOff)
                print("Velocity: " .. velLevel)
                grid_dirty = true;
            elseif edit_type == 2 then -- note lengths
                local yVal = 7 - y

                noteLength = seq_noteLengths[8-y]
                gridSeq:change_noteLength_stepId(noteLength, x)

                print("NoteLength: " .. noteLength)
                grid_dirty = true;
            end
        elseif y == 8 then
            if gridType == gridType_128 then
                if x == 1 then -- switch to seq edit mode
                    change_grid_page("GridSeq")
                    grid_dirty = true
                elseif x == 3 then 
                    change_grid_page("GridSeqVel")
                    grid_dirty = true
                elseif x == 4 then -- switch to seq edit mode
                    change_grid_page("GridSeqNoteLengths")
                    grid_dirty = true
                elseif x == 5 then 
                    show_temporary_notification("Coming soon")
                    -- change_grid_page("GridSeq")
                    -- grid_dirty = true
                elseif x == xCut then -- cut
                    gridSeq.edit_mode = seqmode_cut 
                    show_temporary_notification("Cut")
                    grid_dirty = true
                elseif x == xCopy then -- copy
                    gridSeq.edit_mode = seqmode_copy 
                    show_temporary_notification("Copy")
                    grid_dirty = true
                elseif x == xPaste then -- paste
                    gridSeq.edit_mode = seqmode_paste 
                    show_temporary_notification("Paste")
                    grid_dirty = true
                end
            elseif gridType == gridType_64 then
                if x == 1 then -- switch to seq edit mode
                    change_grid_page("GridSeq")
                    grid_dirty = true
                elseif x == 3 then 
                    if edit_type == 1 then -- velocity
                        change_grid_page("GridSeqNoteLengths")
                    elseif edit_type == 2 then -- note lengths
                        change_grid_page("GridSeqVel")
                    end
                    grid_dirty = true
                elseif x == xCut then -- cut
                    gridSeq.edit_mode = seqmode_cut 
                    show_temporary_notification("Cut")
                    grid_dirty = true
                elseif x == xCopy then -- copy
                    gridSeq.edit_mode = seqmode_copy 
                    show_temporary_notification("Copy")
                    grid_dirty = true
                elseif x == xPaste then -- paste
                    gridSeq.edit_mode = seqmode_paste 
                    show_temporary_notification("Paste")
                    grid_dirty = true
                elseif x == 7 then -- edit steps 1-8
                    edit_steps_9_16 = false
                    show_temporary_notification("Edit 1-8")
                    grid_dirty = true
                elseif x == 8 then -- edit steps 9-16
                    edit_steps_9_16 = true
                    show_temporary_notification("Edit 9-16")
                    grid_dirty = true
                end
            end
        end
    else -- key released
        if y == 8 then
            if x == xCut then -- cut
                gridSeq:clear_edit_mode(seqmode_cut)
                grid_dirty = true
            elseif x == xCopy then -- copy
                gridSeq:clear_edit_mode(seqmode_copy)
                grid_dirty = true
            elseif x == xPaste then -- paste
                gridSeq:clear_edit_mode(seqmode_paste)
                grid_dirty = true
            end
        end
    end
end

function GridSeqVel.grid_key(x,y,z)
    grid_key_param_edit(x,y,z,1)

    -- local xOff = 0
    -- local xCut = 9
    -- local xCopy = 10
    -- local xPaste = 11

    -- if gridType == gridType_64 then
    --     xCut = 4
    --     xCopy = 5
    --     xPaste = 6

    --     if edit_steps_9_16 then
    --         xOff = 8
    --     end
    -- end

    -- if z == 1 then -- key pressed
    --     if y == 1 then
    --         gridSeq:select_stepId(x+xOff)
    --         grid_dirty = true;
    --     elseif y > 1 and y < 8 then
    --         local vel = 7 - y

    --         local velLevel = util.round(util.linlin(0,5,0,127,vel))

    --         gridSeq:change_velocity_stepId(velLevel, x+xOff)

    --         print("Velocity: " .. velLevel)
    --         grid_dirty = true;

    --     elseif y == 8 then
    --         if gridType == gridType_128 then
    --             if x == 1 then -- switch to seq edit mode
    --                 change_grid_page("GridSeq")
    --                 grid_dirty = true
    --             elseif x == 3 then 
    --                 change_grid_page("GridSeq")
    --                 grid_dirty = true
    --             elseif x == 4 then -- switch to seq edit mode
    --                 change_grid_page("GridSeqNoteLengths")
    --                 grid_dirty = true
    --             elseif x == 5 then 
    --                 show_temporary_notification("Coming soon")
    --                 -- change_grid_page("GridSeq")
    --                 -- grid_dirty = true
    --             elseif x == xCut then -- cut
    --                 gridSeq.edit_mode = seqmode_cut 
    --                 show_temporary_notification("Cut")
    --                 grid_dirty = true
    --             elseif x == xCopy then -- copy
    --                 gridSeq.edit_mode = seqmode_copy 
    --                 show_temporary_notification("Copy")
    --                 grid_dirty = true
    --             elseif x == xPaste then -- paste
    --                 gridSeq.edit_mode = seqmode_paste 
    --                 show_temporary_notification("Paste")
    --                 grid_dirty = true
    --             end
    --         elseif gridType == gridType_64 then
    --             if x == 1 then -- switch to seq edit mode
    --                 change_grid_page("GridSeq")
    --                 grid_dirty = true
    --             elseif x == 3 then 
    --                 change_grid_page("GridSeqNoteLengths")
    --                 grid_dirty = true
    --             elseif x == xCut then -- cut
    --                 gridSeq.edit_mode = seqmode_cut 
    --                 show_temporary_notification("Cut")
    --                 grid_dirty = true
    --             elseif x == xCopy then -- copy
    --                 gridSeq.edit_mode = seqmode_copy 
    --                 show_temporary_notification("Copy")
    --                 grid_dirty = true
    --             elseif x == xPaste then -- paste
    --                 gridSeq.edit_mode = seqmode_paste 
    --                 show_temporary_notification("Paste")
    --                 grid_dirty = true
    --             elseif x == 7 then -- edit steps 1-8
    --                 edit_steps_9_16 = false
    --                 show_temporary_notification("Edit 1-8")
    --                 grid_dirty = true
    --             elseif x == 8 then -- edit steps 9-16
    --                 edit_steps_9_16 = true
    --                 show_temporary_notification("Edit 9-16")
    --                 grid_dirty = true
    --             end
    --         end
    --     end
    -- else -- key released
    --     if y == 8 then
    --         if x == xCut then -- cut
    --             gridSeq:clear_edit_mode(seqmode_cut)
    --             grid_dirty = true
    --         elseif x == xCopy then -- copy
    --             gridSeq:clear_edit_mode(seqmode_copy)
    --             grid_dirty = true
    --         elseif x == xPaste then -- paste
    --             gridSeq:clear_edit_mode(seqmode_paste)
    --             grid_dirty = true
    --         end
    --     end
    -- end
end

function GridSeqNoteLengths.grid_key(x,y,z)
    grid_key_param_edit(x,y,z,2)

    -- if z == 1 then -- key pressed
    --     if y == 1 then
    --         gridSeq:select_stepId(x)
    --         grid_dirty = true;
    --     elseif y > 1 and y < 8 then
    --         local yVal = 7 - y

    --         noteLength = seq_noteLengths[8-y]
    --         gridSeq:change_noteLength_stepId(noteLength, x)

    --         print("NoteLength: " .. noteLength)
    --         grid_dirty = true;
    --     elseif y == 8 then
    --         if x == 1 then -- switch to seq edit mode
    --             change_grid_page("GridSeq")
    --             grid_dirty = true
    --         elseif x == 3 then 
    --             change_grid_page("GridSeqVel")
    --             grid_dirty = true
    --         elseif x == 4 then -- switch to seq edit mode
    --             change_grid_page("GridSeq")
    --             grid_dirty = true
    --         elseif x == 5 then 
    --             show_temporary_notification("Coming soon")
    --             -- change_grid_page("GridSeq")
    --             -- grid_dirty = true
    --         elseif x == 9 then -- cut
    --             gridSeq.edit_mode = seqmode_cut 
    --             grid_dirty = true
    --         elseif x == 10 then -- copy
    --             gridSeq.edit_mode = seqmode_copy 
    --             grid_dirty = true
    --         elseif x == 11 then -- paste
    --             gridSeq.edit_mode = seqmode_paste 
    --             grid_dirty = true
    --         end
    --     end
    -- else -- key released
    --     if y == 8 then
    --         if x == 7 then -- delete
    --             gridSeq:clear_edit_mode(seqmode_delete)
    --             grid_dirty = true
    --         elseif x == 9 then -- cut
    --             gridSeq:clear_edit_mode(seqmode_cut)
    --             grid_dirty = true
    --         elseif x == 10 then -- copy
    --             gridSeq:clear_edit_mode(seqmode_copy)
    --             grid_dirty = true
    --         elseif x == 11 then -- paste
    --             gridSeq:clear_edit_mode(seqmode_paste)
    --             grid_dirty = true
    --         end
    --     end
    -- end
end

GridPatLaunch.heldPattern = nil

function GridPatLaunch.grid_key(x,y,z)
    -- print("patLaunchConfig.edit_mode: "..patLaunchConfig.edit_mode)

    local xOff = 0
    local xCut = 9
    local xCopy = 10
    local xPaste = 11

    if gridType == gridType_64 then
        xCut = 4
        xCopy = 5
        xPaste = 6

        if edit_steps_9_16 then
            xOff = 8
        end
    end


    local patIndex = y - 1 + patLaunchConfig.y_offset

    if patLaunchConfig.edit_mode == 1 and not shift_down then
        if z == 1 then -- key pressed
            if y == 1 then
                change_track(x+xOff)
                show_temporary_notification("Track "..(x+xOff))
                grid_dirty = true
            elseif y > 1 and y < 8 then
                if GridPatLaunch.heldPattern == nil then
                    change_track(x+xOff)
                    all_gridSeqs[x+xOff]:change_selected_pattern(patIndex)
                    show_temporary_notification("Pattern "..get_pattern_letter(all_gridSeqs[x].selected_pattern))

                    GridPatLaunch.heldPattern = {}
                    GridPatLaunch.heldPattern.x = x+xOff
                    GridPatLaunch.heldPattern.y = y
                    GridPatLaunch.heldPattern.patIndex = patIndex
                else
                    if x+xOff ~= GridPatLaunch.heldPattern.x or y ~= GridPatLaunch.heldPattern.y then
                        local pat = all_gridSeqs[GridPatLaunch.heldPattern.x]:get_cloned_patern_at_index(GridPatLaunch.heldPattern.patIndex)

                        if pat ~= nil then
                            if all_gridSeqs[x+xOff]:paste_pattern_to_index(pat, patIndex) then
                                show_temporary_notification("Paste "..GridPatLaunch.heldPattern.x..get_pattern_letter(GridPatLaunch.heldPattern.patIndex).. " to "..x..get_pattern_letter(patIndex))
                                grid_dirty = true
                            end
                        end
                    end
                end
                grid_dirty = true
            elseif y == 8 then -- toolbar
                if x == xCut then -- cut
                    patLaunchConfig.edit_mode = 2 
                    show_temporary_notification("Cut")
                    grid_dirty = true
                elseif x == xCopy then -- copy
                    patLaunchConfig.edit_mode = 3 
                    show_temporary_notification("Copy")
                    grid_dirty = true
                elseif x == xPaste then -- paste
                    patLaunchConfig.edit_mode = 4 
                    show_temporary_notification("Paste")
                    grid_dirty = true
                end

                if gridType == gridType_128 then
                    if x == 15 then -- scroll grid keyboard down
                        -- gridKeys:scroll_down()
                        patLaunchConfig.y_offset = math.min(patLaunchConfig.y_offset + 1,15)
                        print("y_offset = "..patLaunchConfig.y_offset)
                        grid_dirty = true
                    elseif x == 16 then -- scroll grid keyboard up
                        -- gridKeys:scroll_up()
                        patLaunchConfig.y_offset = math.max(patLaunchConfig.y_offset - 1, 0)
                        print("y_offset = "..patLaunchConfig.y_offset)
                        grid_dirty = true
                    end
                end
            end
        else  -- key released
        end
    elseif patLaunchConfig.edit_mode == 1 and shift_down then -- Shift Mode
        if gridType == gridType_64 then
            if y == 8 and z == 1 then
                if x == 5 then -- scroll grid keyboard down
                    -- gridKeys:scroll_down()
                    patLaunchConfig.y_offset = math.min(patLaunchConfig.y_offset + 1,15)
                    print("y_offset = "..patLaunchConfig.y_offset)
                    grid_dirty = true
                elseif x == 6 then -- scroll grid keyboard up
                    -- gridKeys:scroll_up()
                    patLaunchConfig.y_offset = math.max(patLaunchConfig.y_offset - 1, 0)
                    print("y_offset = "..patLaunchConfig.y_offset)
                    grid_dirty = true
                end
            end
        end

        if z == 1 then -- key pressed
            if y == 1 then
                all_gridSeqs[x+xOff].mute_seq = not all_gridSeqs[x+xOff].mute_seq
                show_temporary_notification("Track "..(x+xOff).." "..(all_gridSeqs[x+xOff].mute_seq and "mute" or "unmute"))
                grid_dirty = true
            elseif y > 1 and y < 8 then
                for i = 1, #all_gridSeqs do
                    all_gridSeqs[i]:change_selected_pattern(patIndex)
                end

                show_temporary_notification("Scene "..get_pattern_letter(patIndex))

                grid_dirty = true
            end
        else  -- key released
            if y == 8 then
                if x == 2 then -- shift
                    -- shift_down = false
                    -- gridSeq.edit_mode = seqmode_select
                    confirm_delete = false
                    clear_notification()
                    grid_dirty = true
                end
            end
        end
    elseif patLaunchConfig.edit_mode == 2 then -- cut
        if z == 1 then -- key pressed
            if y == 1 then -- copy gridKey settings
                change_track(x+xOff)
                patLaunchConfig.clipboard_gridKeys = all_gridKeys[x+xOff]:get_serialized()
                patLaunchConfig.track_paste_mode = 1
                show_temporary_notification("Trk "..(x+xOff).." copy settings")
                grid_dirty = true
            elseif y > 1 and y < 8 then
                change_track(x+xOff)
                if all_gridSeqs[x+xOff]:does_pattern_have_notes(patIndex) then
                    patLaunchConfig.clipboard_pattern = all_gridSeqs[x+xOff]:get_cloned_patern_at_index(patIndex)
                    all_gridSeqs[x+xOff]:clear_pattern_at_index(patIndex)

                    if patLaunchConfig.clipboard_pattern ~= nil then
                        show_temporary_notification("Pat "..get_pattern_letter(patIndex).." cut")
                        grid_dirty = true
                    end
                else
                    if patLaunchConfig.clipboard_pattern ~= nil then
                        if all_gridSeqs[x+xOff]:paste_pattern_to_index(patLaunchConfig.clipboard_pattern, patIndex) then
                            -- all_gridSeqs[x]:change_selected_pattern(patIndex)
                            show_temporary_notification("Paste to "..get_pattern_letter(patIndex))
                            grid_dirty = true
                        end
                    end
                end
            end
        else -- key released
            if y == 8 then
                if x == xCut then
                    patLaunchConfig.edit_mode = 1
                    grid_dirty = true
                end
            end
        end
    elseif patLaunchConfig.edit_mode == 3 then -- copy
        if z == 1 then -- key pressed
            if y == 1 then
                change_track(x+xOff)
                patLaunchConfig.clipboard_gridSeq = all_gridSeqs[x+xOff]:get_serialized()
                patLaunchConfig.track_paste_mode = 2
                show_temporary_notification("Track "..(x+xOff).." copied")
                grid_dirty = true
            elseif y > 1 and y < 8 then
                change_track(x+xOff)
                if all_gridSeqs[x+xOff]:does_pattern_have_notes(patIndex) then
                    patLaunchConfig.clipboard_pattern = all_gridSeqs[x+xOff]:get_cloned_patern_at_index(patIndex)
                    if patLaunchConfig.clipboard_pattern ~= nil then
                        show_temporary_notification("Pat "..get_pattern_letter(patIndex).." copied")
                        grid_dirty = true
                    end
                else
                    if patLaunchConfig.clipboard_pattern ~= nil then
                        if all_gridSeqs[x+xOff]:paste_pattern_to_index(patLaunchConfig.clipboard_pattern, patIndex) then
                            -- all_gridSeqs[x]:change_selected_pattern(patIndex)
                            show_temporary_notification("Paste to "..get_pattern_letter(patIndex))
                            grid_dirty = true
                        end
                    end
                end
            end
        else -- key released
            if y == 8 then
                if x == xCopy then
                    patLaunchConfig.edit_mode = 1
                    grid_dirty = true
                end
            end
        end
    elseif patLaunchConfig.edit_mode == 4 then -- paste
        if z == 1 then -- key pressed
            if y == 1 then
                if patLaunchConfig.track_paste_mode == 1 and patLaunchConfig.clipboard_gridKeys ~= nil then
                    change_track(x+xOff)
                    all_gridKeys[x+xOff]:load_serialized(patLaunchConfig.clipboard_gridKeys)
                    show_temporary_notification("Trk "..(x+xOff).." settings paste")
                    grid_dirty = true
                elseif patLaunchConfig.track_paste_mode == 2 and patLaunchConfig.clipboard_gridSeq ~= nil then
                    change_track(x+xOff)
                    all_gridSeqs[x+xOff]:load_serialized(patLaunchConfig.clipboard_gridSeq)
                    show_temporary_notification("Track "..(x+xOff).." pasted")
                    grid_dirty = true
                end
            elseif y > 1 and y < 8 then
                change_track(x+xOff)
                if patLaunchConfig.clipboard_pattern ~= nil then
                    if all_gridSeqs[x+xOff]:paste_pattern_to_index(patLaunchConfig.clipboard_pattern, patIndex) then
                        -- all_gridSeqs[x]:change_selected_pattern(patIndex)
                        show_temporary_notification("Paste to "..get_pattern_letter(patIndex))
                        grid_dirty = true
                    end
                end
            end
        else -- key released
            if y == 8 then
                if x == xPaste then
                    patLaunchConfig.edit_mode = 1
                    grid_dirty = true
                end
            end
        end
    end

    grid_key_toolbar(x,y,z)

    if GridPatLaunch.heldPattern ~= nil then
        if gridType == gridType_128 then
            if x == GridPatLaunch.heldPattern.x and y == GridPatLaunch.heldPattern.y and z == 0 then
                GridPatLaunch.heldPattern = nil
            end
        elseif gridType == gridType_64 then
            if (x == GridPatLaunch.heldPattern.x or x+8 == GridPatLaunch.heldPattern.x) and y == GridPatLaunch.heldPattern.y and z == 0 then
                GridPatLaunch.heldPattern = nil
            end
        end
    end
end

function seq_newStep()
    
end

-- grid step edit mode
function grid_draw_step_edit(stepId)
    stepId = stepId or gridSeq:get_current_stepId()
    local cX = 8
    local cY = 5

    if gridType == gridType_64 then
        cX = 4
    end

    local stepHasNotes = gridSeq:does_stepId_have_notes()

    local ledBrightness = stepHasNotes and 3 or 1

    if gridType == gridType_128 then
        for y = cY-2,cY-1 do
            g:led(cX,y,ledBrightness)
            g:led(cX-7,y,ledBrightness)
            g:led(cX+8,y,ledBrightness)
        end

        for x = cX-7,cX+8 do
            g:led(x,cY,ledBrightness)
        end
    
        for x = 0,7 do
            if x % 2 == 0 then
                g:led(cX + x,cY-1,ledBrightness)
                g:led(cX - x,cY-1,ledBrightness)
            end
        end
    
        local offset = gridSeq:get_stepId_offset(stepId)
        local substepCount = gridSeq:get_substep_count(stepId)
    
        local offsetX = util.clamp(cX + util.round(util.linlin(-substepCount,substepCount,-8,8, offset)),1,16)
    
        ledBrightness = stepHasNotes and 15 or 3
    
        for y = cY-2,cY do
            g:led(offsetX,y,ledBrightness)
        end
    elseif gridType == gridType_64 then
        for y = cY-2,cY-1 do
            g:led(cX,y,ledBrightness)
            g:led(1,y,ledBrightness)
            g:led(8,y,ledBrightness)
        end

        for x = cX-3,cX+4 do
            g:led(x,cY,ledBrightness)
        end
    
        for x = 0,3 do
            if x % 2 == 0 then
                g:led(cX + x,cY-1,ledBrightness)
                g:led(cX - x,cY-1,ledBrightness)
            end
        end
    
        local offset = gridSeq:get_stepId_offset(stepId)
        local substepCount = gridSeq:get_substep_count(stepId)
    
        local offsetX = util.clamp(cX + util.round(util.linlin(-substepCount,substepCount,-4,4, offset)),1,8)
    
        ledBrightness = stepHasNotes and 15 or 3
    
        for y = cY-2,cY do
            g:led(offsetX,y,ledBrightness)
        end
    end
end

function grid_key_step_edit(x, y, z, stepId)
    stepId = stepId or gridSeq:get_current_stepId()

    local grid_dirty = false

    if z == 1 then
        if y >= 3 and z <= 6 then
            if gridType == gridType_128 then
                local substep_count = gridSeq:get_substep_count(stepId)

                local offset = util.round(util.linlin(-8, 8, -substep_count, substep_count, x - 8))
                if x == 1 then offset = -substep_count end

                -- print("substep_count "..substep_count.." offset "..offset)
                gridSeq:set_stepId_offset(stepId, offset)
                grid_dirty = true
            elseif gridType == gridType_64 then
                local substep_count = gridSeq:get_substep_count(stepId)

                local offset = util.round(util.linlin(-4, 4, -substep_count, substep_count, x - 4))
                if x == 1 then offset = -substep_count end

                -- print("substep_count "..substep_count.." offset "..offset)
                gridSeq:set_stepId_offset(stepId, offset)
                grid_dirty = true
            end
        end
    else
    end

    return grid_dirty
end

function grid_draw_bars_and_tracks()

    grid_draw_sequence_steps(true, true, 2, false, false)

    if gridType == gridType_128 then
        for x = 1, gridSeq.num_bars do

            local has_notes = gridSeq:does_bar_have_notes(x)
    
            g:led(x, 3, has_notes and 5 or 2)
            g:led(x, 4, has_notes and 5 or 2)
        end
    
        g:led(gridSeq.selected_bar, 4, mode_on_brightness)
    
        for x = 1, 16 do
            g:led(x, 5, gridSeq:does_pattern_have_notes(x) and 5 or 2)
        end
    
        g:led(gridSeq.selected_pattern , 5, mode_on_brightness)
    
        for x = 1, 16 do
            g:led(x, 7, 2)
        end
    
        g:led(track, 7, mode_on_brightness)
    elseif gridType == gridType_64 then
        local xOff = 0

        if edit_steps_9_16 then
            xOff = 8
            -- for x = 9, gridSeq.num_bars do

            --     local has_notes = gridSeq:does_bar_have_notes(x)
        
            --     g:led(x-8, 3, has_notes and 5 or 2)
            --     g:led(x-8, 4, has_notes and 5 or 2)
            -- end
        else
            -- for x = 1, math.min(gridSeq.num_bars, 8) do

            --     local has_notes = gridSeq:does_bar_have_notes(x)
        
            --     g:led(x, 3, has_notes and 5 or 2)
            --     g:led(x, 4, has_notes and 5 or 2)
            -- end
        end

        for x = 1, math.min(gridSeq.num_bars-xOff, 8) do

            local has_notes = gridSeq:does_bar_have_notes(x+xOff)
    
            g:led(x, 3, has_notes and 5 or 2)
            g:led(x, 4, has_notes and 5 or 2)
        end
    
        if gridSeq.selected_bar-xOff > 0 and gridSeq.selected_bar-xOff <= 8 then
            g:led(gridSeq.selected_bar-xOff, 4, mode_on_brightness)
        end
    
        for x = 1, 8 do
            g:led(x, 5, gridSeq:does_pattern_have_notes(x+xOff) and 5 or 2)
        end
    
        if gridSeq.selected_pattern-xOff > 0 and gridSeq.selected_pattern-xOff <= 8 then
            g:led(gridSeq.selected_pattern-xOff, 5, mode_on_brightness)
        end
    
        for x = 1, 8 do
            g:led(x, 7, 2)
        end
    
        if track-xOff > 0 and track-xOff <= 8 then
            g:led(track-xOff, 7, mode_on_brightness)
        end
    end
end

function grid_draw_sequence_steps(highlight_selected_step, highlight_quarter_notes, y_pos, show_bar, show_selected_step)
    if gridType == gridType_64 then
        grid_draw_sequence_steps_64(highlight_selected_step, highlight_quarter_notes, y_pos, show_bar, show_selected_step)
        return
    end

    y_pos = y_pos or 1
    highlight_selected_step = highlight_selected_step or false
    highlight_quarter_notes = highlight_quarter_notes or false
    show_bar = show_bar == nil and true or show_bar
    show_selected_step = show_selected_step == nil and (gridSeq.edit_mode == seqmode_select and not shift_down) or show_selected_step

    local seq_position = gridSeq.stepIndex_to_stepId(gridSeq.position + 1)
    local seq_selectedStep = gridSeq.stepIndex_to_stepId(gridSeq.current_step)

    -- local seq_position = math.floor(gridSeq.position / 4) 
    -- if seq_position == 0 then seq_position = 16 end

    -- draw pattern steps
    for x = 1,gridSeq.bar_length do
        local step_seq_bright = 0

        if highlight_quarter_notes then
            step_seq_bright = (x % 4 == 1) and 3 or 2
        end

        if highlight_selected_step then
            -- if seq_selectedStep == x and gridSeq.edit_mode == seqmode_select and not shift_down then -- dont highlight selected step if in cut,copy, or paste modes
            if show_selected_step and seq_selectedStep == x then -- dont highlight selected step if in cut,copy, or paste modes
                step_seq_bright = gridSeq:get_stepId_mute(x) and 12 or 15
            elseif gridSeq.is_playing and seq_position == x  then 
                step_seq_bright = 15
            elseif gridSeq:does_stepId_have_notes(x) then 
                step_seq_bright = gridSeq:get_stepId_mute(x) and 0 or 9
            else
                step_seq_bright = gridSeq:get_stepId_mute(x) and 0 or step_seq_bright
            end
        else
            if gridSeq.is_playing and seq_position == x  then 
                step_seq_bright = 15
            end
        end

        if show_bar and gridSeq.is_playing and x == gridSeq.play_bar_position then
            step_seq_bright = blink_on and math.max(step_seq_bright, 6) or 2
        end

        g:led(x,y_pos,step_seq_bright)
    end
end

function grid_draw_sequence_steps_64(highlight_selected_step, highlight_quarter_notes, y_pos, show_bar, show_selected_step)
    y_pos = y_pos or 1
    highlight_selected_step = highlight_selected_step or false
    highlight_quarter_notes = highlight_quarter_notes or false
    show_bar = show_bar == nil and true or show_bar
    show_selected_step = show_selected_step == nil and (gridSeq.edit_mode == seqmode_select and not shift_down) or show_selected_step

    local seq_position = gridSeq.stepIndex_to_stepId(gridSeq.position + 1)
    local seq_selectedStep = gridSeq.stepIndex_to_stepId(gridSeq.current_step)

    local xOff = 0
    local startX = 1
    local endX = math.min(gridSeq.bar_length,8)
    if edit_steps_9_16 then 
        xOff = 8 
        startX = 9
        endX = gridSeq.bar_length
    end

    -- local seq_position = math.floor(gridSeq.position / 4) 
    -- if seq_position == 0 then seq_position = 16 end

    -- draw pattern steps
    for x = startX, endX do
        local step_seq_bright = 0

        if highlight_quarter_notes then
            step_seq_bright = (x % 4 == 1) and 3 or 2
        end

        if highlight_selected_step then
            -- if seq_selectedStep == x and gridSeq.edit_mode == seqmode_select and not shift_down then -- dont highlight selected step if in cut,copy, or paste modes
            if show_selected_step and seq_selectedStep == x then -- dont highlight selected step if in cut,copy, or paste modes
                step_seq_bright = gridSeq:get_stepId_mute(x) and 12 or 15
            elseif gridSeq.is_playing and seq_position == x  then 
                step_seq_bright = 15
            elseif gridSeq:does_stepId_have_notes(x) then 
                step_seq_bright = gridSeq:get_stepId_mute(x) and 0 or 9
            else
                step_seq_bright = gridSeq:get_stepId_mute(x) and 0 or step_seq_bright
            end
        else
            if gridSeq.is_playing and seq_position == x  then 
                step_seq_bright = 15
            end
        end

        if show_bar and gridSeq.is_playing and x == gridSeq.play_bar_position then
            step_seq_bright = blink_on and math.max(step_seq_bright, 6) or 2
        end

        g:led(x-xOff,y_pos,step_seq_bright)
    end
end

function grid_draw_image(image, brightness, xOff, yOff)
    xOff = xOff or 0
    yOff = yOff or 1
    brightness = brightness or 15

    for i,e in pairs(image) do
        g:led(xOff + e[1], yOff + e[2], brightness)
    end
end

function grid_redraw()
    current_grid_page.grid_redraw()
end

function grid_draw_toolbar()
     -- Toolbar
     local toolY = 8

     if gridSeq.record then
         if is_playing then 
             g:led(1,toolY,blink_on and 12 or 0)
         else
             g:led(1,toolY,blink_on and 8 or 0)
         end
     else
         g:led(1,toolY,gridSeq.is_playing and 12 or 2)
     end
     g:led(2,toolY, shift_down and 15 or shift_brightness) -- shift
 
     -- g:led(2,toolY,gridSeq.record and 12 or 2)
     -- g:led(2,toolY,gridKeys.layout_mode == 1 and mode_on_brightness or mode_off_brightness)

     if gridType == gridType_128 then
        g:led(3,toolY, config.grid_page_index == 1 and mode_on_brightness or mode_off_brightness) -- play mode active
        g:led(4,toolY, config.grid_page_index == 2 and mode_on_brightness or mode_off_brightness) -- pat launch mode not active
        g:led(5,toolY, config.grid_page_index == 3 and mode_on_brightness or mode_off_brightness) -- step mode not active
     elseif gridType == gridType_64 then
        g:led(3,toolY, mode_on_brightness)

        g:led(7,toolY, edit_steps_9_16 and mode_off_brightness or mode_on_brightness)
        g:led(8,toolY, edit_steps_9_16 and mode_on_brightness or mode_off_brightness)
     end
end

function GridPlay.grid_redraw()
    g:all(0)

    grid_draw_toolbar()

    -- velocity meter
    -- local vel_steps = util.round(util.linlin(1,127,0,6,config.note_velocity))
    -- for y = 0,vel_steps do
    --     g:led(1, 7-y, 8)
    -- end

    -- Toolbar
    local toolY = 8

    if gridType == gridType_128 then
        g:led(13,toolY,gridKeys.layout_mode == 2 and mode_on_brightness or mode_off_brightness)
        g:led(14,toolY,gridKeys.enable_note_highlighting and mode_on_brightness or mode_off_brightness)

        g:led(15,toolY, mode_off_brightness) -- grid down
        g:led(16,toolY, mode_off_brightness) -- grid up

        if confirm_delete then
            grid_draw_image(gridImage_x, 8, 5, 1)
        elseif shift_down then
            grid_draw_sequence_steps(true, true, 1) 
            grid_draw_bars_and_tracks()
        else
            gridKeys:draw_grid(g)
            draw_meters = true
        end
    
        -- draw pattern steps
        if gridSeq.is_playing and gridKeys.enable_note_highlighting then
            local seq_position = gridSeq.stepIndex_to_stepId(gridSeq.position + 1)
    
            if gridSeq.play_bar_position == seq_position then
                local bar_led = blink_on and 12 or 0
    
                g:led(gridSeq.play_bar_position,1,bar_led)
            else
                local bar_led = blink_on and 6 or 0
    
                g:led(gridSeq.play_bar_position,1,bar_led)
                g:led(seq_position,1,12)
            end
        end
    elseif gridType == gridType_64 then
        g:led(5,toolY,gridKeys.layout_mode == 2 and mode_on_brightness or mode_off_brightness)
        g:led(6,toolY,gridKeys.enable_note_highlighting and mode_on_brightness or mode_off_brightness)

        if confirm_delete then
            grid_draw_image(gridImage_x, 8, 1, 1)
        elseif shift_down then
            grid_draw_sequence_steps(true, true, 1) 
            grid_draw_bars_and_tracks()
        else
            gridKeys:draw_grid(g)
            draw_meters = true
            g:led(7,7, mode_off_brightness) -- grid down
            g:led(8,7, mode_off_brightness) -- grid up
        end
    
        -- draw pattern steps
        if gridSeq.is_playing and gridKeys.enable_note_highlighting then
            local seq_position = gridSeq.stepIndex_to_stepId(gridSeq.position + 1)
    
            if gridSeq.play_bar_position == seq_position then
                local bar_led = blink_on and 12 or 0

                if edit_steps_9_16 then
                    if gridSeq.play_bar_position > 8 then
                        g:led(gridSeq.play_bar_position-8,1,bar_led)
                    end
                else
                    if gridSeq.play_bar_position <= 8 then
                        g:led(gridSeq.play_bar_position,1,bar_led)
                    end
                end
            else
                local bar_led = blink_on and 6 or 0

                if edit_steps_9_16 then
                    if gridSeq.play_bar_position > 8 then
                        g:led(gridSeq.play_bar_position-8,1,bar_led)
                    end
                    if seq_position > 8 then
                        g:led(seq_position-8,1,12)
                    end
                else
                    if gridSeq.play_bar_position <= 8 then
                        g:led(gridSeq.play_bar_position,1,bar_led)
                    end
                    if seq_position <=8 then
                        g:led(seq_position,1,12)
                    end
                end
            end
        end
    end

    g:refresh()
end

function GridSeq.grid_redraw()
    g:all(0)

    grid_draw_toolbar()

    local draw_meters = false

    local xOff = 0
    local xCut = 9
    local xCopy = 10
    local xPaste = 11

    if gridType == gridType_64 then
        xCut = 4
        xCopy = 5
        xPaste = 6
        if edit_steps_9_16 then
            xOff = 8
        end
    end

    grid_draw_sequence_steps(true, true, 1) 

    if GridSeq.show_step_edit then
        grid_draw_step_edit()
    else
        -- draw toolbar
        local toolY = 8
        -- g:led(1,toolY,gridSeq.is_playing and 12 or 2)
        -- g:led(2,toolY, shift_down and 15 or shift_brightness) -- shift

        -- g:led(3,toolY, mode_off_brightness) -- play mode not active
        -- g:led(4,toolY, mode_off_brightness) -- pat launch mode not active
        -- g:led(5,toolY, mode_on_brightness) -- step mode active
        
        g:led(xCut,toolY, gridSeq.edit_mode == seqmode_cut and 15 or mode_off_brightness) -- cut
        g:led(xCopy,toolY, gridSeq.edit_mode == seqmode_copy and 15 or mode_off_brightness) -- copy
        g:led(xPaste,toolY, gridSeq.edit_mode == seqmode_paste and 15 or mode_off_brightness) -- paste

        if gridType == gridType_128 then
            g:led(13,toolY, 4) -- shift left
            g:led(14,toolY, 4) -- shift right

            g:led(15,toolY, 6) -- grid down
            g:led(16,toolY, 6) -- grid up

            if confirm_delete then
                grid_draw_image(gridImage_x, 8, 5, 1)
            elseif shift_down then
                grid_draw_bars_and_tracks()
            elseif gridSeq.edit_mode == seqmode_select then
                gridKeys:draw_grid(g)
                draw_meters = true
            elseif gridSeq.edit_mode == seqmode_cut then
                grid_draw_bars_and_tracks()
                -- grid_draw_image(gridImage_cut, 8)
            elseif gridSeq.edit_mode == seqmode_copy then
                grid_draw_bars_and_tracks()
                -- grid_draw_image(gridImage_copy, 8)
            elseif gridSeq.edit_mode == seqmode_paste then
                grid_draw_bars_and_tracks()
                -- grid_draw_image(gridImage_paste, 8)
            end
        elseif gridType == gridType_64 then
            if confirm_delete then
                grid_draw_image(gridImage_x, 8, 1, 1)
            elseif shift_down then
                grid_draw_bars_and_tracks()
            elseif gridSeq.edit_mode == seqmode_select then
                gridKeys:draw_grid(g)
            elseif gridSeq.edit_mode == seqmode_cut then
                grid_draw_bars_and_tracks()
                -- grid_draw_image(gridImage_cut, 8)
            elseif gridSeq.edit_mode == seqmode_copy then
                grid_draw_bars_and_tracks()
                -- grid_draw_image(gridImage_copy, 8)
            elseif gridSeq.edit_mode == seqmode_paste then
                grid_draw_bars_and_tracks()
                -- grid_draw_image(gridImage_paste, 8)
            end

            g:led(7,7, 6) -- grid down
            g:led(8,7, 6) -- grid up
        end

        if draw_meters then
            local vel_steps = util.round(util.linlin(1,127,0,5,gridSeq:get_current_step_velocity()))
            for y = 0,vel_steps do
                g:led(15, 7-y, 8)
            end

            local stepNoteLength = gridSeq:get_current_step_note_length()

            local note_steps = 0

            for i = 1, #seq_noteLengths do
                if stepNoteLength > seq_noteLengths[i] then
                    note_steps = note_steps + 1
                end
            end

            note_steps = math.min(note_steps, 5)

            -- local note_steps = util.round(util.linlin(0.5,32,0,5,gridSeq:get_current_step_note_length()))
            for y = 0,note_steps do
                g:led(16, 7-y, 8)
            end
        end
    end

    g:refresh()
end

function grid_draw_param_edit(edit_type)
    g:all(0)

    local xWidth = 16
    local xOff = 0
    local xCut = 9
    local xCopy = 10
    local xPaste = 11

    if gridType == gridType_64 then
        xWidth = 8
        xCut = 4
        xCopy = 5
        xPaste = 6
        if edit_steps_9_16 then
            xOff = 8
        end
    end

    -- velocity meters
    for x = 1,xWidth do
        if gridSeq:does_stepId_have_notes(x+xOff) then
            if edit_type == 1 then -- velocity
                -- g:led(x,1,9)

                local vel_steps = util.round(util.linlin(1,127,0,5,gridSeq:get_stepId_velocity(x+xOff)))

                local led_brightness = x+xOff > gridSeq.bar_length and 3 or 8

                for y = 0,vel_steps do
                    g:led(x, 7-y, led_brightness)
                end
            elseif edit_type == 2 then -- note lengths
                local stepNoteLength = gridSeq:get_stepId_note_length(x+xOff)
                local note_steps = 0

                for i = 1, #seq_noteLengths do
                    if stepNoteLength > seq_noteLengths[i] then
                        note_steps = note_steps + 1
                    end
                end

                local led_brightness = x > gridSeq.bar_length and 3 or 8

                for y = 0,note_steps do
                    g:led(x, 7-y, led_brightness)
                end
            end
        end
    end

    grid_draw_sequence_steps(true, true, 1)

    -- draw toolbar
    local toolY = 8

    if gridType == gridType_128 then
        g:led(1,toolY,mode_off_brightness)
        g:led(3,toolY,edit_type == 1 and mode_on_brightness or mode_off_brightness)
        g:led(4,toolY,edit_type == 2 and mode_on_brightness or mode_off_brightness)
        g:led(5,toolY,edit_type == 3 and mode_on_brightness or mode_off_brightness)
    elseif gridType == gridType_64 then
        g:led(1,toolY,mode_off_brightness)
        g:led(3,toolY,mode_on_brightness)

        g:led(7,toolY, edit_steps_9_16 and mode_off_brightness or mode_on_brightness)
        g:led(8,toolY, edit_steps_9_16 and mode_on_brightness or mode_off_brightness)
    end

    g:led(xCut,toolY, gridSeq.edit_mode == seqmode_cut and 15 or mode_off_brightness) -- cut
    g:led(xCopy,toolY, gridSeq.edit_mode == seqmode_copy and 15 or mode_off_brightness) -- copy
    g:led(xPaste,toolY, gridSeq.edit_mode == seqmode_paste and 15 or mode_off_brightness) -- paste

    g:refresh()
end

function GridSeqVel.grid_redraw()
    grid_draw_param_edit(1)
    -- g:all(0)

    -- local xWidth = 16
    -- local xOff = 0
    -- local xCut = 9
    -- local xCopy = 10
    -- local xPaste = 11

    -- if gridType == gridType_64 then
    --     xWidth = 8
    --     xCut = 4
    --     xCopy = 5
    --     xPaste = 6
    --     if edit_steps_9_16 then
    --         xOff = 8
    --     end
    -- end

    -- -- velocity meters
    -- for x = 1,xWidth do
    --     if gridSeq:does_stepId_have_notes(x+xOff) then
    --         -- g:led(x,1,9)

    --         local vel_steps = util.round(util.linlin(1,127,0,5,gridSeq:get_stepId_velocity(x+xOff)))

    --         local led_brightness = x+xOff > gridSeq.bar_length and 3 or 8

    --         for y = 0,vel_steps do
    --             g:led(x, 7-y, led_brightness)
    --         end
    --     end
    -- end

    -- grid_draw_sequence_steps(true, true, 1)

    -- -- draw toolbar
    -- local toolY = 8

    -- if gridType == gridType_128 then
    --     g:led(1,toolY,mode_off_brightness)
    --     g:led(3,toolY,mode_on_brightness)
    --     g:led(4,toolY,mode_off_brightness)
    --     g:led(5,toolY,mode_off_brightness)
    -- elseif gridType == gridType_64 then
    --     g:led(1,toolY,mode_off_brightness)
    --     g:led(3,toolY,mode_on_brightness)

    --     g:led(7,toolY, edit_steps_9_16 and mode_off_brightness or mode_on_brightness)
    --     g:led(8,toolY, edit_steps_9_16 and mode_on_brightness or mode_off_brightness)
    -- end

    -- g:led(xCut,toolY, gridSeq.edit_mode == seqmode_cut and 15 or mode_off_brightness) -- cut
    -- g:led(xCopy,toolY, gridSeq.edit_mode == seqmode_copy and 15 or mode_off_brightness) -- copy
    -- g:led(xPaste,toolY, gridSeq.edit_mode == seqmode_paste and 15 or mode_off_brightness) -- paste

    -- g:refresh()
end

function GridSeqNoteLengths.grid_redraw()
    grid_draw_param_edit(2)

    -- g:all(0)

    -- -- velocity meters
    -- for x = 1,16 do
    --     if gridSeq:does_stepId_have_notes(x) then
    --         local stepNoteLength = gridSeq:get_stepId_note_length(x)
    --         local note_steps = 0

    --         for i = 1, #seq_noteLengths do
    --             if stepNoteLength > seq_noteLengths[i] then
    --                 note_steps = note_steps + 1
    --             end
    --         end

    --         local led_brightness = x > gridSeq.bar_length and 3 or 8

    --         for y = 0,note_steps do
    --             g:led(x, 7-y, led_brightness)
    --         end
    --     end
    -- end

  
    -- grid_draw_sequence_steps(true, true, 1)

    -- -- draw toolbar
    -- local toolY = 8
    -- g:led(1,toolY,mode_off_brightness)
    -- g:led(3,toolY,mode_off_brightness)
    -- g:led(4,toolY,mode_on_brightness)
    -- g:led(5,toolY,mode_off_brightness)

    -- g:led(9,toolY, gridSeq.edit_mode == seqmode_cut and 15 or mode_off_brightness) -- cut
    -- g:led(10,toolY, gridSeq.edit_mode == seqmode_copy and 15 or mode_off_brightness) -- copy
    -- g:led(11,toolY, gridSeq.edit_mode == seqmode_paste and 15 or mode_off_brightness) -- paste

    -- g:refresh()
end

function GridPatLaunch.grid_redraw()
    g:all(0)

    local xWidth = 16
    local xOff = 0
    local xCut = 9
    local xCopy = 10
    local xPaste = 11

    if gridType == gridType_64 then
        xWidth = 8
        xCut = 4
        xCopy = 5
        xPaste = 6
        if edit_steps_9_16 then
            xOff = 8
        end
    end


    for x = 1,xWidth do
        local seq = all_gridSeqs[x+xOff]

        local mute = all_gridSeqs[x+xOff].mute_seq

        if x+xOff == track then
            g:led(x,1, mute and 2 or 15)
        else
            g:led(x,1, mute and 0 or 6)
        end

        for y = 2, 7 do
            local patIndex = y-1+patLaunchConfig.y_offset
            local ledBrightness = patIndex == seq.selected_pattern and (x+xOff == track and 15 or (mute and 4 or 9)) or 1
            if seq:does_pattern_have_notes(patIndex) then
                ledBrightness = math.max((mute and 3 or 5), ledBrightness)
            elseif patIndex > 16 then
                ledBrightness = 0
            end

            if is_playing and patIndex == seq.active_pattern then

                ledBrightness = util.round(util.linlin(0,1,1,math.max(ledBrightness, 4),blink_fade))
                -- ledBrightness = blink_on and math.max(ledBrightness, 4) or 1
            end

            g:led(x,y,ledBrightness)
        end
    end

    grid_draw_toolbar()

    if gridType == gridType_128 then
        if is_playing then
            local seq_position = gridSeq.stepIndex_to_stepId(gridSeq.position + 1)
            g:led(seq_position,1,12)
        end
    
        local toolY = 8
    
        g:led(xCut,toolY, patLaunchConfig.edit_mode == 2 and 15 or mode_off_brightness) -- cut
        g:led(xCopy,toolY, patLaunchConfig.edit_mode == 3 and 15 or mode_off_brightness) -- copy
        g:led(xPaste,toolY, patLaunchConfig.edit_mode == 4 and 15 or mode_off_brightness) -- paste
    
        g:led(15,toolY, mode_off_brightness) -- grid down
        g:led(16,toolY, mode_off_brightness) -- grid up
    elseif gridType == gridType_64 then
        if is_playing then
            local seq_position = gridSeq.stepIndex_to_stepId(gridSeq.position + 1)
            if edit_steps_9_16 then
                if seq_position > 8 then
                    g:led(seq_position-8,1,12)
                end
            else
                if seq_position <= 8 then
                    g:led(seq_position,1,12)
                end
            end
        end
    
        local toolY = 8
    
        g:led(xCut,toolY, patLaunchConfig.edit_mode == 2 and 15 or mode_off_brightness) -- cut
        g:led(xCopy,toolY, patLaunchConfig.edit_mode == 3 and 15 or mode_off_brightness) -- copy
        g:led(xPaste,toolY, patLaunchConfig.edit_mode == 4 and 15 or mode_off_brightness) -- paste
    
        -- g:led(15,toolY, mode_off_brightness) -- grid down
        -- g:led(16,toolY, mode_off_brightness) -- grid up
    end

    g:refresh()
end

function key(n,z)
    if fileselect_active or textentry_active then
        return
    end

    if should_show_trig_page() then
        PageTrig.key(n,z)
    else
        current_page.key(n,z)
    end

    
end

function enc(n,d)
    if fileselect_active or textentry_active then
        return
    end

    if should_show_trig_page() then
        PageTrig.enc(n,d)
    else
        if n == 1 then
            local prevPage = config.page_index
            enc_d.page_index = util.clamp(enc_d.page_index + util.clamp(d, -1, 1) * 0.15, 1, #pages) -- makes it take longer to turn to change selection, very nice
            config.page_index = util.round(enc_d.page_index)

            if config.page_index ~= prevPage then
                if current_page.on_disable ~= nil then current_page.on_disable() end

                current_page = pages[config.page_index]
                -- if current_page.init ~= nil then current_page.init() end

                if current_page.on_enable ~= nil then current_page.on_enable() end

                -- redraw()
            end

        else
            current_page.enc(n,d)
        end
    end
end

function should_show_trig_page()
    local pageTitle = page_titles[config.page_index]
    return showTrigPage and pageTitle ~= "Step Time" and pageTitle ~= "Trig"
end

function redraw()
    if fileselect_active or textentry_active then
        return
    end
    screen.clear()

    screen.aa(0)

    -- local pageTitle = page_titles[config.page_index]
    -- local dontShowTrigPage = pageTitle == "Step Time" or pageTitle == "Trig"

    -- "Step Time", "Track", "Trig",

    if should_show_trig_page() then
        PageTrig.redraw()
        draw_page_header(page_titles[config.page_index])
    else
        current_page.redraw()
        draw_page_header(page_titles[config.page_index])
    end

    -- if display_notification then
    --     draw_notification()
    -- end

    screen.update()
end

function show_notification(message)
    message = message or ""

    if temp_notification then
        clock.cancel(notification_clockId)
    end

    display_notification = true
    notification_text = message
    -- redraw()
end

function clear_notification()
    display_notification = false
    notification_text = ""
    -- redraw()
end

function show_temporary_notification(message, duration)
    message = message or ""
    duration = duration or 1

    if temp_notification then
        clock.cancel(notification_clockId)
    end

    display_notification = true
    temp_notification = true

    notification_text = message
    -- print("showing notification")
    -- redraw()

    notification_clockId = clock.run(
    function()
        clock.sleep(duration)
        -- print("Hiding notification")
        display_notification = false
        temp_notification = false
        notification_text = ""
        -- redraw()
    end
    )
end

function draw_notification()
    -- print("drawing notification")
    screen.rect(10, 10, 128-20, 64-20)
    screen.level(0)
    screen.fill()
    screen.rect(10, 10, 128-20, 64-20)
    screen.level(15)
    screen.stroke()
    screen.level(15)
    screen.move(64,34)
    screen.text_center(notification_text)
end

function draw_reset_font()
    screen.font_face(1)
    screen.font_size(8)
end

function get_pattern_letter(patIndex)
    patIndex = patIndex or gridSeq.selected_pattern
    return pattern_num_to_letter[patIndex]
end

function draw_page_header(page_title)

    -- draw pages line
    screen.line_width(1)
    -- local page_line_width = math.floor(128 / #pages)
    local page_line_width = 6
    for i = 1,#pages do
        screen.level(i == config.page_index and 15 or 4)
        screen.move((i-1)*page_line_width, 1)
        screen.line_rel(4, 0)
        screen.stroke()
    end

    screen.level(4)
    screen.move(#pages * page_line_width, 1)
    screen.line(128, 1)
    screen.stroke()

    screen.display_png(img_path.."header"..config.header_img..".png",0,2)

    
    -- screen.level(15)
    -- screen.rect(0,2,14+4,10)
    -- screen.fill()

    -- local track_string = string.format("%02d",track).."A"
    -- local extents = screen.text_extents(track_string)

    -- print("Extents: "..extents) -- min: 10 max: 14

    draw_reset_font()

    screen.level(0)
    screen.move(16,10)
    -- screen.font_face(1)
    -- screen.font_size(9)
    screen.text_right(string.format("%d",track)..get_pattern_letter())


    -- screen.level(15)
    -- screen.rect(128-24,2,24,10)
    -- screen.fill()

    -- local bpm_string = "♪"..string.format("%03d", clock.get_tempo())
    -- extents = screen.text_extents(bpm_string)

    -- print("Extents: "..extents) -- max: 20

    draw_reset_font()

    screen.level(0)
    screen.move(128-2,10)
    -- screen.font_face(1)
    -- screen.font_size(9)
    -- screen.text_right("♪"..string.format("%03d", math.floor(clock.get_tempo())))

    -- screen.text_right(string.format("%3d", math.floor(clock.get_tempo())))

    screen.text_right(util.round(clock.get_tempo()))



    screen.level(15)
    screen.move(21,12)
    screen.font_face(18)
    screen.font_size(11)
    -- page_title = "Long ass title like really long"
    -- page_title = "0808080808080808080808080"
    page_title = string.sub(page_title, 1, 11)  
    screen.text(page_title)


    if display_notification then
        -- screen.level(15)
        -- screen.rect(20,2,128 - 20,10)
        -- screen.fill()
        config.header_notification_y = util.clamp(config.header_notification_y + 4, -10, 2)



        
    else
        config.header_notification_y = util.clamp(config.header_notification_y - 4, -10, 2)
    end

    if config.header_notification_y > -10 then
        screen.display_png(img_path.."header_notification.png",20,config.header_notification_y)

        -- screen.level(15)
        -- screen.rect(20,2,128 - 20,10)
        -- screen.fill()

        screen.level(0)
        screen.move(23, config.header_notification_y + 8)
        screen.font_face(1)
        screen.font_size(8)
        screen.text(util.trim_string_to_width(notification_text, 128-20-4))
    end

    draw_reset_font()
end

PageTrack.paramUtil = {}



function PageTrack.init()

    PageTrack.paramUtil = ParamListUtil.new()
    PageTrack.paramUtil.redraw_func = redraw

    -- PageTrack.paramUtil:reset_options()

    PageTrack.paramUtil:add_option("Track",
        function() return track end,
        function(d,d_raw) 
            if change_track(track + d) then
                grid_redraw()
            end
        end
    )
    PageTrack.paramUtil:add_option("Pattern",
        function() return gridSeq.selected_pattern end,
        function(d,d_raw) 
            if gridSeq:change_selected_pattern(gridSeq.selected_pattern + d) then
                grid_redraw()
            end
        end
    )
    PageTrack.paramUtil:add_option("Sound Source",
        function() return SoundModes[gridKeys.sound_mode] end,
        function(d,d_raw) 
            gridKeys.sound_mode = util.clamp(gridKeys.sound_mode + d, 1, 2)
        end
    )
    PageTrack.paramUtil:add_option("Midi Channel",
        function() return gridKeys.midi_channel end,
        function(d,d_raw) 
            gridKeys.midi_channel = util.clamp(gridKeys.midi_channel + d, 1, 16)
        end
    )
    PageTrack.paramUtil:add_option("Midi Device",
        function() return gridKeys.midi_device end,
        function(d,d_raw) 
            gridKeys.midi_device = util.clamp(gridKeys.midi_device + d, 1, 4)
        end
    )
    PageTrack.paramUtil:add_option("Bar Length",
        function() return gridSeq.bar_length end,
        function(d,d_raw)
            if gridSeq:set_length(gridSeq.bar_length + d, gridSeq.num_bars) then
                grid_redraw()
            end
        end
    )
    PageTrack.paramUtil:add_option("Bars",
        function() return gridSeq.num_bars end,
        function(d,d_raw) 
            if gridSeq:set_length(gridSeq.bar_length, gridSeq.num_bars + d) then
                grid_redraw()
            end
        end
    )
    PageTrack.paramUtil:add_option("Selected Bar",
        function() return gridSeq.selected_bar end,
        function(d,d_raw) 
            local newBar = util.clamp(gridSeq.selected_bar + d, 1, gridSeq.num_bars)
            if gridSeq.selected_bar ~= newBar then
                gridSeq:change_selected_bar(newBar)
                grid_redraw()
            end
        end
    )
    -- PageTrack.paramUtil:add_option("Test1")
    -- PageTrack.paramUtil:add_option("Test2")

    -- PageTrack.paramUtil:add_option("Bears")
    -- PageTrack.paramUtil:add_option("Penguins")
    -- PageTrack.paramUtil:add_option("Parrots")
    -- PageTrack.paramUtil:add_option("Monkeys")

end
function PageTrack.key(n,z)
end
function PageTrack.enc(n,d)
    PageTrack.paramUtil:enc(n,d)
end



function PageTrack.redraw()
    PageTrack.paramUtil:redraw()
end

PageScale.paramUtil = {}

function PageScale.init()
    PageScale.paramUtil = ParamListUtil.new()
    PageScale.paramUtil.redraw_func = redraw
    PageScale.paramUtil.start_y = 20
    PageScale.paramUtil.display_num = 3
    PageScale.paramUtil.scroll_offset = 1

    PageScale.paramUtil:add_option("Root",
        function() return music.NOTE_NAMES[config.root_note] end,
        function(d,d_raw) 
            local prevRootNote = config.root_note
            config.root_note = util.clamp(config.root_note + d, 1, #music.NOTE_NAMES)

            if config.root_note ~= prevRootNote then 
                for i,gk in pairs(all_gridKeys) do
                    gk:change_scale(config.root_note, config.scale_mode)
                end
                all_midi_notes_off()
                grid_redraw()
                all_engine_notes_off()
            end
        end
    )

    PageScale.paramUtil:add_option("Scale",
        function() return music.SCALES[config.scale_mode].name end,
        function(d,d_raw)
            local prevScaleMode = config.scale_mode
            config.scale_mode = util.clamp(config.scale_mode + d, 1, #music.SCALES)

            if config.scale_mode ~= prevScaleMode then
                for i,gk in pairs(all_gridKeys) do
                    gk:change_scale(config.root_note, config.scale_mode)
                end
                all_midi_notes_off()
                grid_redraw()
                all_engine_notes_off()
            end
        end
    )
    PageScale.paramUtil:add_option("Grid Layout",
        function() return  Q7GridKeys.layout_names[gridKeys.layout_mode] end,
        function(d,d_raw)
            if d ~= 0 then
                change_gridKey_layout()
                grid_redraw()
            end
        end
    )
end

function PageScale.key(n,z)
    PageScale.paramUtil:key(n,z)
end

function PageScale.enc(n,d)
    PageScale.paramUtil:enc(n,d)
end

function PageScale.draw_white_key(x,y,keyActive,keyIsRoot)
    screen.level(keyIsRoot and 15 or keyActive and 8 or 2)
    screen.rect(x,y, 4, 15)
    screen.fill()
end

function PageScale.draw_black_key(x,y,keyActive,keyIsRoot)
    screen.level(0)
    screen.rect(x,y, 3, 8)
    screen.fill()

    screen.level(keyIsRoot and 15 or keyActive and 8 or 0)
    screen.move(x+2,y)
    screen.line(x+2,y + 7)
    screen.stroke()
end


function PageScale.redraw()
    local xPos = 46
    local yPos = 14

    for i = 1,12 do
        if whiteKeys[i] == 1 then
            PageScale.draw_white_key(xPos, yPos, gridKeys:is_note_in_scale(i-1+12), i == config.root_note)
            xPos = xPos + 5
        end
    end

    xPos = 46 + 3

    for i = 1,12 do
        if whiteKeys[i] == 0 then
            PageScale.draw_black_key(xPos, yPos, gridKeys:is_note_in_scale(i-1+12), i == config.root_note)

            if i == 4 then
                xPos = xPos + 10
            else
                xPos = xPos + 5
            end
        end
        
    end

    PageScale.paramUtil:redraw()
end


PageSound.paramUtil = {}

function PageSound.init()
    PageSound.paramUtil = ParamListUtil.new()
    PageSound.paramUtil.redraw_func = redraw
    -- PageSound.paramUtil.start_y = 20
    -- PageSound.paramUtil.display_num = 2
    -- PageSound.paramUtil.scroll_offset = 1
    if _MOLLY_ENGINE then
        PageSound.paramUtil:add_option("Random Lead", nil, nil,
            function(n,z)
                if n == 3 and z == 1 then
                    print("Random lead")
                    MollyThePoly.randomize_params("lead")
                end
            end
        )
        PageSound.paramUtil:add_option("Random Pad", nil, nil,
            function(n,z)
                if n == 3 and z == 1 then
                    print("Random pad")
                    MollyThePoly.randomize_params("pad")
                end
            end
        )
        PageSound.paramUtil:add_option("Random Perc", nil, nil,
            function(n,z)
                if n == 3 and z == 1 then
                    print("Random perc")
                    MollyThePoly.randomize_params("perc")
                end
            end
        )
    end
end

function PageSound.key(n,z)
    PageSound.paramUtil:key(n,z)
end
function PageSound.enc(n,d)
    PageSound.paramUtil:enc(n,d)
end
function PageSound.redraw()
    PageSound.paramUtil:redraw()
end


function PageQ7.init()
end
function PageQ7.key(n,z)
end
function PageQ7.enc(n,d)
end
function PageQ7.redraw()
    screen.level(15)
    screen.move(64,20)
    screen.text_center("GridStep was created by")
    screen.move(64,30)
    screen.text_center("Michael Jones / Quixotic7")
    screen.move(64,50)
    screen.text_center("Make music and enjoy life!")
    -- screen.update()
end

PageTest.paramUtil = {}

PageTest.test = {0,0,0,0,0,0,0,0}

function PageTest.init()
    PageTest.paramUtil = GraphicPageOptions.new(1,13,128,64-13)
    PageTest.paramUtil.redraw_func = redraw

    -- name, display_type, min_value, max_value, rounding, units, get_value_func, delta_func, key_func
    -- PageTest.paramUtil:add_option("Cond", 1, 1, 100, "", "",
    --     function() return "100%" end,
    --     function(d,d_raw) 
    --         -- PageTest.test[i] = PageTest.test[i] + d_raw
    --     end
    -- )
    -- PageTest.paramUtil:add_option("Cond", 1, 1, 100, "", "",
    --     function() return "100%" end,
    --     function(d,d_raw) 
    --         -- PageTest.test[i] = PageTest.test[i] + d_raw
    --     end
    -- )
    -- PageTest.paramUtil:add_option("LEN", 4, 0, 1, "", "",
    --     function() 
    --         local v = PageTest.test[3]
    --         local dv = ""

    --         if v == 1 then
    --             dv = "1/16"
    --         elseif v == 2 then
    --             dv ="1/8"
    --         elseif v == 4 then
    --             dv ="1/4"
    --         elseif v == 8 then
    --             dv = "1/2"
    --         elseif v == 16 then
    --             dv = "1 BAR"
    --         elseif v == 32 then
    --             dv = "2 BAR"
    --         elseif v == 64 then
    --             dv = "4 BAR"
    --         elseif v > 8 then
    --             dv = string.format("%.0f", v)
    --         else
    --             dv = string.format("%.2f", v)
    --         end

    --         if v <= 8 then
    --             v = util.linlin(0.25,8,0,0.5,v)
    --         else
    --             v = util.linlin(8,64,0.5,1,v)
    --         end

    --         return v,dv
    --     end,
    --     function(d,d_raw) 
    --         local v = PageTest.test[3]

    --         d_raw = util.clamp(d_raw,-1,1)

    --         if v <= 8 then
    --             if v == 8 and d_raw > 0 then
    --                 PageTest.test[3] = util.clamp(math.floor(v) + d_raw,0.25,64)
    --             else
    --                 PageTest.test[3] = util.clamp(v + d_raw*0.25,0.25,64)
    --             end
    --         else
    --             PageTest.test[3] = util.clamp(math.floor(v) + d_raw,0.25,64)
    --         end
    --     end
    -- )
    -- PageTest.paramUtil:add_option("VEL", 2, 1, 127, "%d", "",
    --     function() return PageTest.test[4] end,
    --     function(d,d_raw) 
    --         PageTest.test[4] = util.clamp(PageTest.test[4] + d_raw,1,127)
    --     end
    -- )

    for i = 1,8 do
        -- name, display_type, min_value, max_value, stringFormat, units, get_value_func, delta_func, key_func

        if i == 3 or i == 7 then
            local o = PageTest.paramUtil:add_option("CC"..i, GraphicPageOptions.type_dial, 0, 100, "", "",
                function() return PageTest.test[i] end,
                function(d,d_raw) 
                    PageTest.test[i] = util.clamp(PageTest.test[i] + d_raw,0,100)
                end
            ) 
        elseif i % 2 == 0 then
            local o = PageTest.paramUtil:add_option("CC"..i, GraphicPageOptions.type_slider, 0, 100, "", "",
                function() return PageTest.test[i] end,
                function(d,d_raw) 
                    PageTest.test[i] = util.clamp(PageTest.test[i] + d_raw,0,100)
                end
            )
        else
            local o = PageTest.paramUtil:add_option("Vel", GraphicPageOptions.type_value_box_outlined, 0, 100, "", "",
                function() return PageTest.test[i] end,
                function(d,d_raw) 
                    PageTest.test[i] = util.clamp(PageTest.test[i] + d_raw,0,100)
                end
            )
        end
    end
end
function PageTest.key(n,z)
    PageTest.paramUtil:key(n,z)
end
function PageTest.enc(n,d)
    PageTest.paramUtil:enc(n,d)
end
function PageTest.redraw()
    PageTest.paramUtil:redraw()
end

PageClock.paramUtil = {}

function PageClock.init()
    PageClock.paramUtil = ParamListUtil.new()
    PageClock.paramUtil.redraw_func = redraw

    PageClock.paramUtil:add_option("Clock Source",
        function() return params:string("clock_source") end,
        function(d,d_raw) 
            params:delta("clock_source", d)
        end
    )

    PageClock.paramUtil:add_option("BPM",
        function() return params:string("clock_tempo") end,
        function(d,d_raw) 
            params:delta("clock_tempo", d_raw)
        end
    )

end

function PageClock.key(n,z)
    -- if n == 3 and z == 1 then
    --     MollyThePoly.randomize_params("lead")
    -- end
end
function PageClock.enc(n,d)
    PageClock.paramUtil:enc(n,d)
end
function PageClock.redraw()
    PageClock.paramUtil:redraw()
end


PageTrig.paramUtil = {}

PageTrig.offsetSlider = {}
PageTrig.enable_snap = false

function PageTrig.init()
    PageTrig.enable_snap = false
    PageTrig.paramUtil = GraphicPageOptions.new(10,15,128-20,32)
    PageTrig.paramUtil.redraw_func = redraw

    PageTrig.offsetSlider = UI.TimeSlider.new("Offset Time", 12, 45, 128-24, 8, 0, -1, 1, true, true)

    -- name, display_type, min_value, max_value, stringFormat, units, get_value_func, delta_func, key_func
    PageTrig.paramUtil:add_option("COND", GraphicPageOptions.type_value_box, 0, #Q7GridSeq.trigConditions, "", "",
        function() 
            local c = gridSeq:get_stepId_cond(gridSeq:get_current_stepId())

            if c <= 1 then
                local p = util.round(c * 100) 
                return c, string.format("%d", p).."%"
            else
                return c, Q7GridSeq.trigConditions[c]
            end
        end,
        function(d,d_raw) 
            local stepId = gridSeq:get_current_stepId()
            local c = gridSeq:get_stepId_cond(stepId)

            local newC = c 

            if c == 1 then -- probability if down, condition if up
                if d_raw < 0 then
                    newC = util.clamp(c + d_raw * 0.05, 0, 1)
                else
                    newC = util.clamp(c + util.clamp(d_raw,-1,1), 1, #Q7GridSeq.trigConditions)
                end
            elseif c > 1 then -- condition
                newC = util.clamp(c + util.clamp(d_raw,-1,1), 1, #Q7GridSeq.trigConditions)
            else -- probability
                newC = util.clamp(c + d_raw * 0.05, 0, 1)
            end

            gridSeq:change_cond_stepId(newC, stepId)
            grid_redraw()
        end
    )
    PageTrig.paramUtil:add_option("VEL", GraphicPageOptions.type_slider, 0, 127, "%d", "",
        function() 
            return gridSeq:get_stepId_velocity(gridSeq:get_current_stepId())
        end,
        function(d,d_raw) 
            local stepId = gridSeq:get_current_stepId()
            local vel = gridSeq:get_stepId_velocity(stepId)
            local newVel = util.clamp(vel + d_raw, 0, 127)

            gridSeq:change_velocity_stepId(newVel, stepId)
            grid_redraw()
        end
    )
    PageTrig.paramUtil:add_option("LEN", GraphicPageOptions.type_dial, 0, 1, "", "",
        function() 
            local v = gridSeq:get_stepId_note_length(gridSeq:get_current_stepId())
            local dv = ""

            if v == 1 then
                dv = "1/16"
            elseif v == 2 then
                dv ="1/8"
            elseif v == 4 then
                dv ="1/4"
            elseif v == 8 then
                dv = "1/2"
            elseif v == 16 then
                dv = "1 BAR"
            elseif v == 32 then
                dv = "2 BAR"
            elseif v == 64 then
                dv = "4 BAR"
            elseif v > 8 then
                dv = string.format("%.0f", v)
            else
                dv = string.format("%.2f", v)
            end

            -- custom scale displayed knob values so 8 is centered
            if v <= 8 then
                v = util.linlin(0.25,8,0,0.5,v)
            else
                v = util.linlin(8,64,0.5,1,v)
            end

            return v,dv
        end,
        function(d,d_raw) 
            local stepId = gridSeq:get_current_stepId()
            local v = gridSeq:get_stepId_note_length(stepId)

            d_raw = util.clamp(d_raw,-1,1)

            if v <= 8 then -- less than 1/2 change by steps of 0.25
                if v == 8 and d_raw > 0 then -- 8 but going up, increment in steps of 1
                    gridSeq:change_noteLength_stepId(util.clamp(math.floor(v) + d_raw,0.25,64), stepId)
                else
                    gridSeq:change_noteLength_stepId(util.clamp(v + d_raw*0.25,0.25,64), stepId)
                end
            else  -- greater than 8, change by steps of 1
                gridSeq:change_noteLength_stepId(util.clamp(math.floor(v) + d_raw,0.25,64), stepId)
            end

            grid_redraw()

        end
    )
end

function PageTrig.key(n,z)
    if PageTrig.paramUtil.selection == 4 then
        if n == 2 then
            if z == 1 then
                PageTrig.enable_snap = true
            else
                PageTrig.enable_snap = false
            end
        elseif n == 3 and z == 1 then
            gridSeq:set_triplet_mode(not gridSeq:get_triplet_mode())
        end
    else
        PageTrig.paramUtil:key(n,z)
    end
    -- PageMicroTiming.paramUtil:key(n,z)

    -- if n == 2 then
    --     if z == 1 then
    --         PageMicroTiming.enable_snap = true
    --     else
    --         PageMicroTiming.enable_snap = false
    --     end
    -- elseif n == 3 and z == 1 then
    --     gridSeq.triplet_mode = not gridSeq.triplet_mode
    -- end
end
function PageTrig.enc(n,d)
    if n == 2 then
        -- self.dial:set_value_delta(d * 0.05)
        local prevSelection = PageTrig.paramUtil.selection
        PageTrig.paramUtil.selection_d, PageTrig.paramUtil.selection = Q7Util.enc_delta_slow(d, PageTrig.paramUtil.selection_d, 1, 4)

        if prevSelection ~= PageTrig.paramUtil.selection then
            PageTrig.paramUtil.enc3_d = 0
        end
    end


    if PageTrig.paramUtil.selection == 4 then
        if n == 3 then
            local v = gridSeq:get_stepId_offset(gridSeq:get_current_stepId())

            local newV = v + util.clamp(d,-1,1)

            if PageTrig.enable_snap then
                local increment = gridSeq:get_substep_count() / 4
                newV = v + (util.clamp(d,-1,1) * increment)
            end

            gridSeq:set_stepId_offset(gridSeq:get_current_stepId(), newV)

            grid_redraw()
        end
    else
        PageTrig.paramUtil:enc(n, d, true) -- ignore selections
    end

    -- PageMicroTiming.paramUtil:enc(n,d)

end
function PageTrig.redraw()
    -- draw_page_header("Trig")

    PageTrig.paramUtil:redraw()



    PageTrig.offsetSlider.selected = PageTrig.paramUtil.selection == 4
    PageTrig.offsetSlider.active = gridSeq:does_stepId_have_notes()
    PageTrig.offsetSlider.value_labels = gridSeq:get_triplet_mode() and PageMicroTiming.triplet_value_labels or PageMicroTiming.normal_value_labels
    PageTrig.offsetSlider.substep_count = gridSeq:get_substep_count()
    PageTrig.offsetSlider.value = gridSeq:get_stepId_offset(gridSeq:get_current_stepId())
    PageTrig.offsetSlider.min_value = -gridSeq:get_substep_count()
    PageTrig.offsetSlider.max_value = gridSeq:get_substep_count()

    PageTrig.offsetSlider:redraw()
    -- screen.level(PageMicroTiming.enable_snap and 15 or 3)
    -- screen.move(2,60)
    -- screen.text("[K2] Snap")

    -- screen.level(gridSeq.triplet_mode and 15 or 3)
    -- screen.move(128-2,60)
    -- screen.text_right("Triplet Mode [K3]")
end

function get_serialized_table()
    local d = {}

    d.version = version_number
    d.root_note = config.root_note
    d.scale_mode = config.scale_mode

    d.gridKeys = {}

    for i = 1,#all_gridKeys do
        d.gridKeys[i] = all_gridKeys[i]:get_serialized()
    end

    d.gridSeqs = {}

    for i = 1,#all_gridSeqs do
        d.gridSeqs[i] = all_gridSeqs[i]:get_serialized()
    end

    return d
end

function load_serialized_table(d)
    if d == nil then
        print("Error: Bad serialized data")
        return
    end

    config.root_note = d.root_note
    config.scale_mode = d.scale_mode

    for i = 1,#all_gridKeys do
        all_gridKeys[i]:load_serialized(d.gridKeys[i])
    end

    for i = 1,#all_gridSeqs do
        all_gridSeqs[i]:load_serialized(d.gridSeqs[i])
    end

    -- set scales and root notes
    for i,gk in pairs(all_gridKeys) do
        gk:change_scale(config.root_note, config.scale_mode)
    end

    -- reset deltas
    enc_d.root_note = config.root_note
    enc_d.scale_mode = config.scale_mode

    -- gridSeq:load_serialized(d.gridSeq)
end

function load_project(path)
    fileselect_active = false

    if path == "cancel" then return end
    if path == "" then return end

    print("Load: "..path)

    local file = io.open(path)
    if file ~= nil then  
        io.close(file)

        load_serialized_table(tab.load(path))

        project_name = path:sub(#data_path+1, #path-4)

        local pset_path = params_path..project_name.."_params.pset"

        if util.file_exists(pset_path) then
            params:read(pset_path) 
            print("Presets loaded")
        end

        show_temporary_notification(project_name.." Load")
        redraw()
        grid_redraw()
    else
        print("Cannot load, bad path. "..path)
    end
end

function save_project(saveName)
    textentry_active = false

    if saveName == nil then return end
    if saveName == "" then 
        print("Cannot save file without a name")
        return
    end

    project_name = saveName

    show_temporary_notification(project_name.." saved")

    local save_path = data_path..project_name..".txt"

    -- print("Save: "..path)

    print("Project: "..project_name.." saved to "..save_path)

    if not util.file_exists(params_path) then
        util.make_dir(params_path)
        print("Made params directory")
    end

    params:write(params_path..project_name.."_params.pset")

    tab.save(get_serialized_table(), save_path)

    redraw()


    -- params:write(storage.."params/"..filename.."_params.pset", "")
    -- filename = filename..".txt"
    -- write_midi_options()
    -- print("Table saved")
    -- tab.save(patterns, storage..filename)
    -- if filename:sub(1, #filename-4) ~= "buffer" then
    --   currFile = filename:sub(1, #filename-4)
    --   print("Project saved: "..filename)
    --   clock.run(flash_message, "save")
    -- end
end


PageSaveLoad.paramUtil = {}

function PageSaveLoad.init()
    PageSaveLoad.paramUtil = ParamListUtil.new()
    PageSaveLoad.paramUtil.redraw_func = redraw

    PageSaveLoad.paramUtil:add_option("Save", nil, nil,
        function(n,z)
            if n == 3 and z == 1 then
                textentry_active = true
                textentry.enter(function(path) save_project(path) end, project_name, "Save As:")
            end
        end
    )
    PageSaveLoad.paramUtil:add_option("Load", nil, nil,
        function(n,z)
            if n == 3 and z == 1 then
                fileselect_active = true

                if not util.file_exists(data_path) then
                    util.make_dir(data_path)
                    print("Made data path directory")
                end

                fileselect.enter(data_path, function(path) load_project(path) end)
            end
        end
    )
    PageSaveLoad.paramUtil:add_option("New", nil, nil,
        function(n,z)
            if n == 3 and z == 1 then
                create_new_project()
            end
        end
    )
    PageSaveLoad.paramUtil:add_option("Kill all notes", nil, nil,
        function(n,z)
            if n == 3 and z == 1 then
                kill_all_notes()
            end
        end
    )
end

function PageSaveLoad.key(n,z)
    PageSaveLoad.paramUtil:key(n,z)
    -- if z == 1 then
    --     if n == 2 then
    --         fileselect_active = true

    --         if not util.file_exists(data_path) then
    --             util.make_dir(data_path)
    --             print("Made data path directory")
    --         end

    --         fileselect.enter(data_path, function(path) load_project(path) end)
    --     elseif n == 3 then
    --         textentry_active = true
    --         textentry.enter(function(path) save_project(path) end, project_name, "Save As:")
    --     end
    -- end
end
function PageSaveLoad.enc(n,d)
    PageSaveLoad.paramUtil:enc(n,d)
end
function PageSaveLoad.redraw()
    PageSaveLoad.paramUtil:redraw()
    -- screen.clear()
    -- screen.level(15)
    -- screen.move(0,20)
    -- screen.text("Load K2 Save K3")
    -- screen.update()
end


PageMicroTiming.paramUtil = {}
PageMicroTiming.offsetSlider = {}
PageMicroTiming.normal_value_labels = {"ON GRID", "1/128T", "2/128T", "1/64", "4/128T", "5/128T", "1/32", "7/128T", "8/128T", "3/64", "10/128T", "11/128T","1/16"}
PageMicroTiming.triplet_value_labels = {"ON GRID", "1/128T", "1/64T", "3/128T", "1/32T", "5/128T", "3/64T", "7/128T", "1/16T", "9/128T", "5/64T", "11/128T", "3/32T", "13/128T", "7/64T", "15/128T", "1/8T",}
PageMicroTiming.enable_snap = false

function PageMicroTiming.init()
    PageMicroTiming.enable_snap = false

    -- label, x, y, width, height, value, min_value, max_value, active, selected, 
    PageMicroTiming.offsetSlider = UI.TimeSlider.new("Offset Time", 12, 20, 128-24, 20, 0, -1, 1, true, true)


    PageMicroTiming.paramUtil = ParamListUtil.new()
    PageMicroTiming.paramUtil.redraw_func = redraw

    PageMicroTiming.paramUtil:add_option("Offset",
        function() 
            local v = gridSeq:get_stepId_offset(gridSeq:get_current_stepId())
            -- return string.format("%.2f", util.linlin(0,6,0,1,v))

            return v
        end,
        function(d,d_raw) 
            local v = gridSeq:get_stepId_offset(gridSeq:get_current_stepId())

            local newV = v + util.clamp(d_raw,-1,1)

            if PageMicroTiming.enable_snap then
                local increment = gridSeq:get_substep_count() / 4
                newV = v + (util.clamp(d_raw,-1,1) * increment)
            end

            gridSeq:set_stepId_offset(gridSeq:get_current_stepId(), newV)

            grid_redraw()
            
        end
    )
    -- PageMicroTiming.paramUtil:add_option("Triplet Mode",
    --     function() 
    --         return gridSeq.triplet_mode and "true" or "false"
    --     end,
    --     function(d,d_raw) 
    --         if d ~= 0 then
    --             gridSeq.triplet_mode = not gridSeq.triplet_mode
    --         end
    --     end
    -- )
end

function PageMicroTiming.key(n,z)
    PageMicroTiming.paramUtil:key(n,z)

    if n == 2 then
        if z == 1 then
            PageMicroTiming.enable_snap = true
        else
            PageMicroTiming.enable_snap = false
        end
    elseif n == 3 and z == 1 then
        gridSeq:set_triplet_mode(not gridSeq:get_triplet_mode())
    end
end
function PageMicroTiming.enc(n,d)
    PageMicroTiming.paramUtil:enc(n,d)
end
function PageMicroTiming.redraw()
    PageMicroTiming.offsetSlider.selected = true
    PageMicroTiming.offsetSlider.active = gridSeq:does_stepId_have_notes()
    PageMicroTiming.offsetSlider.value_labels = gridSeq:get_triplet_mode() and PageMicroTiming.triplet_value_labels or PageMicroTiming.normal_value_labels
    PageMicroTiming.offsetSlider.substep_count = gridSeq:get_substep_count()
    PageMicroTiming.offsetSlider.value = gridSeq:get_stepId_offset(gridSeq:get_current_stepId())
    PageMicroTiming.offsetSlider.min_value = -gridSeq:get_substep_count()
    PageMicroTiming.offsetSlider.max_value = gridSeq:get_substep_count()

    PageMicroTiming.offsetSlider:redraw()

    screen.level(PageMicroTiming.enable_snap and 15 or 3)
    screen.move(2,60)
    screen.text("[K2] Snap")

    screen.level(gridSeq:get_triplet_mode() and 15 or 3)
    screen.move(128-2,60)
    screen.text_right("Triplet Mode [K3]")
end