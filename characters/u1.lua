-- unnamed character 1

local rect_mod = require('space/rect')
local vec_mod = require('space/vec')

return function (u1)

	local Q_COOLDOWN = 500
	local Q_RANGE = 75
	local Q_DAMAGE = 20

	local W_COOLDOWN = 100
	local W_RANGE = 120
	local W_MAX_DAGGERS = 4
	local W_DAMAGE = 5

	local E_COOLDOWN = 50
	local E_JUMP_RANGE = 40
	local E_DASH_SPEED = 2
	local E_DAMAGE = 12

	local R_COOLDOWN = 75
	local R_DAMAGE = 15
	local R_DAMAGE_ADD = 15
	local R_RANGE = 30

	u1.state = nil
	u1.dagger_list = {}

	u1.q_cooldown = 0
	u1.w_cooldown = 0
	u1.e_cooldown = 0
	u1.r_cooldown = 0

	function u1:use_q_skill(frame)
		local blade = {}

		-- TODO prevent walking while chanelling
		self.walk_target = nil
		self.q_cooldown = Q_COOLDOWN
		self.state = "q"
		table.insert(frame.entities, blade)

		blade.owner = self
		blade.start_center = self.shape:center()
		blade.shape = rect_mod.by_center_and_size(
			self.shape:center(),
			vec_mod(4, 4)
		)
		blade.speed = (self.inputs.mouse - self.shape:center()):normalized()

		function blade:remove_self(frame)
			frame.entities:remove(self)
			self.owner.state = nil
		end

		function blade:tick(frame)
			self.shape = self.shape:with_center_keep_size(self.shape:center() + self.speed)
			if (self.start_center - self.shape:center()):length() > Q_RANGE or not frame.map:rect():surrounds(self.shape) then
				self:remove_self(frame)
			end

			for key, entity in pairs(frame.entities) do
				if entity ~= self and entity ~= self.owner then
					if self.shape:intersects(entity.shape) then
						if entity.damage ~= nil then
							entity:damage(Q_DAMAGE)
							self:remove_self(frame)
						end
					end
				end
			end

		end

		function blade:draw(viewport)
			viewport:draw_world_rect(self.shape, 0, 0, 255)
		end

		return blade
	end

	function u1:use_w_skill(frame)
		local dagger = {}

		dagger.timer = 70
		dagger.landed = false

		self.w_cooldown = W_COOLDOWN
		table.insert(frame.entities, dagger)

		dagger.owner = self
		dagger.shape = rect_mod.by_center_and_size(
			self.shape:center() + (self.inputs.mouse - self.shape:center()):cropped_to(W_RANGE),
			vec_mod(3, 3)
		)

		function dagger:land(frame)
			self.landed = true
			if #self.owner.dagger_list == W_MAX_DAGGERS then
				frame.entities:remove(self.owner.dagger_list[1])
				table.remove(self.owner.dagger_list, 1)
			end
			table.insert(self.owner.dagger_list, self)

			for key, entity in pairs(frame.entities) do
				if entity ~= self.owner and entity ~= self then
					if self.shape:intersects(entity.shape) then
						if entity.damage ~= nil then
							entity:damage(W_DAMAGE)
						end
					end
				end
			end
		end

		function dagger:tick(frame)
			self.timer = math.max(0, dagger.timer - 1)
			if self.timer == 0 and not self.landed then
				dagger:land(frame)
			end
		end

		function dagger:draw(viewport)
			if self.timer == 0 then
				-- render dagger
				viewport:draw_world_rect(self.shape, 200, 200, 255)
			else
				-- render shadow
				viewport:draw_world_rect(rect_mod.by_center_and_size(
					self.shape:center(),
					self.shape:size() * 3
				), 40, 40, 40, 80)
			end
		end

		return dagger
	end

	function u1:use_e_skill(frame)
		local closest = nil
		for _, dagger in pairs(self.dagger_list) do
			if closest == nil or (dagger.shape:center() - self.inputs.mouse):length() < (closest.shape:center() - self.inputs.mouse):length() then
				closest = dagger
			end
		end
		if closest ~= nil then
			self.e_cooldown = E_COOLDOWN
			self.state = "e-walk"
			self.walk_target = closest.shape:center()
		end
	end

	function u1:mk_r_aoe(dmg)
		local aoe = {}

		aoe.owner = self
		aoe.shape = rect_mod.by_center_and_size(
			self.shape:center(),
			vec_mod(1, 1):cropped_to(R_RANGE)
		)
		aoe.life_counter = 80
		aoe.dmg = dmg

		function aoe:tick(frame)
			if self.life_counter == 100 then
				for key, entity in pairs(frame.entities) do
					if entity ~= self
						and entity ~= self.owner
						and self.shape:intersects(entity.shape)
						and entity.damage ~= nil then
							entity:damage(self.dmg)
					end
				end
			end

			self.life_counter = self.life_counter - 1
			if self.life_counter <= 0 then
				frame.entities:remove(self)
			end
		end

		function aoe:draw(viewport)
			viewport:draw_world_rect(self.shape, 100, 100, 100, 100)
		end

		return aoe
	end


	function u1:use_r_skill(frame)
		local dmg = R_DAMAGE

		self.r_cooldown = R_COOLDOWN

		for i, dagger in pairs(self.dagger_list) do
			print(i)
			if (self.shape:center() - dagger.shape:center()):length() < R_RANGE then
				dmg = dmg + R_DAMAGE_ADD
				frame.entities:remove(dagger)
				table.remove(self.dagger_list, i)
			end
		end

		local aoe = self:mk_r_aoe(dmg)
		table.insert(frame.entities, aoe)
	end

	function u1:char_tick(frame)
		self.q_cooldown = math.max(0, self.q_cooldown - 1)
		self.w_cooldown = math.max(0, self.w_cooldown - 1)
		self.e_cooldown = math.max(0, self.e_cooldown - 1)
		self.r_cooldown = math.max(0, self.r_cooldown - 1)

		if self.state == nil then
			if self.inputs.q and self.q_cooldown == 0 then
				self:use_q_skill(frame)
			end

			if self.inputs.w and self.w_cooldown == 0 then
				self:use_w_skill(frame)
			end

			if self.inputs.e and self.e_cooldown == 0 then
				self:use_e_skill(frame)
			end

			if self.inputs.r and self.r_cooldown == 0 then
				self:use_r_skill(frame)
			end
		end

		if self.state == "e-walk" and (self.walk_target - self.shape:center()):length() < E_JUMP_RANGE then
			self.state = "e-dash"
		end

		if self.state == "e-dash" then
			for key, entity in pairs(frame.entities) do
				if entity ~= self
				and self.shape:intersects(entity.shape)
				and entity.damage ~= nil then
					-- TODO prevent multiple damage to same target!
					entity:damage(E_DAMAGE)
				end
			end

			if self.walk_target == nil then
				-- dash already there
				self.state = nil
			else
				local move_vec = (self.walk_target - self.shape:center())
				self.shape = self.shape:with_center_keep_size(self.shape:center() + move_vec:cropped_to(E_DASH_SPEED))
			end
		end
	end

	function u1:draw(viewport)
		local alpha = nil
		if self.state == "q" then
			alpha = 100
		else
			alpha = 255
		end
		viewport:draw_world_rect(self.shape, 100, 100, 100, alpha)

		local bar_offset = 10
		local bar_height = 3
		viewport:draw_world_rect(rect_mod.by_left_top_and_size(
			self.shape:left_top() - vec_mod(0, bar_offset),
			vec_mod(self.shape:size().x * self.health/100, bar_height)
		), 255, 0, 0)
	end

	function u1:damage(dmg)
		if not self.state == "q" then
			self.health = math.max(0, self.health - dmg)
		end
	end

	return u1
end
