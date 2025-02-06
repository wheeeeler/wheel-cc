local bridge = peripheral.find("meBridge")
local outputFile = "medump.txt"
 
term.clear()
term.setTextColor(colors.red)
term.setCursorPos(3, 5)
term.write("(C) CrackInc")
sleep(2)

local function writeToFile(file, data)
    local handle = fs.open(file, "a")
    handle.write(data)
    handle.close()
end
 
local function getMEData()
    local data = {}
    
    data["Items"] = bridge.listItems() or {}
    data["Fluids"] = bridge.listFluid() or {}
    data["Gases"] = bridge.listGas() or {}
    
    data["CraftableItems"] = bridge.listCraftableItems() or {}
    data["CraftableFluids"] = bridge.listCraftableFluid() or {}
    
    data["TotalItemStorage"] = bridge.getTotalItemStorage() or 0
    data["UsedItemStorage"] = bridge.getUsedItemStorage() or 0
    data["AvailableItemStorage"] = bridge.getAvailableItemStorage() or 0
    
    return data
end
 
local function formatCategory(title, data, isItem)
    local formatted = "\n////// " .. title .. " //////\n\n"
    local sortedList = {}
 
    for _, entry in pairs(data) do
        table.insert(sortedList, entry)
    end
    table.sort(sortedList, function(a, b) return a.amount > b.amount end)
 
    for _, entry in ipairs(sortedList) do
        if isItem then
            formatted = formatted .. string.format("Name: %s | Amount: %d | Craftable: %s\n", entry.name, entry.amount, tostring(entry.isCraftable))
        else
            formatted = formatted .. string.format("Name: %s | Amount: %d\n", entry.name, entry.amount)
        end
    end
 
    return formatted
end
 
local function formatStorageData(data)
    return string.format(
        "\n//////Storage Info //////\n\nTotal Item Storage: %d\nUsed Item Storage: %d\nAvailable Item Storage: %d\n",
        data["TotalItemStorage"],
        data["UsedItemStorage"],
        data["AvailableItemStorage"]
    )
end
 
local function main()
    if fs.exists(outputFile) then fs.delete(outputFile) end
 
    local data = getMEData()
    
    writeToFile(outputFile, formatCategory("Items", data["Items"], true))
    writeToFile(outputFile, formatCategory("Craftable Items", data["CraftableItems"], true))
    writeToFile(outputFile, formatCategory("Fluids", data["Fluids"], false))
    writeToFile(outputFile, formatCategory("Craftable Fluids", data["CraftableFluids"], false))
    writeToFile(outputFile, formatCategory("Gases", data["Gases"], false))
    writeToFile(outputFile, formatStorageData(data))

    term.clear()
    term.setCursorPos(3, 5)
    term.setTextColor(colors.green)

    print("dumped to " .. outputFile)
end
 
main()