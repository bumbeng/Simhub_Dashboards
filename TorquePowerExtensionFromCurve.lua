require("extensions.Extension")

UserExtension = {}

local torqueCurve = {}
local powerCurve = {}
local maxPower = 0
local maxTorque = 0

function UserExtension:new(o)
  o = o or Extension:new(o)
  setmetatable(o, self)
  self.__index = self
  return o
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function getInterpolatedFromCurve(rpm, curve)
  if not curve or #curve == 0 then return 0 end
  if rpm <= curve[1][1] then return curve[1][2] end
  if rpm >= curve[#curve][1] then return curve[#curve][2] end

  for i = 1, #curve - 1 do
    local rpmA, valA = curve[i][1], curve[i][2]
    local rpmB, valB = curve[i + 1][1], curve[i + 1][2]
    if rpm >= rpmA and rpm <= rpmB then
      local t = (rpm - rpmA) / (rpmB - rpmA)
      return lerp(valA, valB, t)
    end
  end
  return 0
end

local function getCurveMaximum(curve)
  local maxVal = 0
  for _, point in ipairs(curve) do
    if point[2] > maxVal then
      maxVal = point[2]
    end
  end
  return math.floor(maxVal / 10 + 0.5) * 10
end
local function convertCurveValuesToNumbers(curve)
  for i, point in ipairs(curve) do
    point[1] = tonumber(point[1])
    point[2] = tonumber(point[2])
  end
end

local function loadCarCurves()
  local carState = ac.getCar(0)
  local path = ac.getFolder(ac.FolderID.ContentCars) .. "/" .. ac.getCarID(carState.id) .. "/ui/ui_car.json"

  if io.fileExists(path) then
    local file = io.open(path, "r")
    if file then
      local jsonData = file:read("*a")
      file:close()
      local carInfos = JSON.parse(jsonData)

      torqueCurve = carInfos.torqueCurve or {}
      powerCurve = carInfos.powerCurve or {}

      convertCurveValuesToNumbers(torqueCurve)
      convertCurveValuesToNumbers(powerCurve)

      maxTorque = getCurveMaximum(torqueCurve)
      maxPower = getCurveMaximum(powerCurve)

    end
  end
end

loadCarCurves()

local smoothedRpm = 0

function UserExtension:update(dt, customData)
  local car = ac.getCar(0)
  local rpm = car.rpm or 0
  smoothedRpm = smoothedRpm * 0.85 + rpm * 0.15

  local currentTorque = getInterpolatedFromCurve(smoothedRpm, torqueCurve)
  local currentPower = getInterpolatedFromCurve(smoothedRpm, powerCurve)

  if rpm < 400 then
    currentTorque = 0
    currentPower = 0
  end
  currentTorque = math.floor(currentTorque / 5 + 0.5) * 5
  currentPower = math.floor(currentPower / 5 + 0.5) * 5
  maxTorque = math.floor(maxTorque / 5 + 0.5) * 5
  maxPower = math.floor(maxPower / 5 + 0.5) * 5

  customData.TorquePowerExt_currentTorqueNm = currentTorque
  customData.TorquePowerExt_currentPowerHP = currentPower

  customData.TorquePowerExt_torqueNM = maxTorque
  customData.TorquePowerExt_maxPowerHP = maxPower
end

return UserExtension
