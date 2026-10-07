# Runbook — operación técnica

## 1. Configuración inicial — la hace Santiago

Verificada contra la documentación oficial el 2026-10-07 (Supabase: *Connecting to Postgres*, *API keys*,
*General configuration*; Cloudflare: *Turnstile dashboard*, *Testing*). Si algún menú no coincide, avisa y se
ajusta esta guía.

**Qué se crea y cuándo**
| Qué | Cuándo | Por qué |
|---|---|---|
| Proyecto Supabase **dev** | Ahora | Bloquea la demo y la vista del operador |
| Proyecto Supabase **prod** | En el hito 1g (antes del piloto) | El plan Free pausa un proyecto tras 7 días sin uso |
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
host=<host del session pooler>
port=5432
dbname=postgres
user=postgres.<ref>
sslmode=require
```

```bash
nano ~/.pgpass
```
```
<host del session pooler>:5432:postgres:postgres.<ref>:<contraseña de la base de datos>
```
Si la contraseña tiene `:` o `\`, escríbelos como `\:` y `\\`. Luego:

```bash
chmod 600 ~/.pgpass
conda activate bicis
psql "service=bicis_dev" -c "select version();"
```
Debe responder `PostgreSQL 17…`.

### 1.3 Cloudflare Turnstile (más adelante, hito 1e/1g)
1. Cuenta gratuita en Cloudflare → **Turnstile** → **Add widget**.
2. Nombre: `Bicis Públicas Valledupar`; hostname: **solo** `storreglosa.github.io` (Cloudflare recomienda que la
   clave real no admita dominios locales); modo **Managed**; sin pre-clearance.
3. **Create** → copia la **sitekey** (pública) y guarda la **secret key** (irá a los secretos de la Edge Function
   `preinscribir`; no la pegues en el chat).
4. En desarrollo se usan las claves de prueba de Cloudflare (sitekey `1x00000000000000000000AA`, secret
   `1x0000000000000000000000000000000AA`: siempre pasan; funcionan en `localhost`).

### 1.4 Lo que me pasas cuando termines
Solo datos públicos: el **ref**, la **Project URL** y la **publishable key** de dev; el **correo** de tu cuenta
de administrador (para vincularla como administrador) y la confirmación de que el `psql` de 1.2 respondió.
Las contraseñas y las claves secretas se quedan en tus archivos o en el Dashboard.

## 2. Migraciones
(se completa al conectar dev: `scripts/migrar.sh dev|prod`)

### 2.1 Verificaciones obligatorias la primera vez contra Supabase (dev)
Salen de la revisión de seguridad de la fase 1a: en local no se pueden comprobar.
- [ ] `select rolsuper, rolbypassrls from pg_roles where rolname = 'postgres';` — anotar el resultado.
- [ ] Préstamo de punta a punta con foto subida por la API de Storage (no por SQL): confirma que
      `registrar_prestamo` ve el objeto y que `metadata->>'size'` existe.
- [ ] `select relrowsecurity from pg_class where oid = 'auth.users'::regclass;` y `vincular_personal` real.
- [ ] El INSERT del bucket aceptó `file_size_limit` y `allowed_mime_types`; `select public from storage.buckets where id = 'evidencias'` → `false`.
- [ ] `test_superficie` contra dev después de cada `db push` (anon, authenticated, service_role, PUBLIC).
- [ ] PostgREST: una RPC con `Prefer: tx=rollback` no debe poder revertir la bitácora de `buscar_persona`.
- [ ] Un error de validación en `validar_persona` vía HTTP: el campo `details` de la respuesta debe venir vacío.

### 2.2 Riesgos residuales aceptados (MVP)
- Las lecturas directas del administrador (`personas`, `v_prestamos_admin`) no se registran en la bitácora;
  las exportaciones sí (pgaudit u RPC de lectura en Fase 2).
- `marcar_clave_cambiada` es un control de interfaz: no comprueba que la clave haya cambiado.
- El mensaje «ya estás inscrito» revela que un documento existe (mitigado con Turnstile y límite de tasa).

## 3. Respaldo y restauración
(se completa en Fase 1g)

## 4. Si el proyecto se pausa
El plan Free pausa el proyecto tras 7 días sin actividad. Los datos no se borran: se reactiva desde el Dashboard
del proyecto (Restore). Si pasa en prod, revisar que `mantener-activo.yml` siga habilitado en GitHub Actions.
