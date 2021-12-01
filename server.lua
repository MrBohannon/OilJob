-- globals --
data = {}
local currentSpots = {}
local moonshine_station_b = {}
local moonshine_station_m = {}

-- functions --
function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end

function round(x, decimals)
    local n = 10^(decimals or 0)
    x = x * n
    if x >= 0 then x = math.floor(x + 0.5) else x = math.ceil(x - 0.5) end
    return x / n
end

function spawnOil()
    local randomNums = {}
    -- flush table --
    for k in pairs(currentSpots) do
        currentSpots[k] = nil
    end
    -- generate new spots --
    for i=1, OilConfig.ActiveSpots do
        local rand = math.random(1,#OilConfig.Spots)
        currentSpots[i] = {OilConfig.Spots[rand],math.random() + math.random(0,2)}
    end
    -- clear duplicate spots --
    for i=1, #currentSpots do
        for j=2, #currentSpots do
            if currentSpots[i][1] == currentSpots[j][1] then
                currentSpots[j][1] = OilConfig.Spots[math.random(1,#OilConfig.Spots)]
            end
        end
    end
    for i=1, #currentSpots do
        print(currentSpots[i][1],currentSpots[i][2])
    end
end

-- events --
RegisterServerEvent("fd_oil:CheckForOil")
AddEventHandler("fd_oil:CheckForOil", function(pumpjack,pumpPos)
    math.randomseed(os.time())
    print("callback received")
    local src = source
    local srcPos = pumpPos
    local r = OilConfig.Radius
    local bool = false
    local richness
    for k,v in ipairs(currentSpots) do
        local distance = #(srcPos-v[1])
        print(distance)
        if distance <= r then
            bool = true
            richness = v[2]
        end
    end
    print(src,bool,richness,pumpjack)
    TriggerClientEvent("fd_oil:CheckForOil",src,{bool,richness},pumpjack)
end)

RegisterServerEvent("RegisterUsableItem:dowsing_rod")
AddEventHandler("RegisterUsableItem:dowsing_rod", function()
    local src = source
    TriggerClientEvent("fd_oil:DowsingForOil",src,currentSpots)
end)

RegisterServerEvent("fd_oil:DowsingForOil")
AddEventHandler("fd_oil:DowsingForOil", function()
    local src = source
    TriggerClientEvent("fd_oil:DowsingForOil",src,currentSpots)
end)

-- Threads --
Citizen.CreateThread(function()
    while true do
        spawnOil()
        Citizen.Wait(OilConfig.ActiveTimer) -- Resets oil spots based on config definition
    end
end)

RegisterServerEvent("RegisterUsableItem:oilrig")
AddEventHandler("RegisterUsableItem:oilrig", function(source)
    local src = source
    TriggerEvent('redemrp:getPlayerFromId', source, function(user)
    TriggerClientEvent('drrp_oil:placement', source)
	    data.delItem(_source,"oilrig", 1)
		end)
end)

RegisterServerEvent("RegisterUsableItem:oilprospector")
AddEventHandler("RegisterUsableItem:oilprospector", function(source)
    TriggerClientEvent('ricx_shovel:start', source)
end)

RegisterServerEvent('processing:barrel')
AddEventHandler('processing:barrel', function()
	TriggerClientEvent('processing:complete', _source)
end)

RegisterServerEvent('oilrig:sell')
AddEventHandler('oilrig:sell', function(cash)
    local src = source
    TriggerEvent('redemrp:getPlayerFromId', source, function(user)
        user.addMoney(30)
        end)
end)

RegisterNetEvent("grrp_moonshiners:SyncSmoke")
AddEventHandler("grrp_moonshiners:SyncSmoke", function (type, coords)
    if type == 'start' then
        TriggerClientEvent("grrp_moonshiners:StartCookingSmoke", -1, coords)
    else
        TriggerClientEvent("grrp_moonshiners:StopCookingSmoke", -1, coords)
    end
end)

AddEventHandler("redemrp:playerLoaded", function(source, user)
    TriggerClientEvent("grrp_moonshiners:getStations", source ,moonshine_station_b , moonshine_station_m )
end)


RegisterServerEvent("grrp_moonshiners:add_m")
AddEventHandler("grrp_moonshiners:add_m", function (id ,x,y,z )
    moonshine_station_m[id] = vector3(x,y,z)
    TriggerClientEvent("grrp_moonshiners:getStations", -1 ,moonshine_station_b , moonshine_station_m )
end)

RegisterServerEvent("grrp_moonshiners:remove_m")
AddEventHandler("grrp_moonshiners:remove_m", function (id )
    moonshine_station_m[id] = nil
    TriggerClientEvent("grrp_moonshiners:getStations", -1 ,moonshine_station_b , moonshine_station_m )
end)

AddEventHandler("grrp_moonshiners:add_b", function (id ,x,y,z )
    --print(id)
    moonshine_station_b[id] = vector3(x,y,z)
    --print(moonshine_station_b[1])
    TriggerClientEvent("grrp_moonshiners:getStations", -1 ,moonshine_station_b , moonshine_station_m )
end)

RegisterServerEvent("grrp_moonshiners:remove_b")
AddEventHandler("grrp_moonshiners:remove_b", function (id )
    moonshine_station_b[id] = nil
    TriggerClientEvent("grrp_moonshiners:getStations", -1 ,moonshine_station_b , moonshine_station_m )
end)

TriggerEvent("redemrp_inventory:getData",function(call)
    data = call
end)
math.randomseed(os.time())

function round(num, numDecimalPlaces)
    if numDecimalPlaces and numDecimalPlaces>0 then
        local mult = 10^numDecimalPlaces
        return math.floor(num * mult + 0.5) / mult
    end
    return math.floor(num + 0.5)
end

RegisterServerEvent("grrp_moonshiners:StartBaseServer")
AddEventHandler("grrp_moonshiners:StartBaseServer", function ()
    local _source = source
    local ItemData1 = data.getItem(_source, "water")
    local ItemData2 = data.getItem(_source, "sugar")
    local ItemData3 = data.getItem(_source, "yeast")
    if ItemData1.ItemAmount >=5 and ItemData2.ItemAmount >= 2 and ItemData3.ItemAmount >=1 then
        ItemData1.RemoveItem(5)
        ItemData2.RemoveItem(2)
        ItemData3.RemoveItem(1)
        TriggerClientEvent("grrp_moonshiners:StartBase", _source)
    else
        TriggerClientEvent("grrp_moonshiners:Cancel", _source)
        TriggerClientEvent("redemrp_notification:start", _source,"You need: sugar x2 water x5 yeast x1", 3, "error")
    end
end)

RegisterServerEvent("grrp_moonshiners:StartMakeServer")
AddEventHandler("grrp_moonshiners:StartMakeServer", function ()
    local _source = source
    local ItemData = data.getItem(_source, "oilrig")
    if ItemData.ItemAmount >=1 then
        TriggerClientEvent("grrp_moonshiners:Cooking", _source , ItemData.ItemAmount)
		ItemData.RemoveItem(ItemData.ItemAmount)
    else
        TriggerClientEvent("grrp_moonshiners:Cancel", _source)
        TriggerClientEvent("redemrp_notification:start", _source,"You have no mash", 3, "error")
    end
end)


RegisterServerEvent("grrp_moonshiners:Destory")
AddEventHandler("grrp_moonshiners:Destory", function (base_amount)
    local _source = source
    local ItemData = data.getItem(_source, "oilrig")
    local t = round(base_amount*0.4 , -2)
    ItemData.AddItem(t)
end)

RegisterServerEvent("grrp_moonshiners:ShareMove")
AddEventHandler("grrp_moonshiners:ShareMove", function ()
    local _source = source
    TriggerClientEvent("grrp_moonshiners:DrunkMoveEffect", -1, _source)
end)
RegisterServerEvent("grrp_moonshiners:ShareMoveClear")
AddEventHandler("grrp_moonshiners:ShareMoveClear", function ()
    local _source = source
    TriggerClientEvent("grrp_moonshiners:DrunkMoveClear", -1, _source)
end)


RegisterServerEvent('grrp_moonshiners:CallToSherif')
AddEventHandler('grrp_moonshiners:CallToSherif', function(x, y, z, zone)
    local players = GetPlayers()
    for i,k in pairs(players) do
      
        TriggerEvent('redemrp:getPlayerFromId', tonumber(k), function(user)
            if user.getJob() == "sheriff" then
                TriggerClientEvent('grrp_moonshiners:InfoSheriff', k, x, y, z, zone)
            end

        end)
    end
end)

RegisterServerEvent("grrp_moonshiners:SendResults")
AddEventHandler("grrp_moonshiners:SendResults", function (good , amount_base)
    local _source = source
    local _good = good
    local ItemData1 = data.getItem(_source, "moonshine")
    if _good >3900 then
        ItemData1.AddItem( amount_base)
        TriggerClientEvent("grrp_notification:Left", _source, "Moonshiners", "You made "..amount_base.." moonshine" , 5000)
    elseif  _good < 3900 and _good >3500 then
        local amount = round(amount_base*0.75, -2)
        ItemData1.AddItem( amount)
        TriggerClientEvent("grrp_notification:Left", _source, "Moonshiners", "You made "..amount.." moonshine" , 5000)
    elseif  _good >=3000 and _good <3500 then
        local amount = round(amount_base*0.6, -2)
        ItemData1.AddItem( amount)
        TriggerClientEvent("grrp_notification:Left", _source, "Moonshiners", "You made "..amount.." moonshine" , 5000)
    end
end)


RegisterServerEvent("grrp_moonshiners:SendResultsBase")
AddEventHandler("grrp_moonshiners:SendResultsBase", function (sugar,water,yeast)
    local _source = source
    local _sugar = sugar/2
    local _water = water
    local _yeast = yeast
    local test_p
    local test_d
    local amount = 0
    local p = math.floor(_water/_sugar)
    if p == 4 then
        test_p = "idelna"
    elseif p == 4.5 then
        test_p = "dobra"
    elseif p == 3.5 then
        test_p = "dobra"
    elseif p < 3.5 then
        test_p = "zla"
    elseif p > 4.5 then
        test_p = "zla"
    end
    if _yeast <=200 and _yeast <= 350 then
        test_d = "idelna"
    else
        test_d = "dobra"
    end
    if test_p == "idelna" and test_d == "idelna" then
        amount = math.random(8,15)
    elseif test_p == "dobra" and test_d == "idelna" then
        amount = math.random(7,12)
    elseif test_p == "zla" and test_d == "idelna" then
        amount = math.random(5,10)
    elseif test_p == "idelna" and test_d =="dobra" then
        amount = math.random(8,12)
    elseif test_p == "dobra" and test_d == "dobra" then
        amount = math.random(6,10)
    elseif test_p == "zla" and test_d == "dobra" then
        amount = math.random(5,8)
    end
    local ItemData = data.getItem(_source, "moonshine_base")
    ItemData.AddItem(amount)
    TriggerClientEvent("grrp_notification:Left", _source, "Moonshiners", "You made "..amount.." moonshine mash." , 5000)
end)

RegisterNetEvent("grrp_moonshiners:SyncSmoke")
AddEventHandler("grrp_moonshiners:SyncSmoke", function (type, coords)
    if type == 'start' then
        TriggerClientEvent("grrp_moonshiners:StartCookingSmoke", -1, coords)
    else
        TriggerClientEvent("grrp_moonshiners:StopCookingSmoke", -1, coords)
    end
end)


Citizen.CreateThread(function ()
    Wait(3000)
    TriggerClientEvent("grrp_moonshiners:getStations", -1 ,moonshine_station_b , moonshine_station_m )
end)
