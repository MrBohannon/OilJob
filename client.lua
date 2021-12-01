-- globals --
local offset
local activeStill = nil
local activeSmokes = {}
----------------------------------------------------------------------------------------------------
--                                        FUNCTIONS
----------------------------------------------------------------------------------------------------
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
    local barrel = CreateObject(hash,barrelPos.x,barrelPos.y,barrelPos.z,true,false,true)
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
        TriggerEvent("redemrp_notification:start", "Your oil is being processed.", 5000)
        Citizen.Wait(5000)
        TriggerEvent("redemrp_notification:start", "Your oil was lost in processing.", 2)
    else
        DeleteEntity(barrel)
        TriggerEvent("redemrp_notification:start", "Your oil is being processed.", 2)
        Citizen.Wait(10)
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
        Citizen.Wait(5000)
        local newBarrel = CreateObject(hash,newPos.x,newPos.y,newPos.z,true,false,true)
        PlaceObjectOnGroundProperly(newBarrel)
        --TriggerEvent("redemrp_notification:start", "Your oil has been processed.", 2)
    end
end
----------------------------------------------------------------------------------------------------
--                                        EVENTS
----------------------------------------------------------------------------------------------------
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
        local barrel = getTargetBarrel()
        if barrel ~= 0 then
            NetworkRequestControlOfEntity(barrel)
            while not NetworkHasControlOfEntity(barrel) do
                print("gib barrel",barrel)
                Citizen.Wait(10)
            end
            if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
                print(isCarrying,barrel)
                if not isCarrying then
                    AttachEntityToEntity(barrel,playerPed,GetPedBoneIndex(playerPed,11816), 0.0, 1.0, 0, 0, 0, 0, true, true, false, false, 1, true,true,true)
                    --AttachEntityToEntity(barrel, playerPed, GetPedBoneIndex(playerPed,11816), 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                    isCarrying = true
                else
                    DetachEntity(barrel,true,true)
                    isCarrying = false
                end
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
                if dist <= 2.0 then
                    Draw2DText("Press G to Process Oil",0.5,0.85)
                    if IsControlJustPressed(1,0x760A9C6F) then -- pressed g
                        print(loadingDock)
                        local toBeProc = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL01AX"),true,false,true)
                        while toBeProc ~= 0 do
                            print("ToBeProc = ",toBeProc)
                            processOil(toBeProc,pos,heading)
                            Citizen.Wait(sleep)
                            toBeProc = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL01AX"),true,false,true)
                        end
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

----------------------------------------------------------------------------------------------------
--                                        BLIPS
----------------------------------------------------------------------------------------------------
Citizen.CreateThread(function()
        Wait(0)
        for k,v in pairs(OilConfig.ProcessNpcs) do
            local blip = N_0x554d9d53f696d002(1664425300, v[1])
            SetBlipSprite(blip, -272216216, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Oil Refinery")
	    end
        for k,v in pairs(OilConfig.SellNpcs) do
            local blip = N_0x554d9d53f696d002(1664425300, v[1])
            SetBlipSprite(blip, -426139257, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Oil Export")
        end
end)
----------------------------------------------------------------------------------------------------
--                                        SELL BARREL
----------------------------------------------------------------------------------------------------

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
                        local toBeSold = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL04B"),true,true,true)
                        while toBeSold ~= 0 do
                            sleep = 3500
                            print("ToBeSold = ",toBeSold)
                            sellOil(toBeSold)
                            Citizen.Wait(1000)
                            toBeSold = GetClosestObjectOfType(loadingDock.x,loadingDock.y,loadingDock.z,25.0,GetHashKey("P_BARREL04B"),true,true,true)
                        end
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)


function sellOil(barrel)
    DeleteEntity(barrel)
	TriggerServerEvent("oilrig:sell")
	TriggerEvent("redemrp_notification:start", "here is some cash now fuck off!", 2)
end

----------------------------------------------------------------------------------------------------
--                                        COMMANDS
----------------------------------------------------------------------------------------------------
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
----------------------------------------------------------------------------------------------------
--                                        RIG PLACEMENT NEW
----------------------------------------------------------------------------------------------------
function whenKeyJustPressed(key)
    if Citizen.InvokeNative(0x580417101DDB492F, 0, key) then
        return true
    else
        return false
    end
end

--TENT

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
		local x, y, z = table.unpack(GetEntityCoords(PlayerPedId()))
		
		
		local tent = DoesObjectOfTypeExistAtCoords(x, y, z, 1.5, GetHashKey("p_enginefactory01x"), true)
		
		if tent then 
			DrawText("PRESS [SPACE] TO MANAGE TEMERATURE",0.5,0.88)	
			if IsControlJustReleased(0, 0xD9D0E1C0) then -- g
				TriggerEvent('grrp_moonshiners:Cooking')
			end
		end
	end
end)


RegisterNetEvent('drrp_oil:placement')
AddEventHandler('drrp_oil:placement', function()
    local prop5 = nil 
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
    TriggerServerEvent('grrp_moonshiners:SyncSmoke', "start", coords)	
end)

function DrawText(text,x,y)
	local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(0.44,0.44)
    SetTextColor(255,255,255,255)--r,g,b,a
    SetTextCentre(true)--true,false
    SetTextDropshadow(1,0,0,0,255)--distance,r,g,b,a
    SetTextFontForCurrentCommand(0)
	Citizen.InvokeNative(0xADA9255D, 1);
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), x, y)
end
----------------------------------------------------------------------------------------------------
--                                        RIG SMOKE EFFECT
----------------------------------------------------------------------------------------------------
-- string, int, string, bool, bool, bool, int
function StartAnimation(animDict,flags,playbackListName,p3,p4,groundZ,time)
	Citizen.CreateThread(function()
		local player = PlayerPedId()
		local aCoord = GetEntityCoords(player)
		local pCoord = GetOffsetFromEntityInWorldCoords(PlayerPedId(), -10.0, 0.0, 0.0)

		local pRot = GetEntityRotation(player)

		if groundZ then
			local a, groundZ = GetGroundZAndNormalFor_3dCoord( aCoord.x, aCoord.y, aCoord.z + 10 )
			aCoord = {x=aCoord.x, y=aCoord.y, z=groundZ}
		end

		local animScene = Citizen.InvokeNative(0x1FCA98E33C1437B3, animDict, flags, playbackListName, 0, 1)
		Citizen.InvokeNative(0x8B720AD451CA2AB3, animScene, "Arthur", player, 0)
	    
	    	-- DIG UP A CHEST
	    	--local chest = CreateObjectNoOffset(GetHashKey('p_strongbox_muddy_01x'), pCoord, true, true, false, true)
	    	--Citizen.InvokeNative(0x8B720AD451CA2AB3, animScene, "CHEST", chest, 0)

	    	-- LOAD_ANIM_SCENE
	    	Citizen.InvokeNative(0xAF068580194D9DC7, animScene) 
			while not Citizen.InvokeNative(0x477122B8D05E7968 , animScene , 1 , 0) do
				Citizen.Wait(100)
			end
	    	-- START_ANIM_SCENE
	    	--print('START_ANIM_SCENE: '.. animScene)
	    	Citizen.InvokeNative(0xF4D94AF761768700, animScene) 
	    	if time then
	    		Citizen.Wait(tonumber(time))	
	    	else
	   		Citizen.Wait(10000) 
	    	end
			
	    	-- SET CHEST AS OPENED AFTER DUG UP
	    	-- Citizen.InvokeNative(0x188F8071F244B9B8, chest, 1) -- found native sets CHEST as OPENED		
	    	
		-- _DELETE_ANIM_SCENE
	    	Citizen.InvokeNative(0x84EEDB2C6E650000, animScene) 
   	end) 
end




function IsNearZone ( location )

    local player = PlayerPedId()
    local playerloc = GetEntityCoords(player, 0)
    for k,v in pairs (location) do
        if Vdist(playerloc , v) < 1.5 then
            return true, k
        end
    end

end

function TxtAtWorldCoord(x, y, z, txt, size, font)
    local s, sx, sy = GetScreenCoordFromWorldCoord(x, y ,z)
    if (sx > 0 and sx < 1) or (sy > 0 and sy < 1) then
        local s, sx, sy = GetHudScreenPositionFromWorldPosition(x, y, z)
        DrawTxt(txt, sx, sy, size, true, 255, 255, 255, 255, true, font) -- Font 2 has some symbol conversions ex. @ becomes the rockstar logo
    end
end

function DrawTxt(str, x, y, size, enableShadow, r, g, b, a, centre, font)
    local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(1, size)
    SetTextColor(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
    SetTextCentre(centre)
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
    SetTextFontForCurrentCommand(font)
    DisplayText(str, x, y)
end

function DisplayHelp( _message, x, y, w, h, enableShadow, col1, col2, col3, a, centre )

    local str = CreateVarString(10, "LITERAL_STRING", _message, Citizen.ResultAsLong())

    SetTextScale(w, h)
    SetTextColor(col1, col2, col3, a)

    SetTextCentre(centre)

    if enableShadow then
        SetTextDropshadow(1, 0, 0, 0, 255)
    end

    Citizen.InvokeNative(0xADA9255D, 10);

    DisplayText(str, x, y)

end

function StartFxSmoke (propModel,  coords)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local still = GetClosestObjectOfType(playerCoords, 6.0, GetHashKey(propModel), true)

    local finalPos = GetOffsetFromEntityInWorldCoords( still, -0.6, -0.5, -2.0)
    activeStill = still

    TriggerServerEvent('grrp_moonshiners:SyncSmoke', "start", coords)
end

RegisterNetEvent('grrp_moonshiners:StartCookingSmoke')
AddEventHandler('grrp_moonshiners:StartCookingSmoke', function(finalPos)

    print('start smoke')
    UseParticleFxAsset("SCR_ADV_SOK")
    local stillSmoke = StartParticleFxLoopedAtCoord("scr_adv_sok_torchsmoke", 
    finalPos.x, finalPos.y, finalPos.z, -2,0.0,0.0, 2.0, false, false, false, true)
    Citizen.InvokeNative(0x9DDC222D85D5AF2A, stillSmoke, 10.0)
    SetParticleFxLoopedAlpha(stillSmoke, 1.0)
    SetParticleFxLoopedColour(stillSmoke, 0.3, 0.3, 0.3, false)
    table.insert(activeSmokes, { fxHandle = stillSmoke, coords = finalPos})
end)

function StopFxSmoke (coords)
    CreateThread(function ()
        local toMilliseconds = 60 * 1000
        Wait(20 * toMilliseconds)
    
        TriggerServerEvent('grrp_moonshiners:SyncSmoke', "stop", coords)
    end)
end

RegisterNetEvent("grrp_moonshiners:StopCookingSmoke")
AddEventHandler('grrp_moonshiners:StopCookingSmoke', function(coords)
    print('stop smoke')
    local closestDistance = 999.0
    local closestStill
    for k,v in pairs(activeSmokes) do
        if v.coords.x  == coords.x and v.coords.y == coords.y then
            closestStill = v
            print('equal')
        end
    end
    
    print('closest still : ', closestStill)
    if(closestStill) then
        if(closestStill.fxHandle) then
            StopParticleFxLooped(closestStill.fxHandle, true)
        end
    end
end)

RegisterNetEvent('grrp_moonshiners:getStations')
AddEventHandler('grrp_moonshiners:getStations', function(station_b, station_m)
    moonshine_station_b = station_b
    moonshine_station_m = station_m
end)

function CheckForCloseSmokes()
    
    if next(activeSmokes) ~= nil then
        local playerCoords = GetEntityCoords(PlayerPedId())
        for k, v in pairs(activeSmokes) do
            local distance = #(v.coords - playerCoords)
            if distance <= 10.0 then
                TriggerServerEvent('grrp_moonshiners:SyncSmoke', "stop", v.coords)
            end
        end
    end
end

local check_smoke = true

Citizen.CreateThread(function()
    local IsZone2, IdZone2
    local IsZone, IdZone
    while true do
        if CurrentZoneActive == 0 then
            if moonshine_station_b ~= nil then
                IsZone, IdZone = IsNearZone( moonshine_station_b )
                
            end
            if moonshine_station_m ~= nil then
                IsZone2, IdZone2 = IsNearZone( moonshine_station_m )
            end
            if IsZone then
                local playerCoords = GetEntityCoords(PlayerPedId())
                
                if(check_smoke) then
                   -- CheckForCloseSmokes()
                    check_smoke = false
                end
                DrawTxt(Config.Language.Makebase, 0.50, 0.95, 0.6, 0.6, true, 255, 255, 255, 255, true, 10000)
                if IsControlJustReleased(0, keys['ENTER']) then
                    TriggerServerEvent("grrp_moonshiners:StartBaseServer")
                    CurrentZoneActive = IdZone
                end
            end
            
            if IsZone2 then
                local playerCoords = GetEntityCoords(PlayerPedId())
                DrawTxt(Config.Language.Make, 0.50, 0.95, 0.6, 0.6, true, 255, 255, 255, 255, true, 10000)
                if IsControlJustReleased(0, keys['ENTER']) then
                    
                    TriggerServerEvent("grrp_moonshiners:StartMakeServer")
                    CurrentZoneActive = IdZone2
                end
            end
        end
        Citizen.Wait(0)

    end
end)


function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
	SetTextCentre(centre)
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
	Citizen.InvokeNative(0xADA9255D, 1);
    DisplayText(str, x, y)
end

local hold
function TakTak()
    Citizen.CreateThread(function()
        local str = 'Change the Temperature'
        hold = PromptRegisterBegin()
        PromptSetControlAction(hold, 0x07CE1E61)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(hold, str)
        PromptSetEnabled(hold, true)
        PromptSetVisible(hold, true)
        PromptSetHoldMode(hold, true)
        --  PromptSetGroup(FishingPrompt, group)
        PromptRegisterEnd(hold)
    end)
end

function anim2()
        local dict = "mech_loco_m@generic@carry@moonshine@upright@transition"
        local playerPed = PlayerPedId()
        local pos = GetEntityCoords(playerPed)
        local prop = GetHashKey("P_BARREL04B")
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Citizen.Wait(10)
        end

        while not HasModelLoaded( prop ) do
            Wait(500)
            modelrequest( prop )
        end
        local tempObj2 = CreateObject(prop, pos.x, pos.y, pos.z, true, true, false)
        local boneIndex = GetEntityBoneIndexByName(playerPed, "SKEL_R_HAND")
        AttachEntityToEntity(tempObj2, playerPed, boneIndex, 0.1, 0.03, -0.07, 150.0, 10.0, 0.0, true, true, false, true, 1, true)
        TaskPlayAnim(PlayerPedId(), dict, "pour", 1.0, 8.0, -1, 31, 0, false, false, false)
        Citizen.Wait(10000)
        ClearPedTasks(PlayerPedId())
        DeleteObject(tempObj2)
        SetModelAsNoLongerNeeded(prop)
end

RegisterNetEvent('grrp_moonshiners:Cancel')
AddEventHandler('grrp_moonshiners:Cancel', function()
    CurrentZoneActive = 0
    check_smoke = true
    FreezeEntityPosition(PlayerPedId() ,false)
    ClearPedTasksImmediately(PlayerPedId())
end)

RegisterNetEvent('grrp_moonshiners:StartBase')
AddEventHandler('grrp_moonshiners:StartBase', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local still = GetClosestObjectOfType(playerCoords, 7.6, GetHashKey('p_enginefactory01x'), true)
    local coords = GetOffsetFromEntityInWorldCoords( still, -0.6, -0.5, -2.0)
    StartFxSmoke("p_enginefactory01x", coords)
    FreezeEntityPosition(PlayerPedId() ,true)
    ClearPedTasksImmediately(PlayerPedId())
    TriggerEvent("grrp_moonshiners:Sugar")
end)

RegisterNetEvent('grrp_moonshiners:Start')
AddEventHandler('grrp_moonshiners:Start', function()
    ClearPedTasksImmediately(PlayerPedId())
    TriggerEvent("grrp_moonshiners:Cooking")
end)


RegisterNetEvent('grrp_moonshiners:Cooking')
AddEventHandler('grrp_moonshiners:Cooking', function(base_amount)
    local temp = 400
    local timer = 0
    local good = 0
    local cold = 0
    local hot = 0
    anim2()
    local playerCoords = GetEntityCoords(PlayerPedId())

    local still = GetClosestObjectOfType(playerCoords, 6.0, GetHashKey('p_enginefactory01x'), true)
    local coords = GetOffsetFromEntityInWorldCoords( still, -0.6, -0.5, -2.0)
    StartFxSmoke("p_enginefactory01x", coords)
	WaitAfterAddBase()
    TriggerEvent("grrp_notification:Left", "Moonshiners", "Keep the temperature at the right level to create moonshine" , 3000)
    SetCurrentPedWeapon(PlayerPedId(), -1569615261, true)
    Wait(1000)
    ClearPedTasks(PlayerPedId())
    TakTak()
	FreezeEntityPosition(PlayerPedId() ,true)
    Citizen.CreateThread(function()
        while true do
            Wait(10)
            if temp <= 1001 then
                temp = temp + 2.0
            end
            local t = temp/10000
            if t >0.06 then
                DrawSprite("generic_textures", "hud_menu_4a", 0.2, 0.9, 0.01, t, 0.2,204, 0, 0, 190, 0)
                hot = hot + 1
            elseif t < 0.04 then
                DrawSprite("generic_textures", "hud_menu_4a", 0.2, 0.9, 0.01, t, 0.2, 0, 102, 255, 190, 0)
                cold = cold + 1
            else
                DrawSprite("generic_textures", "hud_menu_4a", 0.2, 0.9, 0.01, t, 0.2,51, 204, 51, 190, 0)
                good = good + 1
            end
            DrawSprite("generic_textures", "hud_menu_4a", 0.2, 0.9, 0.02, 0.11, 0.8,0, 0, 0, 190, 0)

            if PromptHasHoldModeCompleted(hold) then
                temp = temp - 2.5
            end

            if hot > 1000 then
			    PromptDelete(hold)
                ClearPedTasks(PlayerPedId())
                FreezeEntityPosition(PlayerPedId() , false)
				WaitAfterAddBase(true)
                TriggerEvent("grrp_notification:Left", "Moonshiners", "The mash is overheated and damaged" , 3000)
                TriggerServerEvent("grrp_moonshiners:Destroy" , base_amount)
                CurrentZoneActive = 0
                check_smoke = true
                local playerCoords = GetEntityCoords(PlayerPedId())
                local still = GetClosestObjectOfType(playerCoords, 6.0, GetHashKey('p_enginefactory01x'), true)
                local coords = GetOffsetFromEntityInWorldCoords( still, -0.6, -0.5, -2.0)
                StopFxSmoke(coords)

                break
            end
            timer = timer + 1
            if timer > 4000 then
                PromptDelete(hold)
                ClearPedTasks(PlayerPedId())
                FreezeEntityPosition(PlayerPedId() , false)
				WaitAfterAddBase(true)
                TriggerServerEvent("grrp_moonshiners:SendResults", good , base_amount)
                CurrentZoneActive = 0
                check_smoke = true
                local playerCoords = GetEntityCoords(PlayerPedId())

                local still = GetClosestObjectOfType(playerCoords, 6.0, GetHashKey('p_enginefactory01x'), true)
                local coords = GetOffsetFromEntityInWorldCoords( still, -0.6, -0.5, -2.0)
                StopFxSmoke(coords)

                break
            end
        end
    end)
end)

RegisterNetEvent('grrp_moonshiners:Water')
AddEventHandler('grrp_moonshiners:Water', function()
    water = 0
    FreezeEntityPosition(PlayerPedId() ,true)
    SetCurrentPedWeapon(PlayerPedId(), -1569615261, true)
    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, true, true, 2.0, true)
    Citizen.Wait(3000)
    Stop()
    Citizen.CreateThread(function()
        while true do
            Wait(1)
            water = water + 1.0
            local t = water/10000
            DisplayHelp("Water", 0.50, 0.95, 0.6, 0.6, true, 255, 255, 255, 255, true, 10000)
            DrawSprite("generic_textures", "hud_menu_4a", 0.2, 0.9, 0.01, t, 0.2,191, 143, 0, 190, 0)
            DrawSprite("generic_textures", "hud_menu_4a", 0.2, 0.9, 0.02, 0.11, 0.8,0, 0, 0, 190, 0)
            if PromptHasHoldModeCompleted(stop) then
                local display = water
                TriggerEvent("grrp_notification:Left", "Moonshiners", "Added "..display.."ml of water" , 2000)
                PromptDelete(stop)
                ClearPedTasksImmediately(PlayerPedId())
                FreezeEntityPosition(PlayerPedId() ,false)
                WaitAfterAdd()
                TriggerEvent("grrp_moonshiners:Yeast")
                break
            end
            if water > 1000 then
                TriggerEvent("grrp_notification:Left", "Moonshiners", "You added all the water" , 2000)
                PromptDelete(stop)
                ClearPedTasksImmediately(PlayerPedId())
                FreezeEntityPosition(PlayerPedId() ,false)
                WaitAfterAdd()
                TriggerEvent("grrp_moonshiners:Yeast")
                
                break
            end
        end
    end)
end)

RegisterNetEvent('grrp_moonshiners:animation')
AddEventHandler('grrp_moonshiners:animation', function()
    local pid = PlayerPedId()
    RequestAnimDict("script_rc@chrb@ig1_visit_clerk")
    while not HasAnimDictLoaded("script_rc@chrb@ig1_visit_clerk") do
        Citizen.Wait(10)
    end
    TaskPlayAnim(PlayerPedId(), "script_rc@chrb@ig1_visit_clerk", "arthur_gives_money_player", 1.0, 8.0, -1, 1, 0, false, false, false)
    Wait(2000)
    ClearPedTasks(PlayerPedId())
end)


function SecondsToClock(seconds)
    local seconds = tonumber(seconds)

    if seconds <= 0 then
        return "00:00:00";
    else
        hours = string.format("%02.f", math.floor(seconds/3600));
        mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
        secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
        return hours..":"..mins..":"..secs
    end
end


function WaitAfterAdd(bool)
    local time = 120000 -- 120000
	local tests = 20
    local IDDDD = 0
	while IDDDD == 0 and tests > 1 do
		IDDDD = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), 6.0, GetHashKey("p_barrelhalf04x"), true)
		Wait(100)
		tests = tests - 1
	end
	if IDDDD == 0 then IDDDD = PlayerPedId() end
    local x , y ,z  = table.unpack(GetEntityCoords(IDDDD))
    while true do
        Wait(1)
        if time > 1 then
            if Vdist(x , y ,z , GetEntityCoords(PlayerPedId())) < 2 then
                TxtAtWorldCoord(x,y,z, "Remaining time: "..SecondsToClock(math.floor(time/1000)), 0.2 , 1)
            end
            time = time - 20
        else
            if Vdist(x , y ,z , GetEntityCoords(PlayerPedId())) < 2 then
                if bool then
                    TxtAtWorldCoord(x,y,z, "Press [ENTER] to complete the process.", 0.2 , 1)
                else
                    TxtAtWorldCoord(x,y,z, "Press [ENTER] to add another component.", 0.2 , 1)
                end

                if IsControlJustReleased(1, 0xC7B5340A) then
                    break
                end
            end
        end
    end
end


function WaitAfterAddBase(bool)
    local time = 300000 -- 300000
	local tests = 20
    local IDDDD = 0
	while IDDDD == 0 and tests > 1 do
		IDDDD = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), 6.0, GetHashKey("p_enginefactory01x"), true)
		Wait(100)
		tests = tests - 1
	end
	if IDDDD == 0 then IDDDD = PlayerPedId() end
    local x , y ,z  = table.unpack(GetEntityCoords(IDDDD))
    while true do
        Wait(1)
        if time > 1 then
            if Vdist(x , y ,z , GetEntityCoords(PlayerPedId())) < 2 then
                TxtAtWorldCoord(x,y,z, "Remaining Time: "..SecondsToClock(math.floor(time/1000)), 0.2 , 1)
            end
            time = time - 20
        else
            if Vdist(x , y ,z , GetEntityCoords(PlayerPedId())) < 2 then
                if bool then
                    TxtAtWorldCoord(x,y,z, "Press [ENTER] to complete the process.", 0.2 , 1)
                else
                    TxtAtWorldCoord(x,y,z, "Press [ENTER] to start the action.", 0.2 , 1)
                end

                if IsControlJustReleased(1, 0xC7B5340A) then
                    break
                end
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
--                                            SHOVEL
----------------------------------------------------------------------------------------------------
local shoveling = false
local shovelObject = nil
local shovelout = false
local ShovelPrompt
local ShovelEndPrompt
local ShovelGroup = GetRandomIntInRange(0, 0xffffff)

function StartScene(animDict,flags,playbackListName,p3,p4,groundZ,time)
	Citizen.CreateThread(function()
		local playerPed = PlayerPedId()
		local aCoord = GetEntityCoords(playerPed)
		local pCoord = GetOffsetFromEntityInWorldCoords(PlayerPedId(), -10.0, 0.0, 0.0)
		local pRot = GetEntityRotation(playerPed)
		if groundZ then
			local a, groundZ = GetGroundZAndNormalFor_3dCoord( aCoord.x, aCoord.y, aCoord.z + 10 )
			aCoord = {x=aCoord.x, y=aCoord.y, z=groundZ}
		end
		local animScene = Citizen.InvokeNative(0x1FCA98E33C1437B3, animDict, flags, playbackListName, 0, 1)
        DeleteShovel()
		Citizen.InvokeNative(0x020894BF17A02EF2, animScene, aCoord.x, aCoord.y, aCoord.z, pRot.x, pRot.y, pRot.z, 2) 
		Citizen.InvokeNative(0x8B720AD451CA2AB3, animScene, "player", playerPed, 0)
	    Citizen.InvokeNative(0xAF068580194D9DC7, animScene) 
	    Citizen.Wait(1000)
	    Citizen.InvokeNative(0xF4D94AF761768700, animScene) 
	    if time then
	    	Citizen.Wait(tonumber(time))	
            Citizen.InvokeNative(0x84EEDB2C6E650000, animScene)
            shoveling = false   
	    else
	   	    Citizen.Wait(10000)
            Citizen.InvokeNative(0x84EEDB2C6E650000, animScene)
            shoveling = false
	    end
   	end) 
end

function CreateShovel()
    if shovelObject ~= nil then
        DeleteObject(shovelObject)
        SetObjectAsNoLongerNeeded(shovelObject)
        shovelObject = nil
    end
    local pedp = PlayerPedId()
    local pc = GetEntityCoords(pedp)
    local shovelmodel = `mp005_p_collectorshovel01`
    RequestModel(shovelmodel)
    while not HasModelLoaded(shovelmodel) do
        Wait(10)
    end
    shovelObject = CreateObject(shovelmodel, pc.x,pc.y,pc.z, true, true, true)
    SetModelAsNoLongerNeeded(shovelmodel)
    if IsPedMale(pedp) then
        AttachEntityToEntity(shovelObject, pedp, 311, 0.0, -0.04, 0.22, -5.0, 180.0, 0.0, false, false, true, false, 0, true, false, false)
    else
        AttachEntityToEntity(shovelObject, pedp, 371, 0.0, -0.04, 0.22, -5.0, 180.0, 0.0, false, false, true, false, 0, true, false, false)
    end
end

function DeleteShovel()
    if shovelObject ~= nil then
        DeleteObject(shovelObject)
        SetObjectAsNoLongerNeeded(shovelObject)
        shovelObject = nil
    end
end

function Shovel()
    if shoveling == false then
        local coordsped = GetEntityCoords(PlayerPedId())
        local town_name = Citizen.InvokeNative(0x43AD8FC02B429D33,coordsped.x,coordsped.y,coordsped.z,1)
        if town_name ~= false then
            for i,v in pairs(OilConfig.Towns) do
                if v == town_name then
                    TriggerEvent("Notification:left", OilConfig.Messages.Title, OilConfig.Messages.WrongArea, 'inventory_items_mp', 'kit_collector_spade', 3000)
                    return
                end
            end
        end
        local luck = math.random(1,10)
        if luck > 10 then --30% to find and 70% to not
            shoveling = true
            StartScene('script@mech@treasure_hunting@nothing',1,'PBL_NOTHING_01',0,1,true,7000)
            Citizen.Wait(7000)
            TriggerEvent("Notification:left", OilConfig.Messages.Title, OilConfig.Messages.Nothing, 'inventory_items_mp', 'kit_collector_spade', 3000)
            CreateShovel()
        else 
            StartScene('script@mech@treasure_hunting@grab',0,'PBL_GRAB_01',0,1,true,10000)
            Citizen.Wait(10000)
            TriggerServerEvent("fd_oil:DowsingForOil")
            --TriggerEvent("Notification:left", Config.Messages.Title, Config.Messages.Success, 'inventory_items_mp', 'kit_collector_spade', 3000)
            CreateShovel()
        end
    end
end

function EndShovel()
    if shoveling == false then
        if shovelObject ~= nil then
            DeleteObject(shovelObject)
            SetObjectAsNoLongerNeeded(shovelObject)
            shovelObject = nil
        end
        shovelout = false
    end
end

function SetupShovelPrompt()
    Citizen.CreateThread(function()
        local str = OilConfig.Prompts.DigName
        ShovelPrompt = PromptRegisterBegin()
        PromptSetControlAction(ShovelPrompt, OilConfig.Prompts.DigPrompt)
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(ShovelPrompt, str)
        PromptSetEnabled(ShovelPrompt, 1)
        PromptSetVisible(ShovelPrompt, 1)
		PromptSetStandardMode(ShovelPrompt,1)
		PromptSetGroup(ShovelPrompt, ShovelGroup)
		Citizen.InvokeNative(0xC5F428EE08FA7F2C,ShovelPrompt,true)
		PromptRegisterEnd(ShovelPrompt)
    end)
    Citizen.CreateThread(function()
        local str = OilConfig.Prompts.StopName
        ShovelEndPrompt = PromptRegisterBegin()
        PromptSetControlAction(ShovelEndPrompt, OilConfig.Prompts.StopPrompt) 
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(ShovelEndPrompt, str)
        PromptSetEnabled(ShovelEndPrompt, 1)
        PromptSetVisible(ShovelEndPrompt, 1)
		PromptSetStandardMode(ShovelEndPrompt,1)
		PromptSetGroup(ShovelEndPrompt, ShovelGroup)
		Citizen.InvokeNative(0xC5F428EE08FA7F2C,ShovelEndPrompt,true)
		PromptRegisterEnd(ShovelEndPrompt)
    end)
end

Citizen.CreateThread(function() --
    SetupShovelPrompt()
	while true do
		Citizen.Wait(4)
		if shovelout == true then
            local label  = CreateVarString(10, 'LITERAL_STRING', OilConfig.Prompts.Title)
            PromptSetActiveGroupThisFrame(ShovelGroup, label)
            DisableControlAction(0, 0xAC4BD4F1, true) -- TAB 
            DisableControlAction(0, 0x4CC0E2FE, true) -- B 
            if Citizen.InvokeNative(0xC92AC953F0A982AE,ShovelPrompt) then
                if GetMount(PlayerPedId()) == 0 then
				    Shovel()
                end
            end
			if Citizen.InvokeNative(0xC92AC953F0A982AE,ShovelEndPrompt) then
                if shovelout == true then
                   EndShovel()
                end
            end
            if IsPedSwimming(PlayerPedId()) or IsPedClimbing(PlayerPedId()) or IsPedFalling(PlayerPedId()) or IsPedDeadOrDying(PlayerPedId()) then
                EndShovel()
            end
        end
    end
end)

RegisterNetEvent('ricx_shovel:start')
AddEventHandler('ricx_shovel:start', function()
    local playerp = PlayerPedId()
    if not IsPedDeadOrDying(playerp) and shovelout == false then
        if GetMount(playerp) == 0 and not IsPedSwimming(playerp) and not IsPedClimbing(playerp) and not IsPedFalling(playerp) then
            shovelout = true
            CreateShovel()
        else
            TriggerEvent("Notification:left", OilConfig.Messages.Title, OilConfig.Messages.NoDig, 'menu_textures', 'stamp_locked_rank', 3000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if (GetCurrentResourceName() ~= resourceName) then
	  return
	end
    if shovelObject then
		DeleteObject(shovelObject)
		SetEntityAsNoLongerNeeded(shovelObject)
	end
    shoveling = false
    shovelObject = nil
    shovelout = false
end)
--Basic Notification
RegisterNetEvent('Notification:left')
AddEventHandler('Notification:left', function(t1, t2, dict, txtr, timer)
    if not HasStreamedTextureDictLoaded(dict) then
        RequestStreamedTextureDict(dict, true) 
        while not HasStreamedTextureDictLoaded(dict) do
            Wait(5)
        end
    end
    if txtr ~= nil then
        exports.ricx_shovel.LeftNot(0, tostring(t1), tostring(t2), tostring(dict), tostring(txtr), tonumber(timer))
    else
        local txtr = "tick"
        exports.ricx_shovel.LeftNot(0, tostring(t1), tostring(t2), tostring(dict), tostring(txtr), tonumber(timer))
    end
end)
