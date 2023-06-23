SLASH_HELLO1 = '/hello'
SLASH_HELLO2 = '/msg'

local function showGreeting(name)
    message('Hello, ' .. name .. '!')
end

local function HelloWorldHandler(name)
    if (string.len(name) > 0) then
        showGreeting(name)
    else
        local playerName = UnitName('player')
        showGreeting(playerName)
    end
end

SlashCmdList["HELLO"] = HelloWorldHandler

SLASH_SOUND1 = "/playsound"
SLASH_STOPSOUND1 = "/stopsound"

local soundType = {
    SOUND = 1,
    GAME_MUSIC = 2,
    CUSTOM = 3
}

local sounds = {
    ["murloc"] = {
        ["sound"] = 416,
        ["description"] = "Mglrlrlrlrlrl!",
        ["type"] = soundType.SOUND
    },
    ["ding"] = {
        ["sound"] = 888,
        ["description"] = "Grats!",
        ["type"] = soundType.SOUND
    },
    ["main theme"] = {
        ["sound"] = "Sound\\Music\\GlueScreenMusic\\wow_main_theme.mp3",
        ["description"] = "DUN DUNNN... DUNNNNNNNNNN",
        ["type"] = soundType.GAME_MUSIC
    },
    ["custom"] = {
        ["sound"] = "Interface\\AddOns\\MusicPlayer\\Sounds\\custom.mp3",
        ["description"] = "Custom sound!",
        ["type"] = soundType.CUSTOM
    }
}

local customSoundId

local function displaySoundList()
    print("----------------------------")
    for command in pairs(sounds) do
        local description = sounds[command].description
        print("Command: /playsound " .. command .. " - Description: " .. description)
    end
    print("----------------------------")
end

local function playTrack(track)
    print(track.description)

    if (track.type == soundType.GAME_MUSIC) then
        PlayMusic(track.sound)
        print("To stop the music type /stopsound")
    elseif(track.type == soundType.SOUND) then
        PlaySound(track.sound)
    elseif(track.type == soundType.CUSTOM) then
        stopSoundHandler()
        customSoundId = select(2, PlaySoundFile(track.sound))
    end
end

local function playSoundHandler(trackId)
    if (string.len(trackId) > 0) then
        local matchesKnownTrack = sounds[trackId] ~= nil

        if (matchesKnownTrack) then
            local track = sounds[trackId]
            playTrack(track)
        else
            displaySoundList()
            print(trackId .. " - Doesn't match a known track.")
        end
    else
        displaySoundList()
    end
end

local function stopSoundHandler()
    StopMusic()

    if (customSoundId ~= nil) then
        StopSound(customSoundId)
        customSoundId = nil
    end
end

SlashCmdList["SOUND"] = playSoundHandler
SlashCmdList["STOPSOUND"] = stopSoundHandler
