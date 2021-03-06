local rect_mod = require('viewmath/rect')
local vec_mod = require('viewmath/vec')
local graphics_mod = require('graphics/mod')

local cam_mod = {} -- a cam is just a viewport-generator

local function get_screen_size()
	return vec_mod(love.graphics.getWidth(), love.graphics.getHeight())
end

local function new_viewport(pos, zoom)
	local viewport = {}
	viewport.pos = pos -- in world coordinates (center of view)
	viewport.zoom = zoom -- world_length * zoom = pixel_length

	function viewport:rect() -- in world coordinates
		return rect_mod.by_center_and_size(
			self.pos,
			get_screen_size() / self.zoom
		)
	end

	function viewport:world_to_screen_pos(pos)
		return (pos - self:rect():left_top()) * self.zoom
	end

	function viewport:world_to_screen_size(size)
		return size * self.zoom
	end

	function viewport:screen_to_world_vec(vec)
		return (vec / self.zoom) + self:rect():left_top()
	end

	function viewport:world_to_screen_rect(world_rect)
		local size = world_rect:size()
		return rect_mod.by_center_and_size(
			self:world_to_screen_pos(world_rect:center()),
			self:world_to_screen_size(size)
		)
	end

	return graphics_mod.init_viewport(viewport)
end

function cam_mod.fixed(pos)
	assert(pos)

	local cam = {
		pos_vec = pos,
		zoom = 2
	}

	function cam:viewport(frame)
		return new_viewport(
			self.pos_vec,
			self.zoom
		)
	end

	return cam
end

function cam_mod.following(entity_id)
	assert(entity_id)

	local cam = {
		entity_id = entity_id,
		zoom = 2
	}

	function cam:viewport(frame)
		return new_viewport(
			frame.entities[entity_id].shape:center(),
			self.zoom
		)
	end

	return cam
end

return cam_mod
