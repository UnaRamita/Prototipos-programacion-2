-- Orquestador principal. Ya no guarda el estado del juego en un string
-- (playing/victory/defeat): eso ahora lo maneja Game.machine, una
-- StateMachine real (src/systems/state_machine.lua) con tres estados
-- (src/states/*.lua). Game.lua queda como el "mundo": crea las entidades a
-- partir de los datos de Dungeon (mapa de teselas via STI) y expone los
-- helpers que los estados necesitan (colisiones, combate, camara), porque
-- son datos/logica del nivel, no de un estado puntual.

local Assets = require("src.assets")
local Constants = require("src.constants")
local Combat = require("src.combat")
local Dungeon = require("src.dungeon")
local Door = require("src.door")
local Player = require("src.player")
local Enemy = require("src.enemy")
local Vampire = require("src.vampire")
local Chest = require("src.chest")
local HeartPickup = require("src.heart_pickup")
local StateMachine = require("src.systems.state_machine")
local Events = require("src.systems.events")
require("src.systems.audio_system") -- se suscribe solo al cargarse; no se usa su valor de retorno
local Camera = require("lib.hump.camera")
local Timer = require("lib.hump.timer")

local GameplayState = require("src.states.gameplay_state")
local PauseState = require("src.states.pause_state")
local VictoryState = require("src.states.victory_state")
local DefeatState = require("src.states.defeat_state")

local Game = {}

Game.LEVEL_COUNT = 2 -- 1: mapa fijo (Tiled) | 2: mapa procedural (ver src/procedural_dungeon.lua)
Game.level = 1

Game.player = nil
Game.enemies = {}
Game.door = nil
Game.chest = nil
Game.key = nil          -- nil hasta que se derrota a todos los enemigos
Game.keySpawned = false
Game.hasKey = false
Game.healthPickup = nil -- nil hasta que se completa la sala (ver ROOM_COMPLETED)
Game.healSpawned = false
Game.message = nil      -- { text = ... } feedback transitorio (llave/cofre); lo limpia Game.timer

Game.timer = Timer.new()  -- eventos temporales de gameplay (ver Game.showMessage)
Game.camera = Camera(0, 0) -- sigue al jugador durante el gameplay (ver Game.updateCamera)

Game.machine = StateMachine.new({
    gameplay = function() return GameplayState.new(Game) end,
    pause = function() return PauseState.new(Game) end,
    victory = function() return VictoryState.new(Game) end,
    defeat = function() return DefeatState.new(Game) end,
})

-- Arma una partida nueva: jugador, puerta, cofre y enemigos ubicados en los
-- spawns que vienen del mapa de teselas (Dungeon.playerSpawn, etc, leidos
-- de la capa de objetos de Tiled). La llama GameplayState:ingresar(), tanto
-- al arrancar el juego como al reiniciar despues de ganar/perder.
function Game.setupEntities()
    Game.player = Player.new(Assets, Dungeon.playerSpawn.x, Dungeon.playerSpawn.y)
    Game.door = Door.new(Dungeon.doorRect, Assets.images.doorSide)
    Game.chest = Chest.new(Dungeon.chestPos.x, Dungeon.chestPos.y, Assets.images.chest, Constants.CHEST_SCALE)
    Game.key = nil
    Game.keySpawned = false
    Game.hasKey = false
    Game.healthPickup = nil
    Game.healSpawned = false
    Game.message = nil
    Game.timer:clear()

    Game.enemies = {}
    for _, s in ipairs(Dungeon.enemySpawnsRoom1) do
        table.insert(Game.enemies, Game.spawnEnemy(s))
    end
    for _, s in ipairs(Dungeon.enemySpawnsRoom2) do
        local enemy = Game.spawnEnemy(s)
        enemy.active = false -- se activan cuando se abre la puerta (ver GameplayState:actualizar)
        table.insert(Game.enemies, enemy)
    end
end

-- Instancia el enemigo que corresponda segun s.kind (leido de la propiedad
-- "enemy" del objeto "enemy_spawn" en el mapa, ver Dungeon.loadObjects).
-- Enemy (Blood Monster) y Vampire comparten exactamente la misma interfaz
-- publica, asi que el resto del juego (Game.resolveCombat, el orden de
-- dibujado, Game.allEnemiesDead) no necesita saber cual es cual.
local ENEMY_TYPES = {
    blood_monster = Enemy,
    vampire = Vampire,
}

function Game.spawnEnemy(spawn)
    local EnemyType = ENEMY_TYPES[spawn.kind] or Enemy
    return EnemyType.new(Assets, spawn.x, spawn.y)
end

-- "RewardSystem": lo unico que hace es escuchar ROOM_COMPLETED y generar
-- el corazon de recuperacion junto a la salida. Vive ahi, no en
-- GameplayState, porque GameplayState no necesita saber nada de corazones
-- ni de Dungeon.healSpawnPos -- solo le avisa a quien escuche que la sala
-- se completo (ver GameplayState:actualizar). Se suscribe una sola vez, al
-- cargarse este modulo (no hay riesgo de duplicar la suscripcion ni de
-- dejarla colgada: Game.lua se require() una unica vez y vive toda la
-- partida, a diferencia de Player/Enemy que se recrean por nivel).
Events:on(Events.ROOM_COMPLETED, function()
    if Game.healSpawned then return end
    Game.healSpawned = true
    Game.healthPickup = HeartPickup.new(
        Dungeon.healSpawnPos.x, Dungeon.healSpawnPos.y,
        Assets.images.heartFull, Constants.HEART_PICKUP_SCALE
    )
end)

-- Carga el mapa correspondiente al nivel (1: fijo via Tiled, 2+: generado
-- proceduralmente) y arma las entidades sobre el. La llama
-- GameplayState:ingresar(), tanto al arrancar el juego (nivel 1) como al
-- pasar de nivel (cofre del nivel 1 -> nivel 2) o al reiniciar (siempre
-- vuelve a nivel 1).
function Game.setupLevel(level)
    Game.level = level
    if level == 1 then
        Dungeon.load()
    else
        Dungeon.loadProcedural()
    end
    Game.setupEntities()
end

function Game.hasNextLevel()
    return Game.level < Game.LEVEL_COUNT
end

function Game.load()
    Assets.load()
    Game.machine:cambiar("gameplay")
end

-- Mensaje transitorio centrado (ej: "¡Llave obtenida!"). Antes esto se
-- resolvia con un contador manual (message.timer restado a mano en
-- Game.update); ahora lo programa lib/hump/timer, que es exactamente para
-- esto: "hace X despues de N segundos".
function Game.showMessage(text, duration)
    Game.message = { text = text }
    Game.timer:after(duration, function()
        Game.message = nil
    end)
end

-- true cuando no queda ningun enemigo vivo en ninguna de las dos salas.
function Game.allEnemiesDead()
    for _, enemy in ipairs(Game.enemies) do
        if enemy:isAlive() then return false end
    end
    return true
end

function Game.buildSolids()
    local solids = {}
    for _, w in ipairs(Dungeon.walls) do
        solids[#solids + 1] = w
    end
    if Game.door:isBlocking() then
        solids[#solids + 1] = Game.door:getCollisionRect()
    end
    return solids
end

function Game.resolveCombat()
    local player = Game.player

    -- Ataque del jugador contra los enemigos dentro del hitbox activo
    if player:isAttackHitActive() then
        local hitbox = player:getAttackHitbox()
        for _, enemy in ipairs(Game.enemies) do
            if enemy:isAlive() and not player:hasHit(enemy) then
                if Combat.aabbOverlap(hitbox, Combat.colliderRect(enemy)) then
                    enemy:takeDamage(Constants.PLAYER_ATTACK_DAMAGE, player.x, player.y)
                    player:registerHit(enemy)
                    Assets.playSound(Assets.sounds.hit)
                end
            end
        end
    end

    -- Se cerro la ventana de golpe sin conectar ningun ataque: sonido de fallo
    if player.attackWindowJustClosed and not player:didLandAnyHit() then
        Assets.playSound(Assets.sounds.miss)
    end

    -- Ataques de los enemigos contra el jugador. El sonido de golpe ya NO
    -- se reproduce aca: lo dispara src/systems/audio_system.lua, escuchando
    -- PLAYER_DAMAGED (emitido desde Player:takeDamage SOLO cuando el daño
    -- realmente se aplica -- no si el jugador estaba invulnerable).
    for _, enemy in ipairs(Game.enemies) do
        if enemy:isAttackHitActive() then
            if Combat.aabbOverlap(enemy:getAttackHitbox(), Combat.colliderRect(player)) then
                player:takeDamage(enemy.attackDamage or Constants.ENEMY_ATTACK_DAMAGE, enemy.x, enemy.y)
                enemy:registerHitOnPlayer()
            end
        end
    end
end

-- Centra la camara (lib/hump/camera) en el jugador, recortando la posicion
-- para que nunca se vea mas alla del borde del mapa de teselas.
--
-- Si el nivel es MAS CHICO que la resolucion virtual en algun eje (pasa con
-- el alto: los niveles miden 576px y la ventana virtual 720px), esa
-- comparacion "w/2" como piso rompia el centrado: fijaba la camara contra
-- la mitad de la VENTANA en vez de la mitad del NIVEL, dejando el mapa
-- pegado arriba con un margen vacio abajo. Por eso, si el nivel entra
-- entero en ese eje, la camara se fija en el centro del nivel (no del
-- viewport); si no entra, se clampea/sigue al jugador como siempre.
function Game.updateCamera()
    local w, h = Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT
    local x, y = Game.player.x, Game.player.y

    if Dungeon.worldWidth <= w then
        x = Dungeon.worldWidth / 2
    else
        x = math.max(w / 2, math.min(x, Dungeon.worldWidth - w / 2))
    end

    if Dungeon.worldHeight <= h then
        y = Dungeon.worldHeight / 2
    else
        y = math.max(h / 2, math.min(y, Dungeon.worldHeight - h / 2))
    end

    Game.camera:lookAt(x, y)
end

-- Game.timer ya NO se actualiza aca: ahora lo hace GameplayState:actualizar
-- (ver src/states/gameplay_state.lua), para que se congele automaticamente
-- durante la pausa igual que el resto de la logica de gameplay (sin
-- necesidad de ningun flag "paused").
function Game.update(dt)
    Game.machine:actualizar(dt)
end

-- El clear de fondo lo hace src/systems/viewport.lua (limpia el canvas
-- virtual antes de esto y las franjas del letterbox despues), asi que aca
-- no hace falta limpiar nada.
function Game.draw()
    Game.machine:dibujar()
end

function Game.keypressed(key)
    Game.machine:tecla(key)
end

return Game
