# Alcance autorizado

Este repositorio esta pensado para auditorias defensivas de experiencias Roblox propias o revisadas con permiso explicito del propietario.

## Permitido

- Inventariar remotes y scripts para entender superficies de entrada.
- Describir decisiones que hoy dependen del cliente.
- Proponer validaciones de servidor.
- Crear NPCs de entrenamiento dentro del juego para probar balance.
- Escribir pruebas y escenarios reproducibles sin afectar jugadores reales.

## No permitido

- Crear automatizacion para ganar contra jugadores.
- Aprovechar huecos de validacion en servidores de terceros.
- Invocar remotes fuera del flujo normal del juego.
- Evasiones de cooldown, distancia, stamina, hitboxes o estado.
- Publicar nombres, rutas o payloads sensibles que faciliten abuso.

## Formato de hallazgo seguro

Cada hallazgo debe escribirse asi:

```text
Titulo:
Impacto defensivo:
Evidencia no explotable:
Correccion:
Prueba de regresion:
Estado:
```

