local addonName, ns = ...  -- Namespace

Lib = {}

ns.Lib = Lib

function Lib:contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end

    return false
end
