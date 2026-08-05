# Umbrella Soccer 1.0.1 — Release Notes

Versión de corrección sobre 1.0.0. Sin cambios de configuración necesarios: ningún cvar se agregó ni cambió de valor por defecto.

## Correcciones
- **Penales**: el gol se detecta automáticamente. Antes había que marcarlo a mano con `sm_soccer_goal <ct/t>` o el penal terminaba en fallo por timeout, lo que además dejaba inutilizable la tanda completa.
- **Tanda de penales**: ahora cierra cuando la ventaja es irremontable, como en el fútbol real. Si vas 3-0 en tres rondas, no se patean las dos que faltan. Y en muerte súbita no termina hasta que ambos equipos patearon lo mismo: antes el que abría la sexta ronda ganaba al convertir, sin respuesta del rival. Los bots tampoco pueden ser tiradores.
- **Posición del tirador**: en el penal ahora aparece detrás de la pelota y mirando al arco. Antes quedaba cruzado de costado.
- **Goles fantasma**: si un período duraba más que `mp_roundtime`, la ronda expiraba sola y CT recibía un gol que nadie hizo. Ahora solo cuentan los finales de ronda que corresponden a un gol.
- **Puntos de ronda**: los ±10 por ganar o perder el gol se reparten aunque el plugin no logre identificar al último jugador que tocó la pelota.
- **Tarjeta roja**: el expulsado ahora muere de forma confiable antes de pasar a espectador.
- **Tiempo añadido**: el modelo interno del trigger se precachea al iniciar el mapa, no a mitad de ronda.

## Limpieza
- Eliminados dos cvars que no tenían efecto: `sm_soccer_assist_window` y `sm_soccer_training_cannon_ball_life`. Si tu `cfg/sourcemod/umbrella_soccer.cfg` de 1.0.0 los tiene, se ignoran sin problema; este paquete ya los trae limpios.

## Instalación
Copiar `addons/` y `cfg/` a la raíz del juego (`cstrike/`), sobreescribiendo. Recargar el plugin o reiniciar el mapa.

- Compilado: SourcePawn 1.12.0.7239 (sin warnings)
- SHA256 (`umbrella_soccer.smx`): `FC7F6423A482B8C49492C6BE30EACBC0CB0A657CF35869EF605B2514BC1245FF`
