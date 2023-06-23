local addonName, ns = ...; -- Namespace

--------------------------------------
-- Custom Slash Command
--------------------------------------
ns.commands = {
	["config"] = ns.Config.Toggle, -- this is a function (no knowledge of Config object)

	["help"] = function()
		print(" ");
		ns:Print("Usage:")
		ns:Print("|cff00cc66/at config|r - shows config menu");
		ns:Print("|cff00cc66/at help|r - shows help info");
		print(" ");
	end,

	["example"] = {
		["test"] = function(...)
			ns:Print("My Value:", tostringall(...));
		end
	}
};

local function HandleSlashCommands(str)
	if (#str == 0) then
		-- User just entered "/at" with no additional args.
		ns.commands.help();
		return;
	end

	local args = {};
	for _, arg in ipairs({ string.split(' ', str) }) do
		if (#arg > 0) then
			table.insert(args, arg);
		end
	end

	local path = ns.commands; -- required for updating found table.

	for id, arg in ipairs(args) do
		if (#arg > 0) then -- if string length is greater than 0.
			arg = arg:lower();
			if (path[arg]) then
				if (type(path[arg]) == "function") then
					-- all remaining args passed to our function!
					path[arg](select(id + 1, unpack(args)));
					return;
				elseif (type(path[arg]) == "table") then
					path = path[arg]; -- another sub-table found!
				end
			else
				-- does not exist!
				ns.commands.help();
				return;
			end
		end
	end
end

function ns:Print(...)
    local hex = select(4, self.Config:GetThemeColor());
    local prefix = string.format("|cff%s%s|r", hex:upper(), addonName .. ':');
    DEFAULT_CHAT_FRAME:AddMessage(string.join(" ", prefix, ...));
end

-- WARNING: self automatically becomes events frame!
function ns:init(event, name)
	if (name ~= addonName) then return end

	-- allows using left and right buttons to move through chat 'edit' box
	for i = 1, NUM_CHAT_WINDOWS do
		_G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
	end

	----------------------------------
	-- Register Slash Commands!
	----------------------------------
	SLASH_RELOADUI1 = "/rl"; -- new slash command for reloading UI
	SlashCmdList.RELOADUI = ReloadUI;

	SLASH_FRAMESTK1 = "/fs"; -- new slash command for showing framestack tool
	SlashCmdList.FRAMESTK = function()
		LoadAddOn("Blizzard_DebugTools");
		FrameStackTooltip_Toggle();
	end

	SLASH_AuraTracker1 = "/at";
	SlashCmdList.AuraTracker = HandleSlashCommands;

    ns:Print('loaded');
end

local events = CreateFrame("Frame");
events:RegisterEvent("ADDON_LOADED");
events:SetScript("OnEvent", ns.init);
