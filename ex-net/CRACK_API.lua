local gui = {}

local isDetailedViewOpen = false

local fixedColors = {
    background = colors.black,
    text = colors.lightGray,
    buttonBackground = colors.gray,
    buttonText = colors.white,
    errorText = colors.red,
    successText = colors.green,
    highlightBackground = colors.lightBlue,
    highlightText = colors.white,
    disabledButtonBackground = colors.lightGray,
    disabledButtonText = colors.gray,
    headerBackground = colors.blue,
    headerText = colors.white,
    warningText = colors.orange,
    backButtonText = colors.white,
    neonPurple = colors.purple
}

local colorConfig = {
    [colors.black] = { 0, 0, 0 },
    [colors.gray] = { 43 / 255, 43 / 255, 43 / 255 },
    [colors.lightGray] = { 0.85, 0.85, 0.85 },
    [colors.white] = { 0.9, 0.9, 0.9 },
    [colors.red] = { 0.6, 0, 0 },
    [colors.green] = { 0.2, 0.5, 0.2 },
    [colors.lightBlue] = { 0.5, 0.75, 1 },
    [colors.orange] = { 1, 0.65, 0 },
    [colors.blue] = { 0, 0, 1 },
    [colors.purple] = { 0.75, 0, 1 }
}

function gui.initPalette()
    for color, rgb in pairs(colorConfig) do
        term.setPaletteColour(color, table.unpack(rgb))
    end
end

function gui.initTerminal()
    gui.initPalette()
    term.setBackgroundColor(fixedColors.background)
    term.setTextColor(fixedColors.text)
    term.clear()
end

function gui.centerText(text, y)
    local w = term.getSize()
    local x = math.floor((w - #text) / 2) + 1
    if y then
        term.setCursorPos(x, y)
    else
        term.setCursorPos(x, select(2, term.getCursorPos()))
    end
    term.write(text)
end

function gui.drawButton(x, y, width, height, text, bgColor, textColor)
    bgColor = bgColor or fixedColors.buttonBackground
    textColor = textColor or fixedColors.buttonText
    term.setBackgroundColor(bgColor)
    term.setTextColor(textColor)
    for i = y, y + height - 1 do
        term.setCursorPos(x, i)
        term.write(string.rep(" ", width))
    end
    term.setCursorPos(x + math.floor((width - #text) / 2), y + math.floor(height / 2))
    term.write(text)
    term.setBackgroundColor(fixedColors.background)
    term.setTextColor(fixedColors.text)
end

function gui.isInsideBorder(x, y, bx, by, bwidth, bheight)
    return x >= bx and x <= bx + bwidth - 1 and y >= by and y <= by + bheight - 1
end

function gui.bootSplash(exnetVersion, message, delay)
    gui.initTerminal()
    term.setTextColor(fixedColors.errorText)
    local w, h = term.getSize()
    local y_center = math.floor(h / 2)
    gui.centerText("(C) CrackInc", y_center - 4)
    gui.centerText("EX-net v" .. exnetVersion, y_center - 1)
    local runningText = message or "LOADING CRACKHOOK"
    gui.centerText(runningText, y_center + 1)
    for i = 1, 10 do
        term.setCursorPos(math.floor((w - #runningText) / 2) + #runningText + 1, y_center + 1)
        term.write(string.rep(".", i))
        sleep(delay or 0.1)
    end
    term.setTextColor(fixedColors.text)
end

function gui.groupPeripherals(peripherals)
    local grouped = {}
    for _, name in ipairs(peripherals) do
        local typeName = peripheral.getType(name) or "unknown"
        grouped[typeName] = grouped[typeName] or {}
        table.insert(grouped[typeName], name)
    end
    local sortedTypes = {}
    for typeName in pairs(grouped) do
        table.insert(sortedTypes, typeName)
    end
    table.sort(sortedTypes)
    return grouped, sortedTypes
end

function gui.createMainMenu(config, actions)
    local w, h = term.getSize()
    local buttonWidth = math.floor(w / 2)
    local buttonHeight = 1
    local startY = 5
    local startX = math.floor((w - buttonWidth) / 2)

    local options = {
        { text = "Network overview", action = actions.displayConfig },
        { text = "Task builder", action = actions.addTransferTask },
        { text = "Settings", action = actions.configurationMenu },
        {
            text = config.transferEnabled and "[ONLINE]" or "[OFFLINE]",
            bgColor = config.transferEnabled and fixedColors.successText or fixedColors.errorText,
            textColor = fixedColors.text,
            action = function()
                config.transferEnabled = not config.transferEnabled
                actions.writeConfig()
            end
        },
        { text = "Shutdown", action = function()
            term.clear()
            term.setTextColor(fixedColors.errorText)
            print("au revoir")
            sleep(0.5)
            os.shutdown()
        end }
    }

    local buttons = {}
    for i, option in ipairs(options) do
        local y = startY + (i - 1) * (buttonHeight + 1)
        gui.drawButton(startX, y, buttonWidth, buttonHeight, option.text, option.bgColor, option.textColor)
        table.insert(buttons, { x = startX, y = y, width = buttonWidth, height = buttonHeight, action = option.action })
    end
    return buttons
end

function gui.handleMenuClick(buttons)
    local event, _, x, y = os.pullEvent("mouse_click")
    for _, button in ipairs(buttons) do
        if gui.isInsideBorder(x, y, button.x, button.y, button.width, button.height) then
            button.action()
            break
        end
    end
end

function gui.selPeripherals(title, excludedPeripherals)
    excludedPeripherals = excludedPeripherals or {}
    while true do
        term.clear()
        local peripherals = peripheral.getNames()
        peripherals = gui.filterExcludedPeripherals(peripherals, excludedPeripherals)
        if #peripherals == 0 then
            term.setTextColor(fixedColors.errorText)
            term.clear()
            term.setCursorPos(1, 8)
            gui.centerText("Err: No peripheral")
            term.setTextColor(fixedColors.text)
            sleep(2)
            return nil
        else
            local grouped, sortedTypes = gui.groupPeripherals(peripherals)
            local w, h = term.getSize()
            local buttonHeight = 1
            local longestNameLength = 0

            for _, typeName in ipairs(sortedTypes) do
                local displayName = typeName:match(":(.+)$") or typeName
                longestNameLength = math.max(longestNameLength, #displayName - 5 )
            end

            local buttonWidth = math.max(longestNameLength, math.floor(w / 2))
            local visibleCount = math.floor((h - 8) / (buttonHeight + 1))
            local offset = 0
            local startX = math.floor((w - buttonWidth) / 2)

            local selectedPeripherals = {}
            local selectedGroups = {}

            local function drawGroups(startIndex)
                term.clear()
                gui.centerText(title, 2)
                local startY = 4
                local buttons = {}
                for i = startIndex, math.min(startIndex + visibleCount - 1, #sortedTypes) do
                    local typeName = sortedTypes[i]
                    local displayName = typeName:match(":(.+)$") or typeName
                    local y = startY + (i - startIndex) * (buttonHeight + 1)
                    local groupText = displayName .. " (" .. #grouped[typeName] .. ")"
                    local bgColor = selectedGroups[typeName] and fixedColors.successText or fixedColors.buttonBackground
                    gui.drawButton(startX, y, buttonWidth, buttonHeight, groupText, bgColor, fixedColors.text)
                    table.insert(buttons, { x = startX, y = y, width = buttonWidth, height = buttonHeight, typeName = typeName })
                end
                gui.drawButton(startX, h - 4, buttonWidth, buttonHeight, "Proceed", colors.green, fixedColors.text)
                gui.drawButton(startX, h - 2, buttonWidth, buttonHeight, "Return", fixedColors.errorText, fixedColors.text)
                return buttons
            end

            local buttons = drawGroups(1)
            while true do
                local event, key, x, y = os.pullEvent()
                if event == "key" then
                    if key == keys.up and offset > 0 then
                        offset = offset - 1
                        buttons = drawGroups(offset + 1)
                    elseif key == keys.down and offset + visibleCount < #sortedTypes then
                        offset = offset + 1
                        buttons = drawGroups(offset + 1)
                    end
                elseif event == "mouse_click" then
                    local clicked = false
                    for _, button in ipairs(buttons) do
                        if gui.isInsideBorder(x, y, button.x, button.y, button.width, button.height) then
                            clicked = true
                            local typeName = button.typeName
                            if not selectedGroups[typeName] then
                                local groupPeripherals = grouped[typeName]
                                local groupSelected = gui.selPeripheralGroups(typeName, groupPeripherals, excludedPeripherals)
                                if groupSelected and #groupSelected > 0 then
                                    selectedGroups[typeName] = true
                                    for _, name in ipairs(groupSelected) do
                                        table.insert(selectedPeripherals, name)
                                    end
                                else
                                    selectedGroups[typeName] = nil
                                end
                            else
                                selectedGroups[typeName] = nil
                            end
                            buttons = drawGroups(offset + 1)
                            break
                        end
                    end
                    if not clicked then
                        if gui.isInsideBorder(x, y, startX, h - 4, buttonWidth, buttonHeight) then
                            return selectedPeripherals
                        elseif gui.isInsideBorder(x, y, startX, h - 2, buttonWidth, buttonHeight) then
                            return nil
                        end
                    end
                elseif event == "mouse_scroll" then
                    if key == -1 and offset > 0 then
                        offset = offset - 1
                        buttons = drawGroups(offset + 1)
                    elseif key == 1 and offset + visibleCount < #sortedTypes then
                        offset = offset + 1
                        buttons = drawGroups(offset + 1)
                    end
                end
            end
        end
    end
end

function gui.selPeripheralGroups(typeName, peripherals, excludedPeripherals)
    local w, h = term.getSize()
    local buttonPadding = 2
    local buttonHeight = 1

    local selectedIndices = {}

    table.sort(peripherals, function(b, a)
        local nameA = a:match(":(.+)$") or a
        local nameB = b:match(":(.+)$") or b
        local numberA = tonumber(nameA:match("_(%d+)$")) or 0
        local numberB = tonumber(nameB:match("_(%d+)$")) or 0

        if numberA ~= numberB then
            return numberA > numberB
        else
            return nameA < nameB
        end
    end)

    local maxDisplayLength = 0
    for _, name in ipairs(peripherals) do
        local displayName = name:match(":(.+)$") or name
        maxDisplayLength = math.max(maxDisplayLength, #displayName)
    end

    local buttonWidth = maxDisplayLength + 2 * buttonPadding

    local function calculateColumns()
        local maxColumns = math.floor(w / (buttonWidth + 2))
        return math.max(1, maxColumns)
    end

    local function drawPeripherals(startIndex)
        local columns = calculateColumns()
        local visibleRows = math.floor((h - 8) / (buttonHeight + 1))
        local visibleCount = visibleRows * columns

        term.clear()
        term.setTextColor(colors.yellow)
        gui.centerText(typeName, 2)
        local startY = 4

        local columnPositions = {}
        local totalWidth = columns * (buttonWidth + 2) - 2
        local startX = math.floor((w - totalWidth) / 2)
        for i = 1, columns do
            local xPos = startX + (i - 1) * (buttonWidth + 2)
            table.insert(columnPositions, xPos)
        end

        local buttons = {}
        for i = startIndex, math.min(startIndex + visibleCount - 1, #peripherals) do
            local name = peripherals[i]
            if not excludedPeripherals[name] then
                local displayName = name:match(":(.+)$") or name
                local paddedDisplayName = string.rep(" ", buttonPadding) .. displayName .. string.rep(" ", buttonPadding)
                local columnIndex = (i - startIndex) % columns + 1
                local rowIndex = math.floor((i - startIndex) / columns)
                local x = columnPositions[columnIndex]
                local y = startY + rowIndex * (buttonHeight + 1)
                local bgColor = selectedIndices[i] and fixedColors.successText or fixedColors.buttonBackground

                gui.drawButton(x, y, buttonWidth, buttonHeight, paddedDisplayName, bgColor)
                table.insert(buttons, { x = x, y = y, width = buttonWidth, height = buttonHeight, index = i, name = name })
            end
        end

        local actionButtonWidth = 10
        local padding = 1

        local selectAllX = math.floor((w - actionButtonWidth) / 2)
        local proceedX = selectAllX - actionButtonWidth - padding
        local returnX = selectAllX + actionButtonWidth + padding

        gui.drawButton(proceedX, h - 1, actionButtonWidth, buttonHeight, "Proceed", fixedColors.successText, fixedColors.text)
        gui.drawButton(selectAllX, h - 1, actionButtonWidth, buttonHeight, "Select all", colors.backButtonText)
        gui.drawButton(returnX, h - 1, actionButtonWidth, buttonHeight, "Return", fixedColors.errorText)

        return buttons, { proceedX = proceedX, selectAllX = selectAllX, returnX = returnX, visibleCount = visibleCount, columns = columns, actionButtonWidth = actionButtonWidth }
    end

    local offset = 0
    local buttons, buttonPositions = drawPeripherals(1)
    while true do
        local event, key, x, y = os.pullEvent()
        if event == "key" then
            if key == keys.up and offset > buttonPositions.columns then
                offset = offset - buttonPositions.columns
                buttons, buttonPositions = drawPeripherals(offset + 1)
            elseif key == keys.down and offset + buttonPositions.visibleCount < #peripherals then
                offset = offset + buttonPositions.columns
                buttons, buttonPositions = drawPeripherals(offset + 1)
            end
        elseif event == "mouse_click" then
            local clicked = false
            for _, button in ipairs(buttons) do
                if gui.isInsideBorder(x, y, button.x, button.y, button.width, button.height) then
                    clicked = true
                    selectedIndices[button.index] = not selectedIndices[button.index]
                    buttons, buttonPositions = drawPeripherals(offset + 1)
                    break
                end
            end

            if not clicked then
                if gui.isInsideBorder(x, y, buttonPositions.proceedX, h - 1, buttonPositions.actionButtonWidth, buttonHeight) then
                    local selected = {}
                    for i, isSelected in pairs(selectedIndices) do
                        if isSelected then
                            table.insert(selected, peripherals[i])
                        end
                    end
                    if #selected == 0 then
                        term.setTextColor(fixedColors.errorText)
                        term.setCursorPos(1, 8)
                        gui.centerText("Err: No peripheral selected")
                        sleep(2)
                    else
                        return selected
                    end
                elseif gui.isInsideBorder(x, y, buttonPositions.selectAllX, h - 1, buttonPositions.actionButtonWidth, buttonHeight) then
                    for i = 1, #peripherals do
                        selectedIndices[i] = true
                    end
                    buttons, buttonPositions = drawPeripherals(offset + 1)
                elseif gui.isInsideBorder(x, y, buttonPositions.returnX, h - 1, buttonPositions.actionButtonWidth, buttonHeight) then
                    return nil
                end
            end
        elseif event == "mouse_scroll" then
            if key == -1 and offset > buttonPositions.columns then
                offset = offset - buttonPositions.columns
                buttons, buttonPositions = drawPeripherals(offset + 1)
            elseif key == 1 and offset + buttonPositions.visibleCount < #peripherals then
                offset = offset + buttonPositions.columns
                buttons, buttonPositions = drawPeripherals(offset + 1)
            end
        end
    end
end


function gui.filterExcludedPeripherals(peripherals, excludedPeripherals)
    local filtered = {}
    for _, peripheralName in ipairs(peripherals) do
        if not excludedPeripherals[peripheralName] then
            table.insert(filtered, peripheralName)
        end
    end
    return filtered
end


function gui.selDestinations()
    term.setTextColor(colors.yellow)
    return gui.selPeripherals("Set destination peripheral (TO)")
end

function gui.selDestinations()
    term.setTextColor(colors.yellow)
    local destinations = gui.selPeripherals("Set destination peripheral (TO)")
    if destinations then
        local excluded = {}
        for _, name in ipairs(destinations) do
            excluded[name] = true
        end
        return destinations, excluded
    end
    return nil, {}
end

function gui.selectSources(excludedPeripherals)
    term.setTextColor(colors.yellow)
    return gui.selPeripherals("Set source peripheral (FROM)", excludedPeripherals)
end

function gui.selectSlotRange(peripheralName, modem)
    if not peripheralName then
        term.setTextColor(fixedColors.errorText)
        term.clear()
        term.setCursorPos(1, 8)
        gui.centerText("Err: No peripheral in list")
        term.setTextColor(fixedColors.text)
        sleep(2)
        return nil
    end
    local peripheralSize
    if peripheral.isPresent(peripheralName) then
        local success, size = pcall(peripheral.call, peripheralName, "size")
        if success and size then
            peripheralSize = size
        end
    elseif modem and modem.isPresentRemote(peripheralName) then
        local success, size = pcall(modem.callRemote, peripheralName, "size")
        if success and size then
            peripheralSize = size
        end
    end
    if not peripheralSize then
        term.setTextColor(fixedColors.errorText)
        term.clear()
        term.setCursorPos(1, 8)
        gui.centerText("No size available for " .. peripheralName)
        term.setTextColor(fixedColors.text)
        sleep(2)
        return nil
    end
    while true do
        term.clear()
        term.setTextColor(colors.yellow)
        gui.centerText("Set slot index", 2)
        gui.centerText("Available slots: 1-" .. peripheralSize, 3)
        local w, h = term.getSize()
        local buttonWidth = math.floor(w / 2)
        local startX = math.floor((w - buttonWidth) / 2)
        gui.drawButton(startX, 5, buttonWidth, 1, "All Slots")
        gui.drawButton(startX, 7, buttonWidth, 1, "Specify Range")
        gui.drawButton(startX, h - 2, buttonWidth, 1, "Return", fixedColors.errorText, fixedColors.text)
        local buttons = {
            { x = startX, y = 5, width = buttonWidth, height = 1, option = "all" },
            { x = startX, y = 7, width = buttonWidth, height = 1, option = "range" },
            { x = startX, y = h - 2, width = buttonWidth, height = 1, option = "Return" }
        }
        local option
        while true do
            local event, _, x, y = os.pullEvent("mouse_click")
            for _, button in ipairs(buttons) do
                if gui.isInsideBorder(x, y, button.x, button.y, button.width, button.height) then
                    option = button.option
                    break
                end
            end
            if option then
                break
            end
        end
        if option == "all" then
            return "all"
        elseif option == "range" then
            term.clear()
            term.setTextColor(colors.pink)
            gui.centerText("Enter Slot Range (e.g., '1-" .. peripheralSize .. "'):", 3)
            term.setCursorPos(w / 2, 5)
            term.write("")
            local slotInput = read()
            local indexStart, indexEnd = slotInput:match("(%d+)%-(%d+)")
            indexStart, indexEnd = tonumber(indexStart), tonumber(indexEnd)
            if indexStart and indexEnd and indexStart >= 1 and indexEnd <= peripheralSize and indexStart <= indexEnd then
                return { indexStart, indexEnd }
            else
                term.setTextColor(fixedColors.errorText)
                term.clear()
                gui.centerText("retard", 8)
                term.setTextColor(fixedColors.text)
                sleep(2)
            end
        elseif option == "Return" then
            return nil
        end
    end
end

function gui.selTransferType()
    while true do
        term.clear()
        local w, h = term.getSize()
        local buttonWidth = math.floor(w / 2)
        local buttonHeight = 1
        local buttonSpacing = 1
        local startY = math.floor((h - (buttonHeight * 3 + buttonSpacing * 2)) / 2)
        local startX = math.floor((w - buttonWidth) / 2)
        
        term.setTextColor(colors.yellow)
        gui.centerText("Set transfer mode", startY - 2)
        
        gui.drawButton(startX, startY, buttonWidth, buttonHeight, "Items", fixedColors.buttonBackground, fixedColors.text)
        gui.drawButton(startX, startY + buttonHeight + buttonSpacing, buttonWidth, buttonHeight, "Fluids", fixedColors.buttonBackground, fixedColors.text)
        gui.drawButton(startX, startY + (buttonHeight + buttonSpacing) * 2, buttonWidth, buttonHeight, "Both", fixedColors.buttonBackground, fixedColors.text)
        gui.drawButton(startX, h - 2, buttonWidth, 1, "Return", fixedColors.errorText, fixedColors.text)

        local buttons = {
            { x = startX, y = startY, width = buttonWidth, height = buttonHeight, option = "items" },
            { x = startX, y = startY + buttonHeight + buttonSpacing, width = buttonWidth, height = buttonHeight, option = "fluids" },
            { x = startX, y = startY + (buttonHeight + buttonSpacing) * 2, width = buttonWidth, height = buttonHeight, option = "both" },
            { x = startX, y = h - 2, width = buttonWidth, height = 1, option = "Return" }
        }

        local transferType
        while true do
            local event, _, x, y = os.pullEvent("mouse_click")
            for _, button in ipairs(buttons) do
                if gui.isInsideBorder(x, y, button.x, button.y, button.width, button.height) then
                    if button.option == "Return" then
                        return nil
                    else
                        transferType = button.option
                    end
                    break
                end
            end
            if transferType then
                return transferType
            end
        end
    end
end


function gui.displayConfig(config)
    local currentTaskIndex = 1
    local totalTasks = #config.transfers
    local MAX_ITEMS_PER_BOX = 100

    local function wrapText(text, width)
        local lines = {}
        local length = #text
        local pos = 1
        while pos <= length do
            local line = text:sub(pos, pos + width - 1)
            table.insert(lines, line)
            pos = pos + width
        end
        return lines
    end

    local function groupPeripherals(peripherals)
        local groups = {}
        for _, name in ipairs(peripherals) do
            local strippedName = name:match(":(.+)$") or name
            local baseName, number = strippedName:match("^(.*)_(%d+)$")
            if baseName and number then
                number = tonumber(number)
                if not groups[baseName] then
                    groups[baseName] = { numbers = {}, fullNames = {}, originalNames = {} }
                end
                table.insert(groups[baseName].numbers, number)
                table.insert(groups[baseName].fullNames, strippedName)
                table.insert(groups[baseName].originalNames, name)
            else
                groups[strippedName] = groups[strippedName] or { numbers = {}, fullNames = {}, originalNames = {} }
                table.insert(groups[strippedName].fullNames, strippedName)
                table.insert(groups[strippedName].originalNames, name)
            end
        end
        return groups
    end

    local function getCompactDisplayText(baseName, group, width)
        if #group.fullNames > MAX_ITEMS_PER_BOX then
            return baseName .. "_[...]"
        else
            local displayText = baseName
            if #group.numbers > 0 then
                table.sort(group.numbers)
                local ranges = {}
                local startNum = group.numbers[1]
                local lastNum = group.numbers[1]
                for i = 2, #group.numbers do
                    if group.numbers[i] == lastNum + 1 then
                        lastNum = group.numbers[i]
                    else
                        table.insert(ranges, startNum == lastNum and tostring(startNum) or (startNum .. "-" .. lastNum))
                        startNum, lastNum = group.numbers[i], group.numbers[i]
                    end
                end
                table.insert(ranges, startNum == lastNum and tostring(startNum) or (startNum .. "-" .. lastNum))
                displayText = baseName .. "_" .. table.concat(ranges, ",")
            end
            return wrapText(displayText, width - 2)
        end
    end

    local function displayPeripheralList(peripherals, peripheralType, originalNames)
        local function refreshDisplay()
            term.clear()
            gui.initTerminal()
            local w, h = term.getSize()
            term.setCursorPos(1, 1)
            term.setTextColor(colors.yellow)
            gui.centerText("Node")
            term.setTextColor(fixedColors.text)
    
            local startY = 4
            for i, name in ipairs(peripherals) do
                if startY + i - 1 > h - 4 then
                    term.setCursorPos(2, h - 4)
                    term.setTextColor(fixedColors.errorText)
                    term.write("truncated")
                    term.setTextColor(fixedColors.text)
                    break
                end
                local yPos = startY + i - 1
                term.setCursorPos(2, yPos)
                term.setTextColor(colors.green)
                gui.centerText("[" .. name .. "]")
            end
    
            gui.drawButton(3, h - 2, w - 6, 1, "Return", fixedColors.errorText, fixedColors.text)
        end
    
        refreshDisplay()
    
        local clickableEntries = {}
        local w, h = term.getSize()
        local startY = 4
        for i, name in ipairs(peripherals) do
            if startY + i - 1 > h - 4 then break end
            local yPos = startY + i - 1
            table.insert(clickableEntries, {
                x1 = 2,
                y1 = yPos,
                x2 = w - 2,
                y2 = yPos,
                originalName = originalNames[i]
            })
        end
    
        while true do
            local event, param1, x, y = os.pullEvent()
            if event == "mouse_click" then
                if gui.isInsideBorder(x, y, 3, h - 2, w - 6, 1) then
                    return
                end
    
                for _, entry in ipairs(clickableEntries) do
                    if x >= entry.x1 and x <= entry.x2 and y == entry.y1 then
                        displayPeripheralDetails(entry.originalName)
                        refreshDisplay()
                        break
                    end
                end
            elseif event == "key" then
                if param1 == keys.backspace or param1 == keys.enter then
                    return
                end
            end
        end
    end

    while true do
        term.clear()
        gui.initTerminal()
        local w, h = term.getSize()
        local paddingLeft = 3
        local maxBoxWidth = math.floor(w / 4)
        local sourceX = paddingLeft
        local destX = w - paddingLeft - maxBoxWidth

        if totalTasks > 1 then
            if currentTaskIndex > 1 then
                gui.drawButton(w - 20, 2, 8, 1, "< Prev", fixedColors.buttonBackground, fixedColors.text)
            end
            if currentTaskIndex < totalTasks then
                gui.drawButton(w - 10, 2, 8, 1, "Next >", fixedColors.buttonBackground, fixedColors.text)
            end
        end

        term.setCursorPos(paddingLeft, 2)
        term.setTextColor(colors.yellow)
        term.write("Task: " .. currentTaskIndex .. "/" .. totalTasks)
        term.setTextColor(fixedColors.text)

        if totalTasks == 0 then
            term.setTextColor(fixedColors.errorText)
            gui.centerText("No active tasks", math.floor(h / 2))
            term.setTextColor(fixedColors.text)
        else
            local task = config.transfers[currentTaskIndex]
            local clickableBoxes = {}

            local sourceGroups = groupPeripherals(task.sources)
            local destinationGroups = groupPeripherals(task.destinations)

            local sourceY = math.floor(h / 2) - 4
            for baseName, group in pairs(sourceGroups) do
                local wrappedText = getCompactDisplayText(baseName, group, maxBoxWidth)
                local boxHeight = #wrappedText + 1
                local boxYEnd = sourceY + boxHeight - 1

                paintutils.drawFilledBox(sourceX, sourceY, sourceX + maxBoxWidth, boxYEnd, colors.green)
                term.setTextColor(colors.black)
                for i, line in ipairs(wrappedText) do
                    term.setCursorPos(sourceX + 1, sourceY + i - 1)
                    term.write(line)
                end

                table.insert(clickableBoxes, {
                    x1 = sourceX,
                    y1 = sourceY,
                    x2 = sourceX + maxBoxWidth,
                    y2 = boxYEnd,
                    peripherals = group.fullNames,
                    type = "source",
                    baseName = baseName,
                    originalNames = group.originalNames
                })

                sourceY = boxYEnd + 2
            end

            local destY = math.floor(h / 2) - 4
            for baseName, group in pairs(destinationGroups) do
                local wrappedText = getCompactDisplayText(baseName, group, maxBoxWidth)
                local boxHeight = #wrappedText + 1
                local boxYEnd = destY + boxHeight - 1

                paintutils.drawFilledBox(destX, destY, destX + maxBoxWidth, boxYEnd, colors.yellow)
                term.setTextColor(colors.black)
                for i, line in ipairs(wrappedText) do
                    term.setCursorPos(destX + 1, destY + i - 1)
                    term.write(line)
                end

                table.insert(clickableBoxes, {
                    x1 = destX,
                    y1 = destY,
                    x2 = destX + maxBoxWidth,
                    y2 = boxYEnd,
                    peripherals = group.fullNames,
                    type = "destination",
                    baseName = baseName,
                    originalNames = group.originalNames
                })

                destY = boxYEnd + 2
            end

            local middleY = math.floor(h / 2)

            for _, srcBox in ipairs(clickableBoxes) do
                if srcBox.type == "source" then
                    local sourceMidY = math.floor((srcBox.y1 + srcBox.y2) / 2)

                    for x = srcBox.x2 + 1, math.floor((srcBox.x2 + destX) / 2) do
                        term.setCursorPos(x, sourceMidY)
                        term.write("-")
                    end

                    term.setCursorPos(math.floor((srcBox.x2 + destX) / 2), sourceMidY)
                    term.write("|")
                    for y = math.min(sourceMidY, middleY), math.max(sourceMidY, middleY) do
                        term.setCursorPos(math.floor((srcBox.x2 + destX) / 2), y)
                        term.write("|")
                    end
                end
            end

            for _, destBox in ipairs(clickableBoxes) do
                if destBox.type == "destination" then
                    local destMidY = math.floor((destBox.y1 + destBox.y2) / 2)
                    for x = math.floor((sourceX + destX + maxBoxWidth) / 2) + 1, destBox.x1 - 1 do
                        term.setCursorPos(x, destMidY)
                        term.write("-")
                    end
                    term.setCursorPos(destBox.x1 - 1, destMidY)
                    term.write(">")
                end
            end

            gui.drawButton(math.floor((w - 10) / 2), h - 2, 10, 1, "Return", fixedColors.errorText, fixedColors.text)

            local event, param1, x, y = os.pullEvent()
            if event == "mouse_click" then
                if gui.isInsideBorder(x, y, math.floor((w - 10) / 2), h - 2, 10, 1) then
                    return
                end

                if totalTasks > 1 and currentTaskIndex > 1 and gui.isInsideBorder(x, y, w - 20, 2, 8, 1) then
                    currentTaskIndex = currentTaskIndex - 1
                end

                if totalTasks > 1 and currentTaskIndex < totalTasks and gui.isInsideBorder(x, y, w - 10, 2, 8, 1) then
                    currentTaskIndex = currentTaskIndex + 1
                end

                for _, box in ipairs(clickableBoxes) do
                    if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
                        displayPeripheralList(box.peripherals, box.type, box.originalNames)
                        break
                    end
                end
            end
        end
    end
end


function gui.addTransferTask(config, writeConfig, modem)
    while true do
        local task = {}
        local destinations, excludedPeripherals = gui.selDestinations()
        if not destinations then
            return
        end
        task.destinations = destinations

        local sources = gui.selectSources(excludedPeripherals)
        if not sources then
            return
        end
        task.sources = sources

        local firstSourcePeripheral = sources[1]
        local slotRange = gui.selectSlotRange(firstSourcePeripheral, modem)
        if not slotRange then
            return
        end
        task.slotRange = slotRange

        local transferType = gui.selTransferType()
        if not transferType then
            return
        end
        task.transferType = transferType

        table.insert(config.transfers, task)
        writeConfig()
        term.clear()
        local w, h = term.getSize()
        gui.centerText("Task saved", 5)
        gui.drawButton(math.floor((w - 4) / 2), h - 2, 4, 1, "Proceed", fixedColors.successText)
        while true do
            local event, btn, x, y = os.pullEvent("mouse_click")
            if gui.isInsideBorder(x, y, math.floor((w - 4) / 2), h - 2, 4, 1) then
                return
            end
        end
    end
end

function gui.updateSettingsMenu(config, writeConfig)
    local function adjustSetting(settingName, minValue, maxValue, step)
        local currentValue = config.settings[settingName]
        local w, h = term.getSize()
        local buttonWidth = 4
        local buttonHeight = 1

        local totalButtonsWidth = 8 * buttonWidth + 7
        local startX = math.floor((w - totalButtonsWidth) / 2)

        while true do
            term.clear()
            term.setTextColor(colors.yellow)
            gui.centerText("Set " .. settingName, 2)
            gui.centerText("Current: " .. currentValue, 4)

            gui.drawButton(startX, 8, buttonWidth, buttonHeight, "-10", fixedColors.errorText, fixedColors.text)
            gui.drawButton(startX + (buttonWidth + 1) * 1, 8, buttonWidth, buttonHeight, "-5", fixedColors.errorText, fixedColors.text)
            gui.drawButton(startX + (buttonWidth + 1) * 2, 8, buttonWidth, buttonHeight, "-1", fixedColors.errorText, fixedColors.text)
            gui.drawButton(startX + (buttonWidth + 1) * 3, 8, buttonWidth, buttonHeight, "-0.1", fixedColors.errorText, fixedColors.text)
            gui.drawButton(startX + (buttonWidth + 1) * 4, 8, buttonWidth, buttonHeight, "+0.1", fixedColors.successText, fixedColors.text)
            gui.drawButton(startX + (buttonWidth + 1) * 5, 8, buttonWidth, buttonHeight, "+1", fixedColors.successText, fixedColors.text)
            gui.drawButton(startX + (buttonWidth + 1) * 6, 8, buttonWidth, buttonHeight, "+5", fixedColors.successText, fixedColors.text)
            gui.drawButton(startX + (buttonWidth + 1) * 7, 8, buttonWidth, buttonHeight, "+10", fixedColors.successText, fixedColors.text)

            gui.drawButton(math.floor((w - 8) / 2), h - 2, 8, buttonHeight, "Proceed", fixedColors.successText, fixedColors.text)

            local event, button, x, y = os.pullEvent("mouse_click")

            if gui.isInsideBorder(x, y, startX, 8, buttonWidth, buttonHeight) then
                currentValue = math.max(minValue, currentValue - 10)
            elseif gui.isInsideBorder(x, y, startX + (buttonWidth + 1) * 1, 8, buttonWidth, buttonHeight) then
                currentValue = math.max(minValue, currentValue - 5)
            elseif gui.isInsideBorder(x, y, startX + (buttonWidth + 1) * 2, 8, buttonWidth, buttonHeight) then
                currentValue = math.max(minValue, currentValue - 1)
            elseif gui.isInsideBorder(x, y, startX + (buttonWidth + 1) * 3, 8, buttonWidth, buttonHeight) then
                currentValue = math.max(minValue, currentValue - 0.1)
            elseif gui.isInsideBorder(x, y, startX + (buttonWidth + 1) * 4, 8, buttonWidth, buttonHeight) then
                currentValue = math.min(maxValue, currentValue + 0.1)
            elseif gui.isInsideBorder(x, y, startX + (buttonWidth + 1) * 5, 8, buttonWidth, buttonHeight) then
                currentValue = math.min(maxValue, currentValue + 1)
            elseif gui.isInsideBorder(x, y, startX + (buttonWidth + 1) * 6, 8, buttonWidth, buttonHeight) then
                currentValue = math.min(maxValue, currentValue + 5)
            elseif gui.isInsideBorder(x, y, startX + (buttonWidth + 1) * 7, 8, buttonWidth, buttonHeight) then
                currentValue = math.min(maxValue, currentValue + 10)
            elseif gui.isInsideBorder(x, y, math.floor((w - 8) / 2), h - 2, 8, buttonHeight) then
                config.settings[settingName] = currentValue
                writeConfig()
                return currentValue
            end
        end
    end

    local function updatePeripheralThreads()
        while true do
            term.clear()
            gui.centerText("Thread options", 2)
            local w, h = term.getSize()
            local buttonWidth = math.floor(w / 2)
            local buttonHeight = 1
            local startX = math.floor((w - buttonWidth) / 2)

            local autoAllocationColor = config.settings.autoThreadAllocation and fixedColors.successText or fixedColors.buttonBackground

            gui.drawButton(startX, 5, buttonWidth, buttonHeight, "Auto allocation: " .. tostring(config.settings.autoThreadAllocation), autoAllocationColor, fixedColors.text)
            
            if not config.settings.autoThreadAllocation then
                gui.drawButton(startX, 7, buttonWidth, buttonHeight, "Peripheral Threads: " .. config.settings.peripheralThreads, fixedColors.buttonBackground, fixedColors.text)
            end

            gui.drawButton(startX, h - 2, buttonWidth, buttonHeight, "Return", fixedColors.errorText, fixedColors.text)

            local event, btn, x, y = os.pullEvent("mouse_click")
            if gui.isInsideBorder(x, y, startX, h - 2, buttonWidth, buttonHeight) then
                return
            elseif gui.isInsideBorder(x, y, startX, 5, buttonWidth, buttonHeight) then
                config.settings.autoThreadAllocation = not config.settings.autoThreadAllocation
                writeConfig()
            elseif not config.settings.autoThreadAllocation and gui.isInsideBorder(x, y, startX, 7, buttonWidth, buttonHeight) then
                adjustSetting("peripheralThreads", 1, 100, 1)
            end
        end
    end

    while true do
        term.clear()
        gui.centerText("Update Settings", 2)
        local w, h = term.getSize()
        local buttonWidth = math.floor(w / 2)
        local buttonHeight = 1
        local startX = math.floor((w - buttonWidth) / 2)

        local dynamicYieldColor = config.settings.dynamicYield and fixedColors.successText or fixedColors.buttonBackground

        gui.drawButton(startX, 5, buttonWidth, buttonHeight, "Thread options", fixedColors.buttonBackground, fixedColors.text)
        gui.drawButton(startX, 7, buttonWidth, buttonHeight, "Sleep timer: " .. config.settings.sleepTimer, fixedColors.buttonBackground, fixedColors.text)
        gui.drawButton(startX, 9, buttonWidth, buttonHeight, "Dynamic yield: " .. tostring(config.settings.dynamicYield), dynamicYieldColor, fixedColors.text)
        gui.drawButton(startX, h - 2, buttonWidth, buttonHeight, "Return", fixedColors.errorText, fixedColors.text)

        local selectedOption = nil
        while true do
            local event, btn, x, y = os.pullEvent("mouse_click")
            if gui.isInsideBorder(x, y, startX, h - 2, buttonWidth, buttonHeight) then
                return
            elseif gui.isInsideBorder(x, y, startX, 5, buttonWidth, buttonHeight) then
                updatePeripheralThreads()
                break
            elseif gui.isInsideBorder(x, y, startX, 7, buttonWidth, buttonHeight) then
                selectedOption = "sleepTimer"
            elseif gui.isInsideBorder(x, y, startX, 9, buttonWidth, buttonHeight) then
                selectedOption = "dynamicYield"
            end

            if selectedOption == "dynamicYield" then
                config.settings.dynamicYield = not config.settings.dynamicYield
                writeConfig()
                break
            elseif selectedOption then
                adjustSetting(selectedOption, 0.1, 100, 0.1)
                break
            end
        end
    end
end

function gui.configurationMenu(config, writeConfig, modem)
    while true do
        term.clear()
        term.setTextColor(colors.yellow)
        gui.centerText("Settings", 2)
        local w, h = term.getSize()
        local buttonHeight = 1
        local options = { "Set global params", "Set task params", "Return" }
        local longestOptionLength = 0

        for _, option in ipairs(options) do
            if #option + 4 > longestOptionLength then
                longestOptionLength = #option + 4
            end
        end

        local buttonWidth = math.max(longestOptionLength, math.floor(w / 2))
        local startX = math.floor((w - buttonWidth) / 2)

        gui.drawButton(startX, 5, buttonWidth, buttonHeight, "Set global params", fixedColors.buttonBackground, fixedColors.text)
        gui.drawButton(startX, 7, buttonWidth, buttonHeight, "Set task params", fixedColors.buttonBackground, fixedColors.text)
        gui.drawButton(startX, h - 2, buttonWidth, buttonHeight, "Return", fixedColors.errorText, fixedColors.text)

        while true do
            local event, btn, x, y = os.pullEvent("mouse_click")
            if gui.isInsideBorder(x, y, startX, h - 2, buttonWidth, buttonHeight) then
                return
            elseif gui.isInsideBorder(x, y, startX, 5, buttonWidth, buttonHeight) then
                gui.updateSettingsMenu(config, writeConfig)
                break
            elseif gui.isInsideBorder(x, y, startX, 7, buttonWidth, buttonHeight) then
                gui.updateTransferTask(config, writeConfig, modem)
                break
            end
        end
    end
end


return gui
