local _, ns = ...  -- Namespace

local List = ns.List

local Table = {}
ns.Table = Table


---@param parent Frame
---@param name? string
---@param header? boolean
---@param highlightHoverCondition? boolean | function
---@param highlightClickCondition? boolean | function
---@param headerClickCallback? function
---@param rowClickCallback? function
function Table:new(parent, name, header, highlightHoverCondition, highlightClickCondition, headerClickCallback, rowClickCallback)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    local frameName = parent:GetName() .. 'Table'
    if name ~= nil then
        frameName = frameName .. name
    end

    local mainFrame = CreateFrame('Frame', frameName, parent)

    local scrollFrameYOffset = 0
    if header then
        scrollFrameYOffset = -20
    end

    mainFrame.scrollFrame = CreateFrame(
        'ScrollFrame',
        mainFrame:GetName() .. 'ScrollFrame',
        mainFrame,
        'UIPanelScrollFrameTemplate'
    )
    mainFrame.scrollFrame:SetPoint('TOPLEFT', mainFrame, 'TOPLEFT', 0, scrollFrameYOffset)
    mainFrame.scrollFrame:SetPoint('BOTTOMRIGHT', mainFrame)

    local scrollFrameName = mainFrame.scrollFrame:GetName()
    mainFrame.scrollBar = _G[scrollFrameName .. 'ScrollBar']
    mainFrame.scrollUpButton = _G[scrollFrameName .. 'ScrollBarScrollUpButton']
    mainFrame.scrollDownButton = _G[scrollFrameName .. 'ScrollBarScrollDownButton']

    mainFrame.scrollUpButton:ClearAllPoints()
    mainFrame.scrollUpButton:SetPoint('TOPRIGHT', mainFrame.scrollFrame, 'TOPRIGHT', -2, 0)

    mainFrame.scrollDownButton:ClearAllPoints()
    mainFrame.scrollDownButton:SetPoint('BOTTOMRIGHT', mainFrame.scrollFrame, 'BOTTOMRIGHT', -2, -2)

    mainFrame.scrollBar:ClearAllPoints()
    mainFrame.scrollBar:SetPoint('TOP', mainFrame.scrollUpButton, 'BOTTOM', 0, 0)
    mainFrame.scrollBar:SetPoint('BOTTOM', mainFrame.scrollDownButton, 'TOP', 0, 0)

    mainFrame.scrollChild = CreateFrame('Frame')
    mainFrame.scrollChild:SetSize(mainFrame.scrollFrame:GetWidth() - mainFrame.scrollBar:GetWidth() - 7, 1)

    mainFrame.scrollFrame:SetScrollChild(mainFrame.scrollChild)

    -- header
    mainFrame.header = CreateFrame('Frame', nil, mainFrame)
    mainFrame.header:SetPoint('TOPLEFT', mainFrame, 'TOPLEFT', 2, 0)
    mainFrame.header:SetPoint('RIGHT', mainFrame.scrollBar, 'LEFT', -7, 0)

    if header then
        mainFrame.header:SetHeight(10)
        mainFrame.header.columns = List:new()
    end

    -- contents
    mainFrame.contents = CreateFrame('Frame', nil, mainFrame.scrollChild)
    mainFrame.contents:SetAllPoints(mainFrame.scrollChild)
    mainFrame.contents.rows = List:new()

    -- hover highlight
    mainFrame.contents.rowHighlight = CreateFrame('Frame', nil, mainFrame.contents)
    local highlightTexture = mainFrame.contents.rowHighlight:CreateTexture(nil, 'OVERLAY')
    highlightTexture:SetAllPoints()
    highlightTexture:SetColorTexture(1, 1, 0, 0.3)
    highlightTexture:SetBlendMode('ADD')
    mainFrame.contents.rowHighlight:Hide()

    -- click highlight
    mainFrame.contents.rowSelectedHighlight = CreateFrame('Frame', nil, mainFrame.contents)
    local highlightTexture = mainFrame.contents.rowSelectedHighlight:CreateTexture(nil, 'OVERLAY')
    highlightTexture:SetAllPoints()
    highlightTexture:SetColorTexture(1, 1, 0, 0.3)
    highlightTexture:SetBlendMode('ADD')
    mainFrame.contents.rowSelectedHighlight:Hide()

    o._mainFrame = mainFrame

    o._header = header

    if highlightHoverCondition == true then
        highlightHoverCondition = function() return true end
    elseif highlightHoverCondition == false or highlightHoverCondition == nil then
        highlightHoverCondition = function() return false end
    end
    o._highlightHoverCondition = highlightHoverCondition

    if highlightClickCondition == true then
        highlightClickCondition = function() return true end
    elseif highlightClickCondition == false or highlightClickCondition == nil then
        highlightClickCondition = function() return false end
    end
    o._highlightClickCondition = highlightClickCondition

    o._headerClickCallback = headerClickCallback
    o._rowClickCallback = rowClickCallback

    o._columnWidths = List:new()

    return o
end


---@param data table
function Table:setData(data)
    self._mainFrame.contents.rowHighlight:Hide()
    self._mainFrame.contents.rowSelectedHighlight:Hide()

    self.data = data

    self._columnWidths:clear()

    self:_setHeader()
    self:_setRows()
    self:_setColumnWidths()
end


function Table:_setHeader()
    if not self._header then
        return
    end

    local header = self._mainFrame.header
    local columns = header.columns

    for i, headerData in ipairs(self.data.header) do
        local column = columns:get(i)
        if column == nil then
            column = CreateFrame('Frame', nil, header)
            column:SetHeight(header:GetHeight())

            column.text = column:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
            column.text:SetAllPoints()
            column.text:SetTextColor(1, 1, 0)
            column.text:SetFont('Fonts\\ARIAL.TTF', 10)

            columns:append(column)
        end

        local headerText = headerData[1]
        local justify = headerData[2]

        column.text:SetText(headerText)
        column.text:SetJustifyH(justify)

        column.textWidth = column.text:GetWrappedWidth()

        self._columnWidths:append(column.textWidth)

        if self._headerClickCallback ~= nil then
            column:SetScript('OnEnter', function() column.text:SetTextColor(1, 1, 1) end)
            column:SetScript('OnLeave', function() column.text:SetTextColor(1, 1, 0) end)

            column:SetScript('OnMouseUp', function(_, button)
                if button == 'LeftButton' then
                    self._headerClickCallback(i)
                end
            end)
        end

        column:Show()
    end

    for i = #self.data.header + 1, columns:len() do
        local column = columns:get(i)
        column:Hide()
    end
end


function Table:_setRows()
    local header = self._mainFrame.header
    local headerColumns = header.columns

    local contents = self._mainFrame.contents
    local rows = contents.rows

    for i, rowData in ipairs(self.data.rows) do
        local metadata = {}
        if type(rowData[#rowData]) == 'table' then
            metadata = rowData[#rowData]
        end

        local row = rows:get(i)

        if row == nil then
            local rowHeight = 15
            local yOffset = (rowHeight + 3) * (i - 1)

            row = CreateFrame('Frame', nil, contents)
            row:SetPoint('TOPLEFT', contents, 'TOPLEFT', 0, -yOffset)
            row:SetWidth(header:GetWidth())
            row:SetHeight(rowHeight)

            if self._highlightHoverCondition ~= nil and self._highlightHoverCondition ~= false then
                row:EnableMouse()

                local rowHighlight = self._mainFrame.contents.rowHighlight

                row:SetScript('OnEnter', function()
                    if self._highlightHoverCondition() then
                        rowHighlight:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
                        rowHighlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
                        rowHighlight:Show()
                    end
                end)

                row:SetScript('OnLeave', function()
                    rowHighlight:Hide()
                end)
            end

            if self._highlightClickCondition ~= nil and self._highlightClickCondition ~= false then
                row:EnableMouse()

                local rowHighlight = self._mainFrame.contents.rowSelectedHighlight

                row:SetScript('OnMouseUp', function(_, button)
                    if button == 'LeftButton' and self._highlightClickCondition() then
                        rowHighlight:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
                        rowHighlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
                        rowHighlight:Show()
                    end
                end)
            end

            if self._rowClickCallback ~= nil then
                row:EnableMouse()

                local existingFunc = row:GetScript('OnMouseUp')

                row:SetScript('OnMouseUp', function(_, button)
                    if existingFunc ~= nil then
                        existingFunc(nil, button)
                    end

                    self._rowClickCallback(button, row)
                end)
            end

            row.columns = List:new()

            rows:append(row)
        end

        row.metadata = metadata

        local columnCount = 0

        for k, columnText in ipairs(rowData) do
            if type(columnText) ~= 'table' then
                local column = row.columns:get(k)

                if column == nil then
                    column = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
                    column:SetPoint('LEFT', row)
                    row.columns:append(column)
                end

                column:SetText(columnText)

                local textWidth = column:GetWrappedWidth()
                local maxWidth = self._columnWidths:get(k)
                if maxWidth == nil then
                    maxWidth = textWidth
                    self._columnWidths:append(maxWidth)
                end
                if (textWidth > maxWidth) then
                    self._columnWidths:set(k, textWidth)
                end

                if metadata.color ~= nil then
                    column:SetTextColor(metadata.color.r, metadata.color.g, metadata.color.b)
                end

                if headerColumns ~= nil then
                    local headerColumn = headerColumns:get(k)
                    column:SetJustifyH(headerColumn.text:GetJustifyH())
                end

                column:Show()

                columnCount = columnCount + 1
            end
        end

        for k = columnCount + 1, row.columns:len() do
            local column = row.columns:get(k)
            column:Hide()
        end

        row.data = rowData
        row:Show()
    end

    for i = #self.data.rows + 1, rows:len() do
        local row = rows:get(i)
        row:Hide()
    end
end


function Table:_setColumnWidths()
    local header = self._mainFrame.header
    local headerColumns = header.columns
    local contents = self._mainFrame.contents
    local rows = contents.rows

    -- Calculate column padding
    local columnWidthTotal = 0
    for width in self._columnWidths:iter() do
        columnWidthTotal = columnWidthTotal + width
    end

    local columnCount = self._columnWidths:len()

    local leftover = header:GetWidth() - columnWidthTotal
    local columnPadding = leftover / columnCount

    -- header
    if self._header then
        for i = 1, columnCount do
            local column = headerColumns:get(i)

            local relativeElement = header
            local relativePoint = 'LEFT'
            local padding = 0
            if (i > 1) then
                relativeElement = headerColumns:get(i - 1)
                relativePoint = 'RIGHT'
                padding = relativeElement.padding
            end

            local xOffset = padding
            local maxWidth = self._columnWidths:get(i)
            column.padding = maxWidth + columnPadding - column.textWidth

            if column.text:GetJustifyH() == 'RIGHT' then
                xOffset = xOffset + maxWidth - column.textWidth
                column.padding = columnPadding
            end

            column:SetPoint('LEFT', relativeElement, relativePoint, xOffset, 0)
            column:SetWidth(column.textWidth)
        end
    end

    -- data
    for row in rows:iter() do
        for i = 1, columnCount do
            local column = row.columns:get(i)

            local textHeight = column:GetLineHeight()
            local verticalPadding = (row:GetHeight() - textHeight) / 2

            local anchorPoint
            local anchor
            if self._header then
                anchorPoint = column:GetJustifyH()
                anchor = headerColumns:get(i)
            else
                anchorPoint = 'LEFT'
                anchor = self._mainFrame.scrollFrame
            end

            column:SetPoint(anchorPoint, anchor)
            column:SetPoint('TOP', row, 'TOP', 0, -verticalPadding)
        end
    end
end


---@param point string
---@param relativeTo any
---@param relativePoint string
---@param ofsX number
---@param ofsY number
function Table:SetPoint(point, relativeTo, relativePoint, ofsX, ofsY)
    self._mainFrame:SetPoint(point, relativeTo, relativePoint, ofsX, ofsY)
end


function Table:getFrame()
    return self._mainFrame
end


function Table:clear()
    if self._mainFrame == nil then
        return
    end

    if self.data ~= nil then
        local header = self.data.header
        if header == nil then
            header = {}
        end

        self:setData({
            header = header,
            rows = {},
        })
    end

    self._mainFrame.contents.rowHighlight:Hide()
    self._mainFrame.contents.rowSelectedHighlight:Hide()
end
