local detector = peripheral.find("playerDetector")
local envDetector = peripheral.find("environmentDetector")
local cb = peripheral.find("chatBox")

term.clear()
term.setCursorPos(20, 8)
term.setTextColor(colors.red)
term.write("(C) CrackInc")
term.setCursorPos(23, 10)
term.write(":--)")


local defaultConfig = {
  afk_timeout = 300,
  excluded_players = {},
  target_players = {},
  prefix = "&4&lAFK TRACKER",
  bracket = "[]",
  bracket_color = "&4&l"
}

local function loadConfig()
  if not fs.exists("cfg.txt") then
    local f = fs.open("cfg.txt", "w")
    f.write(textutils.serialize(defaultConfig))
    f.close()
    return defaultConfig
  else
    local f = fs.open("cfg.txt", "r")
    local contents = f.readAll()
    f.close()
    local loaded = textutils.unserialize(contents)
    if type(loaded) == "table" then
      return loaded
    else
      return defaultConfig
    end
  end
end

local config = loadConfig()
local AFK_TIMEOUT = config.afk_timeout or 300

local excludedPlayers = {}
for _, name in ipairs(config.excluded_players or {}) do
  excludedPlayers[name] = true
end

local targetPlayers = {}
for _, name in ipairs(config.target_players or {}) do
  targetPlayers[name] = true
end

local function canTrack(p)
  if excludedPlayers[p] then return false end
  if next(targetPlayers) == nil then return true end
  return targetPlayers[p]
end

local prefix = config.prefix or "&4&lAFK TRACKER"
local bracket = config.bracket or "[]"
local bracketColor = config.bracket_color or "&4&l"

local lastPositions = {}
local lastMoveTimes = {}
local isAFK = {}
local afkStartTimes = {}
local afkAnnouncements = {}

local function distance(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  local dz = a.z - b.z
  return math.sqrt(dx*dx + dy*dy + dz*dz)
end

while true do
  local players = detector.getOnlinePlayers()
  local successDim, currentDimension = pcall(function() return envDetector.getDimension() end)
  if not successDim or not currentDimension then
    sleep(1)
  else
    for _, player in ipairs(players) do
      if canTrack(player) then
        local successInfo, info = pcall(function() return detector.getPlayer(player) end)
        if successInfo and info and info.dimension == currentDimension then
          local successPos, pos = pcall(function() return detector.getPlayerPos(player) end)
          if successPos and pos then
            if not lastPositions[player] then
              lastPositions[player] = pos
              lastMoveTimes[player] = os.clock()
              isAFK[player] = false
              afkStartTimes[player] = nil
              afkAnnouncements[player] = 0
            else
              if distance(pos, lastPositions[player]) > 0.001 then
                lastPositions[player] = pos
                lastMoveTimes[player] = os.clock()
                isAFK[player] = false
                afkStartTimes[player] = nil
                afkAnnouncements[player] = 0
              else
                local idleTime = os.clock() - lastMoveTimes[player]
                if idleTime >= AFK_TIMEOUT and not isAFK[player] then
                  isAFK[player] = true
                  afkStartTimes[player] = os.clock()
                  afkAnnouncements[player] = 1
                  local afkSeconds = math.floor(idleTime)
                  local message = {
                    { text = "\n", color = "dark_red", bold = true },
                    { text = "\n", color = "dark_red", bold = true },
                    { text = player, color = "gold" },
                    { text = " has not moved for ", color = "white" },
                    { text = tostring(afkSeconds), color = "yellow" },
                    { text = " seconds!\n", color = "white" },
                    { text = "Dimension: ", color = "red" },
                    { text = pos.dimension, color = "light_purple" },
                    { text = "\nX: ", color = "dark_aqua" },
                    { text = tostring(pos.x), color = "green" },
                    { text = "  Y: ", color = "dark_aqua" },
                    { text = tostring(pos.y), color = "green" },
                    { text = "  Z: ", color = "dark_aqua" },
                    { text = tostring(pos.z), color = "green" },
                    { text = "\nEye Height: ", color = "dark_aqua" },
                    { text = string.format("%.2f", pos.eyeHeight), color = "green" },
                    { text = "  Yaw: ", color = "dark_aqua" },
                    { text = string.format("%.2f", pos.yaw), color = "green" },
                    { text = "  Pitch: ", color = "dark_aqua" },
                    { text = string.format("%.2f", pos.pitch), color = "green" },
                    { text = "\n", color = "dark_red", bold = true },
                    { text = "\n(C) Crack Inc", color = "dark_red", bold = true }
                  }
                  local json = textutils.serializeJSON(message)
                  cb.sendFormattedMessage(json, prefix, bracket, bracketColor)
                elseif isAFK[player] then
                  local totalAfkTime = math.floor(os.clock() - afkStartTimes[player])
                  local neededAnnouncements = math.floor(totalAfkTime / AFK_TIMEOUT)
                  if neededAnnouncements > afkAnnouncements[player] then
                    afkAnnouncements[player] = neededAnnouncements
                    local message = {
                      { text = "\n", color = "dark_red", bold = true },
                      { text = "\n", color = "dark_red", bold = true },
                      { text = player, color = "gold" },
                      { text = " is still AFK - total of ", color = "white" },
                      { text = tostring(totalAfkTime), color = "yellow" },
                      { text = " seconds!\n", color = "white" },
                      { text = "Dimension: ", color = "dark_aqua" },
                      { text = pos.dimension, color = "light_purple" },
                      { text = "\nX: ", color = "dark_aqua" },
                      { text = tostring(pos.x), color = "green" },
                      { text = "  Y: ", color = "dark_aqua" },
                      { text = tostring(pos.y), color = "green" },
                      { text = "  Z: ", color = "dark_aqua" },
                      { text = tostring(pos.z), color = "green" },
                      { text = "\nEye Height: ", color = "dark_aqua" },
                      { text = string.format("%.2f", pos.eyeHeight), color = "green" },
                      { text = "  Yaw: ", color = "dark_aqua" },
                      { text = string.format("%.2f", pos.yaw), color = "green" },
                      { text = "  Pitch: ", color = "dark_aqua" },
                      { text = string.format("%.2f", pos.pitch), color = "green" },
                      { text = "\n", color = "dark_red", bold = true },
                      { text = "\n(C) Crack Inc", color = "dark_red", bold = true }
                    }
                    local json = textutils.serializeJSON(message)
                    cb.sendFormattedMessage(json, prefix, bracket, bracketColor)
                  end
                end
              end
            end
          else
            lastPositions[player] = nil
            lastMoveTimes[player] = nil
            isAFK[player] = nil
            afkStartTimes[player] = nil
            afkAnnouncements[player] = nil
          end
        else
          lastPositions[player] = nil
          lastMoveTimes[player] = nil
          isAFK[player] = nil
          afkStartTimes[player] = nil
          afkAnnouncements[player] = nil
        end
      end
    end
    sleep(1)
  end
end
