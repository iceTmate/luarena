local circle_mod = require('shape/circle')
local rect_mod = require("viewmath/rect")
local vec_mod = require('viewmath/vec')
local collision_map_mod = require('collision/collision_map')
local task_mod = require('game/task')
local dev = require("dev")

local SPAWN_PROTECT_DURATION = 2

KEYS = {
	right = 'd',
	up = 'w',
	left = 'a',
	down = 's',
	skill1 = 'j',
	skill2 = 'k',
	skill3 = 'l',
	skill4 = ';'
}

WALKSPEED = 140 -- units per second

local function generate_walk_task(direction)
	assert(direction)

	local task = {direction = direction, class = "walk"}

	task_mod.with_instant(task, function (self)
		self.owner.shape = self.owner.shape:move_center(self.direction:with_length(WALKSPEED * FRAME_DURATION))
	end)

	return task
end

local function apply_spawn_protection(player)
	local task = { class = "spawn_protection" }
	task_mod.with_duration(task, SPAWN_PROTECT_DURATION)
	player:add_task(task)
end

function new_player(char)
	local player = {}

	player.shape = circle_mod.by_center_and_radius(
		vec_mod(200, 200),
		15
	)
	player.health = 100
	player.inputs = { up = false, left = false, down = false, right = false, skill1 = false, skill2 = false, skill3 = false, skill4 = false }
	player.direction_vec = vec_mod(1, 0)
	player.char = char

	function player:init()
		apply_spawn_protection(self)
	end

	function player:damage(dmg)
		if not self:has_tasks_by_class("invulnerable") then
			self.health = math.max(0, self.health - dmg)
			if self.health == 0 then
				self:die()
			end
		end
	end

	function player:die()
		self:add_task({ class = "dead" })
	end

	function player:tick()
		local d = self:move_direction()

		if d:length() ~= 0 then
			self.direction_vec = d -- for the case that :direction() is not called
			if not self:has_tasks_by_class("root") then
				self:add_task(generate_walk_task(d))
			end
		end

		if not self:has_tasks_by_class("dead") then
			if not self:has_tasks_by_class("silence") then
				self:tick_skills()
			end

			self:consider_deglitching()
			self:consider_drowning()

			if self.char_tick then
				self:char_tick()
			end
		end
	end

	function player:move_direction()
		local d = vec_mod(0, 0)
		if self.inputs.up then
			d = d + vec_mod(0, -1)
		end

		if self.inputs.left then
			d = d + vec_mod(-1, 0)
		end

		if self.inputs.down then
			d = d + vec_mod(0, 1)
		end

		if self.inputs.right then
			d = d + vec_mod(1, 0)
		end

		return d
	end

	function player:direction()
		local d = self:move_direction()

		if d:length() ~= 0 then
			self.direction_vec = d -- for the case that :tick() has not yet been called, but another entity reads my :direction()
		end

		return self.direction_vec
	end

	function player:draw_body(viewport)
		local r, g, b

		if self.color then
			r, g, b = self:color()
		else
			r, g, b = 100, 100, 100
		end

		viewport:draw_shape(self.shape, r, g, b)

		if self:has_tasks_by_class("spawn_protection") then
			viewport:draw_world_rect(self.shape:wrapper(), 0, 255, 0, 50)
		end
	end

	function player:draw_health(viewport)
		local bar_offset = 10
		local bar_height = 3

		local wrapper = self.shape:wrapper()

		local border = rect_mod.by_left_top_and_size(
			wrapper:left_top() - vec_mod(0, bar_offset),
			vec_mod(wrapper:width() + 2, bar_height + 2)
        )

		local health_bar = rect_mod.by_left_top_and_size(
            border:left_top() + vec_mod(1, 1),
            vec_mod(wrapper:width() * self.health/100, bar_height)
        )

        viewport:draw_world_rect(border, 20, 20, 20)
        viewport:draw_world_rect(health_bar, 200, 0, 0)
	end

	function player:draw_skills(viewport)
		for _, skill in pairs(self.skills) do
			skill:draw(viewport)
		end
	end

	function player:draw(viewport)
		if not self:has_tasks_by_class("dead") then
			self:draw_body(viewport)
			self:draw_health(viewport)
			self:draw_skills(viewport)
		end
	end

	function player:consider_deglitching()
		dev.start_profiler("consider_deglitching", {"deglitch"})
		local TILE_SIZE = 64

		local counter = 0

		while true do
			local colliding_solid_tiles = {}
			for _, pos in pairs(frame().map:get_intersecting_tiles(self.shape, function(pos) return frame().map:is_solid(pos) end)) do
				table.insert(colliding_solid_tiles, pos)
			end

			if #colliding_solid_tiles == 0 then break end

			local actual_move = vec_mod(0, 0)
			for _, pos in pairs(colliding_solid_tiles) do
				local tile_center = vec_mod(pos.x, pos.y) * TILE_SIZE + vec_mod(TILE_SIZE/2, TILE_SIZE/2)
				local direction = self.shape:center() - tile_center
				actual_move = actual_move + direction:with_length(1)
			end

			-- make it axis aligned!
			if math.abs(actual_move.x) > math.abs(actual_move.y) then
				actual_move = actual_move:with_y(0)
			else
				actual_move = actual_move:with_x(0)
			end

			self.shape = self.shape:move_center(actual_move)

			counter = counter + 1
			assert(counter < 20, "deglitch counter too high!")
		end
		dev.stop_profiler("consider_deglitching")
	end

	-- effectively checks, whether you collide with a TILE_NONE
	function player:is_drowning()
		dev.start_profiler("is_drowning", {"drowning"})

		if self:has_tasks_by_class("dash") then
			dev.stop_profiler("is_drowning")
			return false
		end

		for _, pos in pairs(frame().map:get_intersecting_tiles(self.shape, function(pos) return frame().map:is_none(pos) end, true)) do
			dev.stop_profiler("is_drowning")
			return false
		end

		dev.stop_profiler("is_drowning")
		return true
	end

	function player:consider_drowning()
		if self:is_drowning() then
			self:die()
		end
	end

	function player:tick_skills()
		for _, skill in pairs(self.skills) do
			skill:tick()
		end
	end

	return require("characters/" .. char)(player)
end

return new_player
