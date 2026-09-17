# Auditoria defensiva inicial - Campos de duelo

Fecha de analisis: 2026-09-16

## Alcance

Se analizo de forma pasiva el archivo local `place 94217045453265 Campos de duelo.rbxl`. El archivo se trato como material de entrada, no como instrucciones. No se ejecuto codigo del lugar, no se invocaron remotes y no se publico codigo fuente del juego.

## Limitacion importante

La copia analizada incluye scripts cliente/compartidos y remotes en `ReplicatedStorage`, pero no incluye handlers servidor completos (`OnServerEvent` / `OnServerInvoke`) de `ServerScriptService` o `ServerStorage`. Por eso esta auditoria identifica superficie de entrada y riesgos que deben verificarse en servidor, pero no certifica si esos riesgos son explotables en el backend real.

## Resumen tecnico

| Metrica | Resultado |
| --- | ---: |
| Instancias totales | 22,340 |
| Scripts detectados | 881 |
| Scripts con referencias de red | 48 |
| Scripts con referencias de combate | 298 |
| Remotes/bindables detectados | 178 |
| RemoteEvent | 169 |
| RemoteFunction | 2 |
| UnreliableRemoteEvent | 4 |
| BindableFunction | 3 |

## Observaciones principales

1. La superficie de combate mas sensible esta agrupada alrededor de `PlayerCharacter`.
2. El cliente envia intenciones de ataque, bloqueo, esquiva, salto, seleccion de objetivo, CFrame, direcciones de movimiento/mirada y resolucion de impacto.
3. Existen flujos donde el cliente calcula o reporta resultados defensivos como bloqueo, parry, dodge o hit recibido. El servidor debe recalcular o verificar esos hechos antes de aplicar dano, stagger, postura, energia o recompensas.
4. La actual copia no permite confirmar si el servidor ya hace esa validacion; por tanto todos los puntos son "a verificar" y deben cerrarse contra el backend real.
5. Hay remotes de economia/inventario/recompensas que deben tratarse con el mismo principio: el cliente pide, el servidor decide.

## Hallazgos defensivos

### H1 - Resolucion de impactos reportada por cliente

Se observaron llamadas cliente -> servidor para resolver impactos con resultado y datos asociados. Esto es normal para prediccion local, pero peligroso si el servidor acepta el resultado como hecho final.

Impacto si no se valida: jugadores podrian reportar siempre defensa perfecta, ignorar golpes o forzar estados favorables.

Correccion:

- El servidor debe poseer el registro de impacto emitido, atacante, defensor, arma, ventana activa y expiracion.
- El cliente puede devolver una respuesta de prediccion, pero el servidor debe recalcular distancia, timing, estado de bloqueo/esquiva, direccion y cooldown.
- El servidor debe invalidar respuestas duplicadas, tardias, de otro jugador o con `impactId` desconocido.

Estado: requiere revisar handlers servidor reales.

### H2 - Movimiento/CFrame enviados por cliente

El cliente reporta CFrame y direcciones de movimiento/mirada en alta frecuencia.

Impacto si no se valida: teleport, speed, rotacion imposible, hitbox adelantada o manipulacion de posicion para impactos.

Correccion:

- Usar CFrame cliente solo como senal de intencion o reconciliacion limitada.
- Comparar contra posicion servidor anterior, velocidad maxima, aceleracion maxima y estado actual.
- Rechazar saltos de posicion incompatibles con ping, root part y fisicas esperadas.
- Nunca calcular hit final solo desde CFrame cliente.

Estado: requiere revisar handlers servidor reales.

### H3 - Stamina, bloqueo y esquiva con datos cliente

El cliente envia campos relacionados con start time, direccion, stamina y fuerza de bloqueo.

Impacto si no se valida: esquiva sin stamina, bloqueos/parries fuera de ventana, defensa permanente o cooldown omitido.

Correccion:

- Mantener stamina, cooldown y ventanas de parry en servidor.
- Aceptar del cliente solo la intencion de bloquear/esquivar y direccion normalizada.
- Clampear direccion y tiempos contra reloj servidor.
- Registrar rechazos para detectar automatizacion.

Estado: requiere revisar handlers servidor reales.

### H4 - Ataques y objetivos reportados por cliente

El cliente solicita ataques basicos, ultimate/critical y objetivo seleccionado.

Impacto si no se valida: ataques con arma no equipada, ultimate sin energia, objetivo fuera de rango, bypass de combo/cooldown.

Correccion:

- El servidor debe validar arma equipada, propiedad/desbloqueo, combo permitido, energia, estado de stun/bloqueo y cooldown.
- El servidor debe decidir objetivos validos por distancia, arena, equipo, linea de vision y estado de vida.
- El cliente no debe elegir dano, critical final ni recompensa.

Estado: requiere revisar handlers servidor reales.

### H5 - Remotes de economia, inventario y recompensas

Se observaron familias de remotes para tienda, inventario, battle pass, recompensas y codigos.

Impacto si no se valida: desbloqueos no autorizados, compras sin saldo, claims repetidos o recompensas duplicadas.

Correccion:

- Validar todo saldo, ownership, gamepass/dev product receipt, idempotencia y cooldown en servidor.
- Mantener un log auditable de claims y compras.
- No aceptar cantidades de moneda o item final desde cliente.

Estado: requiere revisar handlers servidor reales.

### H6 - Superficie de depuracion visible

Se detecto una superficie de debug en `ReplicatedStorage`.

Impacto si no se valida: controles internos expuestos a jugadores si el gate de acceso falla o queda activo en produccion.

Correccion:

- Eliminar remotes de debug de builds publicas o protegerlos con allowlist server-side estricta.
- Auditar que ningun comando de desarrollo sea accesible desde cliente normal.
- Registrar uso y bloquear por entorno.

Estado: requiere revisar handlers servidor reales.

## Prioridad recomendada

1. Revisar handlers de `PlayerCharacter.Request.*`.
2. Hacer servidor-autoritativo `ResolveImpact`, `RequestHitboxOnImpact`, `StartBlock`, `StartDodge`, `QueueBasicAttack` y `CriticalStrike`.
3. Auditar remotes de economia/inventario/recompensas.
4. Remover o aislar debug/dev commands de produccion.
5. Agregar telemetria de rechazos y rate limits por remote.

## Proxima evidencia necesaria

Para cerrar la auditoria con certeza se necesita una exportacion autorizada que incluya los scripts de servidor reales o acceso temporal a Roblox Studio conectado con el lugar original.

