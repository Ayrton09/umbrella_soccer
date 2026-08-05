# Changelog

## 1.0.1

### Penales
- El gol de penal ahora se detecta solo. `EventRoundEnd` cortaba antes de tiempo cuando `gPenaltyActive`, así que la rama de penal de `HandleGoal` solo se alcanzaba con `sm_soccer_goal` a mano y todo penal terminaba en fallo por timeout. Afectaba también a la tanda completa.
- `IsShootoutDecided` reemplaza la comprobación de cierre de la tanda. Termina en cuanto un equipo saca más ventaja de la que el otro puede recuperar con los tiros que le quedan (3-0 en tres rondas cierra sin patear las dos restantes), y la muerte súbita no se corta hasta que ambos patearon la misma cantidad. Antes faltaban las dos cosas: se pateaban los cinco siempre, y en la sexta ronda el que abría ganaba al convertir sin que el rival respondiera.
- El tirador se ubica detrás de la pelota y mirando al arco. La dirección sale de `gBallStartPosition` (centro de la cancha) hacia el punto de penal, que es el extremo atacado; no hace falta que los arcos sean entidades con nombre. Antes se aplicaba un desplazamiento fijo de `-96.0` en X, que dejaba al tirador cruzado de costado en canchas orientadas sobre Y. Si no hay centro cacheado se conserva el desplazamiento viejo.
- Los bots ya no pueden ser seleccionados como tiradores en la tanda (`GetNextShootoutShooter` ahora excluye `IsFakeClient`).

### Goles y fin de ronda
- Se ignoran los motivos de fin de ronda que no son gol (`Draw`, `TargetSaved`, `HostagesNotRescued`, `TerroristsNotEscaped`, `VIPNotEscaped`, `GameStart`). Antes cualquier fin de ronda con ganador contaba como gol, así que si el período duraba más que `mp_roundtime` la ronda expiraba sola y CT se llevaba un gol regalado.
- Los puntos de resultado de ronda (`soccer_mod_ranking_points_round_won`/`_lost`) se reparten aunque no se identifique al último tocador. Antes quedaban dentro del `if (IsValidClient(scorer))`.
- La restauración de daño del `trigger_hurt` se ejecuta una sola vez por gol (guard `gGoalDamageRestored`, reseteado en `round_start`), replicando el `goalScored` del soccermod original. Comportamiento idéntico, sin el bucle redundante.

### Otros
- Tarjeta roja: `GiveRedCard` restaura el daño antes de `ForcePlayerSuicide`, igual que ya hacía `TimerMoveRedCardSpectator`. Con `m_takedamage` en 0 el suicidio podía no aplicarse.
- Tiempo añadido: el modelo que le da bounding box al trigger se precachea al iniciar el mapa en vez de a mitad de ronda.
- Limpieza: eliminados dos cvars muertos sin efecto (`sm_soccer_assist_window`, `sm_soccer_training_cannon_ball_life`).

Compilado con SourcePawn 1.12.0.7239, sin warnings.
SHA256 del .smx: `FC7F6423A482B8C49492C6BE30EACBC0CB0A657CF35869EF605B2514BC1245FF`

## 1.0.0

- Release inicial del rebuild de Umbrella Soccer para Counter-Strike: Source.
