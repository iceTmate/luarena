local rect_mod = require('viewmath/rect')
local vec_mod = require('viewmath/vec')
local circle_mod = require('shape/circle')

return function (rogue)

	rogue.q_cooldown = 0
	rogue.w_cooldown = 0

	function rogue:new_aoe(frame)
		local aoe = {}

		aoe.owner = self
		aoe.shape = circle_mod.by_center_and_radius(self.shape:center(), 100)
		aoe.life_counter = 100

		function aoe:initial_damage(frame)
			for _, entity in pairs(frame:find_colliders(self.shape)) do
				if entity ~= self
					and entity ~= self.owner
					and entity.damage then
						entity:damage(20)
				end
			end
		end

		function aoe:tick(frame)
			self.life_counter = self.life_counter - 1
			if self.life_counter <= 0 then
				frame:remove(self)
			end
		end

		function aoe:draw(viewport)
			viewport:draw_shape(self.shape, 100, 100, 100, 100)
		end

		aoe:initial_damage(frame)

		return aoe
	end


	function rogue:char_tick(frame)
		self.q_cooldown = math.max(0, self.q_cooldown - 1)
		self.w_cooldown = math.max(0, self.w_cooldown - 1)

		if self.inputs.q and self.q_cooldown == 0 then
			local MAX_JUMP = 200

			self.q_cooldown = 100

			local jump = (self.inputs.mouse - self.shape:center()):cropped_to(MAX_JUMP)

			self.shape = self.shape:move_center(jump)
			self.walk_target = nil
		end

		if self.inputs.w and self.w_cooldown == 0 then
			self.w_cooldown = 100
			frame:add(self:new_aoe(frame))
		end
	end

	return rogue
end