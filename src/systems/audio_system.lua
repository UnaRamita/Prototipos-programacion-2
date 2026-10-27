-- Respuestas de audio ante eventos del jugador. Se suscribe una sola vez
-- (este modulo se require() una unica vez y vive toda la partida, igual
-- que el HUD -- ver la nota sobre suscripciones en src/systems/events.lua)
-- y no sabe nada de Player, combate ni HUD: solo escucha PLAYER_DAMAGED/
-- PLAYER_HEALED y reproduce el sonido correspondiente.
--
-- El sonido de daño YA existia (Assets.sounds.hit), pero antes se
-- reproducia directo desde Game.resolveCombat en el mismo momento en que
-- se llamaba a player:takeDamage -- incluso si el jugador estaba
-- invulnerable y takeDamage no aplicaba nada (ver Player:takeDamage). Al
-- migrarlo aca, que escucha PLAYER_DAMAGED (emitido SOLO cuando el daño
-- realmente se aplico), tambien se corrige ese caso: ya no suena el golpe
-- si el jugador estaba invulnerable y no paso nada.
--
-- El sonido de curacion (Assets.sounds.heal, HealSound.mp3) suena al
-- juntar un corazon, solo si realmente se recupero vida (ver Player:heal).

local Assets = require("src.assets")
local Events = require("src.systems.events")

local AudioSystem = {}

Events:on(Events.PLAYER_DAMAGED, function()
    Assets.playSound(Assets.sounds.hit)
end)

Events:on(Events.PLAYER_HEALED, function()
    Assets.playSound(Assets.sounds.heal)
end)

return AudioSystem
