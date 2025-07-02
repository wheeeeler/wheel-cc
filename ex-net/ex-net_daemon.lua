local exnetConfig = "ex-net_config.txt"
local config = {}

local transferEnabled = false

term.setCursorPos(17, 6)
term.setTextColor(colors.red)
term.write("Initializing...")
sleep(1)    
term.clear()
term.setTextColor(colors.red)

local defaultSettings = {
    peripheralThreads = 1000,
    sleepTimer = 1,
    dynamicYield = true,
    autoThreadAllocation = false,
    maxThreads = 10000
}

local epochCount = 0

local function loadConfig()
    if fs.exists(exnetConfig) then
        local file = fs.open(exnetConfig, "r")
        local content = file.readAll()
        config = textutils.unserialize(content) or { transfers = {}, transferEnabled = false, settings = defaultSettings }
        file.close()
    else
        config = { transfers = {}, transferEnabled = false, settings = defaultSettings }
    end
end

local function nameFormatter(name)
    return name:match(":(.+)$") or name
end

local function conPerifs(peripheralNames)
    local consolidatedP = {}
    for _, name in ipairs(peripheralNames) do
        local baseName = name:match("^([^_]+)_") or name
        consolidatedP[baseName] = consolidatedP[baseName] or {}
        table.insert(consolidatedP[baseName], name)
    end
    return consolidatedP
end

local function daemonColors(color, message)
    term.setTextColor(color)
    print(message)
    term.setTextColor(colors.white)
end

local function initializePeripherals(peripheralNames)
    local peripherals = {}
    local errors = {}

    local initTasks = {}
    for _, name in ipairs(peripheralNames) do
        table.insert(initTasks, function()
            local wrappedPeripheral = peripheral.wrap(name)
            if wrappedPeripheral then
                peripherals[name] = wrappedPeripheral
            else
                table.insert(errors, "Err: unable to wrap peripheral " .. nameFormatter(name))
            end
        end)
    end

    parallel.waitForAll(table.unpack(initTasks))
    return peripherals, errors
end

local function processConPeripherals(task, sourceNames, destP)
    local numTransferRun = 0
    local errorMessages = {}

    local sources, sourceErrors = initializePeripherals(sourceNames)
    for _, err in ipairs(sourceErrors) do
        table.insert(errorMessages, err)
    end

    local destSlots = {}
    local destItems = destP.list and destP.list()
    local destSize = destP.size and destP.size()
    if destItems and destSize then
        if task.destinationSlotRange == "all" then
            for slotIndex = 1, destSize do
                table.insert(destSlots, slotIndex)
            end
        elseif type(task.destinationSlotRange) == "table" then
            local indexStart = task.destinationSlotRange[1]
            local indexEnd = task.destinationSlotRange[2]
            for slotIndex = indexStart, indexEnd do
                if slotIndex >=1 and slotIndex <= destSize then
                    table.insert(destSlots, slotIndex)
                end
            end
        end
    else
        table.insert(errorMessages, "Err: unable to get slots from destination peripheral " .. nameFormatter(peripheral.getName(destP)))
        return 0, errorMessages
    end

    local destSlotIndex = 1

    for _, sourceName in ipairs(sourceNames) do
        local sourceP = sources[sourceName]
        if not sourceP then
            table.insert(errorMessages, "Err: missing " .. nameFormatter(sourceName) .. " continuing without..")
            return 0, errorMessages
        end

        local items = sourceP.list and sourceP.list()
        local slotsToProcess = {}

        if items then
            if task.sourceSlotRange == "all" then
                for slotIndex, item in pairs(items) do
                    table.insert(slotsToProcess, { slot = slotIndex, count = item.count })
                end
            elseif type(task.sourceSlotRange) == "table" then
                local indexStart = task.sourceSlotRange[1]
                local indexEnd = task.sourceSlotRange[2]
                for slotIndex = indexStart, indexEnd do
                    if items[slotIndex] then
                        table.insert(slotsToProcess, { slot = slotIndex, count = items[slotIndex].count })
                    end
                end
            end
        end

        if (task.transferType == "items" or task.transferType == "both") then
            local batchTasks = {}
            for _, slotInfo in ipairs(slotsToProcess) do
                table.insert(batchTasks, function()
                    local destSlot = destSlots[destSlotIndex]
                    if not destSlot then
                        destSlotIndex = 1
                        destSlot = destSlots[destSlotIndex]
                    end

                    local transCount = sourceP.pushItems(peripheral.getName(destP), slotInfo.slot, slotInfo.count, destSlot)
                    if transCount > 0 then
                        numTransferRun = numTransferRun + transCount
                    end

                    destSlotIndex = destSlotIndex + 1
                    if destSlotIndex > #destSlots then
                        destSlotIndex = 1
                    end
                end)
            end
            parallel.waitForAll(table.unpack(batchTasks))
        end

        if (task.transferType == "fluids" or task.transferType == "both") and sourceP.pushFluid and destP.pullFluid then
            local transCount = sourceP.pushFluid(peripheral.getName(destP))
            if transCount > 0 then
                numTransferRun = numTransferRun + transCount
            end
        end
    end

    return numTransferRun, errorMessages
end

local function runTransfer()
    loadConfig()
    if not config.transferEnabled then
        return 0, {}
    end

    local peripheralThreads = config.settings.peripheralThreads or defaultSettings.peripheralThreads
    local dynamicYield = config.settings.dynamicYield or defaultSettings.dynamicYield
    local autoThreadAllocation = config.settings.autoThreadAllocation or defaultSettings.autoThreadAllocation
    local maxThreads = config.settings.maxThreads or defaultSettings.maxThreads

    local sumItemTransfer = 0
    local numErrors = {}

    local tasksToExec = {}
    for _, task in ipairs(config.transfers) do
        local conSourceP = conPerifs(task.sources or {})
        for baseName, sourceNames in pairs(conSourceP) do
            local destPeripherals, destErrors = initializePeripherals(task.destinations or {})
            for _, err in ipairs(destErrors) do
                table.insert(numErrors, err)
            end

            for destName, destP in pairs(destPeripherals) do
                table.insert(tasksToExec, function()
                    local numTransfers, errorMessages = processConPeripherals(task, sourceNames, destP)
                    if #errorMessages > 0 then
                        for _, msg in ipairs(errorMessages) do
                            table.insert(numErrors, msg)
                        end
                    end
                    sumItemTransfer = sumItemTransfer + numTransfers
                end)
            end
        end
    end

    if autoThreadAllocation then
        peripheralThreads = math.min(#tasksToExec, maxThreads)
    end

    for i = 1, #tasksToExec, peripheralThreads do
        local functionsToExecute = {}
        for j = i, math.min(i + peripheralThreads - 1, #tasksToExec) do
            table.insert(functionsToExecute, tasksToExec[j])
        end

        parallel.waitForAll(table.unpack(functionsToExecute))

        if dynamicYield then
            sleep(math.max(0.02, #tasksToExec / 100))
        else
            sleep(0)
        end
    end

    return sumItemTransfer, numErrors
end

local function errorCleanup(startLine, endLine)
    for line = startLine, endLine do
        term.setCursorPos(1, line)
        term.clearLine()
    end
    term.setCursorPos(1, startLine)
end

local function headTarget()
    local writeErrorLine = 9

    while true do
        term.setCursorPos(1, 1)

        loadConfig()

        if not config.transferEnabled then
            term.setCursorPos(1, 1)
            daemonColors(colors.magenta, "Transfer state = disabled")
            
            term.setCursorPos(1, 2)
            local sleepTimer = config.settings.sleepTimer or defaultSettings.sleepTimer
            daemonColors(colors.magenta, "Recheck in -> " .. sleepTimer .. " seconds")
            sleep(sleepTimer)
        else
            epochCount = epochCount + 1

            local startTime = os.clock()

            local itemEpoch, numErrors = runTransfer()

            local elapsedTime = os.clock() - startTime

            term.setCursorPos(1, 1)
            term.setTextColor(colors.lightGray)
            write("Executed ")

            term.setTextColor(colors.purple)
            write(itemEpoch)

            term.setTextColor(colors.lightGray)
            write(" operations(s) during epoch ")

            term.setTextColor(colors.purple)
            write(epochCount .. "                    ")

            term.setCursorPos(1, 2)
            term.setTextColor(colors.lightGray)
            write("Epoch took ")

            term.setTextColor(colors.purple)
            write(string.format("%.2f", elapsedTime))

            term.setTextColor(colors.lightGray)
            write(" seconds to complete")

            term.setCursorPos(1, 3)
            local sleepTimer = config.settings.sleepTimer or defaultSettings.sleepTimer
            term.setTextColor(colors.lightGray)
            write("Next task in ")

            term.setTextColor(colors.purple)
            write(sleepTimer)

            term.setTextColor(colors.lightGray)
            write(" seconds")

            errorCleanup(writeErrorLine, writeErrorLine + 5)

            term.setCursorPos(1, writeErrorLine)
            for _, errorMsg in ipairs(numErrors) do
                daemonColors(colors.red, errorMsg)
            end

            sleep(sleepTimer)
        end
    end
end

local success, err = pcall(headTarget)
if not success then
    daemonColors(colors.red, "assblasted: " .. tostring(err))
end
