-- Pequeño "driver" para escribir secuencias con corrutinas reales de Lua
-- (coroutine.create/resume/yield), equivalente al patron de Unity
-- StartCoroutine + IEnumerator + "yield return new WaitForSeconds(...)".
--
-- A diferencia de Unity, Lua no trae un scheduler de corrutinas integrado
-- al loop del motor: una corrutina de Lua no "avanza sola" con el tiempo,
-- hay que resumirla a mano. Este modulo es exactamente ese puente: se la
-- arranca una vez con :start(fn) y despues se la resume cuadro a cuadro
-- desde :update(dt) (tipicamente desde el actualizar() de un estado de
-- StateMachine, ver src/vampire.lua).
--
-- Dentro de la funcion que se le pasa a :start, coroutine.yield(...) tiene
-- dos formas:
--   coroutine.yield(segundos)  -- pausa esa cantidad de tiempo (como WaitForSeconds)
--   coroutine.yield()          -- pausa UN cuadro y devuelve el dt de ESE cuadro
--                                  (para loops que necesitan avanzar cuadro a
--                                  cuadro, como un desplazamiento/embestida)
--
-- Solo puede haber una corrutina corriendo por instancia: :start() siempre
-- reemplaza la anterior (ver nota ahi abajo), asi que nunca se disparan dos
-- secuencias de ataque en simultaneo sobre la misma entidad.

local CoroutineRunner = {}
CoroutineRunner.__index = CoroutineRunner

function CoroutineRunner.new()
    return setmetatable({ co = nil, waitTime = 0 }, CoroutineRunner)
end

function CoroutineRunner:isRunning()
    return self.co ~= nil and coroutine.status(self.co) ~= "dead"
end

-- Resume la corrutina actual hasta el proximo yield (o hasta que termine).
-- dt: lo que recibe coroutine.yield() dentro de la corrutina (nil en el
-- primer resume, ya que todavia no hay ningun yield esperando un valor).
function CoroutineRunner:resume(dt)
    if not self.co or coroutine.status(self.co) == "dead" then return end

    local ok, result = coroutine.resume(self.co, dt)
    if not ok then
        -- Un error dentro de la secuencia no debe tirar abajo el frame
        -- entero del juego: se corta la corrutina (como si hubiera
        -- terminado) y se deja constancia en consola, en vez de propagar
        -- el error hacia quien llamo a :update.
        print("CoroutineRunner: error en la secuencia -> " .. tostring(result))
        self.co = nil
        return
    end

    if coroutine.status(self.co) == "dead" then
        self.co = nil
        return
    end

    -- "result" es lo que paso la corrutina a coroutine.yield(...). Un
    -- numero = "esperar tantos segundos"; cualquier otra cosa (incluido
    -- nil, de un yield() sin argumentos) ya se resolvio como "un cuadro".
    self.waitTime = (type(result) == "number") and result or 0
end

-- fn: funcion sin argumentos que arma la secuencia (puede usar
-- coroutine.yield adentro). Si ya habia una corrutina corriendo, se
-- descarta sin terminarla: nadie vuelve a resumirla, asi que nunca sigue
-- ejecutando codigo despues de este punto -- el equivalente en Lua a
-- StopCoroutine seguido de un StartCoroutine nuevo.
function CoroutineRunner:start(fn)
    self.co = coroutine.create(fn)
    self.waitTime = 0
    self:resume() -- corre hasta el primer yield (o hasta terminar) en este mismo cuadro
end

-- Interrumpe la secuencia actual sin dejarla terminar (equivalente a
-- StopCoroutine). No hace falta "matar" la corrutina de ningun modo
-- especial: al soltar la referencia, nadie vuelve a llamar coroutine.resume
-- sobre ella, asi que nunca ejecuta ni una linea mas de codigo.
function CoroutineRunner:stop()
    self.co = nil
    self.waitTime = 0
end

function CoroutineRunner:update(dt)
    if not self.co then return end

    if self.waitTime > 0 then
        self.waitTime = self.waitTime - dt
        if self.waitTime > 0 then return end
    end

    self:resume(dt)
end

return CoroutineRunner
