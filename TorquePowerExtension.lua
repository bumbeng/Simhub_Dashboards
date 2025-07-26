require("extensions.Extension")

TorquePower = {}

local powerLut = nil
local maxPowerHP = 0
local maxTorque = 0
local initialized = false
local boostmax = 0
local smoothTorque = 0
local smoothPower = 0
local alpha = 0.2

function TorquePower:new(o)
  o = o or Extension:new(o)
  setmetatable(o, self)
  self.__index = self
  return o
end


local function initializePowerLUT()
  local car = ac.getCar(0)
  powerLut = ac.DataLUT11.carData(car.index, "power.lut")
  local engineData = ac.INIConfig.carData(car.index, "engine.ini")
  local turbo0 = engineData:get("TURBO_0", "DISPLAY_MAX_BOOST", 0)
  local turbo1 = engineData:get("TURBO_1", "DISPLAY_MAX_BOOST", 0)
if turbo0 > 0 then
  boostmax = boostmax + turbo0
end

if turbo1 > 0 then
  boostmax = boostmax + turbo1
end

  for rpm = 0, 15000, 50 do
    local torque = powerLut:get(rpm)
    local power = torque * rpm / 9549

    if torque > maxTorque then maxTorque = torque end
    if power > maxPowerHP then maxPowerHP = power end
  end

  maxTorque = math.floor(((maxTorque / 5 + 0.5) * 5) * (1 + boostmax))
  maxPowerHP = math.floor(((maxPowerHP / 5 + 0.5) * 5) * (1 + boostmax))
  initialized = true
end

function TorquePower:update(dt, customData)
  if not initialized then
    initializePowerLUT()
    if not powerLut then return end
  end

  local car = ac.getCar(0)
  local rpm = (car.rpm * 0.85 + car.rpm * 0.15) or 0
  local boost = car.turboBoost
  local rawTorque = powerLut:get(rpm)
  local correctedTorque = rawTorque * (1 + boost)
  local correctedPower = correctedTorque * rpm / 9549

  smoothTorque = smoothTorque * (1 - alpha) + correctedTorque * alpha
  smoothPower = smoothPower * (1 - alpha) + correctedPower * alpha

  local displayTorque = math.floor(smoothTorque / 5 + 0.5) * 5
  local displayPower = math.floor(smoothPower / 5 + 0.5) * 5

  if car.rpm <= 400 then
    displayTorque = 0
    displayPower = 0
  end

  customData.TorquePowerExt_currentTorqueNm = displayTorque
  customData.TorquePowerExt_currentPowerHP = displayPower
  customData.TorquePowerExt_torqueNM = maxTorque
  customData.TorquePowerExt_maxPowerHP = maxPowerHP
  customData.TorquePowerExt_maxTurboBoost = boostmax
end

return TorquePower