-----------------------------------------------------------------------------
--  World of Warcraft addon to ...: 
--	1.	Provide a generic framework for a WoW addon
--	2.	...
--
--  (c) March 2023 Duncan Baxter
--
--  License: All available rights reserved to the author
-----------------------------------------------------------------------------
-- SECTION 1: Constant/Variable definitions
-----------------------------------------------------------------------------
-- Define some local "constants"
local addonName = "Generic"
local width, height = 250, 400 -- Width and height of parent frame

-- Define some text strings
local text = {
	txtTooltip = addonName .. ":\nWhat a lovely tooltip!",
	txtLoaded = addonName .. ": Addon has loaded.",
	txtLogout = addonName .. ": Time for a break ...",
}
	
-----------------------------------------------------------------------------
-- SECTION 1.1: Debugging utilities (remove before release)
-----------------------------------------------------------------------------
-- Debugging function to recursively print the contents of a table (eg. a frame)
local function dumpTable(tbl, lvl) -- Parameters are the table(tbl) and (optionally) the recursion level (lvl)
	if (type(lvl) ~= "number") then lvl = 0 end -- If no level is provided (ie. omitted or not a number) then set it to level 0
	for k, v in pairs(tbl) do 
		print(strrep("-->", lvl), format("[%s] ", k), v) -- Each recursion level is indented relative to the level that called it
		if (type(v) == "table") then 
			dumpTable(v, lvl + 1)
		end
	end
end

-- Research function to print the available methods for an object
local function dumpMethods(object)
	local meta = getmetatable(object).__index;
	for k, v in pairs(meta) do
		if (type(v) == "function") then 
			table.insert(genericMethods, format("function %s()", k))
		end
	end
end

-- Research function to print the attributes of an object
local function dumpAttributes(object, p)
	if (type(p) ~= "string") then p = "." end-- If no prefix is provided (ie. omitted or not a string) then initialise to "."
	for k, v in pairs(object) do
		if (type(v) ~= "function") then 
			table.insert(genericAttributes, format("%s%s = %s", p, k, tostring(v))) -- e.g. ".SomeAttribute = 5"
		end
		if (type(v) == "table") then 
			dumpAttributes(v, format("%s%s.", p, k)) -- Recursively print the attributes of the table
		end
	end
end

-----------------------------------------------------------------------------
-- SECTION 2: Create the parent frame and implement core functionality including:
-- 1. Properly centred title
-- 1. Atlas texture used as the background
-- 2. 2D player picture used as the portrait (see Section 4)
-- 3. Exit and Close buttons with "OnClick" handlers (see Section 3)
-- 4.	Dragging (automatically preserved between sessions)
-- 5. Tooltip text
-- 6. Slash commands
-- 7. "OnEvent" handlers (see Section 4)
-----------------------------------------------------------------------------
-- Create the parent frame for our addon
local frame, events = CreateFrame("Frame", addonName, UIParent, "PortraitFrameTemplateNoCloseButton"), {}
if (frame:GetNumPoints() == 0) then 
	frame:SetPoint("CENTER")
	frame:SetSize(width, height)
end
local insets = { left = 20,	right = -20, top = -20 - frame.TitleContainer:GetHeight(), bottom = 20 }
local usableW, usableH = width + insets.right - insets.left, height + insets.top - insets.bottom

-- Set the frame portrait to the player
frame:SetPortraitToUnit("player")

-- Centre the title relative to the whole width of the frame (not just the title bar, which is off-centre)
frame:SetTitleOffsets(24, -24) -- The function "SetTitleOffsets (left, right)" only sets the horizontal offsets
frame:SetTitle(addonName)

-- Hide the default background (by setting its alpha value to 0) and replace it with an Atlas texture
frame.Bg:SetAlpha(0)
frame.texBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8) -- Sub-layers run from -8 to +7: -8 puts our background at the lowest level
frame.texBg:SetPoint("TOP", frame.TitleContainer, "BOTTOM")
frame.texBg:SetPoint("BOTTOMLEFT", frame) -- Need to set BOTTOMLEFT *and* BOTTOMRIGHT because TOP does not provide a "width" reference point
frame.texBg:SetPoint("BOTTOMRIGHT", frame)
frame.texBg:SetAtlas("ChromieTime-Parchment")

-- Make the frame draggable
frame:SetMovable(true)
frame:SetScript("OnMouseDown", function(self, button) self:StartMoving() end)
frame:SetScript("OnMouseUp", function(self, button) self:StopMovingOrSizing() end)

-- Display the mouseover tooltip
frame:SetScript("OnEnter", function(self, motion)
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE") -- Keeps the tooltip text in its default position
	GameTooltip:AddLine(text.txtTooltip)
	GameTooltip:Show()
end)
frame:SetScript("OnLeave", function(self, motion) GameTooltip:Hide() end)

-- Define the callback handler for our slash commands
local function cbSlash(msg, editBox)
	local cmd = msg:lower()
	if (cmd == "show") then frame:Show()
	elseif (cmd == "hide") then frame:Hide()
	elseif (cmd == "reset") then 
		frame:SetPoint("CENTER")
		frame:SetSize(width, height)
	end
	print(addonName .. ": Processed (" .. msg .. ") command")
end

-- Add our slash commands and callback handler to the global table
_G["SLASH_" .. strupper(addonName) .. "1"] = "/" .. strlower(strsub(addonName, 1, 2))
_G["SLASH_" .. strupper(addonName) .. "2"] = "/" .. strupper(strsub(addonName, 1, 2))
_G["SLASH_" .. strupper(addonName) .. "3"] = "/" .. strlower(addonName)
_G["SLASH_" .. strupper(addonName) .. "3"] = "/" .. strupper(addonName)
SlashCmdList[strupper(addonName)] = cbSlash

-----------------------------------------------------------------------------
-- SECTION 3: Create the other interactable objects
-----------------------------------------------------------------------------
-- Display the small Exit button (at top-right of frame)
frame.btnExit = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts") -- Button defined in SharedXML/SharedUIPanelTemplates.xml
frame.btnExit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -2) -- One point plus a size is not enough information for resizing
frame.btnExit:SetSize(20, 20)
frame.btnExit:SetScript("OnClick", function(self, button, down) frame:Hide() end)

-- Display the larger Close button (at bottom of frame)
frame.btnClose = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") -- Button defined in SharedXML/SharedUIPanelTemplates.xml
frame.btnClose:SetPoint("BOTTOM", frame, "BOTTOM", 0, insets.bottom)
frame.btnClose:SetSize(60, 20)
frame.btnClose:SetText("Close")
frame.btnClose:SetScript("OnClick", function(self, button, down) frame:Hide() end)

-----------------------------------------------------------------------------
-- SECTION 4: Define and register OnEvent handlers for the parent frame
-----------------------------------------------------------------------------
function events:ADDON_LOADED(name)
	if (name == addonName) then
		if (type(genericMethods) == nil) then genericMethods = {} end
		if (type(genericAttributes) == nil) then genericAttributes = {} end

		dumpMethods(frame)
		table.sort(genericMethods)
		dumpAttributes(frame)
		table.sort(genericAttributes)

		frame:UnregisterEvent("ADDON_LOADED")
		print(text.txtLoaded)
	end
end

function events:UNIT_PORTRAIT_UPDATE(unitID)
	if (unitID == "player") then frame:SetPortraitToUnit(unitID) end
end

function events:PLAYER_LOGOUT()
	frame:UnregisterAllEvents()
	print(text.txtLogout)
end

-- Register all the events for which we have a separate handling function
frame:SetScript("OnEvent", function(self, event, ...) events[event](self, ...) end)
for k, v in pairs(events) do frame:RegisterEvent(k) end
