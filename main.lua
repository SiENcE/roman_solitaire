--[[
    Roman Solitaire
    
    A strategic board game of tactical captures and territorial control.
    
    Copyright (c) 2025 Florian Fischer
    All rights reserved.
    
    This game features an 8x8 grid where players control black and white pieces,
    moving them to capture opponents through strategic jumps. The game includes
    both random and balanced setup modes, AI opponents, and visual move assistance.
    
    Version: 1.0.0
    Created: March 2025
    
    This gameplay idea and code is protected by copyright law and international treaties.
    Unauthorized reproduction or distribution of this program, or any portion of it,
    may result in severe civil and criminal penalties, and will be prosecuted to
    the maximum extent possible under the law.
]]

local Grid = {}
local currentPlayer = "white"
local whitePieces, blackPieces = 0,0
local selectedPiece = nil
local gameOver = false
local winner = nil
local players = {white = "human", black = "human"}
local showBestMove = false
local buttons = {}
local animatingPiece = nil
local aiThinking = false
local aiCoroutine = nil
local fadingPieces = {}
local setupMode = "random" -- Can be "random" or "balanced"
local isSymmetrical = nil

local WINDOW_WIDTH = 1218 --812
local WINDOW_HEIGHT = 800 --375
local GRID_SIZE = 80
local BOARD_WIDTH = GRID_SIZE * 8
local BOARD_HEIGHT = GRID_SIZE * 8
local BOARD_OFFSET_X = (WINDOW_WIDTH - BOARD_WIDTH) / 2
local BOARD_OFFSET_Y = (WINDOW_HEIGHT - BOARD_HEIGHT) / 2

function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    math.randomseed(os.time())
    createButtons()
    initializeGrid()
end

-- Update the createButtons function to position buttons on the right side
function createButtons()
    local buttonWidth = 120
    local buttonHeight = 30
    local startX = BOARD_OFFSET_X + BOARD_WIDTH + 10
    local startY = BOARD_OFFSET_Y
    local spacing = 5

    buttons = {
        {text = "Restart (r)", x = startX, y = startY, w = buttonWidth, h = buttonHeight, action = function() initializeGrid() end},
        {text = "Show Move Off (b)", x = startX, y = startY + buttonHeight + spacing, w = buttonWidth, h = buttonHeight, action = function() showBestMove = not showBestMove end},
        {text = "White AI Off (1)", x = startX, y = startY + 2*(buttonHeight + spacing), w = buttonWidth, h = buttonHeight, action = function() players.white = players.white == "human" and "ai" or "human" end},
        {text = "Black AI Off (2)", x = startX, y = startY + 3*(buttonHeight + spacing), w = buttonWidth, h = buttonHeight, action = function() players.black = players.black == "human" and "ai" or "human" end},
        {text = "Toggle Setup", x = startX, y = startY + 4*(buttonHeight + spacing), w = buttonWidth, h = buttonHeight, action = function() 
            setupMode = setupMode == "random" and "balanced" or "random"
            initializeGrid()
        end}
    }
end

function initializeGrid()
    Grid = {}
    for i = 1, 8 do
        Grid[i] = {}
        for j = 1, 8 do
            Grid[i][j] = nil
        end
    end
    
    if setupMode == "random" then
        local pieces = {"white", "white", "white", "white", "white", "white", "white", "white", "white",
                        "black", "black", "black", "black", "black", "black", "black", "black", "black"}
        
        for i = 1, 18 do
            local x, y
            repeat
                x, y = math.random(1, 8), math.random(1, 8)
            until Grid[x][y] == nil
            Grid[x][y] = table.remove(pieces, math.random(#pieces))
        end
    else -- balanced setup
        local pieces = {"white", "white", "white", "white", "white", "white", "white", "white", "white"}
        
        -- Place white pieces randomly in the first 4 rows
        for i = 1, 9 do
            local x, y
            repeat
                x, y = math.random(1, 8), math.random(1, 4)
            until Grid[x][y] == nil
            Grid[x][y] = "white"
        end
        
        -- Mirror the positions for black pieces in the last 4 rows
        for i = 1, 8 do
            for j = 1, 4 do
                if Grid[i][j] == "white" then
                    Grid[i][9-j] = "black"
                end
            end
        end
		
		-- Mirror the last 4 rows vertically
		for i = 1, 4 do
			for j = 5, 8 do
				Grid[i][j], Grid[9-i][j] = Grid[9-i][j], Grid[i][j]
			end
		end
    end
    
    currentPlayer = "white"
	local verification = verifySetup(Grid)
	whitePieces, blackPieces = verification.whiteCount, verification.blackCount
	isSymmetrical = verification.isSymmetrical

    selectedPiece = nil
    gameOver = false
    winner = nil
    fadingPieces = {}
end

function verifySetup(grid)
    local whiteCount, blackCount = 0, 0
    local isSymmetrical = true

    for i = 1, 8 do
        for j = 1, 8 do
            if grid[i][j] == "white" then
                whiteCount = whiteCount + 1
            elseif grid[i][j] == "black" then
                blackCount = blackCount + 1
            end

            -- Check symmetry
            if grid[i][j] ~= nil and grid[9-i][9-j] == nil then
                isSymmetrical = false
            elseif grid[i][j] == "white" and grid[9-i][9-j] ~= "black" then
                isSymmetrical = false
            elseif grid[i][j] == "black" and grid[9-i][9-j] ~= "white" then
                isSymmetrical = false
            end
        end
    end

    return {
        whiteCount = whiteCount,
        blackCount = blackCount,
        isSymmetrical = isSymmetrical,
        isValid = (whiteCount == 9 and blackCount == 9 and isSymmetrical)
    }
end

function love.draw()
    -- Draw the game board
    for i = 1, 8 do
        for j = 1, 8 do
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.rectangle("fill", BOARD_OFFSET_X + (i-1)*GRID_SIZE, BOARD_OFFSET_Y + (j-1)*GRID_SIZE, GRID_SIZE, GRID_SIZE)
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("line", BOARD_OFFSET_X + (i-1)*GRID_SIZE, BOARD_OFFSET_Y + (j-1)*GRID_SIZE, GRID_SIZE, GRID_SIZE)
            
            if Grid[i][j] and not (animatingPiece and animatingPiece.fromX == i and animatingPiece.fromY == j) then
                drawPiece(i, j, Grid[i][j])
            end
        end
    end

    -- Draw fading pieces
    for _, piece in ipairs(fadingPieces) do
        drawPiece(piece.x, piece.y, piece.color, piece.alpha)
    end
    
    if animatingPiece then
        drawPiece(animatingPiece.x, animatingPiece.y, animatingPiece.color)
    end
    
    if selectedPiece then
        love.graphics.setColor(0, 1, 0, 0.5)
        love.graphics.circle("fill", 
            BOARD_OFFSET_X + (selectedPiece.x-1)*GRID_SIZE + GRID_SIZE/2, 
            BOARD_OFFSET_Y + (selectedPiece.y-1)*GRID_SIZE + GRID_SIZE/2, 
            GRID_SIZE/2 - 2)
        
        -- Show possible moves
        for i = 1, 8 do
            for j = 1, 8 do
                if isValidMove(selectedPiece.x, selectedPiece.y, i, j) then
                    love.graphics.setColor(1, 1, 0, 0.3)
                    love.graphics.circle("fill", 
                        BOARD_OFFSET_X + (i-1)*GRID_SIZE + GRID_SIZE/2, 
                        BOARD_OFFSET_Y + (j-1)*GRID_SIZE + GRID_SIZE/2, 
                        GRID_SIZE/2 - 2)
                end
            end
        end
    end

	if showBestMove and not aiThinking then
		local bestMove = findBestMove()
		if bestMove then
			love.graphics.setColor(0, 0, 1, 0.5)
			love.graphics.circle("fill", 
				BOARD_OFFSET_X + (bestMove.fromX-1)*GRID_SIZE + GRID_SIZE/2, 
				BOARD_OFFSET_Y + (bestMove.fromY-1)*GRID_SIZE + GRID_SIZE/2, 
				GRID_SIZE/2 - 2)
			love.graphics.setColor(0, 1, 0, 0.5)
			love.graphics.circle("fill", 
				BOARD_OFFSET_X + (bestMove.toX-1)*GRID_SIZE + GRID_SIZE/2, 
				BOARD_OFFSET_Y + (bestMove.toY-1)*GRID_SIZE + GRID_SIZE/2, 
				GRID_SIZE/2 - 2)
		end
	end
    
    -- Draw stats and game info
    love.graphics.setColor(1, 1, 1)
    local infoX = BOARD_OFFSET_X + 8*GRID_SIZE + 10
    local infoY = 280
    love.graphics.print("Current: " .. currentPlayer, infoX, infoY)
    love.graphics.print("White: " .. whitePieces, infoX, infoY + 20)
    love.graphics.print("Black: " .. blackPieces, infoX, infoY + 40)
    love.graphics.print("Setup: " .. setupMode, infoX, infoY + 60)
    love.graphics.print("Symmetrical: " .. tostring(isSymmetrical), infoX, infoY + 80)

    if gameOver then
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("Game Over! " .. winner .. " wins!", BOARD_OFFSET_X + 2*GRID_SIZE, BOARD_OFFSET_Y + 3*GRID_SIZE)
    end
    
    if aiThinking then
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("AI thinking...", BOARD_OFFSET_X + 2*GRID_SIZE, BOARD_OFFSET_Y - 20)
    end

	-- Draw color description on the left
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Legend:", BOARD_OFFSET_X -80, BOARD_OFFSET_Y + 10)
	love.graphics.print("From:",	  BOARD_OFFSET_X -80, BOARD_OFFSET_Y + 30)
	love.graphics.setColor(0, 0, 1, 0.5)
	love.graphics.circle("fill",	  BOARD_OFFSET_X -80 + 50, BOARD_OFFSET_Y + 40, 10)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("To:",		  BOARD_OFFSET_X -80, BOARD_OFFSET_Y + 60)
	love.graphics.setColor(0, 1, 0, 0.5)
	love.graphics.circle("fill",	  BOARD_OFFSET_X -80 + 50, BOARD_OFFSET_Y + 70, 10)

    -- Draw buttons
    for _, button in ipairs(buttons) do
		love.graphics.setColor(0.7, 0.7, 0.7)
		if button.text == "White AI Off (1)" and players.white == "ai" then
			button.text = "White AI On (1)"
		elseif button.text == "White AI On (1)" and players.white == "human" then
			button.text = "White AI Off (1)"
		end
		if button.text == "Black AI Off (2)" and players.black == "ai" then
			button.text = "Black AI On (2)"
		elseif button.text == "Black AI On (2)" and players.black == "human" then
			button.text = "Black AI Off (2)"
		end
		if button.text == "Show Move Off (b)" and showBestMove then
			button.text = "Show Move On (b)"
		elseif button.text == "Show Move On (b)" and not showBestMove then
			button.text = "Show Move Off (b)"
		end
        love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
        love.graphics.print(button.text, button.x + 5, button.y + 8)
    end
end

function drawPiece(x, y, color, alpha)
    if color == "white" then
        love.graphics.setColor(1, 1, 1, alpha or 1)
    else
        love.graphics.setColor(0, 0, 0, alpha or 1)
    end
    love.graphics.circle("fill", BOARD_OFFSET_X + (x-1)*GRID_SIZE + GRID_SIZE/2, BOARD_OFFSET_Y + (y-1)*GRID_SIZE + GRID_SIZE/2, GRID_SIZE/2 - 2)
end

function love.mousepressed(x, y, button)
    if button == 1 and not aiThinking then
        if not gameOver and players[currentPlayer] == "human" and x >= BOARD_OFFSET_X and x < BOARD_OFFSET_X + BOARD_WIDTH and y >= BOARD_OFFSET_Y and y < BOARD_OFFSET_Y + BOARD_HEIGHT then
            local gridX = math.floor((x - BOARD_OFFSET_X) / GRID_SIZE) + 1
            local gridY = math.floor((y - BOARD_OFFSET_Y) / GRID_SIZE) + 1
            if gridX >= 1 and gridX <= 8 and gridY >= 1 and gridY <= 8 then
                if not selectedPiece then
                    if Grid[gridX][gridY] == currentPlayer then
                        selectedPiece = {x = gridX, y = gridY}
                    end
                else
                    if isValidMove(selectedPiece.x, selectedPiece.y, gridX, gridY) then
                        animateMove(selectedPiece.x, selectedPiece.y, gridX, gridY)
                        selectedPiece = nil
                    else
                        selectedPiece = nil
                    end
                end
            end
        else
            -- Check if a button was clicked
            for _, button in ipairs(buttons) do
                if x >= button.x and x <= button.x + button.w and
                   y >= button.y and y <= button.y + button.h then
                    button.action()
                    break
                end
            end
        end
    end
end

function love.keypressed(key)
    if not aiThinking then
        if key == "r" then
            initializeGrid()
        elseif key == "b" then
            showBestMove = not showBestMove
        elseif key == "1" then
            players.white = players.white == "human" and "ai" or "human"
        elseif key == "2" then
            players.black = players.black == "human" and "ai" or "human"
        end
    end
end

function animateMove(fromX, fromY, toX, toY)
    animatingPiece = {
        fromX = fromX,
        fromY = fromY,
        toX = toX,
        toY = toY,
        x = fromX,
        y = fromY,
        color = Grid[fromX][fromY],
        progress = 0
    }
    
    -- Check for capture
    local dx, dy = toX - fromX, toY - fromY
    if math.abs(dx) == 2 or math.abs(dy) == 2 then
        local capturedX, capturedY = fromX + dx/2, fromY + dy/2
        table.insert(fadingPieces, {
            x = capturedX,
            y = capturedY,
            color = Grid[capturedX][capturedY],
            alpha = 1
        })
    end
end

function isValidMove(fromX, fromY, toX, toY)
	if (fromX > 0 and fromX < 9) and (fromY > 0 and fromY < 9) and (toX > 0 and toX < 9) and (toY > 0 and toY < 9) then
	
    if not Grid[toX][toY] then
        local dx, dy = toX - fromX, toY - fromY
        if math.abs(dx) <= 1 and math.abs(dy) <= 1 then
            return true
        elseif math.abs(dx) == 2 and math.abs(dy) == 0 and Grid[fromX + dx/2][fromY] and Grid[fromX + dx/2][fromY] ~= currentPlayer then
            return true
        elseif math.abs(dx) == 0 and math.abs(dy) == 2 and Grid[fromX][fromY + dy/2] and Grid[fromX][fromY + dy/2] ~= currentPlayer then
            return true
        elseif math.abs(dx) == 2 and math.abs(dy) == 2 and Grid[fromX + dx/2][fromY + dy/2] and Grid[fromX + dx/2][fromY + dy/2] ~= currentPlayer then
            return true
        end
    end
	end
    return false
end

function movePiece(fromX, fromY, toX, toY)
    Grid[toX][toY] = Grid[fromX][fromY]
    Grid[fromX][fromY] = nil
    
    local dx, dy = toX - fromX, toY - fromY
    if math.abs(dx) == 2 or math.abs(dy) == 2 then
        Grid[fromX + dx/2][fromY + dy/2] = nil
        if currentPlayer == "white" then
            blackPieces = blackPieces - 1
        else
            whitePieces = whitePieces - 1
        end
    end
    
    checkGameOver()
end

function switchPlayer()
    currentPlayer = currentPlayer == "white" and "black" or "white"
end

function checkGameOver()
    if whitePieces == 0 then
        gameOver = true
        winner = "black"
    elseif blackPieces == 0 then
        gameOver = true
        winner = "white"
    end
end

function findBestMove()
    local bestScore = -math.huge
    local bestMove = nil
    
    for i = 1, 8 do
        for j = 1, 8 do
            if Grid[i][j] == currentPlayer then
                for di = -2, 2 do
                    for dj = -2, 2 do
                        local newI, newJ = i + di, j + dj
                        if isValidMove(i, j, newI, newJ) then
                            local score = evaluateMove(i, j, newI, newJ)
                            if score > bestScore then
                                bestScore = score
                                bestMove = {fromX = i, fromY = j, toX = newI, toY = newJ}
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestMove
end

function evaluateMove(fromX, fromY, toX, toY)
    local score = 0
    local dx, dy = toX - fromX, toY - fromY
    
    if math.abs(dx) == 2 or math.abs(dy) == 2 then
        score = score + 10  -- Capturing move
    end
    
    -- Add more evaluation criteria here if needed
    
    return score
end

function love.update(dt)
    if animatingPiece then
        animatingPiece.progress = animatingPiece.progress + dt * 5
        if animatingPiece.progress >= 1 then
            movePiece(animatingPiece.fromX, animatingPiece.fromY, animatingPiece.toX, animatingPiece.toY)
            animatingPiece = nil
            switchPlayer()
        else
            animatingPiece.x = animatingPiece.fromX + (animatingPiece.toX - animatingPiece.fromX) * animatingPiece.progress
            animatingPiece.y = animatingPiece.fromY + (animatingPiece.toY - animatingPiece.fromY) * animatingPiece.progress
        end
    elseif not gameOver and players[currentPlayer] == "ai" and not aiThinking then
        aiThinking = true
        aiCoroutine = coroutine.create(function()
            local bestMove = findBestMove()
            if bestMove then
                animateMove(bestMove.fromX, bestMove.fromY, bestMove.toX, bestMove.toY)
            end
            aiThinking = false
        end)
    end

    if aiCoroutine and coroutine.status(aiCoroutine) ~= "dead" then
        local success, errorMsg = coroutine.resume(aiCoroutine)
        if not success then
            print("AI coroutine error: " .. errorMsg)
            aiThinking = false
        end
    end
    
    -- Update fading pieces
    for i = #fadingPieces, 1, -1 do
        local piece = fadingPieces[i]
        piece.alpha = piece.alpha - dt
        if piece.alpha <= 0 then
            table.remove(fadingPieces, i)
        end
    end
end
