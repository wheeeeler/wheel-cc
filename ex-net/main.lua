local guiHandler = require("CRACK_HANDLER")
local exnetConfig = "ex-net_config.txt"
local modem = peripheral.find("modem")
local config = {}
local exnetVersion = "0.6"

local defaultSettings = {
    peripheralThreads = 1000,
    sleepTimer = 1,
    dynamicYield = true,
    autoThreadAllocation = false,
    maxThreads = 10000,
    daemonFilename = "ex-net_daemon.lua"
}

local function writeConfig()
    local file = fs.open(exnetConfig, "w")
    file.write(textutils.serialize(config))
    file.close()
end

local function loadConfig()
    if fs.exists(exnetConfig) then
        local file = fs.open(exnetConfig, "r")
        local content = file.readAll()
        config = textutils.unserialize(content) or { transfers = {}, transferEnabled = false, settings = defaultSettings, perifSizes = {} }
        file.close()
    else
        config = { transfers = {}, transferEnabled = false, settings = defaultSettings, perifSizes = {} }
    end
    config.settings = config.settings or {}
    config.settings.peripheralThreads = config.settings.peripheralThreads or defaultSettings.peripheralThreads
    config.settings.sleepTimer = config.settings.sleepTimer or defaultSettings.sleepTimer
    config.settings.daemonFilename = config.settings.daemonFilename or defaultSettings.daemonFilename
    config.settings.dynamicYield = config.settings.dynamicYield or defaultSettings.dynamicYield
end

local function mainMenu()
    loadConfig()
    local daemonFilename = config.settings.daemonFilename
    if not shell.openTab(daemonFilename) then
        print("Err: no daemon " .. daemonFilename)
        return
    end
    while true do
        loadConfig()
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.red)
        guiHandler.createMainMenu(config, {
            displayConfig = function() guiHandler.displayConfig(config) end,
            addTransferTask = function() guiHandler.addTransferTask(config, writeConfig, modem) end,
            configurationMenu = function() guiHandler.configurationMenu(config, writeConfig, modem) end,
            writeConfig = writeConfig
        })
    end
end

loadConfig()
guiHandler.initGUI(exnetVersion)
mainMenu()
