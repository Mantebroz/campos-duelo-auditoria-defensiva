# Modelo defensivo de combate

Un combate justo en Roblox debe ser servidor-autoritativo. El cliente puede pedir acciones e informar intencion, pero el servidor decide el resultado.

## Capas recomendadas

1. Entrada del cliente: accion solicitada, direccion, timestamp local opcional.
2. Normalizacion: convertir payloads a tipos esperados y descartar datos extra.
3. Rate limit: limitar frecuencia por remote y por accion.
4. Estado del jugador: vivo, no aturdido, arma equipada, arena valida.
5. Geometria: distancia, angulo, linea de vision y region de hitbox.
6. Economia de combate: cooldown, stamina, combo y recuperacion.
7. Resultado: dano, bloqueo, parry, knockback y recompensas calculados en servidor.
8. Observabilidad: logs de rechazos, contadores y alertas.

## Principio clave

El cliente nunca debe decidir hechos finales. Puede solicitar "quiero atacar"; no debe dictar "golpee a este jugador con 90 de dano".

## NPC de pruebas

El NPC de este repositorio esta pensado para balance y QA. Debe tener latencia de reaccion, limites de velocidad y reglas equivalentes a las de jugadores reales.

