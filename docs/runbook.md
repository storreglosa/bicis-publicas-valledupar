# Runbook — operación técnica

## 1. Configuración inicial — la hace Santiago

Verificada contra la documentación oficial el 2026-10-07 (Supabase: *Connecting to Postgres*, *API keys*,
*General configuration*; Cloudflare: *Turnstile dashboard*, *Testing*). Si algún menú no coincide, avisa y se
ajusta esta guía.

**Qué se crea y cuándo**
| Qué | Cuándo | Por qué |
|---|---|---|
| Proyecto Supabase **dev** | Ahora | Bloquea la demo y la vista del operador |
| Proyecto Supabase **prod** | Ya creado (2026-10-07); se usa desde el hito 1g | Mientras esté vacío puede pausarse a los 7 días sin uso: se reactiva con **Restore** en su Dashboard, sin pérdida |
| Widget **Turnstile** real | En el hito 1e/1g | En desarrollo se usan las claves de prueba de Cloudflare, que funcionan en `localhost` |

### 1.1 Supabase: cuenta, organización y proyecto dev
1. Entra a https://supabase.com/dashboard y crea la cuenta (idealmente con el **correo institucional**).
   Activa la verificación en dos pasos (MFA) en la configuración de tu cuenta.
2. Crea una **organización** (p. ej. `STTV Valledupar`) en el plan **Free**.
3. **New project**:
   - Nombre: `bicis-valledupar-dev`
   - Database password: usa **Generate a password** y guárdala en un gestor de contraseñas. No la pegues en el chat.
   - Region: **East US (North Virginia)** (decisión D-12).
   - Si aparece una sección de seguridad/Data API: deja **activa** la Data API y **sin** exponer tablas
     automáticamente (las migraciones conceden permisos de forma explícita).
   - Espera a que termine de aprovisionar (unos minutos).
Los pasos 4 y 5 se hacen en **cada** proyecto (dev y prod): cada uno tiene sus propios usuarios. Mismo correo,
claves distintas.

4. **Registro cerrado:** Authentication → configuración de *Sign In / Providers* → desactiva
   **"Allow new users to sign up"**. Deja activo el proveedor **Email** (el personal entra con correo y clave).
5. **Tu cuenta de administrador:** Authentication → Users → **Add user** → *Create new user*: tu correo y una
   clave fuerte, con **Auto Confirm User** marcado. Esa será la primera cuenta administradora de la app.
6. **Datos públicos** (Settings → **API Keys**, https://supabase.com/dashboard/project/_/settings/api-keys):
   - la **publishable key** (`sb_publishable_…`). Si el proyecto no tiene ninguna, créala ahí mismo.
   - La **secret key** (`sb_secret_…`) **no** se comparte ni se pega en el chat.
   - La **Project URL** es `https://<ref>.supabase.co`; el **ref** es ese subdominio.
7. **Conexión para psql:** botón **Connect** (arriba en el proyecto) → **Session pooler**. Anota el host
   (`aws-<n>-us-east-1.pooler.supabase.com`, cópialo tal cual: el número no se puede adivinar) y el usuario
   (`postgres.<ref>`). Puerto 5432.

### 1.2 Credenciales locales para psql / pg_dump / pruebas
Fuera del repo, en tu carpeta personal de WSL. Claude no lee estos archivos; los usan `psql`, `pg_dump` y psycopg.

```bash
nano ~/.pg_service.conf
```
```ini
[bicis_dev]
host=<host del session pooler de dev>
port=5432
dbname=postgres
user=postgres.<ref de dev>
sslmode=require

[bicis_prod]
host=<host del session pooler de prod>
port=5432
dbname=postgres
user=postgres.<ref de prod>
sslmode=require
```

```bash
nano ~/.pgpass
```
```
<host dev>:5432:postgres:postgres.<ref dev>:<contraseña de la base de datos de dev>
<host prod>:5432:postgres:postgres.<ref prod>:<contraseña de la base de datos de prod>
```
Si la contraseña tiene `:` o `\`, escríbelos como `\:` y `\\`. Luego:

```bash
chmod 600 ~/.pgpass
conda activate bicis
psql "service=bicis_dev" -c "select version();"
psql "service=bicis_prod" -c "select version();"
```
Ambos deben responder `PostgreSQL 17…`.

### 1.3 Cloudflare Turnstile (más adelante, hito 1e/1g)
1. Cuenta gratuita en Cloudflare → **Turnstile** → **Add widget**.
2. Nombre: `Bicis Públicas Valledupar`; hostname: **solo** `storreglosa.github.io` (Cloudflare recomienda que la
   clave real no admita dominios locales); modo **Managed**; sin pre-clearance.
3. **Create** → copia la **sitekey** (pública) y guarda la **secret key** (irá a los secretos de la Edge Function
   `preinscribir`; no la pegues en el chat).
4. En desarrollo se usan las claves de prueba de Cloudflare (sitekey `1x00000000000000000000AA`, secret
   `1x0000000000000000000000000000000AA`: siempre pasan; funcionan en `localhost`).
5. La **secret key** de prod no se escribe en ningún archivo: la pide por teclado (sin eco)
   `scripts/desplegar_funciones.sh prod --confirmar <ref>`. La **sitekey** va en la variable
   `VITE_TURNSTILE_SITE_KEY` de GitHub cuando el sitio pase a prod.
   Widget real creado el 2026-10-09 (hostname `storreglosa.github.io`); su sitekey quedó guardada en la variable
   `PROD_TURNSTILE_SITE_KEY` para ese cambio. La demo sigue con la clave de prueba.

### 1.4 Lo que me pasas cuando termines
Solo datos públicos: el **ref**, la **Project URL** y la **publishable key** de cada proyecto; el **correo** de tu
cuenta de administrador y la confirmación de que los dos `psql` de 1.2 respondieron. Prod no se toca hasta el
hito 1g y siempre con confirmación explícita.
Las contraseñas y las claves secretas se quedan en tus archivos o en el Dashboard.

## 2. Migraciones
```bash
scripts/migrar.sh dev                 # simulación: lista las pendientes
scripts/migrar.sh dev --aplicar       # aplica en dev (una transacción por archivo)
BICIS_BD_SERVICIO=bicis_dev python -m pytest tests/bd/test_superficie.py   # siempre después
```
Prod: `scripts/migrar.sh prod --aplicar --confirmar <ref-de-prod>`, solo con aprobación explícita de Santiago.
**Estado de prod (2026-10-08, aprobado por Santiago: «prepararlo vacío»):** 7 migraciones aplicadas,
`test_superficie` 14/14 contra prod, Santiago vinculado como administrador, `retencion.fotos_dias` = 7. Sin
política publicada (nadie se puede inscribir), sin puntos ni bicis: la página pública sigue apuntando a dev
hasta el concepto de Jurídica (C4). 2026-10-09: Santiago publicó las Edge Functions con el widget real de
Turnstile; comprobado: otro origen → 403, token falso → `verificacion_fallida` (secreto real, sin modo demo),
purga sin clave → 401, purga por pg_cron → `ok`; tareas `purgar-fotos` y `purgar-preinscripciones` activas.
Primer respaldo y simulacro de restauración hechos (§3). Más tarde ese día, con el OK de Santiago: migraciones
`20261009100000` y `20261009120000`, plazos 90 días / 24 meses (D-30) y código nuevo de las funciones (CORS con
`x-region`, sin `remoteip`), subido sin tocar los secretos (`functions deploy` solo); verificado: preflight con
`x-region`, token falso → `verificacion_fallida` desde `us-east-1`, purga sin clave → 401, superficie 14/14. Después,
también con su OK: migración `20261009150000` (eliminar puntos y eventos nunca usados, D-32); prod queda con las
10 migraciones de dev, superficie 14/14, vacío (0 personas, 0 puntos, 0 eventos). Con su OK, migración
`20261009170000` (descripción del plazo de preinscripciones: «anonimiza»); prod = dev con 11 migraciones.
Primer administrador de un proyecto: `scripts/vincular_admin_inicial.sh dev <correo> "<Nombre>"`.
Datos de demostración (solo dev): `python scripts/sembrar_dev.py`.

### 2.1 Verificaciones obligatorias la primera vez contra Supabase (dev)
Salen de la revisión de seguridad de la fase 1a: en local no se pueden comprobar.
- [x] `select rolsuper, rolbypassrls from pg_roles where rolname = 'postgres';` → dev 2026-10-07: `rolsuper = f`,
      `rolbypassrls = t`. Las funciones leen `storage.objects` y `auth.users` (la política explícita queda de respaldo).
- [x] Préstamo de punta a punta con foto subida por la API de Storage desde el celular de Santiago
      (2026-10-07, C2): 2 préstamos y devoluciones en dev; fotos WebP de 42 KB y 15 KB con `metadata.size`,
      `owner_id` y ligadas al préstamo; autorización presencial, bitácora y auditoría correctas.
- [x] `auth.users` tiene RLS (`t`), dueño `supabase_auth_admin`; `postgres` la lee por BYPASSRLS. Primer admin
      vinculado en dev con `vincular_admin_inicial.sh`.
- [x] `storage.buckets` tiene `file_size_limit` y `allowed_mime_types`; la migración de permisos se aplicó sin error.
- [x] `test_superficie` contra dev: 14/14 (2026-10-07). Repetir después de cada migración.
- [x] Privilegios por defecto de dev: esquema **clásico** (ALL para anon/authenticated/service_role en public), el
      peor caso que simula el stub. Supabase crea además `public.rls_auto_enable()` (trigger de eventos que activa
      RLS en tablas nuevas); la migración le quita el EXECUTE a PUBLIC sin apagar el trigger (probado en local).
- [x] PostgREST: una RPC con `Prefer: tx=rollback` no puede revertir la bitácora de `buscar_persona`
      (dev, 2026-10-09, sesión real de Santiago: la bitácora pasó de 10 a 11; PostgREST no aplicó la preferencia).
- [x] Un error de validación en `validar_persona` vía HTTP llega sin `details` ni `hint`
      (dev, 2026-10-09: `message='persona_no_existe'`, `details=None`, `hint=None`).
      Las dos se repiten con `scripts/verificar_http.sh dev|prod <correo>` (pide la clave sin mostrarla).

### 2.3 Edge Functions y tareas programadas (hitos 1e y 1f)
Una vez por máquina, en tu terminal (abre el navegador; el token lo guarda la CLI, nadie lo copia):
```bash
npx supabase@2.117.0 login
```
Publicar (funciones `preinscribir` y `purgar-fotos`, sus secretos, Vault y `pg_cron`):
```bash
scripts/desplegar_funciones.sh dev
scripts/desplegar_funciones.sh prod --confirmar <ref-de-prod>    # pide la secret key de Turnstile
```
Cada corrida genera de nuevo `SAL_IP` y `CLAVE_CRON` al azar (no se muestran). En dev fija además
`SOLO_DATOS_FICTICIOS=1`: la demo pública solo acepta documentos que empiezan por 00 (D-27). Comprobar después:
- [ ] Inscribirse en `#/inscribirme` de la demo con datos inventados (documento 00…) → «Listo: quedaste
      preinscrito». Con un documento que no empiece por 00, la función responde `solo_datos_ficticios`.
- [ ] En los registros de la función (Dashboard → Edge Functions → preinscribir → Logs) no aparece
      «la petición llegó sin IP del visitante» (D-25).
- [ ] `select jobname, schedule, active from cron.job;` → `purgar-fotos` (0 8 * * *) y
      `purgar-preinscripciones` (15 8 * * *), activos. 08:00 UTC = 03:00 en Colombia.
- [ ] Al día siguiente, el tablero muestra la última purga con resultado `ok`.

### 2.2 Riesgos residuales aceptados (MVP)
- Las lecturas directas del administrador (`personas`, `v_prestamos_admin`) no se registran en la bitácora;
  las exportaciones sí (pgaudit u RPC de lectura en Fase 2).
- `marcar_clave_cambiada` es un control de interfaz: no comprueba que la clave haya cambiado.
- El mensaje «ya estás inscrito» revela que un documento existe (mitigado con Turnstile y límite de tasa).
- Los intentos de preinscripción con datos inválidos no cuentan para el límite (se revierten con su
  transacción); cada uno exige igual un token nuevo de Turnstile.
- La CSP va en `<meta>` (GitHub Pages no deja poner cabeceras): `frame-ancestors` no aplica, así que otra
  página podría incrustar el sitio en un iframe. Se cierra al migrar a un alojamiento con cabeceras.
- Si la base es la que falla al listar o marcar fotos, la purga no borra nada ese día y queda en error en el
  tablero; los archivos de un borrado fallido se reintentan como huérfanos al día siguiente.

## 3. Respaldo y restauración
El plan Free no trae respaldos. Una vez, crea tu clave gpg (la frase de paso solo la sabes tú; sin ella no se
puede restaurar):
```bash
gpg --quick-gen-key "Santiago Torreglosa - respaldos bicis <correo-institucional>" default default 2y
```
Respaldo (semanal; también antes de cada migración en prod):
```bash
BICIS_RESPALDO_GPG=<correo de la clave> scripts/respaldar_bd.sh prod
```
- Queda en `~/Claude_code/respaldos-bicis/AAAA-MM-DD_bicis_prod.tar.gpg` (fuera del repo, permisos 600). Copia
  el archivo a almacenamiento institucional: si el computador se daña, el respaldo local se pierde con él.
- Guarda public y privado (estructura y datos), id/correo/fecha de las cuentas y los conteos. **No** guarda las
  fotos de Storage (las conservadas por incidencia se exportan en Fase 2).
- Conserva los 8 más recientes y el primero de cada mes de los últimos 12. El tablero muestra el último.

Simulacro de restauración (trimestral; restaura en el Postgres local, nunca sobre Supabase):
```bash
scripts/pg_local.sh start
scripts/restaurar_prueba.sh ~/Claude_code/respaldos-bicis/<archivo>.tar.gpg
```
Compara tabla por tabla con los conteos del respaldo y borra la base local al final. Probado contra dev el
2026-10-08 con una clave desechable: 19/19 tablas coinciden. Primer respaldo real de prod (vacío) el 2026-10-09
con la clave de Santiago (subclave de cifrado `C907655386CDE0C0`, vence 2028-10-08) y simulacro con su frase de
paso: «Restauración verificada». La clave privada y el certificado de revocación tienen copia fuera de
`~/.gnupg` (pendiente una copia fuera de este computador).

Programación: WSL no corre cron sin systemd. Propuesta (no verificada en este equipo): Programador de tareas de
Windows con `wsl.exe -e bash -lc "cd ~/Claude_code/bicis-publicas-valledupar && BICIS_RESPALDO_GPG=… scripts/respaldar_bd.sh prod"`.
Depende de que el PC esté encendido: con el plan Pro, Supabase hace respaldos diarios propios.

## 4. Si el proyecto se pausa
El plan Free pausa el proyecto tras 7 días sin actividad. Los datos no se borran: se reactiva desde el Dashboard
del proyecto (Restore). Si pasa, revisar que `mantener-activo.yml` siga habilitado en GitHub Actions: GitHub
apaga los flujos programados de un repo público tras **60 días sin commits** (se reactivan desde la pestaña
Actions con «Enable workflow»).

## 5. Automatizaciones del repositorio
- `.githooks/pre-commit`: el escáner revisa lo que va en cada commit y lo detiene si hay datos personales o
  secretos. Se activa una vez por clon: `git config core.hooksPath .githooks`.
- `.github/workflows/ci.yml`: en cada push y pull request, pruebas unitarias, contraste WCAG, pruebas del
  escáner, build y escáner (sin credenciales).
- `.github/workflows/desplegar.yml`: push a `main` → pruebas, build con las variables de dev, escáner y Pages.
- `.github/workflows/mantener-activo.yml`: lectura pública diaria de dev y prod (variables `VITE_SUPABASE_*` y
  `PROD_SUPABASE_URL` / `PROD_SUPABASE_PUBLISHABLE_KEY`, públicas por diseño). Se puede correr a mano desde
  Actions → Mantener activo → Run workflow.
- `.github/dependabot.yml`: cada mes propone actualizar las acciones fijadas por SHA (pull request para revisar).

## 6. Modo «Presentar» y video para reenviar
El botón **▶ Presentar** del aviso DEMO abre `#/presentacion`: recorrido de unos 3 minutos con subtítulos para
mostrar el sistema en reunión (Espacio pausa, ← → cambian de escena, Esc sale). Textos y tiempos en
`src/presentacion/guion.js`; los clips (`public/presentacion/`) se graban con datos ficticios.

Para regenerar los clips (tras cambiar pantallas que salen en ellos) y el video MP4:
```bash
npx vite build --mode development --outDir dist-demo
npx vite preview --mode development --outDir dist-demo --port 4174      # en otra terminal
node scripts/grabar_presentacion.mjs     # clips → public/presentacion/ (luego otro build)
node scripts/grabar_video.mjs            # → capturas/presentacion.mp4 (1080p, ~181 s; fuera de git)
```
`grabar_video.mjs` informa el desfase entre la duración real y la del guion. Si supera ~1 s, el equipo
estaba ocupado y los subtítulos se atrasan frente a los clips: cerrar otros programas y repetir. El video
necesita ffmpeg con libx264 (entorno conda `video`, o la variable `FFMPEG`).
