-- half sec loop 75% decay

local sc = {}
-- local delay_enabled = true

function sc.init()
	delay_options = {}

	delay_options.DELAY_TIME = {"2 bars", "1 bar","1/2", "1/2T", "1/4", "1/4T", "1/8", "1/8T", "1/16", "1/16T", "1/32","1/64"}
	delay_options.DELAY_TIME_VAL = {8,     4,      2,     1.33333, 1,    0.66666,0.5,  0.33333, 0.25,  0.16666,  0.125, 0.0625}

  	print("starting halfsecond")
	audio.level_cut(1.0)
	audio.level_adc_cut(1)
	audio.level_eng_cut(1)
	softcut.level(1,1.0)
	softcut.level_slew_time(1,0.25)
	softcut.level_input_cut(1, 1, 1.0)
	softcut.level_input_cut(2, 1, 1.0)
	softcut.pan(1, 0.0)

 	softcut.play(1, 1)
	softcut.rate(1, 1)
  	softcut.rate_slew_time(1,0.25)
	softcut.loop_start(1, 1)
	softcut.loop_end(1, 1.5)
	softcut.loop(1, 1)
	softcut.fade_time(1, 0.1)
	softcut.rec(1, 1)
	softcut.rec_level(1, 1)
	softcut.pre_level(1, 0.75)
	softcut.position(1, 1)
	softcut.enable(1, 1)

	softcut.filter_dry(1, 0.125);
	softcut.filter_fc(1, 1200);
	softcut.filter_lp(1, 0);
	softcut.filter_bp(1, 1.0);
	softcut.filter_rq(1, 2.0);

	params:add_group("Delay", 6)

	params:add{type = "option", id = "delay_enabled", name = "delay enabled", options = {"off", "on"}, default = 1, 
		action = function(value)
			if value == 2 then
				-- softcut.play(1, 1)
				-- softcut.enable(1, 1)
				-- delay_enabled = true
				softcut.level(1,params:get("delay_level"))
				softcut.pre_level(1,params:get("delay_feedback")) 

				-- softcut.rec_level(1, 0)
			else
				-- softcut.play(1, 0)
				-- softcut.enable(1, 0)
				-- softcut.buffer_clear()
				-- softcut.play(1, 0)
				-- delay_enabled = false
				softcut.level(1,0) 
				softcut.pre_level(1,0) 
				-- softcut.rec_level(1, 1)

			end
		end}

	softcut.level(1,0) 
	softcut.pre_level(1,0) 

  	params:add{id="delay_level", name="delay level", type="control", 
		controlspec=controlspec.new(0,1,'lin',0,0.5,""),
		action=function(x) 
			local level = params:get("delay_enabled") == 2 and 1 or 0
			softcut.level(1,x * level) 
		end}

	params:add{type = "option", id = "delay_time", name = "delay time", options = delay_options.DELAY_TIME, default = 5, 
		action = function(value)
			local time = clock.get_beat_sec() * delay_options.DELAY_TIME_VAL[value]

			softcut.loop_start(1, 1)
			softcut.loop_end(1, 1 + time)
			-- softcut.level(1,x) 
		end}
	
		-- params:add{id="delay_time", name="delay time", type="control", 
		--     controlspec=controlspec.new(0,3,'lin',0,0.5,""),
		-- 	action=function(x) 
		-- 		local time = clock.get_beat_sec() * x

		-- 		softcut.loop_start(1, 1)
		-- 		softcut.loop_end(1, 1 + time)
		-- 		-- softcut.level(1,x) 
		-- 	end}
	params:add{id="delay_rate", name="delay rate", type="control", 
		controlspec=controlspec.new(0.5,2.0,'lin',0,1,""),
		action=function(x) 
			-- local rate = clock.get_beat_sec() * x
			softcut.rate(1,x) 
		end}
	params:add{id="delay_feedback", name="delay feedback", type="control", 
		controlspec=controlspec.new(0,1.0,'lin',0,0.75,""),
		action=function(x) 
			local level = params:get("delay_enabled") == 2 and 1 or 0
			softcut.pre_level(1,x*level) 
		end}
	params:add{id="delay_pan", name="delay pan", type="control", 
		controlspec=controlspec.new(-1,1.0,'lin',0,0,""),
		action=function(x) softcut.pan(1,x) end}
	
	sc.tempo_changed(newTempo)
end

function sc.tempo_changed(newTempo)
	local time = clock.get_beat_sec() * delay_options.DELAY_TIME_VAL[params:get("delay_time")]

	softcut.loop_start(1, 1)
	softcut.loop_end(1, 1 + time)
end

return sc
