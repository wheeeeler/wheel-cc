local correctPassword = "asda"

local function flashRed()
    term.setBackgroundColor(colors.red)
    term.clear()
    term.setTextColor(colors.white)
    local width, height = term.getSize()
    for y = 1, height do
        for x = 1, width, 4 do
            term.setCursorPos(x, y)
            term.setTextColor(colors.black)
            term.write("kys")
        end
    end
    sleep(0.1)
    term.setBackgroundColor(colors.black)
    term.clear()
end

local function promptPassword()
    term.clear()
    local inputPassword = ""
    local downKeyHeld = false

    while true do
        local event, param1 = os.pullEventRaw()
        if event == "key" then
            flashRed()
            local key = keys.getName(param1)
            if key == "down" then
                downKeyHeld = true
            elseif key == "backspace" and downKeyHeld then
                
            elseif key:match("^[a-zA-Z0-9]$") and downKeyHeld then
                inputPassword = inputPassword .. key
            end
        elseif event == "key_up" then
            local key = keys.getName(param1)
            if key == "down" then
                downKeyHeld = false
                if inputPassword == correctPassword then
                    return inputPassword
                else
                    term.clear()
                    inputPassword = ""
                    os.shutdown()
                end
            end
        end
    end
end

local function runProgram()
    shell.run("")
end

local function main()
    while true do
        local inputPassword = promptPassword()
        if inputPassword == correctPassword then
            runProgram()
            break
        else
            os.shutdown()
        end
    end
end

main()