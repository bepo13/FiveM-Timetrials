-- Local parameters
local START_PROMPT_DISTANCE = 10.0              -- distance to prompt to start race
local DRAW_TEXT_DISTANCE = 100.0                -- distance to start rendering the race name text
local DRAW_SCORES_DISTANCE = 25.0               -- Distance to start rendering the race scores
local DRAW_SCORES_COUNT_MAX = 15                -- Maximum number of scores to draw above race title
local CHECKPOINT_Z_OFFSET = -5.00               -- checkpoint offset in z-axis
local RACING_HUD_COLOR = {238, 198, 78, 255}    -- color for racing HUD above map

-- State variables
local raceState = {
    cP = 1,
    index = 0 ,
    scores = nil,
    startTime = 0,
    blip = nil,
    checkpoint = nil
}

-- Array of colors to display scores, top to bottom and scores out of range will be white
local raceScoreColors = {
    {214, 175, 54, 255},
    {167, 167, 173, 255},
    {167, 112, 68, 255}
}

-- Create preRace thread
Citizen.CreateThread(function()
    preRace()
end)

-- Function that runs when a race is NOT active
function preRace()
    -- Initialize race state
    raceState.cP = 1
    raceState.index = 0 
    raceState.startTime = 0
    raceState.blip = nil
    raceState.checkpoint = nil
    
    -- While player is not racing
    while raceState.index == 0 do
        -- Update every frame
        Citizen.Wait(0)

        -- Get player
        local player = GetPlayerPed(-1)

        -- Teleport player to waypoint if active and button pressed
        if IsWaypointActive() and IsControlJustReleased(0, 182) then
            -- Teleport player to waypoint
            local waypoint = GetFirstBlipInfoId(8)
            if DoesBlipExist(waypoint) then 
                -- Teleport to location, wait 100ms to load then get ground coordinate
                local coords = GetBlipInfoIdCoord(waypoint)
                teleportToCoord(coords.x, coords.y, coords.z, 0)
                Citizen.Wait(100)
                local temp, zCoord = GetGroundZFor_3dCoord(coords.x, coords.y, 9999.9, 1)
                teleportToCoord(coords.x, coords.y, zCoord + 4.0, 0)
            end
        end

        -- Loop through all races
        for index, race in pairs(races) do
            if race.isEnabled then
                -- Draw map marker
                DrawMarker(1, race.start.x, race.start.y, race.start.z - 1, 0, 0, 0, 0, 0, 0, 3.0001, 3.0001, 1.5001, 255, 165, 0,165, 0, 0, 0,0)
                
                -- Check distance from map marker and draw text if close enough
                if GetDistanceBetweenCoords( race.start.x, race.start.y, race.start.z, GetEntityCoords(player)) < DRAW_TEXT_DISTANCE then
                    -- Draw race name
                    Draw3DText(race.start.x, race.start.y, race.start.z-0.600, race.title, RACING_HUD_COLOR, 4, 0.3, 0.3)
                end

                -- When close enough, draw scores
                if GetDistanceBetweenCoords( race.start.x, race.start.y, race.start.z, GetEntityCoords(player)) < DRAW_SCORES_DISTANCE then
                    -- If we've received updated scores, display them
                    if raceState.scores ~= nil then
                        -- Get scores for this race and sort them
                        raceScores = raceState.scores[race.title]
                        if raceScores ~= nil then
                            local sortedScores = {}
                            for k, v in pairs(raceScores) do
                                table.insert(sortedScores, { key = k, value = v })
                            end
                            table.sort(sortedScores, function(a,b) return a.value.time < b.value.time end)

                            -- Create new list with scores to draw
                            local count = 0
                            drawScores = {}
                            for k, v in pairs(sortedScores) do
                                if count < DRAW_SCORES_COUNT_MAX then
                                    count = count + 1
                                    table.insert(drawScores, v.value)
                                end
                            end

                            -- Initialize offset
                            local zOffset = 0
                            if (#drawScores > #raceScoreColors) then
                                zOffset = 0.450*(#raceScoreColors) + 0.300*(#drawScores - #raceScoreColors - 1)
                            else
                                zOffset = 0.450*(#drawScores - 1)
                            end

                            -- Print scores above title
                            for k, score in pairs(drawScores) do
                                -- Draw score text with color coding
                                if (k > #raceScoreColors) then
                                    -- Draw score in white, decrement offset
                                    Draw3DText(race.start.x, race.start.y, race.start.z+zOffset, string.format("%s %.2fs (%s)", score.car, (score.time/1000.0), score.player), {255,255,255,255}, 4, 0.13, 0.13)
                                    zOffset = zOffset - 0.300
                                else
                                    -- Draw score with color and larger text, decrement offset
                                    Draw3DText(race.start.x, race.start.y, race.start.z+zOffset, string.format("%s %.2fs (%s)", score.car, (score.time/1000.0), score.player), raceScoreColors[k], 4, 0.22, 0.22)
                                    zOffset = zOffset - 0.450
                                end
                            end
                        end
                    end
                end
                
                -- When close enough, prompt player
                if GetDistanceBetweenCoords( race.start.x, race.start.y, race.start.z, GetEntityCoords(player)) < START_PROMPT_DISTANCE then
                    helpMessage("Press ~INPUT_CONTEXT~ to Race!")
                    if (IsControlJustReleased(1, 51)) then
                        -- Set race index, clear scores and trigger event to start the race
                        raceState.index = index
                        raceState.scores = nil
                        TriggerEvent("raceCountdown")
                        break
                    end
                end
            end
        end
    end
end

-- Receive race scores from server and print
RegisterNetEvent("raceReceiveScores")
AddEventHandler("raceReceiveScores", function(scores)
    -- Save scores to state
    raceState.scores = scores
end)

-- Countdown race start with controls disabled
RegisterNetEvent("raceCountdown")
AddEventHandler("raceCountdown", function()
    -- Get race from index
    local race = races[raceState.index]
    
    -- Teleport player to start and set heading
    teleportToCoord(race.start.x, race.start.y, race.start.z + 4.0, race.start.heading)
    
    Citizen.CreateThread(function()
        -- Countdown timer
        local time = 0
        function setcountdown(x) time = GetGameTimer() + x*1000 end
        function getcountdown() return math.floor((time-GetGameTimer())/1000) end
        
        -- Count down to race start
        setcountdown(6)
        while getcountdown() > 0 do
            -- Update HUD
            Citizen.Wait(1)
            DrawHudText(getcountdown(), {255,191,0,255},0.5,0.4,4.0,4.0)
            
            -- Disable acceleration/reverse until race starts
            DisableControlAction(2, 71, true)
            DisableControlAction(2, 72, true)
        end
        
        -- Enable acceleration/reverse once race starts
        EnableControlAction(2, 71, true)
        EnableControlAction(2, 72, true)
        
        -- Start race
        TriggerEvent("raceRaceActive")
    end)
end)

-- Main race function
RegisterNetEvent("raceRaceActive")
AddEventHandler("raceRaceActive", function()
    -- Get race from index
    local race = races[raceState.index]
    
    -- Start a new timer
    raceState.startTime = GetGameTimer()
    Citizen.CreateThread(function()
        -- Create first checkpoint
        checkpoint = CreateCheckpoint(race.checkpoints[raceState.cP].type, race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z + CHECKPOINT_Z_OFFSET, race.checkpoints[raceState.cP].x,race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z, race.checkpointRadius, 204, 204, 1, math.ceil(255*race.checkpointTransparency), 0)
        raceState.blip = AddBlipForCoord(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z)
        
        -- Set waypoints if enabled
        if race.showWaypoints == true then
            SetNewWaypoint(race.checkpoints[raceState.cP+1].x, race.checkpoints[raceState.cP+1].y)
        end
        
        -- While player is racing, do stuff
        while raceState.index ~= 0 do 
            Citizen.Wait(1)
            
            -- Stop race when L is pressed, clear and reset everything
            if IsControlJustReleased(0, 182) and GetLastInputMethod(0) then
                -- Delete checkpoint and raceState.blip
                DeleteCheckpoint(checkpoint)
                RemoveBlip(raceState.blip)
                
                -- Set new waypoint and teleport to the same spot 
                SetNewWaypoint(race.start.x, race.start.y)
                teleportToCoord(race.start.x, race.start.y, race.start.z + 4.0, race.start.heading)
                
                -- Clear racing index and break
                raceState.index = 0
                break
            end

            -- Draw checkpoint and time HUD above minimap
            local checkpointDist = math.floor(GetDistanceBetweenCoords(race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z, GetEntityCoords(GetPlayerPed(-1))))
            DrawHudText(("%.3fs"):format((GetGameTimer() - raceState.startTime)/1000), RACING_HUD_COLOR, 0.015, 0.725, 0.7, 0.7)
            DrawHudText(string.format("Checkpoint %i / %i (%d m)", raceState.cP, #race.checkpoints, checkpointDist), RACING_HUD_COLOR, 0.015, 0.765, 0.5, 0.5)
            
            -- Check distance from checkpoint
            if GetDistanceBetweenCoords(race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z, GetEntityCoords(GetPlayerPed(-1))) < race.checkpointRadius then
                -- Delete checkpoint and map raceState.blip, 
                DeleteCheckpoint(checkpoint)
                RemoveBlip(raceState.blip)
                
                -- Play checkpoint sound
                PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS")
                
                -- Check if at finish line
                if raceState.cP == #(race.checkpoints) then
                    -- Save time and play sound for finish line
                    local finishTime = (GetGameTimer() - raceState.startTime)
                    PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds")
                    
                    -- Get vehicle name and create score
                    local aheadVehHash = GetEntityModel(GetVehiclePedIsUsing(GetPlayerPed(-1)))
                    local aheadVehNameText = GetLabelText(GetDisplayNameFromVehicleModel(aheadVehHash))
                    local score = {}
                    score.player = GetPlayerName(PlayerId())
                    score.time = finishTime
                    score.car = aheadVehNameText
                    
                    -- Send server event with score and message, move this to server eventually
                    message = string.format("Player " .. GetPlayerName(PlayerId()) .. " finished " .. race.title .. " using " .. aheadVehNameText .. " in " .. (finishTime / 1000) .. " s")
                    TriggerServerEvent('racePlayerFinished', GetPlayerName(PlayerId()), message, race.title, score)
                    
                    -- Clear racing index and break
                    raceState.index = 0
                    break
                end

                -- Increment checkpoint counter and create next checkpoint
                raceState.cP = math.ceil(raceState.cP+1)
                if race.checkpoints[raceState.cP].type == 5 then
                    -- Create normal checkpoint
                    checkpoint = CreateCheckpoint(race.checkpoints[raceState.cP].type, race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z + CHECKPOINT_Z_OFFSET, race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z, race.checkpointRadius, 204, 204, 1, math.ceil(255*race.checkpointTransparency), 0)
                    raceState.blip = AddBlipForCoord(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z)
                    SetNewWaypoint(race.checkpoints[raceState.cP+1].x, race.checkpoints[raceState.cP+1].y)
                elseif race.checkpoints[raceState.cP].type == 9 then
                    -- Create finish line
                    checkpoint = CreateCheckpoint(race.checkpoints[raceState.cP].type, race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z + 4.0, race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z, race.checkpointRadius, 204, 204, 1, math.ceil(255*race.checkpointTransparency), 0)
                    raceState.blip = AddBlipForCoord(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z)
                    SetNewWaypoint(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y)
                end
            end
        end
                
        -- Reset race
        preRace()
    end)
end)

-- Create map blips for all enabled tracks
Citizen.CreateThread(function()
    for _, race in pairs(races) do
        if race.isEnabled then
            race.blip = AddBlipForCoord(race.start.x, race.start.y, race.start.z)
            SetBlipSprite(race.blip, race.mapBlipId)
            SetBlipDisplay(race.blip, 4)
            SetBlipScale(race.blip, 1.0)
            SetBlipColour(race.blip, race.mapBlipColor)
            SetBlipAsShortRange(race.blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(race.title)
            EndTextCommandSetBlipName(race.blip)
        end
    end
end)

-- Utility function to teleport to coordinates
function teleportToCoord(x, y, z, heading)
    Citizen.Wait(1)
    local player = GetPlayerPed(-1)
    if IsPedInAnyVehicle(player, true) then
        SetEntityCoords(GetVehiclePedIsUsing(player), x, y, z)
        Citizen.Wait(100)
        SetEntityHeading(GetVehiclePedIsUsing(player), heading)
    else
        SetEntityCoords(player, x, y, z)
        Citizen.Wait(100)
        SetEntityHeading(player, heading)
    end
end

-- Utility function to display help message
function helpMessage(text, duration)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, duration or 5000)
end

-- Utility function to display 3D text
function Draw3DText(x,y,z,textInput,colour,fontId,scaleX,scaleY)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
    local scale = (1/dist)*20
    local fov = (1/GetGameplayCamFov())*100
    local scale = scale*fov

    SetTextScale(scaleX*scale, scaleY*scale)
    SetTextFont(fontId)
    SetTextProportional(1)
    local colourr,colourg,colourb,coloura = table.unpack(colour)
    SetTextColour(colourr,colourg,colourb, coloura)
    SetTextDropshadow(2, 1, 1, 1, 255)
    SetTextEdge(3, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(textInput)
    SetDrawOrigin(x,y,z+2, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Utility function to display HUD text
function DrawHudText(text,colour,coordsx,coordsy,scalex,scaley)
    SetTextFont(4)
    SetTextProportional(7)
    SetTextScale(scalex, scaley)
    local colourr,colourg,colourb,coloura = table.unpack(colour)
    SetTextColour(colourr,colourg,colourb, coloura)
    SetTextDropshadow(0, 0, 0, 0, coloura)
    SetTextEdge(1, 0, 0, 0, coloura)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(coordsx,coordsy)
end
