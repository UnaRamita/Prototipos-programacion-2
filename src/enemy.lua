-- Blood Monster: enemigo con comportamiento preprogramado, manejado por una
-- maquina de estados real (src/systems/state_machine.lua) con 5 estados:
-- idle -> chase -> attack, con hurt y dead como interrupciones desde
-- cualquiera de los anteriores (ver Enemy:takeDamage). La IA es
-- deliberadamente simple: detecta por distancia, persigue en linea recta y
-- ataca cuando esta lo bastante cerca.

local Animation = require("src.animation")
local Combat = require("src.combat")
local Constants = require("src.constants")
local StateMachine = require("src.systems.state_machine")

local Enemy = {}
Enemy.__index = Enemy

local function updateFacing(enemy, dx, dy)
    if math.abs(dx) > math.abs(dy) then
        enemy.facing = dx > 0 and "right" or "left"
    else
        enemy.facing = dy > 0 and "down" or "up"
    end
    if dx ~= 0 then enemy.flipX = dx < 0 end
end

local function distanceToPlayer(enemy)
    local player = enemy.player
    local dx, dy = player.x - enemy.x, player.y - enemy.y
    return dx, dy, math.sqrt(dx * dx + dy * dy)
end

-- ===== Estados del enemigo =====
-- Cada fabrica cierra sobre "enemy". enemy.player/enemy.solids los setea
-- Enemy:update cada frame (ver mas abajo), asi los estados no necesitan
-- recibirlos como parametro.
local EnemyStates = {}

function EnemyStates.idle(enemy)
    return {
        ingresar = function()
            enemy.currentAnim = enemy.idleAnim
        end,
        actualizar = function()
            local _, _, dist = distanceToPlayer(enemy)
            if dist <= Constants.ENEMY_DETECT_RANGE then
                enemy.machine:cambiar("chase")
            end
        end,
    }
end

function EnemyStates.chase(enemy)
    return {
        ingresar = function()
            enemy.currentAnim = enemy.walkAnim
        end,
        actualizar = function(_, dt)
            local dx, dy, dist = distanceToPlayer(enemy)

            if dist > Constants.ENEMY_LOSE_INTEREST_RANGE then
                enemy.machine:cambiar("idle")
                return
            end

            if dist > 0.001 then updateFacing(enemy, dx, dy) end

            if dist <= Constants.ENEMY_ATTACK_RANGE and enemy.attackCooldown <= 0 then
                enemy.machine:cambiar("attack")
                return
            end

            if dist > Constants.ENEMY_ATTACK_RANGE * 0.7 then
                local nx, ny = dx / dist, dy / dist
                Combat.moveWithCollision(enemy, nx * enemy.speed * dt, ny * enemy.speed * dt, enemy.solids)
            end

            enemy.walkAnim:update(dt)
            enemy.currentAnim = enemy.walkAnim
        end,
    }
end

function EnemyStates.attack(enemy)
    return {
        ingresar = function()
            enemy.attackTimer = 0
            enemy.attackHitActive = false
            enemy.hitLandedThisSwing = false
            enemy.attackAnim:reset()
            enemy.currentAnim = enemy.attackAnim
        end,
        actualizar = function(_, dt)
            enemy.attackTimer = enemy.attackTimer + dt
            enemy.attackAnim:update(dt)
            enemy.attackHitActive = enemy.attackTimer >= Constants.ENEMY_ATTACK_HIT_START
                and enemy.attackTimer <= Constants.ENEMY_ATTACK_HIT_END

            local dx, dy, dist = distanceToPlayer(enemy)
            if dist > 0.001 then updateFacing(enemy, dx, dy) end

            if enemy.attackAnim:isFinished() then
                enemy.attackCooldown = Constants.ENEMY_ATTACK_COOLDOWN
                enemy.attackHitActive = false
                enemy.machine:cambiar("chase")
            end
        end,
    }
end

function EnemyStates.hurt(enemy)
    return {
        ingresar = function()
            enemy.hurtTimer = Constants.ENEMY_HURT_TIME
            enemy.currentAnim = enemy.idleAnim
        end,
        actualizar = function(_, dt)
            enemy.hurtTimer = enemy.hurtTimer - dt
            if enemy.hurtTimer <= 0 then
                enemy.machine:cambiar("idle")
            end
        end,
    }
end

function EnemyStates.dead(enemy)
    return {
        ingresar = function()
            enemy.attackHitActive = false
            enemy.flickerTimer = 0
            enemy.removed = false
            enemy.deathAnim:reset()
            enemy.currentAnim = enemy.deathAnim
        end,
        -- El titileo y la desaparicion final se resuelven aca dentro (en vez
        -- de en Enemy:update) para que "que pasa mientras se esta muriendo"
        -- quede todo en un solo lugar, como el resto de los estados.
        actualizar = function(_, dt)
            if not enemy.deathAnim:isFinished() then
                enemy.deathAnim:update(dt)
            else
                enemy.flickerTimer = enemy.flickerTimer + dt
                if enemy.flickerTimer >= Constants.ENEMY_FLICKER_TIME then
                    enemy.removed = true
                end
            end
        end,
    }
end

function Enemy.new(assets, x, y)
    local self = setmetatable({}, Enemy)
    local imgs = assets.images
    local footRow = assets.footRow

    self.x, self.y = x, y
    self.colliderW = Constants.ENEMY_COLLIDER_W
    self.colliderH = Constants.ENEMY_COLLIDER_H
    self.speed = Constants.ENEMY_SPEED
    self.scale = Constants.CHARACTER_SCALE

    self.maxHp = Constants.ENEMY_MAX_HP
    self.hp = self.maxHp

    self.facing = "left"
    self.flipX = true

    self.active = true  -- los enemigos de la sala 2 arrancan inactivos (ver Game.setupEntities)
    self.player = nil   -- referencia al jugador, la setea Enemy:update cada frame
    self.solids = {}    -- lista de rects solidos del frame actual, la setea Enemy:update

    self.walkAnim = Animation.new(imgs.monsterWalk, 100, 100, 8, 0.1, true, footRow.monsterWalk)
    self.idleAnim = Animation.new(imgs.monsterWalk, 100, 100, 1, 999, false, footRow.monsterWalk)
    self.attackAnim = Animation.new(imgs.monsterAttack, 100, 100, 8, 0.07, false, footRow.monsterAttack)
    self.deathAnim = Animation.new(imgs.monsterDeath, 100, 100, 4, 0.15, false, footRow.monsterDeath)
    self.currentAnim = self.idleAnim

    self.attackDamage = Constants.ENEMY_ATTACK_DAMAGE -- lo lee Game.resolveCombat (cada tipo de enemigo trae el suyo)
    self.attackTimer = 0
    self.attackCooldown = 0
    self.attackHitActive = false
    self.hitLandedThisSwing = false

    self.hurtTimer = 0
    self.hurtFlashTimer = 0

    self.knockbackX, self.knockbackY = 0, 0
    self.knockbackTimer = 0

    self.flickerTimer = 0 -- cuenta el titileo post-animacion antes de desaparecer
    self.removed = false  -- true cuando ya termino todo (animacion + titileo): deja de dibujarse

    self.machine = StateMachine.new({
        idle = function() return EnemyStates.idle(self) end,
        chase = function() return EnemyStates.chase(self) end,
        attack = function() return EnemyStates.attack(self) end,
        hurt = function() return EnemyStates.hurt(self) end,
        dead = function() return EnemyStates.dead(self) end,
    })
    self.machine:cambiar("idle")

    return self
end

function Enemy:isAlive()
    return not self.machine:es("dead")
end

function Enemy:isAttackHitActive()
    return self.machine:es("attack") and self.attackHitActive and not self.hitLandedThisSwing
end

function Enemy:getAttackHitbox()
    return Combat.attackHitbox(self, Constants.ENEMY_ATTACK_RANGE, Constants.ENEMY_ATTACK_WIDTH)
end

function Enemy:registerHitOnPlayer()
    self.hitLandedThisSwing = true
end

function Enemy:takeDamage(amount, fromX, fromY)
    if self.machine:es("dead") then return end

    self.hp = math.max(0, self.hp - amount)
    self.hurtFlashTimer = 0.35

    if fromX and fromY then
        local dx, dy = self.x - fromX, self.y - fromY
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.001 then
            self.knockbackX = (dx / len) * 110
            self.knockbackY = (dy / len) * 110
            self.knockbackTimer = 0.15
        end
    end

    if self.hp <= 0 then
        self.machine:cambiar("dead")
        return
    end

    self.machine:cambiar("hurt")
end

function Enemy:update(dt, player, solids)
    self.player = player
    self.solids = solids

    if self.machine:es("dead") then
        if not self.removed then
            self.machine:actualizar(dt)
        end
        return
    end

    if self.hurtFlashTimer > 0 then self.hurtFlashTimer = self.hurtFlashTimer - dt end
    if self.attackCooldown > 0 then self.attackCooldown = self.attackCooldown - dt end

    -- Empujon al recibir daño (se aplica sin importar el estado, salvo muerto)
    if self.knockbackTimer > 0 then
        self.knockbackTimer = self.knockbackTimer - dt
        Combat.moveWithCollision(self, self.knockbackX * dt, self.knockbackY * dt, solids)
    end

    self.machine:actualizar(dt)
end

function Enemy:draw()
    if self.removed then return end

    -- Titileo corto justo antes de desaparecer (una vez termino la animacion de muerte)
    if self.machine:es("dead") and self.deathAnim:isFinished() then
        local visible = math.floor(self.flickerTimer * 16) % 2 == 0
        if not visible then return end
    end

    local r, g, b = 1, 1, 1
    if not self.machine:es("dead") and self.hurtFlashTimer > 0 then
        r, g, b = 1.6, 1.6, 1.6 -- flash blanco/sobreexpuesto al recibir daño
    end
    self.currentAnim:draw(self.x, self.y, self.flipX, self.scale, r, g, b, 1)
end

return Enemy
