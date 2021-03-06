local vec_mod = require('viewmath/vec')
local rect_mod = require("viewmath/rect")
local polygon_mod = require('shape/polygon')
local collision_detection_mod = require('collision/detection')
local dev = require('dev')

-- README: the top-left tile has the top-left vec_mod-coordinates (0, 0) and the tile coordinates (0, 0)

local collision_map_mod = {
	TILE_NONE = 0,
	TILE_SOLID = 1,
	TILE_KILL = 2,
}

function generate_map(size, seed)
	assert(seed)

	local tiles = {}

	--[[
	do --river
		math.randomseed(seed)
		local posx = math.floor(math.random() * size.x / 2) + size.x / 4
		local width = math.floor(math.random() * 4)

		for y = 0, size.y, 1 do
			if math.random() < .1 then
				width = width + 1
			end
			if math.random() < .1 then
				width = width - 1
			end

			if math.random() < .2 then
				posx = posx + 1
			end
			if math.random() < .2 then
				posx = posx - 1
			end

			width = math.max(1, width)

			for x = posx, posx + width, 1 do
				tiles[math.floor(y * size.x + x)] = collision_map_mod.TILE_KILL
			end
		end
	end
	]]

	math.randomseed(seed)

	for y = 0, size.y-1 do
		for x = 0, size.x-1 do
			r = math.random()
			t = collision_map_mod.TILE_NONE
			if r > 0.5 then t = collision_map_mod.TILE_KILL end
			if r > 0.7 then t = collision_map_mod.TILE_SOLID end
			tiles[math.floor(y * size.x + x)] = t
		end
	end

	-- temporary (hacky) solution for the spawn tile
	tiles[2 * size.x + 3] = collision_map_mod.TILE_NONE
	tiles[2 * size.x + 4] = collision_map_mod.TILE_NONE
	tiles[3 * size.x + 3] = collision_map_mod.TILE_NONE
	tiles[3 * size.x + 4] = collision_map_mod.TILE_NONE

	--local x, y = math.floor(math.random() * size.x), math.floor(math.random() * size.y)

	return tiles
end

function collision_map_mod.new(size, seed)
	assert(seed)

	local collision_map = {
		size_tiles = size,
		tiles = generate_map(size, seed)
	}

	function collision_map:size()
		return self.size_tiles
	end

	function collision_map:is_inside(pos)
		return pos.x >= 0 and pos.y >= 0 and pos.x < self.size_tiles.x and pos.y < self.size_tiles.y
	end

	-- returns nil when outta map
	function collision_map:get_tile_raw(pos)
		if self:is_inside(pos) then
			return self.tiles[pos.y * self.size_tiles.x + pos.x + 1]
		end
		return nil
	end

	function collision_map:is_none(pos)
		return self:get_tile(pos) == collision_map_mod.TILE_NONE
	end

	function collision_map:is_solid(pos)
		return self:get_tile(pos) == collision_map_mod.TILE_SOLID
	end

	function collision_map:is_kill(pos)
		return self:get_tile(pos) == collision_map_mod.TILE_KILL
	end

	function collision_map:get_tile(pos)
		return self:get_tile_raw(pos) or collision_map_mod.TILE_SOLID
	end

	-- returns colliding tile coordinates, even if the tiles are out of map
	function collision_map:get_intersecting_tiles(shape, condition, only_one)
		dev.start_profiler("get_intersecting_tiles", {"deglitch", "drowning"})

		local TILE_SIZE = 64

		local rect = shape:wrapper()

		local min_x = math.floor(rect:left() / TILE_SIZE)
		local max_x = math.ceil(rect:right() / TILE_SIZE)

		local min_y = math.floor(rect:top() / TILE_SIZE)
		local max_y = math.ceil(rect:bottom() / TILE_SIZE)

		local out_tiles = {}

		for x=min_x, max_x do
			for y=min_y, max_y do
				local pos = {x=x, y=y}
				if not condition or condition(pos) then
					local tile_rect = rect_mod.by_left_top_and_size(
						vec_mod(x * TILE_SIZE, y * TILE_SIZE),
						vec_mod(TILE_SIZE, TILE_SIZE)
					)
					local tile_shape = polygon_mod.by_rect(tile_rect)
					if collision_detection_mod(tile_shape, shape) then
						table.insert(out_tiles, pos)

						if only_one then
							dev.stop_profiler("get_intersecting_tiles")
							return out_tiles
						end

					end
				end
			end
		end

		dev.stop_profiler("get_intersecting_tiles")
		return out_tiles
	end

	return collision_map
end

return collision_map_mod
