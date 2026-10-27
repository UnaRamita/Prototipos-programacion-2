-- Carga centralizada de todos los recursos (imagenes y sonidos).
-- Se cargan una sola vez en Assets.load() y se comparten por referencia
-- entre Player, Enemy y Dungeon para no leer el disco mas de una vez.

local Assets = {}

Assets.images = {}
Assets.sounds = {}

-- Fila (en pixeles nativos del frame) donde termina la parte visible/opaca
-- de cada spritesheet de personaje. Los sheets de soldier/blood monster
-- tienen mucho relleno transparente debajo del personaje (el frame mide
-- 100px de alto pero el sprite real termina bastante antes), asi que no
-- se puede asumir que "el piso del personaje" esta en la fila 100.
-- Se calcula leyendo los pixeles reales en vez de adivinar un numero fijo.
Assets.footRow = {}

local function img(path)
    return love.graphics.newImage(path)
end

-- Recorre la imagen de abajo hacia arriba y devuelve la primera fila (+1)
-- que tiene algun pixel no transparente. Esa fila es el "piso" real del
-- sprite dentro del frame, sin importar cuanto espacio vacio tenga debajo.
local function findVisualBottom(imageData)
    local w, h = imageData:getDimensions()
    for y = h - 1, 0, -1 do
        for x = 0, w - 1 do
            local _, _, _, a = imageData:getPixel(x, y)
            if a > 0.1 then
                return y + 1
            end
        end
    end
    return h
end

-- Carga una imagen y de paso mide su "piso" visual real (ver findVisualBottom).
local function loadCharacterImage(path)
    local data = love.image.newImageData(path)
    local image = love.graphics.newImage(data)
    return image, findVisualBottom(data)
end

function Assets.load()
    -- Soldier (jugador)
    Assets.images.soldierWalk, Assets.footRow.soldierWalk = loadCharacterImage("Assets/soldier/Soldier_Walk.png")
    Assets.images.soldierAttack, Assets.footRow.soldierAttack = loadCharacterImage("Assets/soldier/Soldier_Attack01.png")
    Assets.images.soldierDeath, Assets.footRow.soldierDeath = loadCharacterImage("Assets/soldier/Soldier_Death.png")

    -- Blood Monster (enemigo)
    Assets.images.monsterWalk, Assets.footRow.monsterWalk = loadCharacterImage("Assets/blood monster/Blood Monster_A_Walk.png")
    Assets.images.monsterAttack, Assets.footRow.monsterAttack = loadCharacterImage("Assets/blood monster/Blood Monster_A_Attack01.png")
    Assets.images.monsterDeath, Assets.footRow.monsterDeath = loadCharacterImage("Assets/blood monster/Blood Monster_A_Death.png")

    -- Vampire (segundo enemigo, ver src/vampire.lua). No trae un sheet de
    -- caminar separado -- "enemies-skeleton2_idle.png" es el unico sheet de
    -- movimiento del pack y se reutiliza para idle/chase, igual de valido.
    Assets.images.vampireIdle, Assets.footRow.vampireIdle = loadCharacterImage("Assets/Vampire enemy/enemies-skeleton2_idle.png")
    Assets.images.vampireAttack, Assets.footRow.vampireAttack = loadCharacterImage("Assets/Vampire enemy/enemies-vampire_attack.png")
    Assets.images.vampireDeath, Assets.footRow.vampireDeath = loadCharacterImage("Assets/Vampire enemy/enemies-vampire_death.png")

    -- Dungeon: el piso y las paredes del nivel 1 vienen del mapa de teselas
    -- (Assets/maps/dungeon.lua + Assets/dungeon/Dungeon_Tileset.png, ver
    -- src/dungeon.lua). Los props dinamicos siguen dibujandose como sprites
    -- sueltos (puerta, velas, cofre, llave).
    Assets.images.doorSide = img("Assets/dungeon/lateraldoors.png")
    Assets.images.chest = img("Assets/dungeon/chest.png")
    Assets.images.candle = img("Assets/dungeon/vela de piso.png")
    Assets.images.key = img("Assets/dungeon/Key .png")

    -- Texturas de pared orientadas, usadas por el nivel 2 (procedural): sus
    -- paredes no encajan en la grilla uniforme del tileset de Tiled (son
    -- tiras finas de tamaño propio, no cuadrados de 16x16), asi que se
    -- dibujan como sprites sueltos elegidos segun vecinos (ver
    -- src/procedural_dungeon.lua y Dungeon.drawFloorAndWalls).
    Assets.images.wallUp = img("Assets/dungeon/upwall.png")
    Assets.images.wallDown = img("Assets/dungeon/downwall.png")
    Assets.images.wallSide = img("Assets/dungeon/leftandrigthWalls.png")
    Assets.images.cornerUL = img("Assets/dungeon/leftupcorner.png")
    Assets.images.cornerUR = img("Assets/dungeon/rigthupcorner.png")
    Assets.images.cornerDL = img("Assets/dungeon/downleftcorner.png")
    Assets.images.cornerDR = img("Assets/dungeon/downRIgthcorner.png")

    -- HUD: corazones (3 estados) y estamina (3 segmentos, cada uno lleno/vacio).
    -- Assets/Hud ya traia estos sprites preparados; no se dibujo nada nuevo.
    Assets.images.heartFull = img("Assets/Hud/full.png")
    Assets.images.heartHalf = img("Assets/Hud/half.png")
    Assets.images.heartEmpty = img("Assets/Hud/empty.png")

    Assets.images.staminaL = img("Assets/Hud/L stamina.png")
    Assets.images.staminaM = img("Assets/Hud/M stamina.png")
    Assets.images.staminaR = img("Assets/Hud/R stamina.png")
    Assets.images.staminaLEmpty = img("Assets/Hud/L empty stamina.png")
    Assets.images.staminaMEmpty = img("Assets/Hud/M empty stamina.png")
    Assets.images.staminaREmpty = img("Assets/Hud/R empty stamina.png")

    -- Sonidos (golpes del jugador, reutilizados de forma razonable)
    Assets.sounds.hit = love.audio.newSource("Assets/sounds/hit.mp3", "static")
    Assets.sounds.miss = love.audio.newSource("Assets/sounds/misshit.mp3", "static")

    -- Sonido de curacion: lo reproduce src/systems/audio_system.lua al
    -- escuchar PLAYER_HEALED (al juntar un corazon de recuperacion).
    Assets.sounds.heal = love.audio.newSource("Assets/sounds/HealSound.mp3", "static")
end

-- Reproduce un sonido permitiendo solapamiento (clona la fuente) para que
-- golpes rapidos consecutivos no se corten entre si.
function Assets.playSound(source)
    local instance = source:clone()
    instance:play()
end

return Assets
