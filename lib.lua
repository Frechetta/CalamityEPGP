local addonName, ns = ...  -- Namespace

Lib = {}

ns.Lib = Lib

function Lib:find(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end

    return -1
end

function Lib:contains(array, value)
    return self:find(array, value) ~= -1
end

function Lib:deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[self:deepcopy(orig_key, copies)] = self:deepcopy(orig_value, copies)
            end
            setmetatable(copy, self:deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Lib:remove(array, value)
    local i = self:find(array, value)
    table.remove(array, i)
end


function Lib:getClickCombination(mouseButton)
    local keySegments = {};

    if IsControlKeyDown() then
        tinsert(keySegments, 'CTRL');
    end

    if IsAltKeyDown() then
        tinsert(keySegments, 'ALT');
    end

    if IsShiftKeyDown() then
        tinsert(keySegments, 'SHIFT');
    end

    if not mouseButton or mouseButton == 'LeftButton' then
        tinsert(keySegments, 'CLICK');
    elseif mouseButton == 'RightButton' then
        tinsert(keySegments, 'RIGHTCLICK');
    end

    return table.concat(keySegments, '_');
end

function Lib:getItemIDFromLink(itemLink)
    if not itemLink or type(itemLink) ~= 'string' or itemLink == '' then
        return false;
    end

    local _, itemID = strsplit(':', itemLink);
    itemID = tonumber(itemID);

    if not itemID then
        return false;
    end

    return itemID;
end
