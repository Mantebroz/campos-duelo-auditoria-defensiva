# Checklist de remotes

Usa esta tabla para cada `RemoteEvent` o `RemoteFunction` encontrado.

| Remote | Direccion | Uso esperado | Validacion requerida | Estado |
| --- | --- | --- | --- | --- |
| Pendiente | Cliente -> Servidor | Pendiente | Pendiente | Pendiente |

## Preguntas de auditoria

- El servidor decide si el golpe existe, o solo acepta una afirmacion del cliente?
- El servidor valida distancia maxima entre atacante y objetivo?
- El servidor valida linea de vision o angulo de ataque cuando aplica?
- El servidor valida cooldown, stun, bloqueo, stamina y estado de arma?
- El servidor limita frecuencia por jugador y por accion?
- El servidor ignora objetivos muertos, invulnerables o fuera de arena?
- El servidor recalcula dano, knockback y recompensa sin confiar en numeros del cliente?
- El servidor registra rechazos para detectar patrones anomalos?
- Los remotes tienen nombres y rutas que no revelan secretos innecesarios?

## Senales de riesgo

- Payloads que incluyen `damage`, `critical`, `comboIndex` o `targetState` enviados por el cliente y aceptados sin recalculo.
- Remotes que aceptan cualquier instancia como objetivo.
- Cooldowns medidos solo en LocalScripts.
- Movimiento o esquiva confirmado por cliente sin limites de velocidad/aceleracion.
- Recompensas, monedas o victorias calculadas desde eventos del cliente.

