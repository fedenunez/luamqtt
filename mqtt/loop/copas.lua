local copas = require "copas"
local log = require "mqtt.log"

local client_registry = {}

local _M = {}


--- Add MQTT client to the Copas scheduler.
-- The client will automatically be removed after it exits.
-- @tparam cl client to add to the Copas scheduler
-- @return true on success or false and error message on failure
function _M.add(cl)
	if client_registry[cl] then
		log:warn("MQTT client '%s' was already added to Copas", cl.opts.id)
		return false, "MQTT client was already added to Copas"
	end
	client_registry[cl] = true

	-- add keep-alive timer
	local timer = copas.addthread(function()
		while client_registry[cl] do
			copas.sleep(cl:check_keep_alive())
		end
	end)

	-- add client to connect and listen
	copas.addthread(function()
		while client_registry[cl] do
			local timeout = cl:step()
			if not timeout then
				client_registry[cl] = nil -- exiting
				log:debug("MQTT client '%s' exited, removed from Copas", cl.opts.id)
				copas.wakeup(timer)
			else
				if timeout > 0 then
					copas.sleep(timeout)
				end
			end
		end
	end)

	return true
end

return setmetatable(_M, {
	__call = function(self, ...)
		return self.add(...)
	end,
})
