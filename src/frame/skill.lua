local skill_mod = {}

local vec_mod = require('viewmath/vec')
local rect_mod = require('viewmath/rect')
require('misc')

local BORDER_R, BORDER_G, BORDER_B = 20, 20, 20

local listify_function = function(obj, name)
	assert(type(obj) == 'table')
	assert(type(name) == 'string')

	if obj[name .. "_list"] == nil then
		obj[name .. "_list"] = {obj[name]}
		obj[name] = function (self, ...)
			for _, f in pairs(self[name .. '_list']) do -- TODO name is closured!
				f(self, ...)
			end
		end
	end
end

-- draws the border, and returns the smaller inner rect
function skill_mod.icon_rect_border(rect, viewport)
	viewport:draw_world_rect(rect, BORDER_R, BORDER_G, BORDER_B)
	return rect_mod.by_center_and_size(rect:center(), rect:size() - vec_mod(2, 2))
end

local eval_and_function = function(obj, name)
	assert(type(name) == 'string')

	if type(obj[name]) == "nil" then
		return true
	elseif obj[name .. '_list'] ~= nil and type(obj[name]) == 'function' then
		for _, f in pairs(obj[name .. '_list']) do
			if not f(obj) then
				return false
			end
		end
		return true
	elseif type(obj[name]) == 'function' then
		return obj[name](obj)
	else
		assert(false)
	end

end

function skill_mod.append_function(obj, name, new_function)
	assert(type(obj) == 'table')
	assert(type(name) == 'string')
	assert(type(new_function) == 'function')

	if type(obj[name]) == 'nil' then
		obj[name] = new_function
	elseif type(obj[name]) == 'function' then
		if obj[name .. '_list'] == nil then
			listify_function(obj, name)
		end
		table.insert(obj[name .. "_list"], new_function)
	else
		assert(false, "can't append to obj[name] of type " .. type(obj[name]))
	end
end

-- basics

function skill_mod.make_blank_skill(player, num)
	assert(type(player) == "table", "wrong player argument in make_blank_skill")
	assert(type(num) == "number", "wrong num argument in make_blank_skill")

	local skill = {}
	skill.task = {}
	skill.owner = player
	skill.num = num
	skill.task.class = skill.owner.char .. "_s" .. tostring(skill.num)

	function skill:icon_rect()
		-- TODO Make this function work with > 4 skills

		local wrapper = self.owner.shape:wrapper()
		local rect = rect_mod.by_left_top_and_size(
			wrapper:left_top() + vec_mod((self.num-1) * (1/3) * wrapper:width() - (self.num-1), -5),
			vec_mod(5, 5)
		)
		return rect
	end

	function skill:is_pressed()
		return isPressed(KEYS.skills[self.num])
	end

	function skill:go()
		local task = clone(self.task)
		task.skill = self
		task.owner = self.owner

		self.owner:add_task(task)
	end

	skill.go_condition = skill.is_pressed

	function skill:tick()
		if eval_and_function(self, "go_condition") then
			self:go()
		end
	end

	return skill
end

-- add ons

function skill_mod.with_fresh_key(skill)
	skill.fresh = true
	skill_mod.append_function(skill, "tick", function(self)
		if not self.fresh and not self:is_pressed() then
			self.fresh = true
		end
	end)

	skill_mod.append_function(skill.task, "init", function(self)
		self.skill.fresh = false
	end)

	function skill:is_fresh_pressed()
		return self.fresh and self:is_pressed()
	end

	skill_mod.append_function(skill, "go_condition", skill.is_fresh_pressed)

	return skill
end

function skill_mod.with_cooldown(skill, cooldown)
	skill.max_cooldown = cooldown
	skill.cooldown = 0

	function skill:tick_cooldown()
		self.cooldown = math.max(0, self.cooldown - FRAME_DURATION)
	end

	skill_mod.append_function(skill, "go_condition", function(self) return self.cooldown == 0 end)
	skill_mod.append_function(skill, "go", function(self) self.cooldown = self.max_cooldown end)

	skill_mod.append_function(skill, "tick", skill.tick_cooldown)

	function skill:draw_cooldown(viewport)
        local SIZE_REDUCTION = 2

		local rect = skill_mod.icon_rect_border(self:icon_rect(), viewport)

		if self.cooldown == 0 then
			viewport:draw_world_rect(rect, 0, 200, 0)
		else
			viewport:draw_world_rect(rect, 70, 70, 255)

			local red_rect = rect:scale_keep_left_top(vec_mod(1, self.cooldown / self.max_cooldown))
			viewport:draw_world_rect(red_rect, 200, 0, 0)
		end
	end

	skill.draw = skill.draw_cooldown -- This way, self.draw can be overwritten, yet self.draw_cooldown can still be used

	return skill
end

function skill_mod.with_instant(skill, init)
	skill_mod.append_function(skill.task, "init", init)
	skill_mod.append_function(skill.task, "init", function(self) self.owner:remove_task(self) end)

	return skill
end

return skill_mod
