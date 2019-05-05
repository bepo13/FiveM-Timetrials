-- Filename to store scores
local scoreFileName = "./scores.txt"

-- Colors for printing scores
local color_finish = {238, 198, 78}
local color_highscore = {238, 78, 118}

-- Save scores to JSON file
function saveScores(scores)
    local file = io.open(scoreFileName, "w+")
    if file then
        local contents = json.encode(scores)
        file:write(contents)
        io.close( file )
        return true
    else
        return false
    end
end

-- Load scores from JSON file
function getScores()
    local contents = ""
    local myTable = {}
    local file = io.open(scoreFileName, "r")
    if file then
        -- read all contents of file into a string
        local contents = file:read("*a")
        myTable = json.decode(contents);
        io.close( file )
        return myTable
    end
    return {}
end

-- Create thread to send scores to clients every 5s
Citizen.CreateThread(function()
    while (true) do
        Citizen.Wait(5000)
        TriggerClientEvent('raceReceiveScores', -1, getScores())
    end
end)

-- Save score and send chat message when player finishes
RegisterServerEvent('racePlayerFinished')
AddEventHandler('racePlayerFinished', function(source, message, title, newScore)
    -- Get top car score for this race
    local msgAppend = ""
    local msgSource = source
    local msgColor = color_finish
    local allScores = getScores()
    local raceScores = allScores[title]
    if raceScores ~= nil then
        -- Compare top score and update if new one is faster
        local carName = newScore.car
        local topScore = raceScores[carName]
        if topScore == nil or newScore.time < topScore.time then
            -- Set new high score
            topScore = newScore
            
            -- Set message parameters to send to all players for high score
            msgSource = -1
            msgAppend = " (fastest)"
            msgColor = color_highscore
        end
        raceScores[carName] = topScore
    else
        -- No scores for this race, create struct and set new high score
        raceScores = {}
        raceScores[newScore.car] = newScore
        
        -- Set message parameters to send to all players for high score
        msgSource = -1
        msgAppend = " (fastest)"
        msgColor = color_highscore
    end
    
    -- Save and store scores back to file
    allScores[title] = raceScores
    saveScores(allScores)
    
    -- Trigger message to all players
    TriggerClientEvent('chatMessage', -1, "[RACE]", msgColor, message .. msgAppend)
end)
