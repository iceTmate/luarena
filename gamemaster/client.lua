local gamemaster_mod = require('gamemaster/mod')
local backtrack_balance_mod = require('gamemaster/backtrack_balance')

function new_clientmaster(networker, chars, local_id)
	local clientmaster = require("game/mod").new(chars, local_id)

	clientmaster.balancer = backtrack_balance_mod.new()

	clientmaster.networker = networker
	networker.event_handler = clientmaster

	function clientmaster:send(p)
		self.networker:send_to_server(p)
	end

	function clientmaster:on_recv(p)
		if p.tag == "inputs" then
			local current_backtrack = #self.frame_history - p.frame_id + 1 -- may be negative
			self.balancer:push_value(current_backtrack)
			self:apply_input_changes(p.inputs, p.player_id, p.frame_id)
		elseif p.tag == "avg_backtrack" then
			local avg = self.balancer:pop_avg()
			if p.avg_backtrack ~= nil and avg ~= nil then
				self.start_time = self.start_time + FRAME_DURATION * (avg - p.avg_backtrack)/2
			end
		else
			print("clientmaster received packet of strange tag: " .. tostring(p.tag))
		end
	end

	print("client - gamemaster alive!")
	return clientmaster
end

return new_clientmaster
