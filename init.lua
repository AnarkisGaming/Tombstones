-- Import everything we'll need
Mannequin:Import("Steamworks")
Mannequin:Import("UI")
Mannequin:Import("Event")
Mannequin:Import("IO")
Mannequin:Import("EIOContext")

-- Create an IO context, so we can save the user notice.
local io = IO(EIOContext.Global)

local deathPopupShown = false
local canGameOver = false
local causeOfDeath = ""

-- The name of the last Survivor
local dName = "";

-- When we're at the menu,
Event.Once("Menu", function()
	-- Check to see if we've accepted the warning
	if not io.Get("accepted", false) then
		-- If not, show it
		UI.ShowMessageDialog("Tombstones Mod Information", "The Tombstones Mod works by sending your Steam information plus the name of your last Survivor to Cutie Cafe servers in order to generate a tombstone to post in our Discord server. You can ask to have your tombstones removed at any time by emailing alex@anarkisgaming.com. Removing this mod will stop any further data sharing.", function()
			-- And set that we've seen it already.
			io.Set("accepted", true)
		end);
	end
end)

-- When an Agent (something in the game) dies,
Event.On("AgentDeath", function(di)
	-- Check to see that it's "living" (i.e. not a wall or other clutter)
	if not di.Victim.IsLiving then return true end
	-- Check to see that it's the player's faction
    if di.Victim.Faction.ID != "player" then return true end
	-- If neither are true, set the last Survivor's name to the name of the survivor that just died
	dName = di.Victim.Name
	
	if di.IsCauseAttacked then causeOfDeath = "Died to " .. di.Description
	elseif di.IsCauseExpedition then causeOfDeath = "Died on an expedition"
	elseif di.IsCauseTrait then causeOfDeath = "Died of " .. di.Description
	else causeOfDeath = "Died of mysterious causes" end
end)

-- When the game ends,
-- (note: this is called repeatedly until the game finally ends)
Event.On("GameOver", function()
	-- Check that Steamworks is ready (so we can make authenticated requests)
	-- If we don't have access to Steamworks, none of this other stuff will work.
	-- HTTP.Post is a drop-in for Steamworks.SignedRequest
	if not Steamworks.IsReady then return true end
	
	-- If the Last Words dialog hasn't been shown,
    if not deathPopupShown then
        deathPopupShown = true
		-- Show the dialog
        UI.ShowInputDialog("Your settlement has collapsed!", "Does " .. dName .. " have any last words?", function(resp)
			-- Once the user has responded,
			-- Set the request arguments
            local rqargs = {}
            rqargs.SurvivorName = dName
            rqargs.LastWords = resp
			rqargs.Cause = causeOfDeath
			
			-- Show a blocking dialog that lets the user know we're submitting their tombstone
			local pnl = UI.ShowDialog("Submitting", "Please wait while your tombstone is submitted. This may take a moment...")
			
			-- Send a signed (authenticated) request.
			-- We use this here so that the user's persona name can be accurately shown on the tombstone.
			-- If you have a reason to send signed requests, please let us know.
			-- HTTP.Post is a drop-in for this
            Steamworks.SignedRequest("Tombstones", rqargs, function(resp)
				-- Close the panel
				pnl:Close()
                canGameOver = true
            end)
        end)
    end
    
	-- For hooks that can be cancelled, we can return "false" to cancel them and not have their results take effect.
    return canGameOver
end)

-- Whenever the menu comes up,
Event.On("Menu", function()
	-- Reset everything
    canGameOver = false
	deathPopupShown = false
	dName = ""
end)