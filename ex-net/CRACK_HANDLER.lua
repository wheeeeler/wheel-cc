local gui = require("CRACK_API")

local function initGUI(exnetVersion)
    gui.initTerminal()
    gui.bootSplash(exnetVersion)
end

local function createMainMenu(config, actions)
    local buttons = gui.createMainMenu(config, actions)
    gui.handleMenuClick(buttons)
end

local function displayConfig(config)
    gui.displayConfig(config)
end

local function addTransferTask(config, writeConfig, modem)
    gui.addTransferTask(config, writeConfig, modem)
end

local function configurationMenu(config, writeConfig, modem)
    gui.configurationMenu(config, writeConfig, modem)
end

return {
    initGUI = initGUI,
    createMainMenu = createMainMenu,
    displayConfig = displayConfig,
    addTransferTask = addTransferTask,
    configurationMenu = configurationMenu
}
