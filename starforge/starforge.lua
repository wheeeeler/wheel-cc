local peripherals = peripheral.getNames()
local inputP = {}
local outputP

for _, name in ipairs(peripherals) do
    if string.find(name, "expatternprovider:ex_interface") then
        table.insert(inputP, name)
    elseif string.find(name, "gtceu:uhv_input_bus") then
        outputP = name
    end
end

if #inputP == 0 or not outputP then
    error("Err: Missing required peripherals")
end

local function getItemCount(interfaceName, itemName)
    local items = peripheral.call(interfaceName, "list")
    local count = 0
    for _, item in pairs(items) do
        if item.name == itemName then
            count = count + item.count
        end
    end
    return count
end

local function transferItems(interfaceName, itemName, requiredCount)
    local itemList = peripheral.call(interfaceName, "list")
    local currentCount = getItemCount(outputP, itemName)
    local needed = math.max(0, requiredCount - currentCount)

    if needed > 0 then
        local tasks = {}
        for slot, item in pairs(itemList) do
            if item.name == itemName and needed > 0 then
                local transferAmount = math.min(item.count, needed)
                table.insert(tasks, function()
                    local success, err = pcall(function()
                        peripheral.call(interfaceName, "pushItems", outputP, slot, transferAmount)
                    end)
                    if not success then
                        print("Error in " .. interfaceName .. ": " .. (err or "unknown"))
                    end
                end)
                needed = needed - transferAmount
            end
        end
        parallel.waitForAll(table.unpack(tasks))
    end
end

local function transferAllItems(itemName, requiredCount)
    local tasks = {}
    for _, interfaceName in ipairs(inputP) do
        table.insert(tasks, function()
            transferItems(interfaceName, itemName, requiredCount)
        end)
    end
    parallel.waitForAll(table.unpack(tasks))
end

local function maintainItems()
    while true do
        local tasks = {}
        for _, itemName in ipairs({"allthetweaks:patrick_star", "allthetweaks:atm_star_shard"}) do
            table.insert(tasks, function()
                local requiredCount = itemName == "allthetweaks:patrick_star" and 256 or 6000
                transferAllItems(itemName, requiredCount)
            end)
        end
        local success, err = pcall(function()
            parallel.waitForAll(table.unpack(tasks))
        end)
        if not success then
            print("Error during item maintenance: " .. (err or "unknown"))
        end
        sleep(1)
    end
end

local function crack()
    local success, err = pcall(maintainItems)
    if not success then
        print("Fatal Error: " .. (err or "unknown"))
    end
end
term.clear()
crack()