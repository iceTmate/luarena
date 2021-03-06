local vec_mod = require('viewmath/vec')

local calendar_mod = {} -- keeps track of the history of pressed keys for all players

function calendar_mod.new(player_count, local_id)
	local calendar = {}

	calendar.player_count = player_count
	calendar.local_id = local_id

	calendar.playertable = {} -- Map<PlayerId, Map<Key, List<{value=<bool>, frame_id=<frame_id> }>>>
	for i=1, player_count do
		table.insert(calendar.playertable, {
			up={{value=false, frame_id=1}},
			left={{value=false, frame_id=1}},
			down={{value=false, frame_id=1}},
			right={{value=false, frame_id=1}},

			skill1={{value=false, frame_id=1}},
			skill2={{value=false, frame_id=1}},
			skill3={{value=false, frame_id=1}},
			skill4={{value=false, frame_id=1}},
		})
	end

	function calendar:read_inputs(player_id, frame_id) -- frame_id == nil searches for newest
		local inputs = {}
		for key, hist in pairs(self.playertable[player_id]) do
			for i=1, #hist do
				local hist_entry = hist[#hist - i + 1]
				if frame_id == nil or hist_entry.frame_id <= frame_id then
					inputs[key] = hist_entry.value
					break
				end
			end
		end

		return inputs
	end

	function calendar:apply_to_frame(f, frame_id)
		for i=1, player_count do
			local inputs = self:read_inputs(i, frame_id)
			for key, value in pairs(inputs) do
				f.entities[i].inputs[key] = value
			end
		end
	end

	function calendar:detect_changed_local_inputs(viewport)
		local inputs = {}

		for _, v in pairs({ "right", "up", "left", "down", "skill1", "skill2", "skill3", "skill4" }) do
			inputs[v] = isPressed(KEYS[v])
		end

		local old_inputs = self:read_inputs(self.local_id, nil)
		local changed_inputs = {}

		for key, is_pressed in pairs(inputs) do
			if old_inputs[key] ~= is_pressed then
				changed_inputs[key] = is_pressed
			end
		end

		return changed_inputs
	end

	function calendar:apply_input_changes(inputs, player_id, frame_id)
		for key, is_pressed in pairs(inputs) do
			table.insert(self.playertable[player_id][key], {value=is_pressed, frame_id=frame_id})
		end
	end

	return calendar
end

return calendar_mod
