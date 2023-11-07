local _, ns = ...  -- Namespace

local Comm = {
    prefix = 'calepgp',
    msgTypes = {
        HEARTBEAT = 0,
        ROLL_PASS = 1,
        DATA_REQ = 10,
        DATA_SEND = 11,
        SYNC_0 = 12,
        SYNC_1 = 13,
        SYNC_2 = 14,
    },
    msgTypeNames = {},
    funcs = {},
}

ns.Comm = Comm

for name, num in pairs(Comm.msgTypes) do
    Comm.msgTypeNames[num] = name
end


function Comm:init()
    ns.addon:RegisterComm(self.prefix, self.handleMessage)
end


---@param msgType integer
---@param func function
function Comm:registerHandler(msgType, func)
    if self.msgTypeNames[msgType] == nil then
        error(('invalid message type %d'):format(msgType))
    end

    if func == nil then
        error('func cannot be nil')
    end

    if type(func) ~= 'function' then
        -- error(('func must be a function, not "%s"'):format(type(func)))
    end

    -- if self.funcs[msgType] ~= nil then
    --     error(('message type %s already has a registered function'):format(self.msgTypeNames[msgType]))
    -- end

    self.funcs[msgType] = func
end


---@param msgType integer
function Comm:unregisterHandler(msgType)
    if self.msgTypeNames[msgType] == nil then
        error(('invalid message type %d'):format(msgType))
    end

    self.funcs[msgType] = nil
end


---@param msgType integer
---@param data? table
---@param distribution string
---@param target? string
function Comm:send(msgType, data, distribution, target)
    if msgType ~= self.msgTypes.HEARTBEAT then
        local dest
        if distribution == 'WHISPER' then
            dest = target
        else
            dest = distribution
        end
        ns.debug(('sending %s msg to %s'):format(self.msgTypeNames[msgType], dest))
    end

    if self.msgTypeNames[msgType] == nil then
        error(('invalid message type %d'):format(msgType))
    end

    if data == nil then
        data = {}
    end

    local message = {
        t = msgType,
        d = data,
        v = ns.addon.versionNum,
    }

    local messageStr = self.packMessage(message)
    ns.addon:SendCommMessage(self.prefix, messageStr, distribution, target)
end


function Comm.handleMessage(prefix, message, _, sender)
    if prefix ~= Comm.prefix or sender == ns.unitName('player') then
        return
    end

    message = Comm.unpackMessage(message)

    local msgType = message.t
    if msgType == nil or Comm.msgTypeNames[msgType] == nil then
        return
    end

    local theirVersion = message.v

    if msgType ~= Comm.msgTypes.HEARTBEAT then
        ns.debug(('got message %s from %s'):format(Comm.msgTypeNames[msgType], sender))

        if theirVersion == nil then
            ns.debug('-- client version unknown (probably out of date)')
            return
        end

        if theirVersion < ns.minSyncVersion and msgType ~= Comm.msgTypes.ROLL_PASS then
            ns.debug(string.format(
                '-- client version (%s) less than minimum (%s)',
                ns.Lib.getVersionStr(theirVersion),
                ns.Lib.getVersionStr(ns.minSyncVersion)
            ))
            return
        end
    end

    local func = Comm.funcs[msgType]
    if func == nil then
        return
    end

    func(message, sender)
end


---@param message any
---@return string
function Comm.packMessage(message)
    local package = ns.addon:Serialize(message)
    package = ns.addon.libc:CompressHuffman(package)
    package = ns.addon.libcEncodeTable:Encode(package)

    return package
end


---@param package string
---@return any
function Comm.unpackMessage(package)
    local message = ns.addon.libcEncodeTable:Decode(package)

    local error
    message, error = ns.addon.libc:Decompress(message)

    if message == nil then
        ns.debug(string.format('could not decompress message. error: %s', error))
        return nil
    end

    local success
    success, message = ns.addon:Deserialize(message)

    if not success then
        ns.debug('could not deserialize message')
        return nil
    end

    return message
end
