# Matriz de hardening PlayerCharacter

Esta matriz baja la interpretacion de cliente a criterios concretos para el servidor. Los nombres se usan para auditoria defensiva; no se incluyen argumentos exactos ni secuencias de invocacion.

## Entradas cliente -> servidor

| Area | Remote observado | Decision que pertenece al servidor |
| --- | --- | --- |
| Ataque | QueueBasicAttack | arma real, combo real, cooldown, energia, cancelacion permitida |
| Ataque | QueueJump | stamina, ventana de salto, direccion permitida |
| Ataque | CriticalStrike | objetivo valido, ventana de critical, distancia, estado del defensor |
| Defensa | StartBlock | ventana de parry/block, fuerza, cooldown, estado del arma |
| Defensa | ReleaseBlock | fin canonico del bloqueo y recovery |
| Defensa | StartDodge | stamina, i-frames, direccion, cooldown |
| Impacto | ResolveImpact | resultado final: hit/block/parry/dodge/stagger |
| Impacto | RequestHitboxOnImpact | hitbox y posicion usada para confirmar impacto |
| Movimiento | UpdateCharacterCFrame | posicion canonica o reconciliada |
| Movimiento | SetDesiredMoveDirection | aceleracion y direccion validas |
| Movimiento | SetDesiredLookDirection | giro/mirada validos |
| Objetivo | SetTargetLock | target valido en arena/match |
| Objetivo | SetTargetSelection | seleccion valida y visible |
| Estado | SetEquippedWeapon | arma poseida, swap permitido, cooldown |
| Estado | RequestResetCharacter | fase permitida y penalizacion |
| Stagger | StartStagger / SoftStagger | stagger final y cancelaciones |

## Notificaciones servidor -> cliente

| Area | Flujo observado | Uso esperado |
| --- | --- | --- |
| Confirmacion | QueueBasicAttack / QueueJump | aceptar o rechazar prediccion local |
| Impacto | RegisterImpact / BasicAttackImpact | mostrar FX y pedir prediccion si aplica |
| Acciones | SwitchToAction / SwitchToActionModule | alinear estado visual con servidor |
| Defensa | MiniStun / SetServerStagger / CompleteStagger | feedback y control local |
| Movimiento | FinishJump / JumpPrepareAttack | completar transiciones |
| Estado | ResetState / DeathAction / UniqueActionCancelled | correccion y limpieza |
| Visual | WhiteOutlineOverlay / StartCriticalStrike / StartUltimateAbility | UI/FX/cinematica |

## Validaciones minimas por request

### QueueBasicAttack

- jugador vivo, en match y no aturdido;
- arma equipada en servidor;
- arma desbloqueada y permitida en esa partida;
- accion anterior permite cancel/chain;
- cooldown por ataque;
- ultimate solo si energia servidor >= 100;
- id de prediccion opcional, no autoridad.

### ResolveImpact

- `impactId` emitido por servidor;
- defensor correcto;
- impacto no expirado ni usado;
- atacante y defensor en la misma partida;
- distancia/angulo/linea de vision dentro de limites;
- estado de block/parry/dodge calculado en servidor;
- resultado final aplicado una sola vez.

### RequestHitboxOnImpact

- solicitud emitida por servidor;
- tiempo dentro de ventana;
- CFrame reconciliado, no crudo;
- hitbox derivada de arma/accion servidor;
- lista de objetivos calculada o filtrada por servidor.

### StartBlock / StartDodge

- stamina servidor suficiente;
- cooldown servidor;
- accion actual permite defensa;
- direccion normalizada;
- ventana de parry/dodge iniciada con reloj servidor.

### UpdateCharacterCFrame

- delta de posicion maximo;
- delta de rotacion maximo;
- aceleracion maximo;
- tolerancia por ping;
- fallback a root CFrame servidor ante anomalia.

## Telemetria recomendada

Registrar por jugador y remote:

- razon de rechazo;
- valor normalizado aplicado;
- delta de CFrame;
- impacto desconocido/expirado/repetido;
- target invalido;
- cooldown violado;
- frecuencia por ventana.

## Umbrales iniciales sugeridos

| Senal | Accion |
| --- | --- |
| 5 impactos desconocidos en 10 s | marcar jugador para observacion |
| 3 CFrames imposibles en 5 s | forzar resync de posicion |
| 10 ataques rechazados en 10 s | enfriar inputs de combate |
| 5 claims/compras invalidas en 60 s | bloquear endpoint temporalmente |
| uso de debug command en produccion | alerta inmediata |

