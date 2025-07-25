require("extensions.Extension")

TorquePower = {}

local powerLut = nil
local maxPowerHP = 0
local maxTorque = 0
local maxBoost = 0
local initialized = false

function TorquePower:new(o)
  o = o or Extension:new(o)
  setmetatable(o, self)
  self.__index = self
  return o
end


local function initializePowerLUT()
  local car = ac.getCar(0)
  powerLut = ac.DataLUT11.carData(car.index, "power.lut")
  
  for rpm = 0, 15000, 50 do
    local torque = powerLut:get(rpm)
    local power = torque * rpm / 9549

    if torque > maxTorque then maxTorque = torque end
    if power > maxPowerHP then maxPowerHP = power end
  end

  maxTorque = math.floor(maxTorque / 5 + 0.5) * 5
  maxPowerHP = math.floor(maxPowerHP / 5 + 0.5) * 5

  initialized = true
end

function TorquePower:update(dt, customData)
  if not initialized then
    initializePowerLUT()
    if not powerLut then return end
  end

  local car = ac.getCar(0)
  local rpm = car.rpm or 0

  local boost = car.turboBoost or 0

  local rawTorque = powerLut:get(rpm)
  local correctedTorque = rawTorque * (1 + boost)
  local correctedPower = correctedTorque * rpm / 9549

  correctedTorque = math.floor(correctedTorque / 5 + 0.5) * 5
  correctedPower = math.floor(correctedPower / 5 + 0.5) * 5

  if correctedTorque > maxTorque then
    maxTorque = correctedTorque
  end
  if correctedPower > maxPowerHP then
    maxPowerHP = correctedPower
  end
  if boost > maxBoost then
    maxBoost = boost
  end
  
  if car.rpm <= 400 then
    correctedTorque = 0
    correctedPower = 0
  end

  customData.TorquePowerExt_currentTorqueNm = correctedTorque
  customData.TorquePowerExt_currentPowerHP = correctedPower
  customData.TorquePowerExt_torqueNM = maxTorque
  customData.TorquePowerExt_maxPowerHP = maxPowerHP
end

return TorquePower