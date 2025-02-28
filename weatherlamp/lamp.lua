local LampC = {}

LampC.lamps = {}
LampC.updateT = 120
LampC.api = "api"

LampC.getLamps = function()
    local p = peripheral.getNames()
    for _, name in ipairs(p) do
        if string.find(name, "colorful_lamp") then
            table.insert(LampC.lamps, name)
        end
    end
    if #LampC.lamps == 0 then
        error("no lamp")
    end
end

LampC.getTemp = function()
    local r = http.get(LampC.api)
    if r then
        local data = textutils.unserializeJSON(r.readAll())
        r.close()
        if data and data.main and data.main.temp then
            return tonumber(data.main.temp)
        end
    end
    print("api ded")
    return nil
end

LampC.tempToColor = function(temp)
    local tC = {
        {-40, 0, 0, 139},
        {-30, 0, 0, 200},
        {-20, 0, 0, 255},
        {-10, 0, 128, 255},
        {-5,  0, 200, 255},
        {0,   0, 255, 200},
        {5,   0, 255, 128},
        {10,  0, 255, 0},
        {12,  128, 255, 0},
        {15,  200, 255, 0},
        {20,  255, 255, 0},
        {25,  255, 175, 0},
        {30,  255, 100, 0},
        {35,  255, 50, 0},
        {40,  255, 0, 0}
    }

    local r, g, b = 0, 0, 0
    for i = 1, #tC - 1 do
        local t1, r1, g1, b1 = table.unpack(tC[i])
        local t2, r2, g2, b2 = table.unpack(tC[i + 1])
        if temp >= t1 and temp <= t2 then
            local rt = (temp - t1) / (t2 - t1)
            r = math.floor(r1 + (r2 - r1) * rt)
            g = math.floor(g1 + (g2 - g1) * rt)
            b = math.floor(b1 + (b2 - b1) * rt)
            break
        end
    end

    local cR = math.floor(r / 255 * (2^5 - 1)) * (2^10)
    local cG = math.floor(g / 255 * (2^5 - 1)) * (2^5)
    local cB = math.floor(b / 255 * (2^5 - 1))
    return cR + cG + cB
end


LampC.setColor = function(c)
    for _, lamp in ipairs(LampC.lamps) do
        peripheral.call(lamp, "setLampColor", c)
    end
end

LampC.run = function()
    LampC.getLamps()
    while true do
        local temp = LampC.getTemp()
        if temp then
            local c = LampC.tempToColor(temp)
            LampC.setColor(c)
            print(string.format("Temp: %.1fC, Color: %d", temp, c))
        end
        sleep(LampC.updateT)
    end
end

LampC.run()
