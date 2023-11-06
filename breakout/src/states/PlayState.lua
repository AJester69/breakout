--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.level = params.level
    self.recoverPoints = params.recoverPoints

    self.keyMode = params.keyMode

    self.powerups = {}

    self.balls = {}

    -- give ball random starting velocity
    params.ball.dx = math.random(-200, 200)
    params.ball.dy = math.random(-50, -60)
    self.balls[1] = params.ball
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    for i = #self.powerups, 1, -1 do
        self.powerups[i]:update(dt)
        if self.powerups[i]:collides(self.paddle) then

           gSounds['Powerup_pickup']:stop()
           gSounds['Powerup_pickup']:play()
           if self.powerups[i].power == BALL_POWER then
                local n = #self.balls
                for i = n + 1, math.min(100, n + 2) do
                    local ball = Ball()
                    ball.skin = math.random(7)
                    ball.x = self.paddle.x + (self.paddle.width / 2)
                    ball.y = self.paddle.y - 8
                    ball.dx = math.random(-200, 200)
                    ball.dy = math.random(-50, -60)
                    self.balls[i] = ball
                end
            elseif self.powerups[i].power == KEY_POWER then
                self.keyMode = 2
            end
            table.remove(self.powerups, i)
        elseif self.powerups[i].y >= VIRTUAL_HEIGHT then
            table.remove(self.powerups, i)
        end
    end


    for i = #self.balls, 1, -1 do
        self.balls[i]:update(dt)
        if self.balls[i]:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            self.balls[i].y = self.paddle.y - 8
            self.balls[i].dy = -self.balls[i].dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if self.balls[i].x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                self.balls[i].dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - self.balls[i].x))

            -- else if we hit the paddle on its right side while moving right...
            elseif self.balls[i].x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                self.balls[i].dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - self.balls[i].x))
            end

            gSounds['paddle-hit']:play()
        end

        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and self.balls[i]:collides(brick) then

                if (not brick:isLocked() or self.keyMode > 1) then
                    brick:hit()

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                    self.paddle:changeSize(true)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                local powerupNew = nil
                local randomValue = math.random()
                if (self.keyMode == 1 and randomValue < 0.04) then
                    powerupNew = Powerup(brick.x, brick.y, KEY_POWER)
                elseif randomValue > 0.96 then
                    powerupNew = Powerup(brick.x, brick.y, BALL_POWER)
                end

                if powerupNew ~= nil then
                    table.insert(self.powerups, powerupNew)
                    gSounds ['Powerup_spawan']:stop()
                    gSounds ['Powerup_spawan']:play()
                end

                -- go to our victory screen if there are no more bricks left
                if not brick.inPlay and self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.balls[i],
                        recoverPoints = self.recoverPoints
                    })
                end
            end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if self.balls[i].x + 2 < brick.x and self.balls[i].dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.balls[i].dx = -self.balls[i].dx
                    self.balls[i].x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif self.balls[i].x + 6 > brick.x + brick.width and self.balls[i].dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    self.balls[i].dx = -self.balls[i].dx
                    self.balls[i].x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif self.balls[i].y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    self.balls[i].dy = -self.balls[i].dy
                    self.balls[i].y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    self.balls[i].dy = -self.balls[i].dy
                    self.balls[i].y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(self.balls[i].dy) < 150 then
                    self.balls[i].dy = self.balls[i].dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end

        -- if ball goes below bounds, revert to serve state and decrease health
        if self.balls[i].y >= VIRTUAL_HEIGHT then
            gSounds['hurt']:play()
            table.remove(self.balls, i)
        end
    end
    if (#self.balls < 1) then
        self.health = self.health - 1
            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                self.paddle:changeSize(false)

                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints,
                    keyMode = self.keyMode
                })
            end
        end

        -- for rendering particle systems
        for k, brick in pairs(self.bricks) do
            brick:update(dt)
        end

        if love.keyboard.wasPressed('escape') then
            love.event.quit()
        end
    end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for k, powerup in pairs(self.powerups) do
        powerup:render()
    end

    for k, ball in pairs(self.balls) do
        ball:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    if self.keyMode == 2 then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][KEY_POWER], VIRTUAL_WIDTH - 123, 1)
    end
    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    local hasLocked = false

    for k, Brick in pairs(self.bricks) do
        if Brick.inPlay then
            if Brick:isLocked() then
                hasLocked = true
            else
                return false
            end
        end
    end

    if not hasLocked then
        return true
    elseif self.keyMode < 2 then
        for k, brick in pairs(self.bricks) do
            if not brick.inPlay and not brick:isLocked() then
                brick.inPlay = true
                    
                self.score = self.score - (brick.tier * 200 + brick.color * 25)

                table.insert(self.powerups, Powerup(brick.x, brick.y, KEY_POWER))
                gSounds ['Powerup_spawan']:stop()
                gSounds ['Powerup_spawan']:play()
            end
        end
    end
    return false
end