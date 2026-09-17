# Plan de hardening de combate

## Principio

El cliente comunica intencion. El servidor decide hechos.

## Modelo de estado servidor

Mantener por jugador:

- `characterId`
- `matchId`
- `equippedWeapon`
- `currentAction`
- `queuedAction`
- `actionCooldowns`
- `stamina`
- `blockState`
- `dodgeState`
- `ultimateEnergy`
- `lastServerCFrame`
- `activeImpacts`
- `recentRemoteCounts`

## Contratos recomendados

### Queue attack

Entrada permitida:

- tipo de ataque solicitado;
- id de prediccion cliente opcional.

Servidor decide:

- arma real equipada;
- ataque real del combo;
- si ultimate tiene energia;
- cooldown;
- si el jugador puede cancelar/encadenar;
- id servidor de accion.

### Resolve impact

Entrada permitida:

- id de impacto emitido por servidor;
- respuesta de prediccion opcional.

Servidor decide:

- atacante y defensor asociados;
- si el impacto sigue vigente;
- distancia, angulo y hitbox;
- si block/parry/dodge era valido;
- dano, stagger, postura y efectos.

### Movement/CFrame

Entrada permitida:

- direccion deseada;
- CFrame para reconciliacion con limites.

Servidor decide:

- velocidad maxima;
- aceleracion maxima;
- teleport reject;
- posicion usada para combate.

## Pseudoflujo de impacto

```text
server creates impactId
server stores attacker, defender candidates, weapon, actionId, createdAt, expiresAt
server notifies clients for prediction/FX
client responds with impactId and optional prediction
server loads impactId
server rejects if expired, reused, wrong defender, wrong match or impossible timing
server recomputes defense state and geometry
server applies final result
server broadcasts final FX
```

## Controles minimos por remote

| Control | Combate | Economia | Match |
| --- | --- | --- | --- |
| Type check | requerido | requerido | requerido |
| Rate limit | requerido | requerido | requerido |
| Ownership/permisos | requerido | requerido | requerido |
| Estado servidor | requerido | requerido | requerido |
| Idempotencia | impactos | compras/claims | transiciones |
| Logs de rechazo | requerido | requerido | requerido |

## Senales para alertas

- mas de N rechazos de combate por minuto;
- muchos `impactId` desconocidos;
- CFrame con delta imposible;
- ataques sin arma/energia/stamina;
- repeticion de claims;
- debug command en produccion;
- seleccion de objetivo fuera de match.

