# Superficie remota resumida

Este resumen omite payloads exactos y codigo fuente. El objetivo es orientar hardening defensivo sin publicar una guia de abuso.

## Conteo por familia

| Familia | Total | RemoteEvent | RemoteFunction | Unreliable | Bindable |
| --- | ---: | ---: | ---: | ---: | ---: |
| PlayerCharacter | 36 | 32 | 1 | 3 | 0 |
| Match | 20 | 20 | 0 | 0 | 0 |
| Player | 12 | 12 | 0 | 0 | 0 |
| CustomMatch | 12 | 12 | 0 | 0 | 0 |
| Party | 11 | 11 | 0 | 0 | 0 |
| SequenceInventory | 9 | 9 | 0 | 0 | 0 |
| WeaponInventory | 8 | 8 | 0 | 0 | 0 |
| RotatingShop | 8 | 8 | 0 | 0 | 0 |
| Achievements | 8 | 8 | 0 | 0 | 0 |
| SpecialAnimation | 6 | 6 | 0 | 0 | 0 |
| BattlePass | 6 | 6 | 0 | 0 | 0 |
| Combat | 4 | 4 | 0 | 0 | 0 |
| Cinematic | 4 | 4 | 0 | 0 | 0 |
| Settings | 4 | 4 | 0 | 0 | 0 |
| Matchmaking | 4 | 4 | 0 | 0 | 0 |
| TextChatCommands | 4 | 4 | 0 | 0 | 0 |
| Other/Workspace/Debug | 11 | 4 | 1 | 1 | 3 |

## Familias de mayor riesgo

### PlayerCharacter

Entradas asociadas a combate, movimiento, objetivo, bloqueo, esquiva, saltos, impactos y sincronizacion de fisicas.

Validaciones obligatorias:

- rate limit por accion y jugador;
- estado vivo/en partida/no aturdido;
- arma equipada y permitida;
- cooldown y combo en servidor;
- stamina y ventanas de defensa en servidor;
- distancia/angulo/linea de vision para impactos;
- CFrame cliente limitado por velocidad, ping y estado fisico;
- ids de accion/impacto emitidos por servidor y de un solo uso.

### Economia e inventario

Incluye tienda rotativa, battle pass, armas, cosmeticos, recompensas, codigos y monedas.

Validaciones obligatorias:

- saldo y ownership calculados en servidor;
- recibos de productos procesados idempotentemente;
- claims con estado persistente y no repetible;
- compras atomicas;
- payloads de cliente tratados como seleccion, no como resultado.

### Match, party y matchmaking

Incluye seleccion, espectador, retorno a lobby, invitaciones y estado de match.

Validaciones obligatorias:

- pertenencia a match/lobby/party;
- permisos de host/lider;
- transiciones de fase permitidas;
- anti-spam por jugador;
- no aceptar ids de match/party ajenos.

### Debug/dev commands

Debe estar ausente o fuertemente protegido en produccion.

Validaciones obligatorias:

- allowlist por UserId en servidor;
- deshabilitado por entorno;
- sin comandos de desbloqueo o moneda en cliente publico;
- logging y alertas.

## Matriz rapida

| Riesgo | Severidad | Evidencia pasiva | Accion |
| --- | --- | --- | --- |
| Resolucion de impactos reportada por cliente | Alta | cliente envia resultado defensivo/ofensivo | recalcular en servidor |
| CFrame cliente de alta frecuencia | Alta | cliente reporta posicion/mirada | clamp + reconciliacion |
| Stamina/block/dodge en payload cliente | Alta | cliente envia tiempos/fuerzas/direccion | estado servidor-autoritativo |
| Compras/claims solicitados por cliente | Media/Alta | multiples familias de economia | validacion/idempotencia |
| Debug remoto visible | Alta | familia debug expuesta | quitar o allowlist estricta |
| Match/party selection | Media | ids enviados por cliente | validar pertenencia/permisos |
