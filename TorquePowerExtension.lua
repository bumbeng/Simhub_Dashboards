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

local function boostCurve(rpm, refRpm, maxBoost, gamma)
  if rpm <= 1000 then return 0 end
  if rpm >= refRpm then return maxBoost end
  local norm = (rpm - 1000) / (refRpm - 1000)
  return maxBoost * (norm ^ gamma)
end

local function initializePowerLUT()
  powerLut = ac.DataLUT11.carData(car.index, "power.lut")
  if not powerLut then return end

  local engineData = ac.INIConfig.carData(car.index, "engine.ini")
  local limiter = engineData:get("ENGINE_DATA", "LIMITER", 15000)
  if limiter <= 0 then limiter = 15000 end

local turbos = {}
local i = 0

while true do
  local section = "TURBO_" .. tostring(i)
  local wastegateRaw = engineData:get(section, "WASTEGATE", nil)
  if wastegateRaw == nil then break end

  local wastegate = nil
  if type(wastegateRaw) == "table" then
    wastegate = tonumber(wastegateRaw[1])
  else
    wastegate = tonumber(wastegateRaw)
  end

  if not wastegate then break end

  if wastegate > 0 then
    local refRpmRaw = engineData:get(section, "REFERENCE_RPM", 0)
    local gammaRaw = engineData:get(section, "GAMMA", 0)

    local refRpm = type(refRpmRaw) == "table" and tonumber(refRpmRaw[1]) or tonumber(refRpmRaw)
    local gamma = type(gammaRaw) == "table" and tonumber(gammaRaw[1]) or tonumber(gammaRaw)

    table.insert(turbos, {
      refRpm = refRpm or 0,
      boostMax = wastegate,
      gamma = gamma or 0
    })
  end

  i = i + 1
end

  boostmax = 0
  for rpm = 0, limiter, 50 do
    local totalBoost = 0
    for _, turbo in ipairs(turbos) do
      totalBoost = totalBoost + boostCurve(rpm, turbo.refRpm, turbo.boostMax, turbo.gamma)
    end

    if totalBoost > boostmax then
      boostmax = totalBoost
    end

    local torque = powerLut:get(rpm) * (1 + totalBoost)
    local power = torque * 0.101972 * rpm / 725

    if torque > maxTorque then maxTorque = torque end
    if power > maxPowerHP then maxPowerHP = power end
  end

  maxTorque = math.floor((maxTorque / 0.85 ) + 0.5)
  maxPowerHP = math.floor((maxPowerHP / 0.85) + 0.5)
  boostmax = math.floor(boostmax * 100 + 0.5) / 100

  initialized = true
end

function TorquePower:update(dt, customData)
  if not initialized then
    initializePowerLUT()
    if not powerLut then return end
  end

  local rpm = car.rpm or 0
  local boost = car.turboBoost or 0
  local rawTorque = powerLut:get(rpm) * (1 + boost)
  local correctedPower = rawTorque * 0.101972 * rpm / 725

  smoothTorque = smoothTorque * (1 - alpha) + rawTorque * alpha
  smoothPower = smoothPower * (1 - alpha) + correctedPower * alpha

  local displayTorque = math.floor((smoothTorque / 0.85) + 0.5)
  local displayPower = math.floor((smoothPower / 0.85) + 0.5)

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
