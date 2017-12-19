local enet = require "enet"

return function(server, char, port)
	if char == nil then
		print("missing character!")
		usage()
	end

	server.chars = {char}

	function server:on_recv(p)
		if p.tag == "join" then
			table.insert(self.chars, p.char)
			self:broadcast_chars_packet()
		else
			print("received packet with strange tag: " .. tostring(p.tag))
			os.exit(1)
		end
	end

	server.networker = require("networker/server")(server, port)

	function server:broadcast_chars_packet()
		self.networker:broadcast_packet({
			tag = "chars",
			chars = self.chars
		})
	end

	function server:go()
		self.networker:broadcast_packet({
			tag = "go"
		})
		master = require("gamemaster/server")(self.chars, self.networker)
	end

	function server:update(dt)
		self.networker:handle_events()

		if love.keyboard.isDown('g') then
			self:go()
		end
	end

	return server
end
