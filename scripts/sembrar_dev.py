"""Siembra datos de DEMOSTRACIÓN en el proyecto Supabase de desarrollo.

    conda activate bicis
    python scripts/sembrar_dev.py

Crea (si no existen): 4 puntos fijos, 1 taller y 1 punto de evento en lugares
reales de Valledupar (coordenadas de OpenStreetMap/Nominatim, consultadas el
2026-10-07), las 130 bicicletas repartidas entre ellos, un evento de prueba y
el borrador de la política de datos publicado como versión de demostración.

Todos los nombres llevan «(demo)». No crea personas ni préstamos: esos datos los
genera el uso de la demo. Se niega a correr contra cualquier servicio que no sea
bicis_dev. Es idempotente: correrlo dos veces no duplica nada.

    python scripts/sembrar_dev.py --politica

publica en dev, como vigente, la versión de docs/politica-tratamiento-v1.md si aún no
existe (las versiones publicadas son inmutables: un cambio de texto exige una versión
nueva). Queda en la auditoría con su motivo.
"""

import pathlib
import re
import sys

import psycopg

SERVICIO = "bicis_dev"
RAIZ = pathlib.Path(__file__).resolve().parents[1]

# Supabase trabaja en UTC: current_date y date_trunc('day', now()) dan el día UTC,
# que después de las 7:00 p. m. de Colombia ya es «mañana». Fechas y horas de la
# semilla se calculan en hora de Colombia.
HOY_COLOMBIA = "(now() at time zone 'America/Bogota')::date"

# (código, nombre, tipo, estado, lat, lon, dirección, horario, bicis)
PUNTOS = [
    ("P01", "Plaza Alfonso López (demo)", "fijo", "activo", 10.477751, -73.244632,
     "Calle 15, Comuna 1", "Lunes a sábado, 6:00 a. m. – 6:00 p. m. (demo)", 35),
    ("P02", "Parque Novalito (demo)", "fijo", "activo", 10.481670, -73.248189,
     "Comuna 6", "Lunes a sábado, 6:00 a. m. – 6:00 p. m. (demo)", 30),
    ("P03", "Universidad Popular del Cesar (demo)", "fijo", "activo", 10.449123, -73.262523,
     "Carrera 30, Comuna 3", "Lunes a viernes, 7:00 a. m. – 5:00 p. m. (demo)", 30),
    ("P04", "Parque Lineal Hurtado (demo)", "fijo", "inactivo", 10.500424, -73.265668,
     "Carrera 4, Comuna 6", "Fines de semana (demo)", 20),
    ("T01", "Taller de la Secretaría (demo)", "taller", "activo", 10.477751, -73.244632,
     None, None, 5),
    ("E01", "Balneario Hurtado — ciclopaseo (demo)", "evento", "activo", 10.501328, -73.270795,
     "Vía Valledupar – San Juan del Cesar", "Domingo, 7:00 a. m. – 12:00 m. (demo)", 10),
]


def politica_demo() -> tuple[str, str, str, str]:
    """Toma el borrador de docs/politica-tratamiento-v1.md (sin comentarios HTML) y su versión."""
    texto = (RAIZ / "docs" / "politica-tratamiento-v1.md").read_text()
    version = re.search(r"\*\*Versión:\*\* ([0-9.]+)", texto).group(1)
    texto = re.sub(r"<!--.*?-->", "", texto, flags=re.S).strip()
    cuerpo, _, casillas = texto.partition("## Textos de autorización")
    citas = re.findall(r"^> (.+(?:\n> .+)*)", casillas, flags=re.M)
    limpiar = lambda c: re.sub(r"\n> ", " ", c).strip()
    return version, cuerpo.strip(), limpiar(citas[0]), limpiar(citas[1])


def main() -> None:
    with psycopg.connect(f"service={SERVICIO}") as conn:
        servicio = conn.info.get_parameters().get("service") or SERVICIO
        if servicio != SERVICIO:
            sys.exit(f"Me niego a sembrar en {servicio}: solo {SERVICIO}.")
        with conn.transaction(), conn.cursor() as cur:
            cur.execute("select set_config('app.accion', 'sembrar_dev', true)")

            cur.execute(
                f"""insert into public.eventos (nombre, descripcion, lugar_texto, inicia_en, termina_en, estado, publicado)
                   select 'Ciclopaseo de demostración', 'Evento ficticio para probar los puntos temporales.',
                          'Balneario Hurtado',
                          ({HOY_COLOMBIA} + 4 + time '07:00') at time zone 'America/Bogota',
                          ({HOY_COLOMBIA} + 4 + time '12:00') at time zone 'America/Bogota', 'planeado', true
                    where not exists (select 1 from public.eventos where nombre = 'Ciclopaseo de demostración')""")
            cur.execute("select id from public.eventos where nombre = 'Ciclopaseo de demostración'")
            evento = cur.fetchone()[0]

            numero = 1
            for codigo, nombre, tipo, estado, lat, lon, direccion, horario, cantidad in PUNTOS:
                cur.execute(
                    """insert into public.puntos (codigo, nombre, tipo, estado, evento_id, latitud, longitud, direccion, horario_texto)
                       values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                       on conflict (codigo) do nothing""",
                    (codigo, nombre, tipo, estado, evento if tipo == "evento" else None, lat, lon, direccion, horario))
                cur.execute("select id from public.puntos where codigo = %s", (codigo,))
                punto = cur.fetchone()[0]
                condicion = "en_reparacion" if tipo == "taller" else "operativa"
                disponibilidad = "no_disponible" if tipo == "taller" else "disponible"
                cur.execute(
                    f"""insert into public.bicicletas (numero, disponibilidad, condicion, punto_actual_id, marca, fecha_ingreso)
                       select n, %s, %s, %s, 'Demo', {HOY_COLOMBIA} from generate_series(%s::int, %s::int) n
                       on conflict (numero) do nothing""",
                    (disponibilidad, condicion, punto, numero, numero + cantidad - 1))
                numero += cantidad

            cur.execute("select count(*) from public.politicas_tratamiento")
            if cur.fetchone()[0] == 0:
                version, texto, autorizacion, foto = politica_demo()
                cur.execute(
                    f"""insert into public.politicas_tratamiento
                         (version, vigente_desde, texto_md, texto_autorizacion, texto_autorizacion_foto, sha256, vigente)
                       values (%s, {HOY_COLOMBIA}, %s, %s, %s, '', true)""",
                    (version, texto, autorizacion, foto))

            cur.execute("select count(*) from public.bicicletas")
            bicis = cur.fetchone()[0]
            cur.execute("select codigo, bicis_disponibles, visible, abierto from public.disponibilidad_puntos order by codigo")
            filas = cur.fetchall()
    print(f"Bicicletas en dev: {bicis}")
    for codigo, disponibles, visible, abierto in filas:
        print(f"  {codigo}: {disponibles:>3} disponibles · visible={visible} · abierto={abierto}")


def publicar_politica() -> None:
    version, texto, autorizacion, foto = politica_demo()
    with psycopg.connect(f"service={SERVICIO}") as conn:
        servicio = conn.info.get_parameters().get("service") or SERVICIO
        if servicio != SERVICIO:
            sys.exit(f"Me niego a publicar en {servicio}: solo {SERVICIO}.")
        with conn.transaction(), conn.cursor() as cur:
            cur.execute("select 1 from public.politicas_tratamiento where version = %s", (version,))
            if cur.fetchone():
                print(f"La versión {version} ya está publicada en dev: no se toca (es inmutable).")
                return
            cur.execute("select set_config('app.accion', 'politica.publicar', true), "
                        "set_config('app.motivo', %s, true)",
                        (f"Política {version} de la demo (docs/politica-tratamiento-v1.md), publicada por script",))
            cur.execute("update public.politicas_tratamiento set vigente = false where vigente")
            cur.execute(
                f"""insert into public.politicas_tratamiento
                     (version, vigente_desde, texto_md, texto_autorizacion, texto_autorizacion_foto, sha256, vigente)
                   values (%s, {HOY_COLOMBIA}, %s, %s, %s, '', true)
                   returning id, sha256""",
                (version, texto, autorizacion, foto))
            id_, sha = cur.fetchone()
    print(f"Publicada la versión {version} como vigente en dev (id {id_}, sha256 {sha[:12]}…).")


if __name__ == "__main__":
    publicar_politica() if "--politica" in sys.argv[1:] else main()
