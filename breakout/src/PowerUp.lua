KEY_POWER = 9
BALL_POWER = 6

Powerup = Class()

function Powerup:init(x, y, power)
    self.width = 16
    self.height = 16

    self.x = x
    self.y = y

    self.dy = 30

    self.power = power

    self.timer = 0
    self.withAlpha = true
end

function Powerup:collides(target)
    if self.x > target.x + target.Width or target.x > self.x + self.width then
        return false
    end

    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end

    return true
end

function Powerup:update(dt)
    self.y = self.y + self.dy * dt

    self.timer = self.timer + dt
    if (self.timer > 0.5) then
        self.timer = 0
        self.withAlpha = not self.withAlpha
    end
end

function Powerup:render()
    if (self.withAlpha) then
        love.graphics.setColor(255, 255, 255, 100)
    end
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.power], self.x, self.y)
    love.graphics.setColor(255, 255, 255, 255)
end