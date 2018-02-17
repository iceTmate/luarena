local visual_map_mod = require('graphics/visual_map')
local collision_mod = require('collision/mod')
local collision_map_mod = require('collision/collision_map')
local task_mod = require('frame/task')
local vec_mod = require('viewmath/vec')

local frame_mod = {}
require("misc")

function frame_mod.initial(chars)
	local frame = {}
	frame.map = visual_map_mod.init_collision_map(collision_map_mod.new(vec_mod(16, 16)))
	frame.entities = {}

	function frame:init(chars)
		collision_mod.init_frame(self)
		task_mod.init_frame(self)

		for _, char in pairs(chars) do
			self:add(require('frame/player')(char))
		end
	end

	function frame:add(entity)
		assert(entity)

		collision_mod.init_entity(entity)
		task_mod.init_entity(entity)

		table.insert(self.entities, entity)
	end

	function frame:remove(entity)
		for _, e in pairs(self.entities) do
			if table.contains(e.colliders, entity) then
				table.remove_val(e.colliders, entity)
				collision_mod.call_on_exit_collider(e, self, entity)
			end
		end
		table.remove_val(self.entities, entity)
	end

	function frame:tick()
		self:tick_tasks()
		self:tick_collision()
		for _, entity in pairs(self.entities) do
			entity:tick(self)
		end


		if love.keyboard.isDown('x') then
			if self.dummy then
				self:remove(self.dummy)
			end
			self.dummy = require('frame/player')('dummy')
			self:add(self.dummy)
		end

	end

	function frame:draw(viewport)
		assert(viewport)

		self.map:draw(viewport)
		for _, entity in pairs(self.entities) do
			entity:draw(viewport)
		end
	end

	function frame:clone()
		return clone(self)
	end

	frame:init(chars)

	return frame
end

return frame_mod
