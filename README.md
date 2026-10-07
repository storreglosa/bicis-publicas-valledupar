# Bicis Públicas Valledupar

Página web para gestionar el sistema de bicicletas públicas de la Secretaría de Tránsito y Transporte de
Valledupar (STTV): información al ciudadano, mapa de puntos con disponibilidad en tiempo real, preinscripción
en línea y registro asistido de préstamos y devoluciones con evidencia fotográfica e historial completo.

> Nombre provisional. Estado: **en construcción, aún no operativo**.

**Demo:** https://storreglosa.github.io/bicis-publicas-valledupar/ — conectada a un proyecto de desarrollo
con **datos ficticios** (puntos de prueba en lugares reales de Valledupar, marcados «demo»). No ingreses
datos personales reales.

## Cómo funciona
- **Préstamo asistido por operador**: el ciudadano presenta su documento (solo se exhibe, nunca se retiene),
  el operador lo valida y registra el préstamo desde un celular o tableta.
- **Puntos fijos y de evento**: puntos permanentes y puntos temporales para ciclopaseos y jornadas.
- **Sin GPS ni pagos por ahora**: la disponibilidad se calcula a partir de los préstamos y devoluciones
  registrados. El modelo de datos está preparado para incorporar GPS.

## Arquitectura
- Frontend estático (Vue 3 + Vite) publicado en GitHub Pages.
- Backend en Supabase: PostgreSQL con seguridad a nivel de fila, funciones para préstamo y devolución,
  autenticación del personal, tiempo real y almacenamiento privado de fotos.
- **Este repositorio no contiene datos personales.** Los datos de los usuarios viven solo en la base de datos.

## Documentación
| Documento | Contenido |
|---|---|
| [docs/plan-aprobado-2026-10-07.md](docs/plan-aprobado-2026-10-07.md) | Plan aprobado: decisiones, arquitectura, fases |
| [docs/diseno-detallado.md](docs/diseno-detallado.md) | Diseño técnico completo: SQL, seguridad, API, vistas |
| [docs/investigacion/](docs/investigacion/) | Investigación de referencia: OpenSourceBikeShare, OpenBike, GBFS, casos y normativa |

## Publicación segura
Antes de cada despliegue, `scripts/verificar_publicacion.py` revisa el build y **todo el historial** de git en
busca de correos, celulares, claves secretas y archivos que no deben publicarse; si encuentra algo, el
despliegue se detiene (`.github/workflows/desplegar.yml`).

## Licencia
Pendiente de definir por la entidad (decisión D-20). Mientras tanto, todos los derechos reservados.
