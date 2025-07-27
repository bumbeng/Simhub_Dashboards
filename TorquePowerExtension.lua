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
local car = ac.getCar(0)

function TorquePower:new(o)
  o = o or Extension:new(o)
  setmetatable(o, self)
  self.__index = self
  return o
end


local function initializePowerLUT()

  powerLut = ac.DataLUT11.carData(car.index, "power.lut")
  local engineData = ac.INIConfig.carData(car.index, "engine.ini")
  local turbo0 = engineData:get("TURBO_0", "WASTEGATE", 0)
  local turbo1 = engineData:get("TURBO_1", "WASTEGATE", 0)
if turbo0 > 0 then
  boostmax = boostmax + turbo0
end

if turbo1 > 0 then
  boostmax = boostmax + turbo1
end

  for rpm = 0, 15000, 50 do
    local torque = powerLut:get(rpm) * (1 + boostmax)
    local power = torque * 0.101972 * rpm / 725

    if torque > maxTorque then maxTorque = torque end
    if power > maxPowerHP then maxPowerHP = power end
  end

  maxTorque = math.floor((maxTorque * 1.15) / 1 + 0.5) * 1
  maxPowerHP = math.floor((maxPowerHP * 1.15) / 1 + 0.5) * 1
  initialized = true
end

function TorquePower:update(dt, customData)
  if not initialized then
    initializePowerLUT()
    if not powerLut then return end
  end

  local rpm = car.rpm or 0
  local boost = car.turboBoost
  local rawTorque = powerLut:get(rpm) * (1 + boost)
  local correctedTorque = rawTorque
  local correctedPower =  correctedTorque * 0.101972 * rpm / 725

  smoothTorque = smoothTorque * (1 - alpha) + correctedTorque * alpha
  smoothPower = smoothPower * (1 - alpha) + correctedPower * alpha

  local displayTorque = math.floor((smoothTorque * 1.15) / 1 + 0.5) * 1
  local displayPower = math.floor((smoothPower * 1.15) / 1 + 0.5) * 1

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