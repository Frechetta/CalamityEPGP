local _, ns = ...  -- Namespace

local List = ns.List

local Table = {}
ns.Table = Table


---@param parent Frame
---@param header? boolean
---@param highlightHover? boolean
---@param highlightClick? boolean
---@param headerClickCallback? function
---@param rowClickCallback? function
function Table:new(parent, header, highlightHover, highlightClick, headerClickCallback, rowClickCallback)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o._header = header
    o._highlightHover = highlightHover
    o._highlightClick = highlightClick
    o._headerClickCallback = headerClickCallback
    o._rowClickCallback = rowClickCallback

    local mainFrame = CreateFrame('Frame', parent:GetName() .. 'TableFrame', parent)

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
    mainFrame.scrollBar = _G[scrollFrameName .. 'ScrollBar'];
    mainFrame.scrollUpButton = _G[scrollFrameName .. 'ScrollBarScrollUpButton'];
    mainFrame.scrollDownButton = _G[scrollFrameName .. 'ScrollBarScrollDownButton'];

    mainFrame.scrollUpButton:ClearAllPoints();
    mainFrame.scrollUpButton:SetPoint('TOPRIGHT', mainFrame.scrollFrame, 'TOPRIGHT', -2, 0);

    mainFrame.scrollDownButton:ClearAllPoints();
    mainFrame.scrollDownButton:SetPoint('BOTTOMRIGHT', mainFrame.scrollFrame, 'BOTTOMRIGHT', -2, -2);

    mainFrame.scrollBar:ClearAllPoints();
    mainFrame.scrollBar:SetPoint('TOP', mainFrame.scrollUpButton, 'BOTTOM', 0, 0);
    mainFrame.scrollBar:SetPoint('BOTTOM', mainFrame.scrollDownButton, 'TOP', 0, 0);

    mainFrame.scrollChild = CreateFrame('Frame')
    mainFrame.scrollChild:SetSize(mainFrame.scrollFrame:GetWidth() - mainFrame.scrollBar:GetWidth() - 7, 1)

    mainFrame.scrollFrame:SetScrollChild(mainFrame.scrollChild);

    -- header
    if header then
        mainFrame.header = CreateFrame('Frame', nil, mainFrame)
        mainFrame.header:SetPoint('TOPLEFT', mainFrame, 'TOPLEFT', 2, 0)
        mainFrame.header:SetHeight(10)
        mainFrame.header:SetPoint('RIGHT', mainFrame.scrollBar, 'LEFT', -5, 0)
        mainFrame.header.columns = List:new()
    end

    -- contents
    mainFrame.contents = CreateFrame('Frame', nil, mainFrame.scrollChild)
    mainFrame.contents:SetAllPoints(mainFrame.scrollChild)
    mainFrame.contents.rows = List:new()

    -- hover highlight
    if highlightHover then
        mainFrame.contents.rowHighlight = CreateFrame('Frame', nil, mainFrame.contents)
        local highlightTexture = mainFrame.contents.rowHighlight:CreateTexture(nil, 'OVERLAY')
        highlightTexture:SetAllPoints()
        highlightTexture:SetColorTexture(1, 1, 0, 0.3)
        highlightTexture:SetBlendMode('ADD')
        mainFrame.contents.rowHighlight:Hide()
    end

    -- click highlight
    if highlightClick then
        mainFrame.contents.rowSelectedHighlight = CreateFrame('Frame', nil, mainFrame.contents)
        local highlightTexture = mainFrame.contents.rowSelectedHighlight:CreateTexture(nil, 'OVERLAY')
        highlightTexture:SetAllPoints()
        highlightTexture:SetColorTexture(1, 1, 0, 0.3)
        highlightTexture:SetBlendMode('ADD')
        mainFrame.contents.rowSelectedHighlight:Hide()
    end

    o._mainFrame = mainFrame

    return o
end


---@param data table
function Table:setData(data)
    self.data = data

    self:_setHeader()
    self:_setRows()
    self:_setColumnWidths()
end


function Table:_setHeader()
    if self.data.header == nil then
        return
    end

    local header = self._mainframe.header
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
        column.maxWidth = column.textWidth

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
        local row = rows:get(i)

        if row == nil then
            local rowHeight = 15
            local yOffset = (rowHeight + 3) * (i - 1)

            row = CreateFrame('Frame', nil, contents)
            row:SetPoint('TOPLEFT', contents, 'TOPLEFT', 0, -yOffset)
            row:SetWidth(header:GetWidth())
            row:SetHeight(rowHeight)

            if self._highlightHover then
                row:EnableMouse()

                local rowHighlight = self._mainFrame.contents.rowHighlight

                row:SetScript('OnEnter', function()
                    rowHighlight:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
                    rowHighlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, 0)
                    rowHighlight:Show()
                end)

                row:SetScript('OnLeave', function()
                    rowHighlight:Hide()
                end)
            end

            if self._highlightClick then
                row:EnableMouse()

                local rowHighlight = self._mainFrame.contents.rowSelectedHighlight

                row:SetScript('OnMouseUp', function(_, button)
                    if button == 'LeftButton' then
                        rowHighlight:SetPoint('TOPLEFT', row, 'TOPLEFT', 0, 0)
                        rowHighlight:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 5, 0)
                        rowHighlight:Show()
                    end
                end)
            end

            if self._rowClickCallback ~= nil then
                row:EnableMouse()

                local existingFunc = row:GetScript('OnMouseUp')

                row:SetScript('OnMouseUp', function(_, button)
                    existingFunc()

                    if button == 'LeftButton' then
                        self._rowClickCallback(row)
                    end
                end)
            end

            row.columns = List:new()

            rows:append(row)
        end

        for k, columnText in ipairs(rowData) do
            local headerColumn = headerColumns:get(k)
            local column = row.columns:get(k)

            if column == nil then
                column = row:CreateFontString(nil, 'OVERLAY', 'GameTooltipText')
                column:SetPoint('LEFT', row)
                row.columns:append(column)
            end

            column:SetText(columnText)
            column:SetJustifyH(headerColumn:GetJustifyH())

            if row.color ~= nil then
                column:SetTextColor(row.color.r, row.color.g, row.color.b)
            end

            local text_width = column:GetWrappedWidth()
            if (text_width > headerColumn.maxWidth) then
                headerColumn.maxWidth = text_width
            end
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
    for column in headerColumns:iter() do
        columnWidthTotal = columnWidthTotal + column.maxWidth
    end

    local leftover = header:GetWidth() - columnWidthTotal
    local columnPadding = leftover / headerColumns:len()

    -- header
    for i, column in headerColumns:enumerate() do
        local relativeElement = header
        local relativePoint = 'LEFT'
        local padding = 0
        if (i > 1) then
            relativeElement = headerColumns:get(i - 1)
            relativePoint = 'RIGHT'
            padding = relativeElement.padding
        end

        local xOffset = padding
        column.padding = column.maxWidth + columnPadding - column.textWidth

        if column.text:GetJustifyH() == 'RIGHT' then
            xOffset = xOffset + column.maxWidth - column.textWidth
            column.padding = columnPadding
        end

        column:SetPoint('LEFT', relativeElement, relativePoint, xOffset, 0)
        column:SetWidth(column.textWidth)

        -- column.text:SetAllPoints()
    end

    -- data
    for row in rows:iter() do
        for i, column in row.columns:enumerate() do
            local headerColumn = headerColumns:get(i)

            -- local textHeight = column:GetLineHeight()
            -- local verticalPadding = (row:GetHeight() - textHeight) / 2

            local anchorPoint = headerColumn.text:GetJustifyH()
            column:SetPoint(anchorPoint, headerColumn, anchorPoint, 0, 0)
            -- column:SetPoint('TOP', row, 'TOP', 0, -verticalPadding)
        end
    end
end


---@param point string
---@param relativeTo any
---@param relativePoint string
---@param ofsX number
---@param ofsY number
function Table:SetPoint(point, relativeTo, relativePoint, ofsX, ofsY)
    self.mainFrame:SetPoint(point, relativeTo, relativePoint, ofsX, ofsY)
end
