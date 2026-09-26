# Base de datos del club de puntos (Supabase)

Estos archivos crean la base de datos del club, en orden:

1. `migraciones/001_club_de_puntos.sql`: tablas, reglas del programa y permisos.
2. `migraciones/002_vencimiento_diario.sql`: el vencimiento automático de puntos.
3. `pruebas/pruebas_seguridad.sql`: comprueba que nadie pueda sumarse puntos
   solo ni ver datos de otro socio.

Se aplican una sola vez, en el proyecto de Supabase **burgercouple-club**.
**Nunca** en el proyecto de BC OS.

Si hay que cambiar algo, se agrega un archivo nuevo (`003_...`). Los que ya
se aplicaron no se editan, así queda la historia de cada cambio.
