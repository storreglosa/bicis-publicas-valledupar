"""Dos operadores prestan la misma bici al mismo tiempo (RN-01).

Es la falla real de OpenSourceBikeShare (sin transacciones: ganan los dos).
Aquí el segundo debe quedar esperando el bloqueo de la fila y, cuando el
primero confirma, recibir 'bici_ya_prestada'.
"""

import json
import threading
import time
import uuid

import psycopg
from conftest import Sesion, sembrar


def _como(cur, uid):
    cur.execute("select set_config('request.jwt.claims', %s, true)",
                (json.dumps({"role": "authenticated", "sub": str(uid)}),))
    cur.execute("set local role authenticated")


def _prestar(cur, prestamo_id, persona_id, numero, punto, ruta):
    cur.execute(
        """select public.registrar_prestamo(p_id => %s, p_persona_id => %s, p_numero_bici => %s,
                                            p_punto_id => %s, p_foto_ruta => %s)""",
        (prestamo_id, persona_id, numero, punto, ruta))
    return cur.fetchone()[0]


def test_dos_operadores_prestan_la_misma_bici_a_la_vez(dsn_aislada):
    # Datos confirmados: dos personas validadas y una foto para cada préstamo.
    with psycopg.connect(dsn_aislada) as conn:
        with conn.transaction():
            with conn.cursor() as cur:
                d = sembrar(cur, sufijo="c", base_bici=500, n_bicis=2)
            s = Sesion(conn, d)
            persona_a = s.persona("00700001", validar_con=d.op1)
            persona_b = s.persona("00700002", validar_con=d.op2)
            prestamo_a, prestamo_b = uuid.uuid4(), uuid.uuid4()
            ruta_a = s.subir_foto(prestamo_a, d.op1)
            ruta_b = s.subir_foto(prestamo_b, d.op2)

    # Operador A presta la bici 500 y NO confirma todavía (tiene la fila bloqueada).
    conn_a = psycopg.connect(dsn_aislada)
    cur_a = conn_a.cursor()
    _como(cur_a, d.op1)
    _prestar(cur_a, prestamo_a, persona_a, 500, d.p01, ruta_a)

    # Operador B intenta la misma bici en paralelo.
    resultado = {}

    def operador_b():
        with psycopg.connect(dsn_aislada) as conn_b:
            with conn_b.cursor() as cur_b:
                cur_b.execute("set lock_timeout = '15s'")
                _como(cur_b, d.op2)
                try:
                    resultado["ok"] = _prestar(cur_b, prestamo_b, persona_b, 500, d.p01, ruta_b)
                    conn_b.commit()
                except psycopg.errors.RaiseException as e:
                    resultado["error"] = e.diag.message_primary
                except psycopg.Error as e:
                    resultado["error"] = f"inesperado: {e}"

    hilo = threading.Thread(target=operador_b)
    hilo.start()
    time.sleep(1.0)
    assert hilo.is_alive(), "B no esperó el bloqueo de la fila: hay una carrera"

    conn_a.commit()
    conn_a.close()
    hilo.join(timeout=20)

    assert resultado == {"error": "bici_ya_prestada"}
    with psycopg.connect(dsn_aislada) as c:
        assert c.execute("select count(*) from public.prestamos p join public.bicicletas b on b.id = p.bicicleta_id "
                         "where b.numero = 500 and p.estado = 'activo'").fetchone()[0] == 1
