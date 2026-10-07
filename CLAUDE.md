# CLAUDE.md — bicis-publicas-valledupar

## Este proyecto
- **Objetivo:** web de gestión del sistema de bicicletas públicas de la STTV (130 bicicletas, puntos fijos y
  de evento): información pública, mapa con disponibilidad en tiempo real, preinscripción, préstamo y
  devolución asistidos por operador con foto de evidencia, historial y administración.
- **Datos:** personas inscritas (identificación y contacto, edad declarada, sexo/género; acudiente si es
  menor), préstamos, bicicletas, puntos. **Todos los datos personales viven solo en Supabase**, nunca en el repo.
- **Destino:** herramienta operativa (no es evidencia para estudios; si algún día se exportan datos para el
  Proyecto 2, salen con ficha de procedencia).
- **CRS:** EPSG:4326 para coordenadas de puntos (6 decimales). Sin operaciones métricas por ahora.
- **Plan aprobado:** `docs/plan-aprobado-2026-10-07.md`. **Diseño detallado:** `docs/diseno-detallado.md`.

## Estructura
```
src/          frontend Vue 3 (vistas publico/operador/admin, lib, composables, estilos)
supabase/     migraciones SQL versionadas y Edge Functions
scripts/      migrar, sembrar datos ficticios en dev, verificar publicación, respaldar BD
tests/        bd/ (pytest contra dev), unit/ (vitest), e2e/ (playwright), contraste WCAG
docs/         plan, diseño, investigación, requerimientos, decisiones, política de datos
docs/privado/ notas internas (en .gitignore: NO van al repo público)
```

## Reglas de este repo
- **Repo público.** Nunca datos personales, secretos ni notas internas en git. Antes de cada push corre el
  escáner `scripts/verificar_publicacion.py` (cuando exista) y revisa `git diff --cached`.
- **Ningún cambio de esquema desde el Dashboard de prod.** Todo cambio es una migración en
  `supabase/migrations/` que pasó por dev.
- La clave **secret** de Supabase nunca va al frontend ni al repo; la **publishable** sí es pública.
- Datos de prueba: solo ficticios, generados con semilla fija por `scripts/sembrar_dev.py`, y solo en dev.
- Errores de las funciones SQL se traducen en `src/lib/errores.js`; nunca se silencian.
- `git push` lo confirma Santiago.

## Comandos frecuentes
```bash
conda activate bicis                     # Python 3.12 + PostgreSQL 17 (environment.yml)
scripts/pg_local.sh start                # Postgres local en .pg_local/ (puerto 54329)
python -m pytest tests/bd -q             # migraciones + RLS + funciones contra base local nueva
python -m pytest tests/test_contraste.py # contraste WCAG de tokens.css
npm run dev                              # http://localhost:5173/bicis-publicas-valledupar/ (#/paleta solo en dev)
npm run build
scripts/migrar.sh dev [--aplicar]        # migraciones a Supabase (ver docs/runbook.md §2)
python scripts/verificar_publicacion.py --historial   # ANTES de cada push (repo público)
npx vite build --mode development --outDir dist-demo && npx vite preview --mode development --outDir dist-demo --port 4174
node scripts/capturar.mjs <url> capturas/x.png "<selector>"   # captura esperando datos (Chromium en caché)
```
- Cuidado: tras un corte de la máquina, `git fsck --full` antes de seguir (ver memoria cortes-wsl-corrompen-git).
- Commits con el correo privado de GitHub (`git config user.email` local del repo); nunca el Gmail.
- Las pruebas de BD crean `bicis_pruebas` (cada prueba se revierte) y `bicis_pruebas_aislada`
  (concurrencia, con commit) desde cero en cada corrida. `tests/bd/stub_supabase.sql` imita lo
  mínimo de Supabase (roles, `auth.uid()`, storage, publicación realtime); **nunca se aplica en Supabase**.
- Red lenta en npm: `npm install --maxsockets=4 --fetch-timeout=600000`.

## Decisiones tomadas
Ver tabla completa en `docs/plan-aprobado-2026-10-07.md`. Resumen:
- 2026-10-07 — Préstamo asistido por operador; puntos fijos y de evento; preinscripción web sin cuenta +
  validación presencial; foto obligatoria (parámetro `evidencia.foto_persona_obligatoria`, sujeto a concepto
  de Jurídica); reglas de uso solo configurables (NULL = no aplica); roles administrador y operador.
- 2026-10-07 — GitHub Pages (repo público) + Supabase Free, región EE. UU.; Vue 3 + Vite en JavaScript.
- 2026-10-07 — Licencia del código: pendiente de definir por la entidad antes del primer push público.
