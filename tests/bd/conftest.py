"""Pruebas de la base de datos (migraciones, RLS, funciones).

Modo local (por defecto): crea una base nueva en el Postgres local
(`scripts/pg_local.sh start`), aplica tests/bd/stub_supabase.sql y todas las
migraciones con psql, y corre las pruebas.

Cada prueba corre dentro de una transacción que se revierte al final: no deja
residuos. Los roles se simulan como lo hace Supabase: `set local role` +
`request.jwt.claims`.

Todos los datos son ficticios (documentos que empiezan por 00, teléfonos 300000…).
"""

import json
import os
import pathlib
import subprocess
import uuid
from dataclasses import dataclass, field

import psycopg
import pytest
from psycopg.types.json import Jsonb

RAIZ = pathlib.Path(__file__).resolve().parents[2]
MIGRACIONES = sorted((RAIZ / "supabase" / "migrations").glob("*.sql"))
STUB = RAIZ / "tests" / "bd" / "stub_supabase.sql"
PSQL = pathlib.Path(os.environ.get("CONDA_PREFIX", pathlib.Path.home() / "miniconda3/envs/bicis")) / "bin" / "psql"
BASE_LOCAL = f"host={RAIZ / '.pg_local'} port=54329 user=postgres"
NOMBRE_BD = "bicis_pruebas"


def _psql(dsn: str, archivo: pathlib.Path) -> None:
    r = subprocess.run([str(PSQL), dsn, "-q", "-v", "ON_ERROR_STOP=1", "-1", "-f", str(archivo)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"Falló {archivo.name}:\n{r.stderr}")


def crear_bd(nombre: str) -> str:
    """Base nueva con el stub de Supabase y todas las migraciones aplicadas."""
    try:
        with psycopg.connect(BASE_LOCAL + " dbname=postgres", autocommit=True) as c:
            c.execute(f"drop database if exists {nombre} with (force)")
            c.execute(f"create database {nombre}")
    except psycopg.OperationalError as e:
        pytest.exit(f"No hay Postgres local. Ejecuta scripts/pg_local.sh start\n{e}", returncode=2)
    destino = BASE_LOCAL + f" dbname={nombre}"
    _psql(destino, STUB)
    for m in MIGRACIONES:
        _psql(destino, m)
    return destino


@pytest.fixture(scope="session")
def dsn() -> str:
    return crear_bd(NOMBRE_BD)


@pytest.fixture(scope="session")
def dsn_aislada() -> str:
    """Base aparte para pruebas que necesitan confirmar datos (commit)."""
    return crear_bd(NOMBRE_BD + "_aislada")


# --- Datos de prueba ----------------------------------------------------------

@dataclass
class Datos:
    admin: uuid.UUID
    op1: uuid.UUID
    op2: uuid.UUID
    sin_rol: uuid.UUID
    p01: uuid.UUID          # punto fijo activo con bicis
    p02: uuid.UUID          # punto fijo activo vacío
    t01: uuid.UUID          # taller
    e01: uuid.UUID          # punto de evento (evento en curso)
    p03: uuid.UUID          # punto fijo inactivo
    bicis: list[int] = field(default_factory=list)
    version_politica: str = "0.1"


def sembrar(cur, sufijo: str = "", base_bici: int = 1, n_bicis: int = 10) -> Datos:
    """Siembra datos ficticios como dueño de las tablas. `sufijo` evita choques
    cuando se siembra más de una vez en la misma base (pruebas con commit)."""
    ids = {k: uuid.uuid4() for k in ("admin", "op1", "op2", "sin_rol")}
    for k, i in ids.items():
        cur.execute("insert into auth.users (id, email) values (%s, %s)", (i, f"{k}{sufijo}@prueba.invalid"))
    cur.execute(
        """insert into public.personal (id, nombre, rol, debe_cambiar_clave) values
           (%s, 'Admin Prueba', 'administrador', false),
           (%s, 'Operador Uno', 'operador', false),
           (%s, 'Operador Dos', 'operador', false)""",
        (ids["admin"], ids["op1"], ids["op2"]))
    cur.execute("select 1 from public.politicas_tratamiento where vigente")
    if cur.fetchone() is None:
        cur.execute(
            """insert into public.politicas_tratamiento
                 (version, vigente_desde, texto_md, texto_autorizacion, texto_autorizacion_foto, sha256, vigente)
               values ('0.1', current_date, repeat('Texto ficticio de la política de prueba. ', 10),
                       'Autorizo el tratamiento de mis datos (prueba).', 'Autorizo la foto de evidencia (prueba).', '', true)""")
    cur.execute(
        """insert into public.eventos (nombre, inicia_en, termina_en, estado, publicado)
           values ('Ciclopaseo de prueba', now() - interval '1 hour', now() + interval '5 hours', 'en_curso', true)
           returning id""")
    evento = cur.fetchone()[0]

    def punto(codigo, tipo, estado, evento_id=None):
        cur.execute(
            """insert into public.puntos (codigo, nombre, tipo, estado, evento_id, latitud, longitud)
               values (%s, %s, %s, %s, %s, 10.4631, -73.2532) returning id""",
            (codigo, f"Punto {codigo}", tipo, estado, evento_id))
        return cur.fetchone()[0]

    s = sufijo.upper()
    d = Datos(
        admin=ids["admin"], op1=ids["op1"], op2=ids["op2"], sin_rol=ids["sin_rol"],
        p01=punto(f"P{s}01", "fijo", "activo"),
        p02=punto(f"P{s}02", "fijo", "activo"),
        t01=punto(f"T{s}01", "taller", "activo"),
        e01=punto(f"E{s}01", "evento", "activo", evento),
        p03=punto(f"P{s}03", "fijo", "inactivo"),
    )
    d.bicis = list(range(base_bici, base_bici + n_bicis))
    cur.execute(
        """insert into public.bicicletas (numero, disponibilidad, condicion, punto_actual_id)
           select n, 'disponible', 'operativa', %s from generate_series(%s::int, %s::int) n""",
        (d.p01, d.bicis[0], d.bicis[-1]))
    return d


# --- Sesión de pruebas con cambio de rol --------------------------------------

class ErrorBD(Exception):
    pass


class Sesion:
    def __init__(self, conn: psycopg.Connection, datos: Datos):
        self.conn = conn
        self.d = datos

    def como(self, quien) -> "Sesion":
        """quien: 'dueno' | 'anon' | 'servicio' | uuid de personal/usuario."""
        with self.conn.cursor() as cur:
            cur.execute("reset role")
            if quien == "dueno":
                cur.execute("select set_config('request.jwt.claims', '', true)")
                return self
            if quien == "anon":
                claims, rol = {"role": "anon"}, "anon"
            elif quien == "servicio":
                claims, rol = {"role": "service_role"}, "service_role"
            else:
                claims, rol = {"role": "authenticated", "sub": str(quien)}, "authenticated"
            cur.execute("select set_config('request.jwt.claims', %s, true)", (json.dumps(claims),))
            cur.execute(f"set local role {rol}")
        return self

    def sql(self, consulta: str, params=None):
        with self.conn.transaction():
            with self.conn.cursor() as cur:
                cur.execute(consulta, params)
                return cur.fetchall() if cur.description else None

    def uno(self, consulta: str, params=None):
        filas = self.sql(consulta, params)
        return filas[0][0] if filas else None

    def rpc(self, nombre: str, **kw):
        kw = {k: (Jsonb(v) if isinstance(v, (dict, list)) and not k.endswith("numeros") else v) for k, v in kw.items()}
        args = ", ".join(f"{k} => %({k})s" for k in kw)
        try:
            with self.conn.transaction():
                with self.conn.cursor() as cur:
                    cur.execute(f"select * from public.{nombre}({args})", kw)
                    filas = cur.fetchall()
        except psycopg.errors.RaiseException as e:
            raise ErrorBD(e.diag.message_primary) from None
        except psycopg.errors.InsufficientPrivilege as e:
            # 'no_autorizado' lo lanza la función (rol de la app); lo demás es Postgres
            # negando el EXECUTE o el acceso (permiso del rol de la API).
            mensaje = e.diag.message_primary or ""
            raise ErrorBD(mensaje if mensaje == "no_autorizado" else "sin_permiso:" + mensaje) from None
        if len(filas) == 1 and len(filas[0]) == 1:
            return filas[0][0]
        return filas

    def error(self, nombre: str, **kw) -> str:
        try:
            self.rpc(nombre, **kw)
        except ErrorBD as e:
            return str(e)
        raise AssertionError(f"{nombre} no falló")

    # Atajos de negocio ------------------------------------------------------
    def persona(self, documento: str, edad: int = 30, tipo: str = "CC", acudiente: dict | None = None,
                autoriza_foto: bool = True, validar_con=None) -> uuid.UUID:
        """Preinscribe (como servicio) y, si se indica, valida con un operador."""
        p = {
            "id_operacion": str(uuid.uuid4()),
            "tipo_documento": tipo, "numero_documento": documento,
            "nombres": "Persona", "apellidos": "De Prueba",
            "telefono": "3000000000", "correo": None, "edad": str(edad), "sexo_genero": "mujer",
            "autorizacion": {"id": str(uuid.uuid4()), "politica_version": self.d.version_politica,
                             "autoriza_tratamiento": True, "autoriza_foto": autoriza_foto,
                             "menor_escuchado": True if acudiente else None},
        }
        if acudiente:
            p["acudiente"] = acudiente
        self.como("servicio")
        r = self.rpc("preinscribir", p=p)
        assert r["resultado"] == "inscrito", r
        self.como("dueno")
        pid = self.uno("select id from public.personas where numero_documento = %s", (documento,))
        if validar_con:
            self.como(validar_con)
            self.rpc("validar_persona", p_persona_id=pid)
        return pid

    def subir_foto(self, prestamo_id: uuid.UUID, quien=None, extension: str = "webp") -> str:
        ruta = f"prestamos/{prestamo_id}/salida.{extension}"
        self.como(quien or self.d.op1)
        self.sql("insert into storage.objects (bucket_id, name, metadata) values ('evidencias', %s, %s)",
                 (ruta, Jsonb({"size": 120000})))
        return ruta

    def prestar(self, persona_id, numero: int, punto=None, quien=None, prestamo_id=None) -> dict:
        prestamo_id = prestamo_id or uuid.uuid4()
        ruta = self.subir_foto(prestamo_id, quien)
        self.como(quien or self.d.op1)
        return self.rpc("registrar_prestamo", p_id=prestamo_id, p_persona_id=persona_id,
                        p_numero_bici=numero, p_punto_id=punto or self.d.p01, p_foto_ruta=ruta)

    def parametro(self, clave: str, valor) -> None:
        self.como("dueno")
        self.sql("update public.parametros set valor = %s where clave = %s",
                 (Jsonb(valor) if valor is not None else None, clave))


@pytest.fixture
def bd(dsn):
    """Sesión con datos sembrados dentro de una transacción que se revierte."""
    with psycopg.connect(dsn) as conn:
        with conn.transaction(force_rollback=True):
            with conn.cursor() as cur:
                datos = sembrar(cur)
            yield Sesion(conn, datos)
