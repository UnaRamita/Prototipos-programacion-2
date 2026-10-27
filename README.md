# Dungeon Soldier — Prototipo 4 (TP LÖVE2D)

Juego 2D top-down estilo Zelda clásico, hecho en Lua sobre el framework
LÖVE2D. Un soldado explora una mazmorra de dos niveles, combate enemigos
cuerpo a cuerpo, recoge objetos y progresa hasta completar el juego.

## Versión: Prototipo 4

Respecto del Prototipo 3, esta versión suma:

- Un **segundo tipo de enemigo, el Vampire**, cuyo ataque (preparación →
  embestida → recuperación) está implementado con **corrutinas reales de
  Lua**. Ver "Corrutinas" más abajo.
- Corrección: cada enemigo aplica su propio daño de ataque (el Vampire ahora
  hace `VAMPIRE_ATTACK_DAMAGE`, antes usaba el valor del Blood Monster).
- Mezcla de enemigos en ambos niveles (en el nivel 1 por spawns del mapa de
  Tiled; en el nivel 2, proceduralmente).
- Todo lo anterior (máquinas de estado, mapas de teselas, cámara, ventana
  escalable, pausa, HUD, eventos y audio) se mantiene sin cambios.

## Cómo ejecutar

1. Instalar [LÖVE2D](https://love2d.org/) (11.x).
2. Desde la carpeta del proyecto:

   ```bash
   love .
   ```

## Controles

| Acción                                   | Tecla                 |
|-------------------------------------------|-----------------------|
| Moverse                                    | WASD o flechas         |
| Atacar                                     | ESPACIO                |
| Interactuar (puerta / llave / cofre / corazón) | F (cerca del objeto) |
| Pausar / continuar                         | ESC                    |
| Reiniciar                                  | R (tras ganar o perder)|

La ventana es redimensionable: el juego se reescala y se centra solo,
manteniendo siempre su proporción original.

## Funcionalidades

### Jugador

El personaje (Soldier) se mueve en las 4 direcciones, ataca cuerpo a cuerpo
con un hitbox direccional, y tiene una barra de vida y una de estamina. Al
recibir daño queda brevemente invulnerable y es empujado en dirección
opuesta al golpe. Su comportamiento está organizado en estados: inactivo,
caminando, atacando y muerto.

### Enemigos

Hay dos tipos de enemigo, elegidos por cada spawn del mapa (propiedad
`enemy` del objeto `enemy_spawn`; sin esa propiedad, Blood Monster por
defecto — ver `src/dungeon.lua` y `Game.spawnEnemy` en `src/game.lua`).
Ambos comparten la misma interfaz pública, así que el resto del juego
(combate, orden de dibujado, condición de "todos muertos") no necesita
distinguirlos.

- **Blood Monster** (`src/enemy.lua`): detecta al jugador por distancia, lo
  persigue en línea recta y ataca cuando está lo bastante cerca. Estados:
  inactivo, persiguiendo, atacando, lastimado y muerto.
- **Vampire** (`src/vampire.lua`): mismos estados, con dos diferencias.
  Mientras está inactivo (sin haber detectado al jugador), patrulla en
  línea recta — camina hacia un lado hasta chocar una pared, invierte
  dirección y vuelve hasta la pared opuesta, así indefinidamente, hasta
  que el jugador entra en su rango de detección. Y su ataque está
  manejado por una **corrutina real de Lua** con tres fases —
  preparación (se detiene y telegrafía el golpe), ataque (embestida en
  línea recta hacia el jugador) y recuperación (queda vulnerable un
  instante) — antes de volver a perseguir. Ver la sección "Corrutinas" más
  abajo.

Al morir, cualquiera de los dos reproduce su animación completa, titila
brevemente y recién ahí desaparece (deja de dibujarse y de participar en
colisiones/combate).

### Combate

Los ataques del jugador y los enemigos usan hitboxes rectangulares
proyectados según la dirección en la que mira cada uno. Los golpes
conectados reproducen un sonido de impacto; un ataque del jugador que no
conecta reproduce un sonido distinto.

### Niveles

El juego tiene dos niveles consecutivos:

- **Nivel 1**: mapa de teselas fijo, creado en el editor Tiled (dos salas
  conectadas por una puerta interactiva que se abre al acercarse e
  interactuar).
- **Nivel 2**: mapa de teselas generado proceduralmente en cada partida —
  habitaciones de tamaño y posición aleatoria conectadas por pasillos, con
  enemigos y elementos decorativos distribuidos sobre el piso generado.
  Las paredes eligen su textura (pared superior/inferior/lateral o esquina)
  según sus celdas vecinas, no según su posición absoluta.

En ambos niveles, derrotar a todos los enemigos hace aparecer una llave;
recogerla y llevarla hasta el cofre lo abre. Abrir el cofre del nivel 1
pasa al nivel 2; abrir el del nivel 2 termina el juego con victoria.

### Cámara

La cámara sigue al jugador y se mantiene dentro de los límites del nivel
actual, sea cual sea su tamaño real.

### Ventana y escalado

La resolución de la ventana puede cambiar libremente (se puede agrandar,
achicar o usar otra proporción). El juego se dibuja siempre a una
resolución fija internamente y esa imagen se escala de forma uniforme y se
centra dentro de la ventana real, sin deformarse y sin recortar el nivel.
El espacio sobrante se rellena con el color de fondo del juego.

### Pausa

Presionar ESC durante la partida congela el juego (nada se mueve, ni
jugador ni enemigos, ni corre ningún temporizador de gameplay) y muestra
una pantalla de pausa superpuesta. Presionar ESC de nuevo continúa la
partida exactamente donde quedó.

### HUD

La vida del jugador se muestra como tres corazones, cada uno con tres
estados posibles (lleno, medio, vacío). La estamina se muestra como una
barra de tres segmentos, cada uno lleno o vacío. Ambos indicadores se
actualizan automáticamente cuando cambia la vida o la estamina real del
jugador.

### Estamina

El jugador tiene 3 unidades de estamina. Atacar consume una unidad; la
estamina se recupera sola con el tiempo si no se sigue atacando.

### Sala completada y corazón de recuperación

Al derrotar a todos los enemigos de un nivel aparece, junto al cofre, un
corazón de recuperación. Al recogerlo, el jugador recupera una porción de
vida (sin superar el máximo).

### Sistema de eventos

Los distintos sistemas del juego (interfaz, audio, generación de
recompensas) se comunican entre sí mediante eventos, en vez de consultarse
directamente unos a otros. Cuando cambia la vida o la estamina del
jugador, cuando el jugador recibe daño o se cura, o cuando se completa una
sala, el juego emite un evento correspondiente; cada sistema interesado
reacciona por su cuenta (la interfaz se redibuja, se reproduce un sonido,
aparece el corazón de recompensa).

### Audio

El juego reproduce sonidos para: golpe conectado (jugador o enemigo),
ataque del jugador que falla, daño recibido por el jugador y recuperación
de vida al juntar un corazón (acompañada de un breve destello visual).

## Estructura del proyecto

```
main.lua          -- callbacks de LOVE, delega todo a src/game.lua
conf.lua          -- configuracion de ventana

lib/
  sti/            -- Simple Tiled Implementation: carga y dibuja mapas de teselas
  hump/           -- camera.lua (camara) y timer.lua (eventos temporales)

Assets/
  maps/           -- dungeon.tmx (editable en Tiled) y dungeon.lua (exportado, usado en runtime)
  dungeon/        -- tileset y sprites de props de la mazmorra
  soldier/        -- spritesheets del jugador
  blood monster/  -- spritesheets del enemigo Blood Monster
  Vampire enemy/  -- spritesheets del enemigo Vampire (idle/ataque/muerte)
  Hud/            -- sprites de corazones y estamina
  sounds/         -- efectos de sonido

src/
  constants.lua           -- valores de balance y configuracion
  assets.lua              -- carga centralizada de imagenes y sonidos
  animation.lua           -- reproductor generico de spritesheets
  combat.lua              -- colisiones, hitboxes, movimiento con colision
  player.lua              -- jugador: movimiento, combate, vida, estamina
  enemy.lua               -- enemigo Blood Monster: IA y combate
  vampire.lua             -- enemigo Vampire: IA y ataque por corrutina
  door.lua                -- puerta interactiva
  key.lua                 -- llave recogible
  chest.lua               -- cofre final de cada nivel
  heart_pickup.lua        -- corazon de recuperacion
  dungeon.lua             -- carga y dibuja el mapa de teselas del nivel actual
  procedural_dungeon.lua  -- genera el nivel 2
  ui.lua                  -- HUD, carteles de interaccion, pantallas de pausa/victoria/derrota
  game.lua                -- orquestacion general: entidades, camara, colisiones, niveles
  systems/
    state_machine.lua     -- maquina de estados generica
    coroutine_runner.lua  -- driver de corrutinas controladas por tiempo (ver Vampire)
    events.lua            -- bus de eventos
    audio_system.lua       -- respuestas de audio a eventos del jugador
    viewport.lua           -- escalado/centrado de la ventana
  states/
    gameplay_state.lua     -- partida en curso
    pause_state.lua         -- pausa
    victory_state.lua       -- pantalla de victoria
    defeat_state.lua        -- pantalla de derrota
```

## Cumplimiento de la consigna

### Máquinas de estado

El proyecto usa una máquina de estados genérica y reutilizable
(`src/systems/state_machine.lua`), con cuatro métodos por estado
(`ingresar`, `actualizar`, `dibujar`, `tecla`). Se aplica en tres niveles
distintos:

- **Flujo del juego**: `gameplay` ↔ `pause` ↔ `victory`/`defeat`.
- **Jugador**: `idle` → `walk` → `attack` → `idle`/`walk`, con `dead` como
  interrupción desde cualquiera.
- **Enemigo**: `idle` → `chase` → `attack`, con `hurt` y `dead` como
  interrupciones desde cualquiera.

Los cambios de estado son reales y verificables en tiempo de ejecución
(por ejemplo, morir interrumpe cualquier estado del jugador y lleva a
`dead`; completar el nivel lleva de `gameplay` a `victory`; ESC alterna
entre `gameplay` y `pause`).

### Mapa de teselas y generación procedural

El nivel 1 es un mapa de teselas (Tiled + Simple Tiled Implementation),
con colisiones derivadas de una propiedad del tileset en vez de estar
hardcodeadas. El nivel 2 se genera proceduralmente en cada partida
(cantidad, tamaño y posición de las salas, pasillos, enemigos y
decoración), reutilizando el mismo formato y el mismo sistema de carga y
dibujado que el nivel 1.

### Cámara y ventana

La cámara sigue al jugador respetando los límites del nivel actual. La
ventana es redimensionable; el juego se escala de forma uniforme (sin
deformarse) y se centra dentro de la ventana real, sea cual sea su
tamaño o proporción.

### Pausa

La pausa está implementada como un estado más de la máquina de estados del
juego, no como una variable booleana aislada: mientras el estado de pausa
está activo, la lógica de la partida simplemente no se ejecuta.

### Corrutinas

Lua no tiene un scheduler de corrutinas integrado al loop del motor (a
diferencia de, por ejemplo, `StartCoroutine`/`IEnumerator` en Unity): una
corrutina de Lua (`coroutine.create`) hay que resumirla (`coroutine.resume`)
a mano. `src/systems/coroutine_runner.lua` es ese puente: un driver chico y
reutilizable que resume la corrutina cuadro a cuadro desde `:update(dt)`,
interpretando lo que la corrutina le pasa a `coroutine.yield(...)`:

- `coroutine.yield(segundos)` → pausa esa cantidad de tiempo (equivalente a
  `yield return new WaitForSeconds(...)`).
- `coroutine.yield()` (sin argumentos) → pausa un único cuadro y devuelve
  el `dt` de ese cuadro (para loops que necesitan avanzar cuadro a cuadro,
  como la embestida).

El **Vampire** (`src/vampire.lua`) es quien la usa: su estado `attack`
arranca, en `ingresar()`, una corrutina con la secuencia completa —

```text
preparación (yield 0.45s, quieto, telegrafiando el golpe)
        ↓
ataque (apunta una vez hacia el jugador, embiste en línea recta
        cuadro a cuadro durante 0.35s)
        ↓
recuperación (yield 0.6s, vulnerable, no puede volver a atacar de inmediato)
```

y la resume en `actualizar(dt)` llamando a `vampire.attackCoroutine:update(dt)`.
Si el vampiro recibe daño o muere a mitad de secuencia, `machine:cambiar()`
llama primero a `salir()` del estado `attack`, que corta la corrutina
(`:stop()`) antes de que la máquina de estados pase a `hurt`/`dead`: la
secuencia nunca sigue moviendo al enemigo ni aplicando daño después de una
interrupción, y nunca hay dos corrutinas de ataque corriendo a la vez sobre
el mismo enemigo (`:start()` siempre reemplaza cualquier corrutina
anterior). Un error dentro de la secuencia tampoco puede tirar abajo el
juego: `CoroutineRunner:resume` captura el resultado de `coroutine.resume`
y corta la corrutina en vez de propagar el error.

### Interfaz de usuario y eventos personalizados

La vida se representa con corazones y la estamina con una barra de
segmentos, ambos actualizados mediante un sistema de eventos personalizado
(`src/systems/events.lua`) en vez de leer las variables del jugador en
cada cuadro. Los eventos del jugador (cambio de vida, cambio de estamina,
daño recibido, curación) y de progreso (sala completada) comunican entre
sí a la interfaz, el sistema de audio y la generación del corazón de
recompensa, sin que esos sistemas se conozcan directamente entre sí.
