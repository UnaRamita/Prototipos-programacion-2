-- Valores de ajuste centralizados. Tenerlos en un solo lugar facilita
-- explicar y tunear el balance del juego durante la defensa del TP.

local Constants = {}

-- Resolucion logica ("virtual") a la que se dibuja todo el juego (mundo +
-- UI): la ventana real de LOVE puede redimensionarse (ver
-- src/systems/viewport.lua), pero el juego siempre calcula/dibuja como si
-- midiera esto, y despues se escala+centra dentro de la ventana real.
Constants.WINDOW_WIDTH = 1280
Constants.WINDOW_HEIGHT = 720

Constants.BACKGROUND_COLOR = { 0.05, 0.05, 0.07 } -- usado para limpiar tanto el canvas como las franjas del letterbox

Constants.DUNGEON_SCALE = 3   -- escala de los graficos de assets/dungeon (son muy chicos)
Constants.CHARACTER_SCALE = 1.6 -- escala de los sprites de soldier/blood monster (100x100 por frame)
Constants.CHEST_SCALE = Constants.DUNGEON_SCALE -- mismo tamaño visual que el resto del tileset
Constants.KEY_SCALE = 2.6     -- objeto chico para recoger; similar proporcion al resto de props de la dungeon

-- ===== Jugador (Soldier) =====
Constants.PLAYER_SPEED = 210
Constants.PLAYER_MAX_HP = 100
Constants.PLAYER_COLLIDER_W = 28
Constants.PLAYER_COLLIDER_H = 22

Constants.PLAYER_ATTACK_DAMAGE = 20
Constants.PLAYER_ATTACK_RANGE = 50   -- distancia hacia adelante del hitbox de ataque
Constants.PLAYER_ATTACK_WIDTH = 46   -- ancho del hitbox de ataque
Constants.PLAYER_ATTACK_HIT_START = 0.16 -- segundos desde que arranca el swing hasta que el hitbox se activa
Constants.PLAYER_ATTACK_HIT_END = 0.30
Constants.PLAYER_HURT_INVULN_TIME = 0.7

-- Estamina: 3 unidades (una por segmento del HUD, ver src/ui.lua). Se gasta
-- al atacar y se regenera sola con el tiempo; a proposito NO bloquea el
-- ataque si llega a 0 -- agregar esa restriccion cambiaria el combate ya
-- balanceado, y la consigna de este TP pide integrar eventos/HUD, no
-- rediseñar el combate. Queda documentado como decision de diseño (ver
-- Player:consumeStamina en src/player.lua y el README).
Constants.PLAYER_MAX_STAMINA = 3
Constants.STAMINA_COST_ATTACK = 1
Constants.STAMINA_REGEN_INTERVAL = 1.8 -- segundos para recuperar 1 unidad sin atacar

-- Corazon de recuperacion (aparece al completar una sala, ver ROOM_COMPLETED
-- en src/systems/events.lua). Un "corazon" en el HUD representa maxHp/3, asi
-- que recuperar "una unidad de vida" es eso mismo.
Constants.HEART_PICKUP_HEAL = Constants.PLAYER_MAX_HP / 3
Constants.HEART_PICKUP_SCALE = 2.5 -- el sprite (Assets/Hud/full.png) es de 16x16, chico

-- ===== Enemigo (Blood Monster) =====
Constants.ENEMY_MAX_HP = 45
Constants.ENEMY_SPEED = 85
Constants.ENEMY_COLLIDER_W = 26
Constants.ENEMY_COLLIDER_H = 20

Constants.ENEMY_DETECT_RANGE = 230
Constants.ENEMY_ATTACK_RANGE = 46
Constants.ENEMY_ATTACK_WIDTH = 44
Constants.ENEMY_ATTACK_DAMAGE = 10
Constants.ENEMY_ATTACK_COOLDOWN = 1.1     -- tiempo minimo entre ataques
Constants.ENEMY_ATTACK_HIT_START = 0.28   -- ventana de daño dentro de la animacion de ataque
Constants.ENEMY_ATTACK_HIT_END = 0.42
Constants.ENEMY_HURT_TIME = 0.25
Constants.ENEMY_FLICKER_TIME = 0.5 -- titileo corto despues de terminar la animacion de muerte, antes de desaparecer
Constants.ENEMY_LOSE_INTEREST_RANGE = 340 -- si el jugador se aleja demasiado, vuelve a IDLE

-- ===== Enemigo (Vampire) =====
-- Mas fragil y rapido que el Blood Monster, pero su ataque (manejado por
-- una corrutina real, ver src/vampire.lua y src/systems/coroutine_runner.lua)
-- se telegrafia primero (preparacion) y despues embiste en linea recta
-- (ataque) antes de quedar vulnerable un instante (recuperacion): premia
-- al jugador que nota el aviso y lo interrumpe o lo esquiva.
Constants.VAMPIRE_MAX_HP = 35
Constants.VAMPIRE_SPEED = 95
Constants.VAMPIRE_PATROL_SPEED = 45 -- mas lento que al perseguir: patrulla "idle" de pared a pared (ver src/vampire.lua)
Constants.VAMPIRE_COLLIDER_W = 20
Constants.VAMPIRE_COLLIDER_H = 18
Constants.VAMPIRE_SCALE = 3.5 -- sprites de 32x32 (mas chicos que los 100x100 de soldier/blood monster)

Constants.VAMPIRE_DETECT_RANGE = 220
Constants.VAMPIRE_LOSE_INTEREST_RANGE = 320
Constants.VAMPIRE_ATTACK_TRIGGER_RANGE = 90 -- distancia, persiguiendo, a la que arranca la secuencia de ataque
Constants.VAMPIRE_ATTACK_HIT_RANGE = 46     -- alcance del hitbox durante la fase de embestida
Constants.VAMPIRE_ATTACK_WIDTH = 40
Constants.VAMPIRE_ATTACK_DAMAGE = 15
Constants.VAMPIRE_ATTACK_COOLDOWN = 1.3 -- minimo entre secuencias de ataque completas
Constants.VAMPIRE_HURT_TIME = 0.2

-- Fases de la corrutina de ataque (ver VampireStates.attack en src/vampire.lua)
Constants.VAMPIRE_WINDUP_TIME = 0.45  -- preparacion: aviso visual antes de atacar
Constants.VAMPIRE_LUNGE_TIME = 0.35   -- duracion de la embestida
Constants.VAMPIRE_LUNGE_SPEED = 260   -- velocidad durante la embestida (mas rapido que VAMPIRE_SPEED)
Constants.VAMPIRE_RECOVER_TIME = 0.6  -- recuperacion: vulnerable, no ataca de nuevo de inmediato

-- ===== HUD (corazones + estamina, ver src/ui.lua) =====
-- Los sprites de Assets/Hud son chicos (corazones 16x16, estamina 32x32);
-- se escalan para que se lean bien en la esquina superior izquierda sin
-- competir con el resto de la interfaz (barra de vida numerica anterior).
Constants.HUD_HEART_SCALE = 3
Constants.HUD_STAMINA_SCALE = 1.5

return Constants
