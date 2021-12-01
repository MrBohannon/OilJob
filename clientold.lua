-- globals --
local offset
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


function Draw2DText(text, x, y)
    local string = CreateVarString(10, "LITERAL_STRING", text)
    SetTextColor(255, 255, 255, 255)
    SetTextFontForCurrentCommand(0)
    SetTextScale(0.3, 0.3)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextCentre(true)
    DisplayText(string, x, y)
end

function getTargetBarrel()
    local pos = GetEntityCoords(PlayerPedId())
    local entityWorld = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0)
    local result = GetClosestObjectOfType(entityWorld.x,entityWorld.y,entityWorld.z,1.0,GetHashKey("P_BARREL01AX"),true,true,true)
    if result == 0 then
        result = GetClosestObjectOfType(entityWorld.x,entityWorld.y,entityWorld.z,1.0,GetHashKey("P_BARREL04B"),true,true,true)
    end
    return result
end

function spawnBarrel(pumpjack)
    print("spawnBarrel invoked by "..pumpjack)
    local pumpPos = GetEntityCoords(pumpjack)
    local barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,0.0,5.0,-0.5)
    local hash = GetHashKey("P_BARREL01AX")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        RequestModel(hash)
        print("Waiting for model "..hash)
        Citizen.Wait(100)
    end
    if offset ~= nil then
        offset = offset + 1.0
        local rand = math.random(1,2)
        if rand == 1 then
            barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,offset,5.0,0.0)
        elseif rand == 2 then
            barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,0.0,5.0 + offset,0.0)
        end
    end
    local barrel = CreateObject(hash,barrelPos.x,barrelPos.y,barrelPos.z,true,true,true)
    PlaceObjectOnGroundProperly(barrel,true)
end

function processOil(barrel, npc, h)
    local unf = barrel
    local time = OilConfig.ProcessTime
    local chance = OilConfig.ProcessChance
    local pos = npc
    local rand = math.random()
    if rand <= chance then
        DeleteEntity(barrel)
        TriggerEvent("redemrp_notification:start", "Your oil is being processed.", 2)
        Citizen.Wait(time)
        TriggerEvent("redemrp_notification:start", "Your oil was lost in processing.", 2)
    else
        DeleteEntity(barrel)
        TriggerEvent("redemrp_notification:start", "Your oil is being processed.", 2)
        Citizen.Wait(time)
        --spawn new barrel--
        local newPos = GetObjectOffsetFromCoords(pos.x,pos.y,pos.z,h,0.0,1.5,1.5)
        local hash = GetHashKey("P_BARREL04B")
        print(newPos)
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            RequestModel(hash)
            print("Waiting for model "..hash)
            Citizen.Wait(100)
        end
        local newBarrel = CreateObject(hash,newPos.x,newPos.y,newPos.z,true,true,true)
        PlaceObjectOnGroundProperly(newBarrel)
        TriggerEvent("redemrp_notification:start", "Your oil has been processed.", 2)
    end
end

function sellOil(barrel)
    DeleteEntity(barrel)
    TriggerServerEvent("fd_oil:SellOil")
end

-- events --
RegisterNetEvent("fd_oil:DowsingForOil")
AddEventHandler("fd_oil:DowsingForOil", function(spots)
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local r = OilConfig.Radius
    for k,v in pairs(spots) do
        local distance = Vdist2(playerPos.x,playerPos.y,playerPos.z,v[1].x,v[1].y,v[1].z)
        if distance <= r then
            if v[2] >= 1.5 then
                TriggerEvent("redemrp_notification:start", "You found some oil! It seems pretty rich!", 2)
            else
                TriggerEvent("redemrp_notification:start", "You found some oil! It seems not that rich", 2)
            end
        else
            TriggerEvent("redemrp_notification:start", "You didn't find any oil", 2)
        end
    end
end)

RegisterNetEvent("fd_oil:CheckForOil")
AddEventHandler("fd_oil:CheckForOil", function(result,pumpjack)
    print(result)
    if result[1] == true then
        local pumpPos = GetEntityCoords(pumpjack)
        local richMult = 1/result[2]
        local barrelTime = OilConfig.CollectTime * richMult
        print(barrelTime)
        Citizen.Wait(barrelTime)
        spawnBarrel(pumpjack)
        TriggerServerEvent("fd_oil:CheckForOil",pumpjack,pumpPos)
    else
        TriggerEvent("redemrp_notification:start", "Your well has dried up", 2)
    end
end)
-- Threads --
Citizen.CreateThread(function()
    local sleep = 10
    local playerPed = PlayerPedId()
    local isCarrying = false
    while true do
        if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
            local barrel = getTargetBarrel()
            if not isCarrying then
                print(isCarrying,barrel)
                AttachEntityToEntity(barrel,playerPed,GetPedBoneIndex(playerPed,11816), 0.0, 1.0, 0, 0, 0, 0, true, true, false, false, 1, true,true,true)
                isCarrying = true
            else
                print(isCarrying,barrel)
                DetachEntity(barrel,true,true)
                isCarrying = false
            end
        end
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    local sleep = 1000
    local processNPCs = OilConfig.ProcessNpcs
    local processPoints = OilConfig.ProcessSpots
    local playerPed = PlayerPedId()
    while true do
        local playerPos = GetEntityCoords(playerPed)
        for i=1, #processNPCs do
            local pos = processNPCs[i][1]
            local heading = processNPCs[i][2]
            local dist = #(playerPos-pos)
            local loadingDock = processPoints[i]
            if dist <= 5.0 then
                sleep = 10
                if dist <= 1.0 then
                    Draw2DText("Press G to Process Oil",0.5,0.85)
                    if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
                        print(loadingDock)
                        local toBeProc = 0
                        repeat
                            toBeProc = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL01AX"),true,true,true)
                            print("ToBeProc = ",toBeProc)
                            processOil(toBeProc,pos,heading)
                            Citizen.Wait(sleep)
                        until toBeProc == 0
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

---- Blips ----
Citizen.CreateThread(function()
        Wait(0)
        for k,v in pairs(OilConfig.ProcessNpcs) do
            print("blips for processing")
            local blip = N_0x554d9d53f696d002(1664425300, v[1])
            SetBlipSprite(blip, -392465725, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Oil Refinery")
	    end
        for k,v in pairs(OilConfig.SellNpcs) do
            local blip = N_0x554d9d53f696d002(1664425300, v[1])
            print("sellNPCS",blip)
            SetBlipSprite(blip, 1106719664, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Oil Export")
        end
end)

Citizen.CreateThread(function()
    local sleep = 1000
    local sellNPCs = OilConfig.SellNpcs
    local sellPoints = OilConfig.SellSpots
    local playerPed = PlayerPedId()
    while true do
        local playerPos = GetEntityCoords(playerPed)
        for i=1, #sellNPCs do
            local pos = sellNPCs[i][1]
            local heading = sellNPCs[i][2]
            local dist = #(playerPos-pos)
            local loadingDock = sellPoints[i]
            if dist <= 5.0 then
                sleep = 10
                if dist <= 1.0 then
                    Draw2DText("Press G to Sell Oil",0.5,0.85)
                    if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
                        print(loadingDock)
                        local toBeSold = 0
                        repeat
                            sleep = 3500
                            toBeSold = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL04B"),true,true,true)
                            print("ToBeSold = ",toBeSold)
                            sellOil(toBeSold)
                            Citizen.Wait(sleep)
                        until toBeSold == 0
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- Commands --
RegisterCommand("checkForOil", function(src,args,raw)
    local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
    TriggerServerEvent("fd_oil:DowsingForOil")
end)

RegisterCommand("spawnOilBarrel", function(src,args,raw)
    local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
    local barrelPos = GetOffsetFromEntityInWorldCoords(player,0.0,5.0,0.0)
    local hash = GetHashKey("P_BARREL01AX")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        RequestModel(hash)
        print("Waiting for model "..hash)
        Citizen.Wait(100)
    end
    print(barrelPos)
    if offset ~= nil then
        offset = offset + 1.0
        local rand = math.random(1,2)
        if rand == 1 then
            barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,offset,5.0,0.0)
        elseif rand == 2 then
            barrelPos = GetOffsetFromEntityInWorldCoords(pumpjack,0.0,5.0 + offset,0.0)
        end
    end
    local barrel = CreateObject(hash,barrelPos.x,barrelPos.y,barrelPos.z,true,true,true)
    PlaceObjectOnGroundProperly(barrel)
    print(dump(Citizen.ResultAsInteger()))
end)

RegisterCommand("spawnOilPump", function(src,args,raw)
    local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
    local pumpPos = GetOffsetFromEntityInWorldCoords(player,0.0,5.0,0.0)

    local hash = GetHashKey("p_enginefactory01x")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        RequestModel(hash)
        print("Waiting for model "..hash)
        Citizen.Wait(100)
    end
    local pump = CreateObject(hash,pumpPos.x,pumpPos.y,pumpPos.z,true,true,true)
    PlaceObjectOnGroundProperly(pump)
    TriggerServerEvent("fd_oil:CheckForOil",pump,pumpPos)
end)

RegisterCommand("spawnCart", function(src,args,raw)
    local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
    local cartPos = GetOffsetFromEntityInWorldCoords(player,0.0,5.0,0.0)

    local hash = GetHashKey("UTILLIWAG")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        RequestModel(hash)
        print("Waiting for model "..hash)
        Citizen.Wait(100)
    end
    local cart = CreateVehicle(hash,cartPos.x,cartPos.y,cartPos.z,0.0,true,true,true,true)
end)

RegisterCommand("spawnBarrel", function(src,args,raw)
    local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
    local pumpPos = GetOffsetFromEntityInWorldCoords(player,0.0,5.0,0.0)

    local hash = GetHashKey(args[1])
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        RequestModel(hash)
        print("Waiting for model "..hash)
        Citizen.Wait(100)
    end
    local barrel = CreateObject(hash,pumpPos.x,pumpPos.y,pumpPos.z,true,true,true)
    PlaceObjectOnGroundProperly(barrel,true)
end)