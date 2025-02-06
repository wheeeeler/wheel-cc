local peripherals = peripheral.getNames()
local mineshafts = {}
local fluidTank
local patternProviders = {}

for _, name in ipairs(peripherals) do
    if string.find(name, "occultism:dimensional_mineshaft") then
        table.insert(mineshafts, name)
    elseif string.find(name, "enderio:fluid_tank") then
        fluidTank = name
    elseif string.find(name, "expatternprovider:ex_interface") then
        table.insert(patternProviders, name)
    end
end

if #mineshafts == 0 or not fluidTank or #patternProviders == 0 then
    error("Err: Missing required peripherals")
end

local function mineshaftTask(mineshaftName)
    local items = peripheral.call(mineshaftName, 'list')
    local minerFound = false
    for slot, item in pairs(items) do
        if item.name == 'occultism:miner_marid_master' then
            minerFound = true
            local meta = peripheral.call(mineshaftName, 'getItemDetail', slot)
            local damage = meta.damage or 0
            if damage >= 1500 then
                peripheral.call(mineshaftName, 'pushItems', fluidTank, slot)
                minerFound = false
            end
        else
            local targetPatternProvider = patternProviders[1]
            peripheral.call(mineshaftName, 'pushItems', targetPatternProvider, slot)
        end
    end
    if not minerFound then
        local fluidTankItems = peripheral.call(fluidTank, 'list')
        for slot, item in pairs(fluidTankItems) do
            if item.name == 'occultism:miner_marid_master' then
                local meta = peripheral.call(fluidTank, 'getItemDetail', slot)
                local damage = meta.damage or 0
                if damage < 1500 then
                    peripheral.call(fluidTank, 'pushItems', mineshaftName, slot)
                    break
                end
            end
        end
    end
end

local function fluidTankTask()
    local tanks = peripheral.call(fluidTank, 'tanks')
    local xpJuiceAmount = 0
    for _, tank in ipairs(tanks) do
        if tank.name == 'enderio:xp_juice' then
            xpJuiceAmount = xpJuiceAmount + tank.amount
        end
    end
    if xpJuiceAmount < 15000 then
        for _, provider in ipairs(patternProviders) do
            peripheral.call(fluidTank, 'pullFluid', provider, 99999)
        end
    end
    local items = peripheral.call(fluidTank, 'list')
    for slot, item in pairs(items) do
        if item.name == 'occultism:miner_marid_master' then
            local meta = peripheral.call(fluidTank, 'getItemDetail', slot)
            local damage = meta.damage or 0
            if damage < 1500 then
                for _, mineshaftName in ipairs(mineshafts) do
                    local mineshaftItems = peripheral.call(mineshaftName, 'list')
                    local hasMiner = false
                    for _, mineshaftItem in pairs(mineshaftItems) do
                        if mineshaftItem.name == 'occultism:miner_marid_master' then
                            hasMiner = true
                            break
                        end
                    end
                    if not hasMiner then
                        peripheral.call(fluidTank, 'pushItems', mineshaftName, slot)
                        break
                    end
                end
            end
        end
    end
end

local function mainTask()
    while true do
        local tasks = {}
        for _, mineshaftName in ipairs(mineshafts) do
            table.insert(tasks, function()
                mineshaftTask(mineshaftName)
            end)
        end
        table.insert(tasks, function()
            fluidTankTask()
        end)
        local success, err = pcall(function()
            parallel.waitForAll(table.unpack(tasks))
        end)
        if not success then
            print("Err: " .. (err or "unknown"))
        end
        sleep(1)
    end
end

local function crack()
    local success, err = pcall(mainTask)
    if not success then
        print("Fatal Error: " .. (err or "unknown"))
    end
end

term.clear()
crack()
