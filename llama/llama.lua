local sensor = peripheral.wrap("back")
local lasers = {
    top = peripheral.wrap("back"),
    left = peripheral.wrap("back"),
    right = peripheral.wrap("back"),
    bottom = peripheral.wrap("back")
}
 
local function rf(filename)
    local file = fs.open(filename, "r")
    local content = {}
    if file then
        for line in file.readLine do
            table.insert(content, line)
        end
        file.close()
    end
    return content
end
 
local trustedP = rf("homies.txt")
local excl = rf("excl.txt")
 
local debug = false 
 
local offset = { X = 0, Y = 0, Z = 0 }
local rSquared = 32 * 32
 
local function dSquare(X,Y,Z)
    local xd = X - offset.X
    local yd = Y - offset.Y
    local zd = Z - offset.Z
    return xd*xd + yd*yd + zd*zd
end
 
local function tc(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then return true end
    end
    return false
end
 
local function sw(str, start)
    return str:sub(1, #start) == start
end
 
local function isExcl(entityName)
    for _, prefix in pairs(excl) do
        if sw(entityName, prefix) then return true end
    end
    return false
end
 
local function fire(entity)
    local x, y, z = entity.x, entity.y, entity.z
    local pitch = -math.atan2(y, math.sqrt(x * x + z * z))
    local yaw = math.atan2(-x, z)
    
    local fT = {}
    for _, laser in pairs(lasers) do
        table.insert(fT, function()
            laser.fire(math.deg(yaw), math.deg(pitch), 5)
        end)
    end
    parallel.waitForAll(table.unpack(fT))
end
 
 
while true do
    local e = sensor.sense()
    if e then  
        for _, entity in pairs(e) do
            if entity.name and not tc(trustedP, entity.name) and not isExcl(entity.name) then
                if entity.x and entity.y and entity.z and dSquare(entity.x, entity.y, entity.z) < rSquared then
                    fire(entity)
                    if debug then
                        local logfile = fs.open("log.txt", "a")
                        logfile.writeLine("Targeted: " .. entity.name)
                        logfile.close()
                    end
                end
            end
        end
    end
    os.sleep(0.01)
end