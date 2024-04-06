function widget:GetInfo()
  return {
    name      = "Battle Resource Tracker",
    desc      = "Shows the resource gains/losses in battles",
    author    = "citrine",
    date      = "2023",
    license   = "GNU GPL, v2 or later",
    version   = 3,
    layer     = -100,
    enabled   = true
  }
end

-- user configuration
-- =============

-- the maximum distance at which battles can be combined
local searchRadius = 600

-- how long battles stay after they haven't changed (in frames; frames=30*seconds)
local eventTimeout = 30 * 15

-- font size for battle text
local fontSize = 80

-- RGB text color that indicates a positive resource delta (your opponents lost resources)
local positiveTextColor = {0.2, 1, 0.2}

-- RGB text color that indicates a negative resource delta (your allyteam lost resources)
local negativeTextColor = {1, 0.2, 0.2}

-- maximum alpha value for resource delta text (0-1, 1=opaque, 0=transparent)
local maxTextAlpha = 0.8

-- distance to swap between drawing text under units, and above units/icons
local cameraThreshold = 3500

-- advanced configuration
-- ======================

-- the size of the cells that the map is divided into (for performance optimization)
local spatialHashCellSize = 500

-- how often to check and remove old events (for performance optimization)
local eventTimeoutCheckPeriod = 30 * 1

-- how distance affects font size when drawing using DrawScreenEffects
local distanceScaleFactor = 1800

-- how far to offset the black outline text effect
local outlineOffset = 3

-- how much to increase the size of the text as you zoom out
local farCameraTextBoost = 0.8

-- what drawing mode to use depending on camera distance
-- "PreDecals" or "WorldPreUnit" or "World" or "ScreenEffects" or nil
local nearCameraMode = "PreDecals"
local farCameraMode = "ScreenEffects"

-- engine call optimizations
-- =========================

local SpringGetCameraState = Spring.GetCameraState
local SpringGetGameFrame = Spring.GetGameFrame
local SpringGetGroundHeight = Spring.GetGroundHeight
local SpringGetMyTeamID = Spring.GetMyTeamID
local SpringGetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local SpringGetUnitHealth = Spring.GetUnitHealth
local SpringGetUnitPosition = Spring.GetUnitPosition
local SpringIsGUIHidden = Spring.IsGUIHidden
local SpringWorldToScreenCoords = Spring.WorldToScreenCoords
local SpringIsSphereInView = Spring.IsSphereInView
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glColor = gl.Color
local glText = gl.Text

-- spatial hash implementation
-- ===========================

local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash.new(cellSize)
  local self = setmetatable({}, SpatialHash)
  self.cellSize = cellSize
  self.cells = {}
  return self
end

function SpatialHash:hashKey(x, z)
  return string.format("%d,%d", math.floor(x / self.cellSize), math.floor(z / self.cellSize))
end

function SpatialHash:addEvent(event)
  local key = self:hashKey(event.x, event.z)
  local cell = self.cells[key]
  if not cell then
    cell = {}
    self.cells[key] = cell
  end
  table.insert(cell, event)
end

function SpatialHash:removeEvent(event)
  local key = self:hashKey(event.x, event.z)
  local cell = self.cells[key]
  if cell then
    for i, storedEvent in ipairs(cell) do
      if storedEvent == event then
        table.remove(cell, i)
        break
      end
    end
  end
end

function SpatialHash:allEvents(filterFunc)
  local events = {}
  for _, cell in pairs(self.cells) do
    for _, event in ipairs(cell) do
      if not filterFunc or filterFunc(event) then
        table.insert(events, event)
      end
    end
  end
  return events
end

function SpatialHash:getNearbyEvents(x, z, radius)
  local nearbyEvents = {}
  local startX = math.floor((x - radius) / self.cellSize)
  local startZ = math.floor((z - radius) / self.cellSize)
  local endX = math.floor((x + radius) / self.cellSize)
  local endZ = math.floor((z + radius) / self.cellSize)

  for i = startX, endX do
    for j = startZ, endZ do
      local key = self:hashKey(i * self.cellSize, j * self.cellSize)
      local cell = self.cells[key]
      if cell then
        for _, event in ipairs(cell) do
          local distance = math.sqrt((event.x - x)^2 + (event.z - z)^2)
          if distance <= radius then
            table.insert(nearbyEvents, event)
          end
        end
      end
    end
  end

  return nearbyEvents
end

-- widget code
-- ===========

local spatialHash = SpatialHash.new(spatialHashCellSize)
local drawLocation = nil

function combineEvents(events)
  -- Calculate the average position (weighted by number of events)
  local totalSubEvents = 0
  local averageX, averageZ = 0, 0
  for _, event in ipairs(events) do
    averageX = averageX + (event.x * event.n)
    averageZ = averageZ + (event.z * event.n)
    totalSubEvents = totalSubEvents + event.n
  end
  averageX = averageX / totalSubEvents
  averageZ = averageZ / totalSubEvents
  
  -- Sum team metal values
  local totalMetal = {}
  for _, event in ipairs(events) do
    for key, value in pairs(event.metal) do
      if totalMetal[key] then
        totalMetal[key] = totalMetal[key] + value
      else
        totalMetal[key] = value
      end
    end
  end
  
  -- Calculate max game time (most recent event)
  local maxT = 0
  for _, event in ipairs(events) do
    maxT = math.max(event.t, maxT)
  end
  
  -- Create the combined event
  local combinedEvent = {
    x = averageX,
    z = averageZ,
    metal = totalMetal,
    t = maxT,
    n = totalSubEvents
  }

  return combinedEvent
end

function scaleText(size, distance)
  return size * distanceScaleFactor / distance
end

local function DrawBattleText()
  local cameraState = SpringGetCameraState()
  local events = spatialHash:allEvents()
  local currentFrame = SpringGetGameFrame()

  local myTeamID = SpringGetMyTeamID()
  local myAllyTeamID = SpringGetTeamAllyTeamID(myTeamID)

  local drawLocation = getDrawLocation()

  local currentFontSize = fontSize
  local currentOutlineOffset = outlineOffset

  if drawLocation == "ScreenEffects" then
    local cameraDistance = getCameraDistance()
    local boostSize = math.max(0, cameraDistance - cameraThreshold) * farCameraTextBoost
    currentFontSize = scaleText(currentFontSize, cameraDistance - boostSize)
    currentOutlineOffset = scaleText(currentOutlineOffset, cameraDistance - boostSize*1.1)
  end

  for _, event in ipairs(events) do
    local ex, ey, ez = event.x, SpringGetGroundHeight(event.x, event.z), event.z
    if Spring.IsSphereInView(ex, ey, ez, 300) then
      -- generate text for the event
      local eventAge = (currentFrame - event.t) / eventTimeout -- fraction of total lifetime left
      local alpha = maxTextAlpha * (1 - math.min(1, eventAge * eventAge * eventAge * eventAge)) -- fade faster as it gets older
      local metalDelta = 0
      for key, value in pairs(event.metal) do
        -- show my allyteam metal lost as negative and any other allyteam as positive
        if key == myAllyTeamID then
          metalDelta = metalDelta - value
        else
          metalDelta = metalDelta + value
        end
      end
      local sign = "+"
      local textColor = positiveTextColor
      if metalDelta < 0 then
        sign = ""
        textColor = negativeTextColor
      end

      local text = sign .. tostring(metalDelta) .. "m"

      -- draw the text
      glPushMatrix()

      if drawLocation == "ScreenEffects" then
        glTranslate(SpringWorldToScreenCoords(ex, ey, ez))
      else
        glTranslate(ex, ey, ez)

        glRotate(-90, 1, 0, 0)
        if cameraState.flipped == 1 then
          glRotate(180, 0, 0, 1)
        end
      end

      -- draw text outline
      glColor(0, 0, 0, math.max(0, alpha * 0.7))
      glText(text, -currentOutlineOffset, -currentOutlineOffset, currentFontSize, "cd")
      glText(text, -currentOutlineOffset, currentOutlineOffset, currentFontSize, "cd")
      glText(text, currentOutlineOffset, -currentOutlineOffset, currentFontSize, "cd")
      glText(text, currentOutlineOffset, currentOutlineOffset, currentFontSize, "cd")

       -- draw actual text
      glColor(textColor[1], textColor[2], textColor[3], alpha)
      glText(text, 0, 0, currentFontSize, "cd")

      glPopMatrix()
    end
  end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
  local _, _, _, _, buildProgress = SpringGetUnitHealth(unitID)
  local allyTeamID = SpringGetTeamAllyTeamID(unitTeam)
  local x, y, z = SpringGetUnitPosition(unitID)
  local gameTime = SpringGetGameFrame()
  local metal = math.floor(UnitDefs[unitDefID].metalCost * buildProgress)

  if metal < 1 then
    return
  end

  local event = {
    x = x, -- x coordinate of the event
    z = z, -- y coordinate of the event
    t = gameTime, -- game time (in frames) when the event happened
    metal = { -- the metal lost in the event, by allyteam that lost the metal
      [allyTeamID] = metal
    },
    n = 1 -- how many events have been combined into this one
  }
  
  -- combine with nearby events if necessary
  local nearbyEvents = spatialHash:getNearbyEvents(x, z, searchRadius)
  local combinedEvent = event
  if #nearbyEvents > 0 then
    table.insert(nearbyEvents, event)
    combinedEvent = combineEvents(nearbyEvents)
    
    for _, nearbyEvent in ipairs(nearbyEvents) do
      spatialHash:removeEvent(nearbyEvent)
    end
  end
  
  spatialHash:addEvent(combinedEvent)
end

function widget:GameFrame(frame)
  if frame % eventTimeoutCheckPeriod == 0 then
    local oldEvents = spatialHash:allEvents(
      function(event)
        return event.t < frame - eventTimeout
      end
    )
    
    for _, event in ipairs(oldEvents) do
      spatialHash:removeEvent(event)
    end
  end
end

function getCameraDistance()
  local cameraState = SpringGetCameraState()
  return cameraState.height or cameraState.dist or (cameraThreshold - 1)
end

function getDrawLocation()
  if SpringIsGUIHidden() then
    return nil
  end

  local dist = getCameraDistance()
  if dist < cameraThreshold then
    return nearCameraMode
  else
    return farCameraMode
  end
end

function widget:Update(dt)
  drawLocation = getDrawLocation()
end

function widget:DrawPreDecals()
  if drawLocation == "PreDecals" then
    DrawBattleText()
  end
end

function widget:DrawWorldPreUnit()
  if drawLocation == "WorldPreUnit" then
    DrawBattleText()
  end
end

function widget:DrawWorld()
  if drawLocation == "World" then
    DrawBattleText()
  end
end

function widget:DrawScreenEffects()
  if drawLocation == "ScreenEffects" then
    DrawBattleText()
  end
end
