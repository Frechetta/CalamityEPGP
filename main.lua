SLASH_RELOADUI1 = '/rl'
SlashCmdList.RELOADUI = ReloadUI

SLASH_FRAMESTK1 = '/fs'
SlashCmdList.FRAMESTK = function()
    LoadAddOn('Blizzard_DebugTools')
    FrameStackTooltip_Toggle()
end

for i = 1, NUM_CHAT_WINDOWS do
    _G['ChatFrame' .. i .. 'EditBox']:SetAltArrowKeyMode(false)
end
---------------------------------------------------------------

local addonName, ns = ...  -- Namespace

local addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceConsole-3.0')
ns.addon = addon


function addon:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New(addonName)
    guildName, _, _ = GetGuildInfo(UnitName('player'))

    if (self.db.profile.standings == nil) then
        self.db.profile.standings = {}
    end

    for i = 1, GetNumGuildMembers() do
        local name, rank, _, level, class, _, _, _, _, _, _ = GetGuildRosterInfo(i)
        if (self.db.profile.standings[name] == nil) then
            self.db.profile.standings[name] = {
                ['name'] = name,
                ['level'] = level,
                ['class'] = class,
                ['inGuild'] = true,
                ['rank'] = rank,
                ['ep'] = 0,
                ['gp'] = 1
            }
        end
    end

    self:Print('loaded')

    self.ShowWindowHandler(self)
end


function addon:OnEnable()
    -- Called when the addon is enabled
end


function addon:OnDisable()
    -- Called when the addon is disabled
end


function addon:SlashCommandHandler(input)
    if (input == 'show') then
        self.ShowWindowHandler(self)
    elseif (input == 'cfg') then
        self:Print('show options')
    else
        self:Print('Usage:')
        self:Print('show - Open the main window')
        self:Print('cfg - Opens the configuration menu')
    end
end


addon:RegisterChatCommand('ce', 'SlashCommandHandler')

local MainFrame;

function addon:ShowWindowHandler()
    local window = MainFrame or self:createWindow()
    window:SetShown(true)

    -- CalamityEPGP_MainFrame:Show()
    -- local textStore

    -- local frame = AceGUI:Create('Frame')
    -- frame:SetTitle('Example Frame')
    -- frame:SetStatusText('AceGUI-3.0 Example Container Frame')
    -- frame:SetCallback('OnClose', function(widget) AceGUI:Release(widget) end)
    -- frame:SetLayout('Flow')

    -- local editbox = AceGUI:Create('EditBox')
    -- editbox:SetLabel('Insert text:')
    -- editbox:SetWidth(200)
    -- editbox:SetCallback('OnEnterPressed', function(widget, event, text) textStore = text end)
    -- frame:AddChild(editbox)

    -- local button = AceGUI:Create('Button')
    -- button:SetText('Click Me!')
    -- button:SetWidth(200)
    -- button:SetCallback('OnClick', function() print(textStore) end)
    -- frame:AddChild(button)

    -- local standingsContainer = AceGUI:Create('SimpleGroup')
    -- standingsContainer:SetFullWidth(true)
    -- standingsContainer:SetFullHeight(true)
    -- standingsContainer:SetLayout('Fill')
    -- frame:AddChild(standingsContainer)

    -- local standingsTable = AceGUI:Create('ScrollFrame')
    -- standingsTable:SetLayout('Flow')
    -- standingsContainer:AddChild(standingsTable)

    -- for character in pairs(self.db.profile.standings) do
    --     local group = AceGUI:Create('SimpleGroup')
    --     group:SetFullWidth(true)
    --     group:SetLayout('Flow')
    --     standingsTable:AddChild(group)

    --     local level = self.db.profile.standings[character].level

    --     local labelChar = AceGUI:Create('Label')
    --     labelChar:SetText(character)
    --     group:AddChild(labelChar)

    --     local labelLevel = AceGUI:Create('Label')
    --     labelLevel:SetText(level)
    --     group:AddChild(labelLevel)
    -- end
end

function addon:createWindow()
    MainFrame = CreateFrame("Frame", addonName .. "_MainFrame", UIParent, "BasicFrameTemplateWithInset");
	MainFrame:SetSize(500, 400);
	MainFrame:SetPoint("CENTER"); -- Doesn't need to be ("CENTER", UIParent, "CENTER")

    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag('LeftButton')
    MainFrame:SetScript('OnDragStart', MainFrame.StartMoving)
    MainFrame:SetScript('OnDragStop', MainFrame.StopMovingOrSizing)

	MainFrame.title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	MainFrame.title:SetPoint("LEFT", MainFrame.TitleBg, "LEFT", 5, 0);
	MainFrame.title:SetText("CalamityEPGP");

	----------------------------------
	-- Buttons
	----------------------------------
	-- Save Button:
	MainFrame.saveBtn = self:createButton("CENTER", MainFrame, "TOP", -70, "Save");

    MainFrame.tableFrame = CreateFrame('Frame', MainFrame:GetName() .. 'TableFrame', MainFrame)
    MainFrame.tableFrame:SetPoint('TOP', MainFrame.saveBtn, 'BOTTOM', 0, -10)
    MainFrame.tableFrame:SetPoint('LEFT', MainFrame, 'LEFT', 10, 0)
    MainFrame.tableFrame:SetPoint('RIGHT', MainFrame, 'RIGHT', -8, 0)
    MainFrame.tableFrame:SetPoint('BOTTOM', MainFrame, 'BOTTOM', 0, 6)

    local data = self:getData()

    self:createTable(MainFrame.tableFrame, data)

	-- -- Reset Button:
	-- MainFrame.resetBtn = createButton("TOP", MainFrame.saveBtn, "BOTTOM", -10, "Reset");

	-- -- Load Button:
	-- MainFrame.loadBtn = createButton("TOP", MainFrame.resetBtn, "BOTTOM", -10, "Load");

	-- ----------------------------------
	-- -- Sliders
	-- ----------------------------------
	-- -- Slider 1:
	-- MainFrame.slider1 = CreateFrame("SLIDER", nil, MainFrame, "OptionsSliderTemplate");
	-- MainFrame.slider1:SetPoint("TOP", MainFrame.loadBtn, "BOTTOM", 0, -20);
	-- MainFrame.slider1:SetMinMaxValues(1, 100);
	-- MainFrame.slider1:SetValue(50);
	-- MainFrame.slider1:SetValueStep(30);
	-- MainFrame.slider1:SetObeyStepOnDrag(true);

	-- -- Slider 2:
	-- MainFrame.slider2 = CreateFrame("SLIDER", nil, MainFrame, "OptionsSliderTemplate");
	-- MainFrame.slider2:SetPoint("TOP", MainFrame.slider1, "BOTTOM", 0, -20);
	-- MainFrame.slider2:SetMinMaxValues(1, 100);
	-- MainFrame.slider2:SetValue(40);
	-- MainFrame.slider2:SetValueStep(30);
	-- MainFrame.slider2:SetObeyStepOnDrag(true);

	-- ----------------------------------
	-- -- Check Buttons
	-- ----------------------------------
	-- -- Check Button 1:
	-- MainFrame.checkBtn1 = CreateFrame("CheckButton", nil, MainFrame, "UICheckButtonTemplate");
	-- MainFrame.checkBtn1:SetPoint("TOPLEFT", MainFrame.slider1, "BOTTOMLEFT", -10, -40);
	-- MainFrame.checkBtn1.text:SetText("My Check Button!");

	-- -- Check Button 2:
	-- MainFrame.checkBtn2 = CreateFrame("CheckButton", nil, MainFrame, "UICheckButtonTemplate");
	-- MainFrame.checkBtn2:SetPoint("TOPLEFT", MainFrame.checkBtn1, "BOTTOMLEFT", 0, -10);
	-- MainFrame.checkBtn2.text:SetText("Another Check Button!");
	-- MainFrame.checkBtn2:SetChecked(true);

	-- MainFrame:Hide();

	return MainFrame;
end

function addon:createButton(point, relativeFrame, relativePoint, yOffset, text)
	local btn = CreateFrame("Button", nil, MainFrame, "GameMenuButtonTemplate");
	btn:SetPoint(point, relativeFrame, relativePoint, 0, yOffset);
	btn:SetSize(140, 40);
	btn:SetText(text);
	btn:SetNormalFontObject("GameFontNormalLarge");
	btn:SetHighlightFontObject("GameFontHighlightLarge");
	return btn;
end

function addon:createTable(parent, data)
    parent.scrollFrame = CreateFrame('ScrollFrame', parent:GetName() .. 'ScrollFrame', parent, 'UIPanelScrollFrameTemplate')
    parent.scrollFrame:SetAllPoints(parent)

    parent.scrollChild = CreateFrame('Frame')

    local scrollFrameName = parent.scrollFrame:GetName()
    parent.scrollBar = _G[scrollFrameName .. "ScrollBar"];
    parent.scrollUpButton = _G[scrollFrameName .. "ScrollBarScrollUpButton"];
    parent.scrollDownButton = _G[scrollFrameName .. "ScrollBarScrollDownButton"];

    -- all of these objects will need to be re-anchored (if not, they appear outside the frame and about 30 pixels too high)
    parent.scrollUpButton:ClearAllPoints();
    parent.scrollUpButton:SetPoint("TOPRIGHT", parent.scrollFrame, "TOPRIGHT", -2, -2);

    parent.scrollDownButton:ClearAllPoints();
    parent.scrollDownButton:SetPoint("BOTTOMRIGHT", parent.scrollFrame, "BOTTOMRIGHT", -2, 2);

    parent.scrollBar:ClearAllPoints();
    parent.scrollBar:SetPoint("TOP", parent.scrollUpButton, "BOTTOM", 0, -2);
    parent.scrollBar:SetPoint("BOTTOM", parent.scrollDownButton, "TOP", 0, 2);

    parent.scrollFrame:SetScrollChild(parent.scrollChild);

    parent.scrollChild:SetSize(parent.scrollFrame:GetWidth(), parent.scrollFrame:GetHeight() * 2)

    parent.contents = CreateFrame('Frame', nil, parent.scrollChild)
    parent.contents:SetAllPoints(parent.scrollChild)

    parent.contents.row1 = CreateFrame('Frame', nil, parent.contents)
    parent.contents.row1:SetPoint('TOP', parent.contents, 'TOP', 0, 0)
    parent.contents.row1:SetWidth(parent.contents:GetWidth())
    parent.contents.row1:SetHeight(20)

    parent.contents.row1.col1 = parent.contents.row1:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    parent.contents.row1.col1:SetText('Col1')
    parent.contents.row1.col1:SetPoint('LEFT', parent.contents.row1, 'LEFT', 0, 0)

    parent.contents.row2 = CreateFrame('Frame', nil, parent.contents)
    parent.contents.row2:SetPoint('TOP', parent.contents.row1, 'BOTTOM', 0, 0)
    parent.contents.row2:SetWidth(parent.contents:GetWidth())
    parent.contents.row2:SetHeight(20)

    parent.contents.row2.col1 = parent.contents.row2:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    parent.contents.row2.col1:SetText('Col1')
    parent.contents.row2.col1:SetPoint('LEFT', parent.contents.row2, 'LEFT', 0, 0)
end

function addon:getData()
    local data = {}

    for character, charData in pairs(self.db.profile.standings) do
        local row = AceGUI:Create('SimpleGroup')
        row:SetFullWidth(true)
        row:SetLayout('Flow')
        standingsTable:AddChild(row)

        local nameDash = string.find(character, '-')
        local name = string.sub(character, 0, nameDash - 1)

        local labelChar = AceGUI:Create('Label')
        labelChar:SetText(name)
        labelChar:SetWidth(columnWidth)
        row:AddChild(labelChar)

        local labelLevel = AceGUI:Create('Label')
        labelLevel:SetText(charData.level)
        labelLevel:SetWidth(columnWidth)
        row:AddChild(labelLevel)

        local labelClass = AceGUI:Create('Label')
        labelClass:SetText(charData.class)
        labelClass:SetWidth(columnWidth)
        row:AddChild(labelClass)

        local labelInGuild = AceGUI:Create('Label')
        labelInGuild:SetText(tostring(charData.inGuild))
        labelInGuild:SetWidth(columnWidth)
        row:AddChild(labelInGuild)

        local labelGuildRank = AceGUI:Create('Label')
        labelGuildRank:SetText(charData.rank)
        labelGuildRank:SetWidth(columnWidth)
        row:AddChild(labelGuildRank)

        local labelEp = AceGUI:Create('Label')
        labelEp:SetText(charData.ep)
        labelEp:SetWidth(columnWidth)
        row:AddChild(labelEp)

        local labelGp = AceGUI:Create('Label')
        labelGp:SetText(charData.gp)
        labelGp:SetWidth(columnWidth)
        row:AddChild(labelGp)

        local labelPr = AceGUI:Create('Label')
        labelPr:SetText(charData.ep / charData.gp)
        labelPr:SetWidth(columnWidth)
        row:AddChild(labelPr)
    end

    return data
end
