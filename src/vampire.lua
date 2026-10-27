-- Vampire: segundo tipo de enemigo, con la misma forma/interfaz publica que
-- Enemy (src/enemy.lua) -- :isAlive(), :isAttackHitActive(), :getAttackHitbox(),
-- :registerHitOnPlayer(), :takeDamage(), :update(dt, player, solids), :draw(),
-- campos .x/.y/.active/.attackDamage/.colliderW/.colliderH -- para que Game.enemies pueda
-- mezclar Blood Monsters y Vampires en una sola lista sin que game.lua,
-- GameplayState ni Combat tengan que distinguirlos (duck typing: ya es como
-- esos modulos tratan a cualquier "enemigo", ver src/states/gameplay_state.lua).
--
-- Lo que lo diferencia de Enemy es su secuencia de ataque: en vez de jugar
-- una animacion fija con una ventana de daño a mitad de camino, el estado
-- "attack" arranca una CORRUTINA real (coroutine.create/resume/yield, via
-- src/systems/coroutine_runner.lua) que recorre tres fases --
-- preparacion (se queda quieto, avisando el golpe) -> ataque (embestida en
-- linea recta hacia el jugador) -> recuperacion (vulnerable, no puede
-- volver a atacar de inmediato) -- antes de volver a "chase" y reevaluar.
-- Es el equivalente Lua al patron de Unity IEnumerator + StartCoroutine +
-- WaitForSeconds.

local Animation = require("src.animation")
local Combat = require("src.combat")
local Constants = require("src.constants")
local StateMachine = require("src.systems.state_machine")
local CoroutineRunner = require("src.systems.coroutine_runner")

local Vampire = {}
Vampire.__index = Vampire

local function updateFacing(vampire, dx, dy)
    if math.abs(dx) > math.abs(dy) then
        vampire.facing = dx > 0 and "right" or "left"
    else
        vampire.facing = dy > 0 and "down" or "up"
    end
    if dx ~= 0 then vampire.flipX = dx < 0 end
end

local function distanceToPlayer(vampire)
    local player = vampire.player
    local dx, dy = player.x - vampire.x, player.y - vampire.y
    return dx, dy, math.sqrt(dx * dx + dy * dy)
end

-- ===== Estados del vampiro =====
local VampireStates = {}

-- Mientras no detecta al jugador, patrulla en linea recta: camina hacia un
-- lado (vampire.patrolDir, +1 derecha / -1 izquierda) hasta chocar una
-- pared, ahi invierte direccion y vuelve, asi indefinidamente. Reutiliza
-- Combat.moveWithCollision igual que el resto de los estados; "choco una
-- pared" se detecta comparando cuanto se movio de verdad contra cuanto
-- queria moverse -- si quedo muy por debajo, es que se topo con algo.
local function patrol(vampire, dt)
    local intendedDx = vampire.patrolDir * Constants.VAMPIRE_PATROL_SPEED * dt
    local beforeX = vampire.x

    Combat.moveWithCollision(vampire, intendedDx, 0, vampire.solids)

    if math.abs(vampire.x - beforeX) < math.abs(intendedDx) * 0.5 then
        vampire.patrolDir = -vampire.patrolDir
    end

    vampire.facing = (vampire.patrolDir > 0) and "right" or "left"
    vampire.flipX = vampire.patrolDir < 0
end

function VampireStates.idle(vampire)
    return {
        ingresar = function()
            vampire.currentAnim = vampire.moveAnim
        end,
        actualizar = function(_, dt)
            vampire.moveAnim:update(dt)
            patrol(vampire, dt)

            local _, _, dist = distanceToPlayer(vampire)
            if dist <= Constants.VAMPIRE_DETECT_RANGE then
                vampire.machine:cambiar("chase")
            end
        end,
    }
end

function VampireStates.chase(vampire)
    return {
        ingresar = function()
            vampire.currentAnim = vampire.moveAnim
        end,
        actualizar = function(_, dt)
            local dx, dy, dist = distanceToPlayer(vampire)

            if dist > Constants.VAMPIRE_LOSE_INTEREST_RANGE then
                vampire.machine:cambiar("idle")
                return
            end

            if dist > 0.001 then updateFacing(vampire, dx, dy) end

            if dist <= Constants.VAMPIRE_ATTACK_TRIGGER_RANGE and vampire.attackCooldown <= 0 then
                vampire.machine:cambiar("attack")
                return
            end

            if dist > Constants.VAMPIRE_ATTACK_TRIGGER_RANGE * 0.6 then
                local nx, ny = dx / dist, dy / dist
                Combat.moveWithCollision(vampire, nx * vampire.speed * dt, ny * vampire.speed * dt, vampire.solids)
            end

            vampire.moveAnim:update(dt)
        end,
    }
end

-- Preparacion -> ataque -> recuperacion, manejado por una corrutina real
-- (ver src/systems/coroutine_runner.lua). El estado solo se encarga de
-- arrancarla en ingresar(), resumirla en actualizar() y cortarla en
-- salir() si algo la interrumpe (p. ej. el vampiro queda "hurt" o muere a
-- mitad de la secuencia) -- asi nunca sigue moviendose ni aplicando daño
-- despues de una interrupcion.
function VampireStates.attack(vampire)
    return {
        ingresar = function()
            vampire.hitLandedThisSwing = false
            vampire.attackPhase = "windup"
            vampire.attackAnim:reset()
            vampire.currentAnim = vampire.attackAnim

            vampire.attackCoroutine:start(function()
                -- 1) Preparacion: queda quieto un instante, telegrafiando
                -- el golpe (el jugador tiene esta ventana para reaccionar).
                coroutine.yield(Constants.VAMPIRE_WINDUP_TIME)

                -- 2) Ataque: embestida en linea recta hacia donde este el
                -- jugador en ESTE instante (se apunta una sola vez, no cuadro
                -- a cuadro: es un golpe comprometido, no un misil teledirigido).
                vampire.attackPhase = "strike"
                local dx, dy, dist = distanceToPlayer(vampire)
                if dist > 0.001 then
                    updateFacing(vampire, dx, dy)
                    vampire.lungeDirX, vampire.lungeDirY = dx / dist, dy / dist
                else
                    vampire.lungeDirX, vampire.lungeDirY = 0, 0
                end

                local elapsed = 0
                while elapsed < Constants.VAMPIRE_LUNGE_TIME do
                    -- yield() sin argumentos = "esperar un cuadro"; devuelve
                    -- el dt de ESE cuadro (ver CoroutineRunner).
                    local frameDt = coroutine.yield()
                    elapsed = elapsed + frameDt
                    Combat.moveWithCollision(
                        vampire,
                        vampire.lungeDirX * Constants.VAMPIRE_LUNGE_SPEED * frameDt,
                        vampire.lungeDirY * Constants.VAMPIRE_LUNGE_SPEED * frameDt,
                        vampire.solids
                    )
                end

                -- 3) Recuperacion: vulnerable, no vuelve a atacar de inmediato.
                vampire.attackPhase = "recover"
                coroutine.yield(Constants.VAMPIRE_RECOVER_TIME)
            end)
        end,
        actualizar = function(_, dt)
            vampire.attackAnim:update(dt)
            vampire.attackCoroutine:update(dt)

            -- Sigue mirando al jugador durante preparacion/recuperacion (no
            -- durante la embestida: ahi la direccion ya quedo fijada).
            if vampire.attackPhase ~= "strike" then
                local dx, dy, dist = distanceToPlayer(vampire)
                if dist > 0.001 then updateFacing(vampire, dx, dy) end
            end

            -- La corrutina murio sola (recorrio las 3 fases sin que nada la
            -- interrumpiera): volver a perseguir y reevaluar.
            if not vampire.attackCoroutine:isRunning() then
                vampire.attackCooldown = Constants.VAMPIRE_ATTACK_COOLDOWN
                vampire.machine:cambiar("chase")
            end
        end,
        salir = function()
            -- Corta la secuencia si se interrumpio por hurt/dead (ver nota
            -- en CoroutineRunner:stop). Sin esto, un vampiro "lastimado" a
            -- mitad de la embestida seguiria empujandose solo y, peor, un
            -- vampiro MUERTO podria seguir aplicando daño durante el resto
            -- de la secuencia -- exactamente lo que pide evitar la consigna.
            vampire.attackCoroutine:stop()
            vampire.attackPhase = nil
        end,
    }
end

function VampireStates.hurt(vampire)
    return {
        ingresar = function()
            vampire.hurtTimer = Constants.VAMPIRE_HURT_TIME
            vampire.currentAnim = vampire.moveAnim
        end,
        actualizar = function(_, dt)
            vampire.hurtTimer = vampire.hurtTimer - dt
            if vampire.hurtTimer <= 0 then
                vampire.machine:cambiar("idle")
            end
        end,
    }
end

function VampireStates.dead(vampire)
    return {
        ingresar = function()
            -- Defensivo: si por algun motivo quedara una corrutina de
            -- ataque corriendo (no deberia, takeDamage siempre pasa por
            -- attack:salir() antes de llegar aca), se corta aca tambien.
            vampire.attackCoroutine:stop()
            vampire.attackHitActive = false
            vampire.flickerTimer = 0
            vampire.removed = false
            vampire.deathAnim:reset()
            vampire.currentAnim = vampire.deathAnim
        end,
        actualizar = function(_, dt)
            if not vampire.deathAnim:isFinished() then
                vampire.deathAnim:update(dt)
            else
                vampire.flickerTimer = vampire.flickerTimer + dt
                if vampire.flickerTimer >= Constants.ENEMY_FLICKER_TIME then
                    vampire.removed = true
                end
            end
        end,
    }
end

function Vampire.new(assets, x, y)
    local self = setmetatable({}, Vampire)
    local imgs = assets.images
    local footRow = assets.footRow

    self.x, self.y = x, y
    self.colliderW = Constants.VAMPIRE_COLLIDER_W
    self.colliderH = Constants.VAMPIRE_COLLIDER_H
    self.speed = Constants.VAMPIRE_SPEED
    self.scale = Constants.VAMPIRE_SCALE

    self.maxHp = Constants.VAMPIRE_MAX_HP
    self.hp = self.maxHp

    self.facing = "left"
    self.flipX = true

    self.active = true -- igual que Enemy: los spawns de la sala 2 arrancan inactivos (ver Game.setupEntities)
    self.player = nil
    self.solids = {}

    -- Direccion de la patrulla en "idle" (ver la funcion local patrol):
    -- +1 arranca yendo a la derecha, -1 a la izquierda. Se sortea para que
    -- varios vampires en la misma sala no patrullen todos sincronizados.
    self.patrolDir = (love.math.random() < 0.5) and -1 or 1

    -- Un solo sheet sirve para idle/caminar (no hay walk separado en los
    -- assets de este enemigo, ver Assets/Vampire enemy): se reutiliza la
    -- misma animacion en ambos estados, igual de valido que tener dos.
    self.moveAnim = Animation.new(imgs.vampireIdle, 32, 32, 6, 0.12, true, footRow.vampireIdle)

    -- La tira de ataque (16 frames) ya trae horneadas las 3 fases
    -- (preparacion/embestida/recuperacion) como pose dibujada; su duracion
    -- total se hace coincidir con la suma de los tiempos de la corrutina
    -- para que la animacion y la secuencia logica avancen sincronizadas sin
    -- tener que mapear a mano que frame corresponde a cada fase.
    local totalAttackTime = Constants.VAMPIRE_WINDUP_TIME + Constants.VAMPIRE_LUNGE_TIME + Constants.VAMPIRE_RECOVER_TIME
    self.attackAnim = Animation.new(imgs.vampireAttack, 32, 32, 16, totalAttackTime / 16, false, footRow.vampireAttack)
    self.deathAnim = Animation.new(imgs.vampireDeath, 32, 32, 14, 0.05, false, footRow.vampireDeath)
    self.currentAnim = self.moveAnim

    self.attackDamage = Constants.VAMPIRE_ATTACK_DAMAGE -- lo lee Game.resolveCombat (mas daño que el Blood Monster)
    self.attackCooldown = 0
    self.attackPhase = nil         -- nil | "windup" | "strike" | "recover" (ver VampireStates.attack)
    self.hitLandedThisSwing = false
    self.lungeDirX, self.lungeDirY = 0, 0
    self.attackCoroutine = CoroutineRunner.new()

    self.hurtTimer = 0
    self.hurtFlashTimer = 0

    self.knockbackX, self.knockbackY = 0, 0
    self.knockbackTimer = 0

    self.flickerTimer = 0
    self.removed = false

    self.machine = StateMachine.new({
        idle = function() return VampireStates.idle(self) end,
        chase = function() return VampireStates.chase(self) end,
        attack = function() return VampireStates.attack(self) end,
        hurt = function() return VampireStates.hurt(self) end,
        dead = function() return VampireStates.dead(self) end,
    })
    self.machine:cambiar("idle")

    return self
end

function Vampire:isAlive()
    return not self.machine:es("dead")
end

function Vampire:isAttackHitActive()
    return self.machine:es("attack") and self.attackPhase == "strike" and not self.hitLandedThisSwing
end

function Vampire:getAttackHitbox()
    return Combat.attackHitbox(self, Constants.VAMPIRE_ATTACK_HIT_RANGE, Constants.VAMPIRE_ATTACK_WIDTH)
end

function Vampire:registerHitOnPlayer()
    self.hitLandedThisSwing = true
end

function Vampire:takeDamage(amount, fromX, fromY)
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

    -- machine:cambiar() llama primero a salir() del estado actual: si esto
    -- pasa durante "attack", VampireStates.attack.salir() corta la
    -- corrutina antes de que se registre el daño/la muerte (ver esa nota).
    if self.hp <= 0 then
        self.machine:cambiar("dead")
        return
    end

    self.machine:cambiar("hurt")
end

function Vampire:update(dt, player, solids)
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

    if self.knockbackTimer > 0 then
        self.knockbackTimer = self.knockbackTimer - dt
        Combat.moveWithCollision(self, self.knockbackX * dt, self.knockbackY * dt, solids)
    end

    self.machine:actualizar(dt)
end

function Vampire:draw()
    if self.removed then return end

    if self.machine:es("dead") and self.deathAnim:isFinished() then
        local visible = math.floor(self.flickerTimer * 16) % 2 == 0
        if not visible then return end
    end

    local r, g, b = 1, 1, 1
    if not self.machine:es("dead") and self.hurtFlashTimer > 0 then
        r, g, b = 1.6, 1.6, 1.6
    end
    self.currentAnim:draw(self.x, self.y, self.flipX, self.scale, r, g, b, 1)
end

return Vampire
