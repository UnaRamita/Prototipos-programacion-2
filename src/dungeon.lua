-- Construccion y dibujado del nivel a partir de un mapa de teselas cargado
-- con Simple Tiled Implementation (lib/sti). El mapa (Assets/maps/dungeon.lua,
-- exportado desde Assets/maps/dungeon.tmx) tiene dos capas de tiles
-- ("Suelo" y "Paredes") mas una capa de objetos ("Objetos") con los puntos
-- de interes del nivel (spawns, cofre, llave, velas, puerta).
--
-- Los muros ya NO estan hardcodeados: se generan leyendo, tile por tile, la
-- propiedad "collidable" definida en el tileset (Assets/dungeon/Dungeon_Tileset.png).
-- Las posiciones de juego (spawns, cofre, llave, velas, puerta) tampoco
-- estan hardcodeadas: se leen de la capa de objetos del mapa.

local sti = require("lib.sti")
local Assets = require("src.assets")
local Constants = require("src.constants")
local ProceduralDungeon = require("src.procedural_dungeon")

local Dungeon = {}

local SCALE = Constants.DUNGEON_SCALE
local TILE = 16

-- Columna de la particion del nivel 1 (debe coincidir con
-- Assets/maps/dungeon.tmx): usada solo para calcular el rectangulo de
-- oscurecimiento de su sala 2, algo especifico de ESE mapa. El tamaño del
-- mundo (Dungeon.worldWidth/Height, abajo) se lee del mapa ya cargado, no
-- de una constante, para no hardcodear dimensiones que varian por nivel.
local PARTITION_COL = 13

Dungeon.map = nil
Dungeon.walls = {}              -- rects solidos {x,y,w,h}, generados desde la capa "Paredes"
Dungeon.doorRect = nil
Dungeon.playerSpawn = nil
Dungeon.enemySpawnsRoom1 = {}
Dungeon.enemySpawnsRoom2 = {}
Dungeon.candlesRoom1 = {}
Dungeon.candlesRoom2 = {}
Dungeon.chestPos = nil
Dungeon.keySpawnPos = nil
Dungeon.healSpawnPos = nil -- punto fijo junto a la salida para el corazon de recuperacion (ver Events.ROOM_COMPLETED)
Dungeon.room2DarknessRect = nil

-- Texturas de pared orientadas para el nivel procedural (lista de
-- {x, y, imageKey}, en coordenadas de mundo): el nivel 1 no las usa
-- (queda vacia) y sigue dibujando su capa de tiles "Paredes" tal cual.
-- Ver src/procedural_dungeon.lua (quien decide que textura le toca a cada
-- celda) y Dungeon.drawFloorAndWalls (quien las dibuja).
Dungeon.wallSprites = {}

-- Tamaño del nivel actual en coordenadas de mundo. Se recalcula en cada
-- carga (finishLoading) leyendo las dimensiones reales del mapa ya cargado
-- (Dungeon.map.width/height/tilewidth/tileheight), no de una constante fija
-- -- asi funciona igual para el mapa fijo del nivel 1 y para cualquier
-- mapa procedural, sea cual sea su tamaño.
Dungeon.worldWidth = 0
Dungeon.worldHeight = 0

local function rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

-- Convierte coordenadas nativas del mapa (pixeles del tileset, 16x16) a
-- coordenadas de mundo (las que usan Player/Enemy/Combat), aplicando la
-- misma escala con la que se dibuja el mapa.
local function toWorld(nx, ny)
    return nx * SCALE, ny * SCALE
end

-- Recorre la capa de colision tile por tile y arma un rect solido por cada
-- tile marcado con la propiedad "collidable = true" en el tileset.
local function buildWallsFromLayer(layer)
    local walls = {}
    for y = 1, layer.height do
        local row = layer.data[y]
        if row then
            for x = 1, layer.width do
                local tile = row[x]
                if tile and tile.properties and tile.properties.collidable then
                    local wx, wy = toWorld((x - 1) * TILE, (y - 1) * TILE)
                    local ww, wh = TILE * SCALE, TILE * SCALE
                    walls[#walls + 1] = rect(wx, wy, ww, wh)
                end
            end
        end
    end
    return walls
end

-- Lee la capa de objetos ("Objetos") y distribuye cada punto de interes
-- segun su "type" (definido en Tiled) a la lista correspondiente.
local function loadObjects(layer)
    -- Se resetea todo (no solo las listas) porque el nivel 2 no tiene
    -- objeto "door": si no se limpiara aca, Dungeon.doorRect se quedaria
    -- con el valor del nivel anterior en vez de quedar en nil.
    Dungeon.playerSpawn = nil
    Dungeon.chestPos = nil
    Dungeon.keySpawnPos = nil
    Dungeon.healSpawnPos = nil
    Dungeon.doorRect = nil
    Dungeon.enemySpawnsRoom1 = {}
    Dungeon.enemySpawnsRoom2 = {}
    Dungeon.candlesRoom1 = {}
    Dungeon.candlesRoom2 = {}
    Dungeon.wallSprites = {}

    for _, obj in ipairs(layer.objects) do
        local wx, wy = toWorld(obj.x, obj.y)
        local props = obj.properties or {}

        if obj.type == "player_spawn" then
            Dungeon.playerSpawn = { x = wx, y = wy }
        elseif obj.type == "enemy_spawn" then
            local target = (props.room == 1) and Dungeon.enemySpawnsRoom1 or Dungeon.enemySpawnsRoom2
            -- props.enemy: que tipo de enemigo instanciar (ver Game.setupEntities).
            -- Los objetos "enemy_spawn" ya existentes en el mapa no tienen esta
            -- propiedad -- por eso el default es "blood_monster", para no
            -- cambiarles el comportamiento a los spawns que ya estaban.
            table.insert(target, { x = wx, y = wy, kind = props.enemy or "blood_monster" })
        elseif obj.type == "candle" then
            local target = (props.room == 1) and Dungeon.candlesRoom1 or Dungeon.candlesRoom2
            table.insert(target, { x = wx, y = wy })
        elseif obj.type == "chest" then
            Dungeon.chestPos = { x = wx, y = wy }
        elseif obj.type == "key_spawn" then
            Dungeon.keySpawnPos = { x = wx, y = wy }
        elseif obj.type == "heal_spawn" then
            Dungeon.healSpawnPos = { x = wx, y = wy }
        elseif obj.type == "door" then
            local ww, wh = obj.width * SCALE, obj.height * SCALE
            Dungeon.doorRect = rect(wx, wy, ww, wh)
        elseif obj.type == "wall_texture" then
            table.insert(Dungeon.wallSprites, { x = wx, y = wy, imageKey = props.texture, gx = props.gx, gy = props.gy })
        end
    end
end

-- Comun a los dos niveles: una vez que Dungeon.map esta cargado (ya sea
-- desde el archivo fijo o desde una tabla generada), extraer paredes y
-- objetos es exactamente el mismo trabajo sin importar de donde vino el mapa.
local function finishLoading()
    -- Dimensiones reales del mapa recien cargado (en tiles) * su tamaño de
    -- tile * la escala de dibujado = tamaño del nivel en mundo. Se lee del
    -- objeto Map de STI, nunca se asume un tamaño fijo.
    Dungeon.worldWidth = Dungeon.map.width * Dungeon.map.tilewidth * SCALE
    Dungeon.worldHeight = Dungeon.map.height * Dungeon.map.tileheight * SCALE

    Dungeon.walls = buildWallsFromLayer(Dungeon.map.layers["Paredes"])
    loadObjects(Dungeon.map.layers["Objetos"])
end

-- Nivel 1: mapa fijo, autorado en Tiled (Assets/maps/dungeon.tmx).
function Dungeon.load()
    Dungeon.map = sti("Assets/maps/dungeon.lua")
    finishLoading()

    -- Oscurecimiento de la sala 2: todo lo que esta a la derecha de la
    -- particion (sala + su pared exterior), a lo alto de todo el mapa.
    local darkX = toWorld((PARTITION_COL + 1) * TILE, 0)
    Dungeon.room2DarknessRect = rect(darkX, 0, Dungeon.worldWidth - darkX, Dungeon.worldHeight)
end

-- Nivel 2: mapa generado en runtime (src/procedural_dungeon.lua). No hay
-- puerta ni "sala 2" oscurecida -- es un solo espacio conectado -- asi que
-- alcanza con un rect vacio (drawRoom2Darkness no llega a dibujar nada
-- porque Door.new(nil, ...) deja openProgress en 1 desde el arranque).
function Dungeon.loadProcedural()
    Dungeon.map = sti(ProceduralDungeon.generate())
    finishLoading()

    Dungeon.room2DarknessRect = rect(0, 0, 0, 0)
end

-- upwall.png/downwall.png/leftandrigthWalls.png NO son un tile suelto:
-- son tiras con VARIAS copias del mismo patron ya "horneadas" adentro (asi
-- las usaba el nivel original, repitiendolas a lo largo de todo un borde,
-- antes de pasar a Tiled). Estirar la tira ENTERA dentro de una sola celda
-- (lo que se hacia antes) mostraba todas esas copias amontonadas ahi
-- mismo. La correccion: con un Quad se recorta UNA sola copia por celda
-- (la que corresponda segun la posicion en la grilla, vía gx/gy), igual de
-- limpio que un tile del nivel 1. axis/count salen de medir cada imagen:
-- upwall/downwall miden 64px de ancho = 4 copias de 16px (TILE) cada una;
-- leftandrigthWalls mide 48px de alto = 3 copias de 16px cada una. Los
-- otros keys (esquinas) no vienen en tira -- una esquina es una unica
-- ocurrencia, no algo que se repita -- asi que se dibujan enteros, como ya
-- se hacia.
local WALL_REPEAT = {
    wallUp = { axis = "x", count = 4 },
    wallDown = { axis = "x", count = 4 },
    wallSide = { axis = "y", count = 3 },
}

-- Dibuja el piso (siempre por tiles) y las paredes. El nivel 1 (mapa fijo
-- de Tiled) sigue dibujando su capa de tiles "Paredes" tal cual, sin
-- cambios. El nivel 2 (procedural) NO tiene sprites de pared encajables en
-- la grilla de 16x16 del tileset (son tiras de tamaño propio, no
-- cuadrados), asi que en vez de la capa de tiles dibuja Dungeon.wallSprites
-- -- una imagen por celda de pared, elegida segun sus vecinos (ver
-- src/procedural_dungeon.lua:getWallTexture). La colision de las paredes
-- (Dungeon.walls) sigue viniendo de la MISMA capa de tiles en los dos
-- casos, sin tocar nada: esto solo cambia como se VEN, no donde estan.
function Dungeon.drawFloorAndWalls()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.scale(SCALE, SCALE)
    Dungeon.map.layers["Suelo"]:draw()
    if #Dungeon.wallSprites == 0 then
        Dungeon.map.layers["Paredes"]:draw()
    end
    love.graphics.pop()

    if #Dungeon.wallSprites > 0 then
        local cellSize = TILE * SCALE
        local imgs = Assets.images
        for _, w in ipairs(Dungeon.wallSprites) do
            local image = imgs[w.imageKey]
            local imgW, imgH = image:getWidth(), image:getHeight()

            -- Por defecto (esquinas): usar la imagen entera.
            local qx, qy, qw, qh = 0, 0, imgW, imgH
            local repeatInfo = WALL_REPEAT[w.imageKey]
            if repeatInfo then
                if repeatInfo.axis == "x" then
                    qw = imgW / repeatInfo.count
                    qx = (w.gx % repeatInfo.count) * qw
                else
                    qh = imgH / repeatInfo.count
                    qy = (w.gy % repeatInfo.count) * qh
                end
            end

            local quad = love.graphics.newQuad(qx, qy, qw, qh, imgW, imgH)
            love.graphics.draw(image, quad, w.x, w.y, 0, cellSize / qw, cellSize / qh)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- litAmount: 0 = totalmente apagada, 1 = totalmente iluminada (progreso de apertura de puerta)
function Dungeon.drawCandles(litAmount)
    local imgs = Assets.images
    local cw, ch = imgs.candle:getWidth() * SCALE, imgs.candle:getHeight() * SCALE

    for _, c in ipairs(Dungeon.candlesRoom1) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(imgs.candle, c.x - cw / 2, c.y - ch, 0, SCALE, SCALE)
    end

    for _, c in ipairs(Dungeon.candlesRoom2) do
        -- apagada: gris oscuro. encendida: tono calido con un leve parpadeo.
        local flicker = 1 + math.sin(love.timer.getTime() * 6 + c.x) * 0.06 * litAmount
        local r = (0.25 + 0.75 * litAmount) * flicker
        local g = (0.25 + 0.55 * litAmount) * flicker
        local b = 0.25 + 0.15 * litAmount
        love.graphics.setColor(r, g, b, 1)
        love.graphics.draw(imgs.candle, c.x - cw / 2, c.y - ch, 0, SCALE, SCALE)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Superposicion oscura sobre la sala 2 mientras la puerta sigue cerrada.
-- darkAmount: 0 = sin oscuridad (sala revelada), 1 = totalmente a oscuras.
function Dungeon.drawRoom2Darkness(darkAmount)
    if darkAmount <= 0 then return end
    love.graphics.setColor(0, 0, 0, 0.88 * darkAmount)
    local r = Dungeon.room2DarknessRect
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    love.graphics.setColor(1, 1, 1, 1)
end

return Dungeon
