FRAME_DURATION = 1/60 -- in seconds
INPUT_DELAY = 2
BACKTRACK_BALANCE_INTERVAL = 2000
FRAME_HISTORY_LENGTH = math.ceil(5 / FRAME_DURATION)

local structure_mod = {}
local frame_mod = require("frame/mod")
local calendar_mod = require("frame/calendar")
local cam_mod = require("graphics/cam")
local vec_mod = require('viewmath/vec')
local dev = require('dev')

require("misc")

local NO_FRAME = {}

-- A global function to return the current frame
frame = nil

function structure_mod.new(chars, local_id, seed, start_time)
	assert(seed)

	local structure = {}
	structure.map_seed = seed
	structure.current_frame = frame_mod.initial(chars, structure.map_seed)
	structure.cam = -- choose one:
			cam_mod.following(local_id)
			-- cam_mod.fixed(structure.current_frame.map:rect():center())
	structure.frame_history = {}
	structure.frame_counter = 0 -- in the first frames the same as #frame_history
	structure.chars = chars
	structure.calendar = calendar_mod.new(#chars, local_id)
	structure.local_id = local_id
	structure.start_time = start_time

	frame = function() return structure.current_frame end

	for i=1, FRAME_HISTORY_LENGTH do
		structure.frame_history[i] = NO_FRAME
	end

	-- frame_id is the oldest frame to be re-calculated
	function structure:backtrack(frame_id)
		dev.start_profiler("backtrack", {"backtrack"})

		local c = 0
		local old_frame_counter = self.frame_counter
		while frame_id <= self.frame_counter do
			c = c + 1
			set(self.frame_history, self.frame_counter, NO_FRAME)
			self.frame_counter = self.frame_counter - 1
		end

		assert(#self.frame_history == FRAME_HISTORY_LENGTH)

		if frame_id == 1 then
			self.current_frame = frame_mod.initial(structure.chars, self.map_seed)
		else
			local base_frame = get(self.frame_history, self.frame_counter)
			assert(base_frame ~= NO_FRAME, "backtracking too far!")
			self.current_frame = base_frame:clone()
		end

		local current_time = love.timer.getTime()
		while self.frame_counter * FRAME_DURATION < current_time - self.start_time do
			self:frame_update()
		end
		dev.debug("went back " .. c .. " frames (" .. old_frame_counter .. " -> " .. frame_id-1 .. " -> " .. self.frame_counter .. ")", {"backtrack"})

		dev.stop_profiler("backtrack")
	end

	-- will do calendar:apply_input_changes and backtrack
	function structure:apply_input_changes(input_packets)
		local oldest_frame_id = nil
		for _, p in pairs(input_packets) do
			self.calendar:apply_input_changes(p.inputs, p.player_id, p.frame_id)
			if oldest_frame_id == nil or oldest_frame_id > p.frame_id then
				oldest_frame_id = p.frame_id
			end
		end

		if oldest_frame_id <= self.frame_counter then
			self:backtrack(oldest_frame_id)
		end
	end

	function structure:update_local_calendar()
		local viewport = self.cam:viewport(self.current_frame)
		local changed_inputs = self.calendar:detect_changed_local_inputs(viewport)

		if next(changed_inputs) == nil then return end

		self.calendar:apply_input_changes(changed_inputs, self.local_id, self.frame_counter + 1 + INPUT_DELAY)

		self:send({
			tag = "inputs",
			inputs = changed_inputs,
			player_id = self.local_id,
			frame_id = self.frame_counter + 1 + INPUT_DELAY
		})
	end

	function structure:frame_update()
		dev.start_profiler("frame_update")

		self.calendar:apply_to_frame(self.current_frame, self.frame_counter + 1)
		self.current_frame:tick()
		set(self.frame_history, self.frame_counter + 1, self.current_frame:clone())
		self.frame_counter = self.frame_counter + 1

		dev.stop_profiler("frame_update")
	end

	function structure:update(dt)
		self:handle_debug_hotkeys()
		self.networker:handle_events()
		self:update_local_calendar()

		local current_time = love.timer.getTime()
		while self.frame_counter * FRAME_DURATION < current_time - self.start_time do
			if self.gamemaster_update then
				self:gamemaster_update()
			end

			self:update_local_calendar()
			self:frame_update()
		end
	end

	function structure:draw()
		local viewport = self.cam:viewport(self.current_frame)
		self.current_frame:draw(viewport)
	end

	function structure:handle_debug_hotkeys()
		-- b => backtrack
		if isPressed('b') then
			print("backtracking to frame 2")
			self:backtrack(2)
		end

		-- p => print profilers
		if isPressed('p') then
			if not p_pressed then
				dev.dump_profilers()
				p_pressed = true
			end
		else
			p_pressed = nil
		end

		-- c => clear profilers
		if isPressed('c') then
			dev.profilers = {}
		end
	end

	return structure
end

return structure_mod
