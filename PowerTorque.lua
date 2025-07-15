--[[ 
    RENAME THIS FILE TO UserExtension.lua TO ACTIVATE IT 
]]

require("extensions.Extension")

UserExtension = {}

local basePath = "C:/Program Files (x86)/Steam/steamapps/common/assettocorsa/content/cars/"

-- 📄 Datei lesen
local function readFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

local function normalizeString(text)
    return text:lower():gsub("[^%w]", "")
end

local function findCarFolder(carName)
    local normalizedCarName = normalizeString(carName)
    local command = 'dir "' .. basePath .. '"'
    local pipe = io.popen(command)
    if not pipe then return nil end
    local result = pipe:read("*all")
    pipe:close()

    for line in result:gmatch("[^\r\n]+") do
        local folder = line:match("<DIR>%s+(.+)")
        if folder then
            folder = folder:gsub("^%s+", ""):gsub("%s+$", "")
            local normalizedFolder = normalizeString(folder)

            if normalizedFolder:find(normalizedCarName, 1, true) then
                print("✅ Fahrzeugordner gefunden:", folder)
                return basePath .. folder .. "/ui/ui_car.json"
            end
        end
    end

    print("❌ Kein Fahrzeugordner gefunden für:", carName)
    return nil
end

-- 🔢 Robustes Kurven-Parsing (auch mehrzeilig)
local function parseCurveArray(text, arrayName)
    local array = {}

    -- Suche nach Start-Label (z.B. "torqueCurve") und parse alle Zahlenpaare danach
    local startPos = text:find('"' .. arrayName .. '"%s*:%s*%[')
    if not startPos then
        print("⚠️ Tabelle nicht gefunden:", arrayName)
        return array
    end

    -- Ab Startposition arbeiten (Text ab dem Array-Start)
    local subText = text:sub(startPos)

    -- Debug-Ausgabe: erster Abschnitt ab Tabellenstart
    print("\n📋 Suche ab Start von [" .. arrayName .. "]:")

    -- Alle Paare direkt finden (suche im gesamten nach Paaren)
    for rpm, value in subText:gmatch('%["(%d+)"%s*,%s*"(%d+)"%]') do
        print("➡️ Gelesen:", rpm, value)
        table.insert(array, { tonumber(rpm), tonumber(value) })
    end

    print("✔️ Geladene Punkte in " .. arrayName .. ": " .. tostring(#array))
    return array
end




-- bhp und torque bleiben wie bisher
local function parseSpecValue(text, key)
    local pattern = '"' .. key .. '"%s*:%s*"(.-)"'
    local value = text:match(pattern)
    return value or ""
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getInterpolatedFromCurve(rpm, curve, label)
    if rpm <= curve[1][1] then
        print(string.format("[%s] RPM %.0f unter Minimum: Rückgabe %.2f", label, rpm, curve[1][2]))
        return curve[1][2]
    end
    if rpm >= curve[#curve][1] then
        print(string.format("[%s] RPM %.0f über Maximum: Rückgabe %.2f", label, rpm, curve[#curve][2]))
        return curve[#curve][2]
    end

    for i = 1, #curve - 1 do
        local rpmA, valueA = curve[i][1], curve[i][2]
        local rpmB, valueB = curve[i+1][1], curve[i+1][2]
        if rpm >= rpmA and rpm <= rpmB then
            local t = (rpm - rpmA) / (rpmB - rpmA)
            local result = lerp(valueA, valueB, t)
            print(string.format(
                "[%s] Interp: %.0f RPM → %.2f (zwischen %d=%.2f und %d=%.2f, t=%.3f)",
                label, rpm, result, rpmA, valueA, rpmB, valueB, t
            ))
            return result
        end
    end

    print(string.format("[%s] Keine passende Interpolation gefunden für RPM %.0f", label, rpm))
    return 0
end


-- 🚀 Setup
local carName = ac.getCarName(0)
local carJsonPath = findCarFolder(carName)

local torqueCurve, powerCurve, bhp, maxTorque = {}, {}, 0, 0

if carJsonPath then
    local jsonContent = readFile(carJsonPath)
    if jsonContent then
        torqueCurve = parseCurveArray(jsonContent, "torqueCurve")
        powerCurve = parseCurveArray(jsonContent, "powerCurve")

        print("📊 torqueCurve Punkte:", #torqueCurve)
        for i, point in ipairs(torqueCurve) do
            print(string.format("[%d] RPM=%d Nm=%d", i, point[1], point[2]))
        end

        print("📊 powerCurve Punkte:", #powerCurve)
        for i, point in ipairs(powerCurve) do
            print(string.format("[%d] RPM=%d PS=%d", i, point[1], point[2]))
        end

        local bhp_raw = parseSpecValue(jsonContent, "bhp")
        local torque_raw = parseSpecValue(jsonContent, "torque")
        bhp = tonumber(bhp_raw:match("(%d+)")) or 0
        maxTorque = tonumber(torque_raw:match("(%d+)")) or 0

        print("✅ BHP:", bhp)
        print("✅ Max Torque:", maxTorque)
    else
        print("❌ ui_car.json konnte nicht gelesen werden.")
    end
else
    print("❌ Fahrzeugordner nicht gefunden.")
end

-- 📊 Laufende Werte
local currentTorque = 0
local currentPower = 0

function UserExtension:new(o)
    o = o or Extension:new(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function UserExtension:update(dt, customData)
    local carState = ac.getCar(0)
    local currentRpm = math.floor(carState.rpm)
    local rpm = currentRpm  -- Deine gewählte RPM-Methode

    if #torqueCurve > 0 and #powerCurve > 0 then
        currentTorque = getInterpolatedFromCurve(rpm, torqueCurve, "Torque")
        currentPower = getInterpolatedFromCurve(rpm, powerCurve, "Power")
        currentTorque = math.floor(currentTorque / 10 + 0.5) * 10
        currentPower = math.floor(currentPower / 10 + 0.5) * 10
    end

    customData.currentpower = currentPower
    customData.currenttorque = currentTorque
    customData.bhp = bhp
    customData.torque = maxTorque
end

return UserExtension
