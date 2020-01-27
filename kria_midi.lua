-- Kria MIDI
--
-- Port of Kira from Ansible
--
-- original code by Tehn
--
--

-- don't need an engine
-- but it seems to do a sine noise
-- if you don't specifiy one
-- engine.name = "ack"

local kria = require 'kria_midi/lib/kria'
local BeatClock = require 'beatclock'
local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = function(data)
  clk:process_midi(data)
end

local options = {}
options.STEP_LENGTH_NAMES = {"1 bar", "1/2", "1/3", "1/4", "1/6", "1/8", "1/12", "1/16", "1/24", "1/32", "1/48", "1/64"}
options.STEP_LENGTH_DIVIDERS = {0.25, 0.5, 0.6, 1 , 1.5 , 2, 3 , 4 , 5, 6, 12 , 8}

local g = grid.connect(1)
function g.key(x,y,z) gridkey(x,y,z) end
local k

local preset_mode = false
local clocked = true
local clock_count = 1
local current_sld = 8

local note_list = {}

m = midi.connect()

local function nsync(x)
	if x == 2 then
		k.note_sync = true
	else
		k.note_sync = false
	end
end

local function lsync(x)
	if x == 1 then
		k.loop_sync = 0
  elseif x == 2 then
		k.loop_sync = 1
  else
		k.loop_sync = 2
	end
end

function make_note(track,n,oct,dur,tmul,rpt,glide)
		local midich = params:get(track .."_midi_chan")
		print("[" .. track .. "/" .. midich .. "] Note " .. n .. "/" .. oct .. " for " .. dur .. " repeats " .. rpt .. " glide " .. glide  )
		-- ignore repeats and glide for now
		-- currently 1 == C3 (60 = 59 + 1)
		local r = rpt + 1
		local notedur = 6  * (dur/r * tmul)
		print( notedur )
		for rptnum = 1,r do
		  midi_note = (59 + n) + ( (oct - 3) * 12 )
		  -- m:note_on(midi_note,100,midich)
		  table.insert(note_list,{ action = 1 , timestamp = clock_count + ( (rptnum - 1) * notedur), channel = midich , note = midi_note })
		  table.insert(note_list,{ action = 0 , timestamp = (clock_count + (rptnum * notedur)) - 0.1, channel = midich , note = midi_note })
		end
end


function init()
  print("Kria Init")
	k = kria.loadornew("Kria/kria.data")
	--k = kria.new()
	
  k:init(make_note)
  clk.on_step = step
  clk.beats_per_bar = 4
  clk.on_select_internal = function() clk:start() end
  -- clk.on_select_external = reset_pattern
	clk:add_clock_params()
	params:add{type = "option", id = "step_length", name = "step length", options = options.STEP_LENGTH_NAMES, default = 6,
    action = function(value)
      -- clk.ticks_per_step = 96 / options.STEP_LENGTH_DIVIDERS[value]
      clk.ticks_per_step = 96 
      clk.steps_per_beat = options.STEP_LENGTH_DIVIDERS[value] * 6
      current_sld = options.STEP_LENGTH_DIVIDERS[value]
      print("current sld " .. current_sld)
      clk:bpm_change(clk.bpm)
    end}
	params:add_separator()
	params:add{type="option",name="Note Sync",id="note_sync",options={"Off","On"},default=2, action=nsync}
	params:add{type="option",name="Loop Sync",id="loop_sync",options={"None","Track","All"},default=1, action=lsync}
	params:add_separator()
	for i = 1, 4 do
    params:add_number(i.."_midi_chan", i..": midi chan", 1, 16,i)
  end
	params:add_separator()
	-- params:add_number("clock_ticks", "clock ticks", 1, 96,1)
  params:bang()
  -- grid refresh timer, 15 fps
  metro_grid_redraw = metro.init(function(idx,stage) gridredraw() end, 1 / 30 )
  metro_grid_redraw:start()
end

function step()
	clock_count = clock_count + 1
	table.sort(note_list,function(a,b) return a.timestamp < b.timestamp end)
	while note_list[1] ~= nil and note_list[1].timestamp <= clock_count do
		--print("note off " .. note_off_list[1].note)
		print("clock " .. clock_count)
		if note_list[1].action == 1 then 
		  print("note on " .. note_list[1].timestamp)
		  m:note_on(note_list[1].note,100,note_list[1].channel)
		else 
		  print("note off " .. note_list[1].timestamp)
		  m:note_off(note_list[1].note,0,note_list[1].channel)
		end
		table.remove(note_list,1)
	end
	if clock_count %   6  == 0 then
	   if clocked then
		   k:clock()
	   end
	end
end

function redraw()
  screen.clear()
	screen.move(40,40)
	screen.text("Kria")

  screen.update()
end

function gridredraw()
	if preset_mode then
		k:draw_presets(g)
	else
	  k:draw(g)
	end
end

function enc(n,delta)
end

function key(n,z)
	-- key 2 opens presets for now
	-- this may change
	if n == 2 and z == 1 then
		preset_mode = true
	else
		preset_mode = false
	end
	if n == 3 and z == 1 then
		if clocked == true then
				clocked = false
		else
				clocked = true
		end
	end
end

function gridkey(x, y, z)
	k:event(x,y,z)
end

function cleanup()
	print("Cleanup")
	k:save("Kria/kria.data")
	print("Done")
end