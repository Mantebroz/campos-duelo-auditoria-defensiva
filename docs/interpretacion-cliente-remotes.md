# Interpretacion desde cliente de remotes

Este documento resume lo que se puede inferir desde los scripts cliente/compartidos disponibles. No contiene payloads exactos ni instrucciones de invocacion. Su uso esperado es guiar validaciones de servidor.

## Metodo

- Direccion inferida por uso cliente: `FireServer`/`InvokeServer` implica intencion cliente -> servidor; `OnClientEvent`/`OnClientInvoke` implica notificacion servidor -> cliente.
- Cuando un remote esta bajo una carpeta `Request`, se trata como entrada no confiable.
- Cuando un remote esta bajo una carpeta `Update`, se trata como estado que deberia originarse en servidor, salvo excepciones observadas que deben revisarse.
- Todo dato enviado por cliente se considera sugerencia, nunca hecho final.

## PlayerCharacter

Familia mas sensible. Contiene combate, movimiento, objetivo, defensa, impactos y sincronizacion.

| Remote/flujo | Lectura cliente | Riesgo si el servidor confia | Regla defensiva |
| --- | --- | --- | --- |
| QueueBasicAttack | intencion de ataque basico/ultimate con prediccion local | combo/cooldown/arma falsos | servidor elige ataque valido desde estado real |
| QueueJump | intencion de salto/ataque con consumo de recurso | stamina o direccion manipulada | servidor valida stamina, estado y direccion normalizada |
| StartDodge | intencion de esquiva con direccion/timing | invulnerabilidad fuera de ventana | servidor mantiene stamina, cooldown y ventana |
| StartBlock / ReleaseBlock | intencion de bloqueo | bloqueo/parry permanente | servidor define inicio, fin, fuerza y recuperacion |
| ResolveImpact | respuesta local a impacto | negar dano o forzar parry/dodge | servidor recalcula resultado final |
| RequestHitboxOnImpact | respuesta local a consulta de hitbox | hitbox adelantada o posicion falsa | servidor valida contra CFrame/tiempo permitido |
| CriticalStrike | intencion de critical contra objetivo | objetivo invalido o fuera de ventana | servidor valida target, distancia, estado y permiso |
| UpdateCharacterCFrame | reconciliacion de posicion cliente | teleport/speed/hitbox desfasada | servidor aplica clamp por velocidad, ping y fisicas |
| SetDesiredMoveDirection | direccion deseada | movimiento imposible | servidor normaliza y limita aceleracion |
| SetDesiredLookDirection | mirada deseada | giro imposible o ayuda de aim | servidor limita y no usa como verdad de impacto |
| SetTargetLock / SetTargetSelection | seleccion local de objetivo | target fuera de arena/equipo/rango | servidor solo guarda si es target valido |
| SetEquippedWeapon | intencion de equipar/desequipar | arma no poseida o swap cancelado | servidor valida inventario, estado y tiempo de swap |
| RequestResetCharacter | intencion de reset | abuso de estado/match | servidor valida fase y consecuencias |
| SoftStagger / StartStagger | reaccion/prediccion de stagger | cancelar castigos o forzar animaciones | servidor decide stagger final |
| SyncPhysicsOwnership | handshake de fisicas | ownership indebido | servidor decide ownership y revoca en anomalias |

### Observacion de naming

Se observo al menos un flujo cliente -> servidor bajo una carpeta con nombre `Update`. Conviene auditar nombres y separar explicitamente:

- `Request`: entradas cliente -> servidor.
- `Update`: servidor -> cliente.
- `Debug`: solo entorno privado.

## PlayerCharacter.Update

La mayoria de estos remotes parecen notificaciones servidor -> cliente: confirmar acciones, iniciar animaciones, aplicar FX, cambiar estado local, pausar ataques y resetear estado visual.

Regla defensiva: aunque el cliente reciba estos eventos para prediccion/visual, el servidor debe mantener el estado canonico y poder corregir al cliente.

## Match

Incluye inicio/fin de partida, fases, ronda, puntaje, seleccion de mapa/arma, espectador y retorno a lobby.

Validaciones esperadas:

- pertenencia al match;
- fase actual;
- permisos del jugador;
- seleccion disponible;
- no aceptar `matchId` ajeno;
- rate limit en requests de seleccion/spectate/return.

## CustomMatch y Party

Incluye crear lobby, invitar, aceptar, declinar, expulsar, iniciar match y retornar como party.

Validaciones esperadas:

- lider/host para acciones administrativas;
- destinatario existente y elegible;
- cooldown de invitaciones;
- idempotencia en aceptar/declinar;
- no permitir kick/start fuera del lobby propio.

## Economia, inventario y recompensas

Familias relevantes:

- Player rewards/codes/gamepass;
- WeaponInventory;
- SequenceInventory;
- RotatingShop;
- BattlePass;
- Achievements;
- DailyGems.

Reglas defensivas:

- el cliente solo selecciona item/codigo/claim;
- servidor valida saldo, ownership y disponibilidad;
- compras y claims deben ser idempotentes;
- recibos de MarketplaceService deben procesarse server-side;
- no aceptar cantidades finales de monedas, gemas, XP o tier desde cliente.

## Settings, keybinds y layout

Son cambios de preferencias del jugador. Riesgo menor, pero igual necesitan type checks y limites de tamano.

Reglas defensivas:

- allowlist de claves configurables;
- serializacion con tamano maximo;
- cooldown de guardado;
- valores dentro de rangos permitidos.

## Analytics y loading

Incluye progreso de carga, ping, distancia recorrida y device info.

Reglas defensivas:

- nunca usar estos datos para recompensas directas sin validacion;
- limitar frecuencia;
- truncar strings;
- descartar payloads grandes.

## Debug y comandos

Se observaron superficies de debug/comandos de chat en cliente. Deben tratarse como alto riesgo en produccion.

Reglas defensivas:

- allowlist estricta por `UserId`;
- entorno de produccion deshabilitado;
- logs de cada uso;
- ningun comando de desbloqueo o moneda accesible a jugadores normales.

## Lectura de riesgo por tipo de dato

| Dato desde cliente | Confianza | Uso permitido |
| --- | --- | --- |
| CFrame/posicion | baja | reconciliacion limitada |
| direccion de movimiento | media-baja | intencion normalizada |
| target instance/model | baja | sugerencia; servidor revalida |
| attack name/combo | baja | solicitud; servidor canonicaliza |
| resultado de impacto | muy baja | prediccion; servidor recalcula |
| timestamps cliente | baja | comparacion aproximada con tolerancia |
| settings/keybinds | media | persistir tras allowlist |
| receipt/purchase claim | muy baja | servidor verifica receipt real |

## Cola de trabajo sugerida

1. Crear wrapper unico para `OnServerEvent` con type checks y rate limit.
2. Migrar `ResolveImpact` a resultado servidor-autoritativo.
3. Agregar ledger de `impactId` emitidos por servidor, con expiracion y un solo uso.
4. Aplicar clamp de CFrame y telemetria de movimiento imposible.
5. Separar carpetas/nombres `Request`, `Update` y `Debug`.
6. Auditar economia con idempotencia y recibos server-side.
7. Crear dashboard de rechazos por jugador/remote.

