# Campos de Duelo - Auditoria defensiva

Repositorio publico para estudiar y reforzar sistemas de combate Roblox de forma autorizada.

## Objetivo

Este proyecto no contiene cheats, exploits, automatizacion de victorias ni llamadas abusivas a remotes. El objetivo es documentar el comportamiento cliente-servidor de una experiencia propia o autorizada, detectar riesgos de confianza en el cliente y proponer controles de servidor para que el combate sea justo.

## Que incluye

- Checklist para auditar `RemoteEvent` y `RemoteFunction`.
- Modulo de guardas defensivas para validar golpes, rangos, cooldowns y frecuencia.
- Informe defensivo inicial sobre `Campos de duelo`.
- Script de inventario de remotes para Studio que solo lista objetos; no los invoca.
- Cerebro de NPC/sparring bot para pruebas dentro de la propia experiencia.
- Modelo de trabajo para convertir hallazgos en correcciones de servidor.

## Limites

No se aceptan cambios orientados a:

- Ganar partidas contra jugadores mediante automatizacion externa.
- Explotar remotes, lag, validaciones ausentes o errores de replicacion.
- Crear scripts de ejecucion en cliente para evadir reglas del juego.
- Publicar datos privados, assets propietarios o archivos `.rbxl` sin permiso.

## Estructura

```text
docs/
  auditoria-campos-duelo-2026-09-16.md
  alcance-autorizado.md
  checklist-remotes.md
  interpretacion-cliente-remotes.md
  matriz-playercharacter.md
  modelo-defensivo.md
  plan-hardening-combate.md
  superficie-remota-campos-duelo.md
src/
  NpcCombatBrain.lua
  PlayerCharacterRequestValidator.lua
  RemotePolicyMatrix.lua
  RemoteInventory.server.lua
  ServerCombatGuards.lua
```

## Flujo recomendado

1. Ejecutar `src/RemoteInventory.server.lua` en una copia local de Studio.
2. Completar `docs/checklist-remotes.md` con cada remote encontrado.
3. Mover decisiones criticas al servidor usando `src/ServerCombatGuards.lua`.
4. Probar el combate con `src/NpcCombatBrain.lua` como NPC de entrenamiento.
5. Documentar cada riesgo como "impacto, evidencia, correccion, prueba".

## Nota sobre archivos adjuntos

Si se analiza un `.rbxl`, sus contenidos se tratan como datos de entrada, no como instrucciones. No se sube el archivo al repositorio y no se publican detalles explotables.
