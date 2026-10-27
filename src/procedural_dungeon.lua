-- Generacion procedural del nivel 2: habitaciones rectangulares de tamaño
-- y posicion aleatoria, conectadas por pasillos rectos, con enemigos y
-- props (velas, llave, cofre) distribuidos al azar sobre el piso generado.
--
-- La funcion generate() no dibuja nada ni instancia entidades: arma una
-- tabla Lua CON EL MISMO FORMATO que exporta Tiled (tilesets + layers,
-- el mismo que usa Assets/maps/dungeon.lua para el nivel 1 hardcodeado).
-- Esa tabla se le pasa directo a Simple Tiled Implementation (sti(map)
-- acepta una tabla ya armada, no solo la ruta a un archivo), asi que todo
-- el resto del pipeline -- carga de tiles, deteccion de paredes por la
-- propiedad "collidable", lectura de la capa de objetos, dibujado, camara
-- -- es exactamente el mismo cdigo que usa el nivel 1 fijo (ver
-- src/dungeon.lua). El generador solo decide QUE datos poner en esa tabla.

local ProceduralDungeon = {}

local TILE = 16
local MAP_W, MAP_H = 29, 12 -- misma grilla que el nivel 1: la camara no necesita saber que nivel es

local FLOOR = 32
local FLOOR_VARIANT = 24
local WALL = 42 -- alcanza un solo tile de pared; ya esta marcado "collidable" en el tileset

local MIN_ROOMS, MAX_ROOMS = 4, 6
local ROOM_MIN_W, ROOM_MAX_W = 3, 5
local ROOM_MIN_H, ROOM_MAX_H = 3, 4
local MIN_ENEMIES, MAX_ENEMIES = 5, 8
local VAMPIRE_CHANCE = 0.35 -- probabilidad de que un spawn de enemigo sea Vampire en vez de Blood Monster

local function newGrid(w, h, value)
    local grid = {}
    for y = 1, h do
        grid[y] = {}
        for x = 1, w do grid[y][x] = value end
    end
    return grid
end

local function overlaps(a, b)
    -- +1 de margen para que dos salas nunca queden pegadas pared con pared
    return a.x < b.x + b.w + 1 and a.x + a.w + 1 > b.x
       and a.y < b.y + b.h + 1 and a.y + a.h + 1 > b.y
end

local function roomCenter(room)
    return math.floor(room.x + room.w / 2), math.floor(room.y + room.h / 2)
end

-- Coloca entre MIN_ROOMS y MAX_ROOMS rectangulos que no se superpongan
-- (reintentando con posiciones nuevas), dentro del margen interior de la
-- grilla (deja siempre 1 tile libre en el borde para la pared exterior).
local function placeRooms()
    local rooms = {}
    local target = love.math.random(MIN_ROOMS, MAX_ROOMS)
    local attempts = 0

    while #rooms < target and attempts < 300 do
        attempts = attempts + 1
        local w = love.math.random(ROOM_MIN_W, ROOM_MAX_W)
        local h = love.math.random(ROOM_MIN_H, ROOM_MAX_H)
        local room = {
            x = love.math.random(2, MAP_W - w - 1),
            y = love.math.random(2, MAP_H - h - 1),
            w = w, h = h,
        }

        local free = true
        for _, other in ipairs(rooms) do
            if overlaps(room, other) then
                free = false
                break
            end
        end

        if free then rooms[#rooms + 1] = room end
    end

    return rooms
end

local function carveRoom(floor, room)
    for y = room.y, room.y + room.h - 1 do
        for x = room.x, room.x + room.w - 1 do
            floor[y][x] = ((x + y) % 7 == 0) and FLOOR_VARIANT or FLOOR
        end
    end
end

-- Pasillo en "L" (primero horizontal, despues vertical) entre dos puntos:
-- la forma mas simple de garantizar que toda sala quede conectada con la
-- siguiente sin tener que resolver un laberinto de verdad.
local function carveCorridor(floor, x1, y1, x2, y2)
    local x, y = x1, y1
    while x ~= x2 do
        floor[y][x] = FLOOR
        x = x + (x2 > x and 1 or -1)
    end
    while y ~= y2 do
        floor[y][x] = FLOOR
        y = y + (y2 > y and 1 or -1)
    end
    floor[y][x] = FLOOR
end

-- Pared solida en cualquier celda vacia que quede pegada a una celda de
-- piso (8 direcciones, para que las esquinas tambien queden tapadas). Es
-- lo que le da a cualquier forma de sala/pasillo un borde solido sin tener
-- que razonar caso por caso.
local function buildWallRing(floor, walls)
    for y = 1, MAP_H do
        for x = 1, MAP_W do
            if floor[y][x] == 0 then
                local nextToFloor = false
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local ny, nx = y + dy, x + dx
                        if ny >= 1 and ny <= MAP_H and nx >= 1 and nx <= MAP_W
                            and floor[ny][nx] ~= 0 then
                            nextToFloor = true
                        end
                    end
                end
                if nextToFloor then walls[y][x] = WALL end
            end
        end
    end
end

-- true si (x,y) es una celda de PISO dentro de la grilla (fuera de rango
-- cuenta como "no piso", igual que buildWallRing).
local function isFloor(floor, x, y)
    if x < 1 or x > MAP_W or y < 1 or y > MAP_H then return false end
    return floor[y][x] ~= 0
end

-- Elige que textura de pared le corresponde a la celda de pared (x,y)
-- mirando sus vecinos en la grilla de PISO -- nunca sus coordenadas
-- absolutas -- para que funcione igual con cualquier forma de sala/pasillo
-- que produzca el generador, no solo con rectangulos perfectos.
--
-- Las esquinas se revisan PRIMERO porque, miradas de a un vecino ortogonal
-- por vez, tambien "parecen" una pared recta (por ejemplo la esquina
-- superior izquierda tiene piso abajo-a-la-derecha en diagonal, pero ni
-- directamente abajo ni directamente a la derecha) -- el patron que las
-- distingue es que el piso entra en diagonal mientras los dos vecinos
-- ortogonales de esa esquina siguen sin ser piso.
local function getWallTexture(floor, x, y)
    local n = isFloor(floor, x, y - 1)
    local s = isFloor(floor, x, y + 1)
    local w = isFloor(floor, x - 1, y)
    local e = isFloor(floor, x + 1, y)
    local nw = isFloor(floor, x - 1, y - 1)
    local ne = isFloor(floor, x + 1, y - 1)
    local sw = isFloor(floor, x - 1, y + 1)
    local se = isFloor(floor, x + 1, y + 1)

    -- interior en diagonal abajo-derecha, nada directamente abajo/derecha
    if se and not s and not e then return "cornerUL" end
    -- interior en diagonal abajo-izquierda, nada directamente abajo/izquierda
    if sw and not s and not w then return "cornerUR" end
    -- interior en diagonal arriba-derecha, nada directamente arriba/derecha
    if ne and not n and not e then return "cornerDL" end
    -- interior en diagonal arriba-izquierda, nada directamente arriba/izquierda
    if nw and not n and not w then return "cornerDR" end

    if s then return "wallUp" end        -- interior directamente abajo -> borde superior
    if n then return "wallDown" end      -- interior directamente arriba -> borde inferior
    if e or w then return "wallSide" end -- interior a un costado -> pared lateral

    -- Celda de pared sin vecino de piso directo ni en diagonal "limpia"
    -- (caso raro; ver limitaciones). Se usa la textura lateral como
    -- fallback razonable en vez de dejarla sin textura.
    return "wallSide"
end

-- Una celda de piso al azar, opcionalmente evitando la sala de spawn del
-- jugador (para no hacer aparecer un enemigo encima suyo).
local function randomFloorCell(floor, excludeRoom)
    for _ = 1, 300 do
        local x = love.math.random(1, MAP_W)
        local y = love.math.random(1, MAP_H)
        if floor[y][x] ~= 0 then
            local inExcluded = excludeRoom
                and x >= excludeRoom.x and x < excludeRoom.x + excludeRoom.w
                and y >= excludeRoom.y and y < excludeRoom.y + excludeRoom.h
            if not inExcluded then return x, y end
        end
    end
    return nil
end

function ProceduralDungeon.generate()
    local floor = newGrid(MAP_W, MAP_H, 0)
    local walls = newGrid(MAP_W, MAP_H, 0)

    local rooms = placeRooms()
    for _, room in ipairs(rooms) do
        carveRoom(floor, room)
    end

    -- Encadena las salas en el orden en que se colocaron: alcanza para que
    -- el nivel entero sea alcanzable desde la sala de spawn.
    for i = 2, #rooms do
        local x1, y1 = roomCenter(rooms[i - 1])
        local x2, y2 = roomCenter(rooms[i])
        carveCorridor(floor, x1, y1, x2, y2)
    end

    buildWallRing(floor, walls)

    -- ===== capa de objetos: spawns, cofre, llave, velas =====
    local objects = {}
    local nextId = 1
    local function addObject(objType, gx, gy, props)
        nextId = nextId + 1
        objects[#objects + 1] = {
            id = nextId, name = "", type = objType, shape = "point",
            x = (gx - 0.5) * TILE, y = gy * TILE,
            width = 0, height = 0, rotation = 0, visible = true,
            properties = props or {},
        }
    end

    -- addWallTexture usa las esquinas superior-izquierda de la celda (no el
    -- "pie" centrado de addObject): tiene que coincidir exactamente con el
    -- rect de colision que arma Dungeon.buildWallsFromLayer para esa misma
    -- celda, para que el sprite se vea justo donde esta la pared solida.
    -- gx/gy tambien viajan en las propiedades: Dungeon.lua los necesita
    -- para elegir, dentro de las texturas que vienen "en tira" (varias
    -- copias del mismo patron en un solo archivo), cual copia le toca a
    -- esta celda especifica (ver WALL_REPEAT en src/dungeon.lua).
    local function addWallTexture(gx, gy, imageKey)
        nextId = nextId + 1
        objects[#objects + 1] = {
            id = nextId, name = "", type = "wall_texture", shape = "point",
            x = (gx - 1) * TILE, y = (gy - 1) * TILE,
            width = 0, height = 0, rotation = 0, visible = true,
            properties = { texture = imageKey, gx = gx, gy = gy },
        }
    end

    for y = 1, MAP_H do
        for x = 1, MAP_W do
            if walls[y][x] ~= 0 then
                addWallTexture(x, y, getWallTexture(floor, x, y))
            end
        end
    end

    local spawnRoom = rooms[1]
    local px, py = roomCenter(spawnRoom)
    addObject("player_spawn", px, py, {})

    local enemyCount = love.math.random(MIN_ENEMIES, MAX_ENEMIES)
    for _ = 1, enemyCount do
        local ex, ey = randomFloorCell(floor, spawnRoom)
        if ex then
            -- room = 1: en el nivel procedural no hay puerta que gatille
            -- una segunda oleada, todos los enemigos arrancan activos.
            -- enemy: ~35% de probabilidad de Vampire en vez de Blood
            -- Monster, para que el nivel procedural tambien mezcle los dos
            -- tipos (ver Game.spawnEnemy en src/game.lua).
            local kind = (love.math.random() < VAMPIRE_CHANCE) and "vampire" or "blood_monster"
            addObject("enemy_spawn", ex, ey, { room = 1, enemy = kind })
        end
    end

    local lastRoom = rooms[#rooms]
    local cx, cy = roomCenter(lastRoom)
    addObject("chest", cx, cy, {})
    addObject("key_spawn", cx, cy - 1, {})
    -- heal_spawn: punto fijo para el corazon de recuperacion, al OTRO lado
    -- del cofre que key_spawn (para no superponerse entre si). Valido para
    -- cualquier sala de al menos 3 tiles de alto (ROOM_MIN_H), igual que
    -- key_spawn ya asumia.
    addObject("heal_spawn", cx, cy + 1, {})

    for i = 2, #rooms - 1 do
        local qx, qy = roomCenter(rooms[i])
        addObject("candle", qx, qy, { room = 1 })
    end

    -- ===== aplanar las grillas a arrays GID (mismo esquema que Tiled: 0 = vacio, GID = id_tile + 1) =====
    local floorData, wallsData = {}, {}
    local i = 1
    for y = 1, MAP_H do
        for x = 1, MAP_W do
            local fv, wv = floor[y][x], walls[y][x]
            floorData[i] = (fv == 0) and 0 or (fv + 1)
            wallsData[i] = (wv == 0) and 0 or (wv + 1)
            i = i + 1
        end
    end

    return {
        version = "1.9", luaversion = "5.1", tiledversion = "1.10.2",
        orientation = "orthogonal", renderorder = "right-down",
        width = MAP_W, height = MAP_H, tilewidth = TILE, tileheight = TILE,
        nextlayerid = 4, nextobjectid = nextId + 1, properties = {},
        tilesets = {
            {
                name = "Dungeon_Tileset", firstgid = 1,
                tilewidth = TILE, tileheight = TILE, spacing = 0, margin = 0,
                columns = 10,
                -- Sin ruta de archivo (mapa generado en memoria, no cargado
                -- desde un .lua): la imagen se resuelve relativa a la raiz
                -- del proyecto, no a Assets/maps/ como en el nivel 1.
                image = "Assets/dungeon/Dungeon_Tileset.png",
                imagewidth = 160, imageheight = 160,
                tileoffset = { x = 0, y = 0 },
                grid = { orientation = "orthogonal", width = TILE, height = TILE },
                properties = {}, terrains = {}, tilecount = 100,
                tiles = {
                    { id = WALL, properties = { ["collidable"] = true } },
                },
            },
        },
        layers = {
            {
                type = "tilelayer", id = 1, name = "Suelo",
                x = 0, y = 0, width = MAP_W, height = MAP_H,
                visible = true, opacity = 1, offsetx = 0, offsety = 0,
                parallaxx = 1, parallaxy = 1, properties = {},
                encoding = "lua", data = floorData,
            },
            {
                type = "tilelayer", id = 2, name = "Paredes",
                x = 0, y = 0, width = MAP_W, height = MAP_H,
                visible = true, opacity = 1, offsetx = 0, offsety = 0,
                parallaxx = 1, parallaxy = 1, properties = {},
                encoding = "lua", data = wallsData,
            },
            {
                type = "objectgroup", id = 3, name = "Objetos",
                visible = true, opacity = 1, offsetx = 0, offsety = 0,
                parallaxx = 1, parallaxy = 1, properties = {},
                draworder = "topdown", x = 0, y = 0, objects = objects,
            },
        },
    }
end

return ProceduralDungeon
