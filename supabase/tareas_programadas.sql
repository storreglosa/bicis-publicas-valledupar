-- Tareas programadas (pg_cron) y sus secretos en Vault. NO es una migración: la
-- aplica scripts/desplegar_funciones.sh con psql, que antes define las variables
-- :clave_cron y :url_purga (nunca quedan en el repositorio ni en la línea de comandos).
-- Es idempotente: se puede volver a correr (rota la clave del cron).
\set ON_ERROR_STOP on

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- Secretos en Vault (cifrados en reposo). Crear o actualizar.
select vault.update_secret(s.id, :'clave_cron') from vault.secrets s where s.name = 'clave_cron';
select vault.create_secret(:'clave_cron', 'clave_cron', 'Cabecera x-clave-cron de la Edge Function purgar-fotos')
 where not exists (select 1 from vault.secrets s where s.name = 'clave_cron');
select vault.update_secret(s.id, :'url_purga') from vault.secrets s where s.name = 'url_purgar_fotos';
select vault.create_secret(:'url_purga', 'url_purgar_fotos', 'URL de la Edge Function purgar-fotos')
 where not exists (select 1 from vault.secrets s where s.name = 'url_purgar_fotos');

-- 03:00 hora de Colombia (08:00 UTC): purga de fotos vencidas.
select cron.schedule('purgar-fotos', '0 8 * * *', $tarea$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'url_purgar_fotos'),
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-clave-cron', (select decrypted_secret from vault.decrypted_secrets where name = 'clave_cron')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000)
$tarea$);

-- 03:15 hora de Colombia: anonimiza preinscripciones nunca validadas (si hay plazo definido).
select cron.schedule('purgar-preinscripciones', '15 8 * * *', $tarea$ select privado.purgar_preinscripciones() $tarea$);

select jobname, schedule, active from cron.job where jobname in ('purgar-fotos', 'purgar-preinscripciones') order by 1;
