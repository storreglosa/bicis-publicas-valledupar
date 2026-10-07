# Runbook — operación técnica

## 1. Configuración inicial (Fase 0) — la hace Santiago

Las etiquetas exactas de los menús de Supabase y Cloudflare pueden variar; si algo no coincide, avisa y se
ajusta esta guía.

### 1.1 Supabase: organización y dos proyectos
1. Crear la cuenta en supabase.com, idealmente con un **correo institucional** como dueño, y **activar 2FA**.
2. Crear una organización (p. ej. `STTV Valledupar`) en el plan **Free**. Confirmar que no haya otro proyecto
   Free activo: el plan permite dos y los usaremos ambos.
3. Crear dos proyectos, los dos en la región **East US (North Virginia) / us-east-1** (decisión D-12):
   - `bicis-valledupar-dev`: desarrollo y pruebas, solo datos ficticios.
   - `bicis-valledupar-prod`: operación real.
   Guarda la **contraseña de la base de datos** de cada uno en un gestor de contraseñas. No la pegues en el chat.
4. En cada proyecto: Authentication → desactivar **"Allow new users to sign up"**. Solo el administrador crea cuentas.
5. Anota de cada proyecto (Project Settings → API / API Keys):
   - **Project URL** (`https://<ref>.supabase.co`) y el **ref**.
   - **Publishable key** (`sb_publishable_…`): es pública, va en el frontend.
   - La **secret key** (`sb_secret_…`) **no** se comparte ni se pega en el chat; se usará solo en los secretos
     de las Edge Functions.
6. En Connect → **Session pooler** (puerto 5432, IPv4): anota host y usuario (`postgres.<ref>`).

### 1.2 Credenciales locales para psql / pg_dump / pruebas
Fuera del repo, en tu carpeta personal. Claude no lee estos archivos; los usan `psql`, `pg_dump` y psycopg.

`~/.pg_service.conf`:
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

`~/.pgpass` (una línea por proyecto; luego `chmod 600 ~/.pgpass`):
```
<host dev>:5432:postgres:postgres.<ref dev>:<contraseña dev>
<host prod>:5432:postgres:postgres.<ref prod>:<contraseña prod>
```

Prueba (con el entorno conda activo):
```bash
conda activate bicis
psql "service=bicis_dev" -c "select version();"
```

### 1.3 Cloudflare Turnstile (anti-spam de la preinscripción)
1. Cuenta gratuita en Cloudflare → Turnstile → agregar un widget en modo **Managed**.
2. Dominios: `storreglosa.github.io` y `localhost`.
3. Anota la **site key** (es pública). La **secret key** irá a los secretos de la Edge Function `preinscribir`;
   no la pegues en el chat.

### 1.4 Lo que me pasas cuando termines
Solo datos públicos: el **ref** y la **Project URL** de dev y de prod, las dos **publishable keys** y la
**site key** de Turnstile. Las contraseñas y las claves secretas se quedan en tus archivos o en el Dashboard.

## 2. Migraciones
(se completa en Fase 1a: `scripts/migrar.sh dev|prod`)

## 3. Respaldo y restauración
(se completa en Fase 1g)

## 4. Si el proyecto se pausa
El plan Free pausa el proyecto tras 7 días sin actividad. Los datos no se borran: se reactiva desde el Dashboard
del proyecto (Restore). Si pasa en prod, revisar que `mantener-activo.yml` siga habilitado en GitHub Actions.
