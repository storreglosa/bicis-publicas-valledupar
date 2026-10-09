"""Hitos 1e y 1f: límite de intentos de la preinscripción, purga de fotos,
conservación de evidencia y anonimización de preinscripciones sin validar."""

import secrets
import uuid

from psycopg.types.json import Jsonb


def _solicitud(bd, documento):
    return {
        "id_operacion": str(uuid.uuid4()), "tipo_documento": "CC", "numero_documento": documento,
        "nombres": "Persona", "apellidos": "De Prueba", "telefono": "3000000000", "correo": None,
        "edad": "30", "sexo_genero": "mujer",
        "autorizacion": {"id": str(uuid.uuid4()), "politica_version": bd.d.version_politica,
                         "autoriza_tratamiento": True, "autoriza_foto": True},
    }


def _prestamo_devuelto(bd, persona, numero, hace_dias, con_novedad=False):
    """Presta y devuelve la bici; luego corre las fechas hacia atrás (como dueño)."""
    r = bd.prestar(persona, numero)
    bd.como(bd.d.op1)
    devolucion = {"p_id_operacion": uuid.uuid4(), "p_numero_bici": numero, "p_punto_id": bd.d.p01}
    if con_novedad:
        devolucion |= {"p_con_novedad": True,
                       "p_incidencia": {"tipo": "dano", "gravedad": "leve", "descripcion": "Timbre suelto"}}
    bd.rpc("registrar_devolucion", **devolucion)
    bd.como("dueno")
    bd.sql("update public.prestamos set salida_en = now() - make_interval(days => %s, hours => 1), "
           "devuelto_en = now() - make_interval(days => %s) where id = %s", (hace_dias, hace_dias, r["prestamo_id"]))
    return r["prestamo_id"]


def _ruta(prestamo_id):
    return f"prestamos/{prestamo_id}/salida.webp"


def _por_purgar(bd):
    bd.como("servicio")
    return {ruta for (_, ruta) in bd.sql("select * from public.fotos_por_purgar(500)")}


# --- 1e. Límite de intentos ---------------------------------------------------

def test_preinscribir_limita_cinco_intentos_por_hora_por_ip(bd):
    huella = secrets.token_hex(32)
    bd.como("servicio")
    for i in range(5):
        assert bd.rpc("preinscribir", p=_solicitud(bd, f"0010001{i}"), p_ip_huella=huella) == {"resultado": "inscrito"}
    assert bd.error("preinscribir", p=_solicitud(bd, "00100019"), p_ip_huella=huella) == "demasiados_intentos"
    # Otra IP sigue pudiendo.
    assert bd.rpc("preinscribir", p=_solicitud(bd, "00100019"), p_ip_huella=secrets.token_hex(32)) == {"resultado": "inscrito"}


def test_ya_inscrito_tambien_cuenta_para_el_limite(bd):
    """Recorrer documentos responde «ya inscrito»: esos intentos deben contar."""
    bd.persona("00100001")
    huella = secrets.token_hex(32)
    bd.como("servicio")
    for _ in range(5):
        assert bd.rpc("preinscribir", p=_solicitud(bd, "00100001"), p_ip_huella=huella) == {"resultado": "ya_inscrito"}
    assert bd.error("preinscribir", p=_solicitud(bd, "00100002"), p_ip_huella=huella) == "demasiados_intentos"


def test_preinscribir_limita_veinte_intentos_por_dia(bd):
    huella = secrets.token_hex(32)
    bd.como("dueno")
    bd.sql("insert into privado.intentos_preinscripcion (ip_huella, en) "
           "select %s, now() - interval '3 hours' from generate_series(1, 20)", (huella,))
    bd.como("servicio")
    assert bd.error("preinscribir", p=_solicitud(bd, "00100001"), p_ip_huella=huella) == "demasiados_intentos"


def test_preinscribir_exige_huella_valida(bd):
    bd.como("servicio")
    for huella in (None, "abc", "Z" * 64):
        assert bd.error("preinscribir", p=_solicitud(bd, "00100001"), p_ip_huella=huella) == "datos_invalidos"


# --- 1f. Purga de fotos -------------------------------------------------------

def test_sin_plazo_definido_no_se_purga_nada(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    _prestamo_devuelto(bd, pid, 1, hace_dias=400)
    bd.parametro("retencion.fotos_dias", None)
    assert _por_purgar(bd) == set()


def test_fotos_por_purgar_respeta_plazo_novedades_y_conservacion(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    vieja = _prestamo_devuelto(bd, pid, 1, hace_dias=8)
    reciente = _prestamo_devuelto(bd, pid, 2, hace_dias=3)
    con_novedad = _prestamo_devuelto(bd, pid, 3, hace_dias=8, con_novedad=True)
    conservada = _prestamo_devuelto(bd, pid, 4, hace_dias=8)
    activo = bd.prestar(pid, 5)["prestamo_id"]
    bd.como("dueno")
    bd.sql("update public.prestamos set foto_retener = true where id = %s", (conservada,))
    bd.parametro("retencion.fotos_dias", 7)

    rutas = _por_purgar(bd)
    assert _ruta(vieja) in rutas
    for no in (reciente, con_novedad, conservada, activo):
        assert _ruta(no) not in rutas


def test_los_prestamos_anulados_tambien_se_purgan(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    r = bd.prestar(pid, 1)
    bd.como(bd.d.admin)
    bd.rpc("anular_prestamo", p_prestamo_id=r["prestamo_id"], p_motivo="Registrado por error de prueba")
    bd.como("dueno")
    bd.sql("update public.prestamos set salida_en = now() - interval '9 days', cerrado_en = now() - interval '8 days' "
           "where id = %s", (r["prestamo_id"],))
    bd.parametro("retencion.fotos_dias", 7)
    assert _ruta(r["prestamo_id"]) in _por_purgar(bd)


def test_marcar_eliminadas_devuelve_solo_lo_que_marco_y_las_huerfanas_se_detectan(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    vieja = _prestamo_devuelto(bd, pid, 1, hace_dias=8)
    conservada = _prestamo_devuelto(bd, pid, 2, hace_dias=8)
    bd.parametro("retencion.fotos_dias", 7)
    rutas = sorted(_por_purgar(bd))
    # Entre listar y marcar, el administrador conserva una: no se debe marcar ni borrar.
    bd.como(bd.d.admin)
    bd.rpc("conservar_foto", p_prestamo_id=conservada, p_motivo="Reclamo de la persona en trámite")
    bd.como("servicio")
    marcadas = {r for (r,) in bd.sql("select * from public.marcar_fotos_eliminadas(%s)", (rutas,))}
    assert marcadas == {_ruta(vieja)}
    bd.como("dueno")
    assert bd.uno("select foto_estado from public.prestamos where id = %s", (vieja,)) == "eliminada"
    assert bd.uno("select foto_estado from public.prestamos where id = %s", (conservada,)) == "almacenada"

    # Huérfanas: la marcada cuyo archivo sigue (borrado fallido) y una subida sin préstamo de hace 2 días.
    sin_prestamo = f"prestamos/{uuid.uuid4()}/salida.webp"
    reciente = f"prestamos/{uuid.uuid4()}/salida.webp"
    bd.sql("insert into storage.objects (bucket_id, name, metadata, created_at) values "
           "('evidencias', %s, %s, now() - interval '2 days'), ('evidencias', %s, %s, now())",
           (sin_prestamo, Jsonb({"size": 1}), reciente, Jsonb({"size": 1})))
    bd.como("servicio")
    huerfanas = {r for (r,) in bd.sql("select * from public.fotos_huerfanas(500)")}
    assert huerfanas == {_ruta(vieja), sin_prestamo}


def test_conservar_foto_solo_admin_con_motivo_y_auditado(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    prestamo = _prestamo_devuelto(bd, pid, 1, hace_dias=1)
    bd.como(bd.d.op1)
    assert bd.error("conservar_foto", p_prestamo_id=prestamo, p_motivo="Reclamo de la persona") == "no_autorizado"
    bd.como(bd.d.admin)
    assert bd.error("conservar_foto", p_prestamo_id=prestamo, p_motivo="corto") == "motivo_insuficiente"
    bd.rpc("conservar_foto", p_prestamo_id=prestamo, p_motivo="Reclamo de la persona en trámite")
    bd.como("dueno")
    assert bd.uno("select foto_retener from public.prestamos where id = %s", (prestamo,)) is True
    assert bd.sql("select accion, motivo from public.auditoria where tabla = 'prestamos' and accion = 'foto.conservar'") \
        == [("foto.conservar", "Reclamo de la persona en trámite")]


def test_no_se_conserva_una_foto_ya_eliminada(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    prestamo = _prestamo_devuelto(bd, pid, 1, hace_dias=8)
    bd.parametro("retencion.fotos_dias", 7)
    bd.como("servicio")
    bd.sql("select * from public.marcar_fotos_eliminadas(%s)", ([_ruta(prestamo)],))
    bd.como(bd.d.admin)
    assert bd.error("conservar_foto", p_prestamo_id=prestamo, p_motivo="Reclamo de la persona") == "foto_ya_eliminada"


def test_reportar_averia_conserva_la_foto_del_ultimo_prestamo(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    anterior = _prestamo_devuelto(bd, pid, 1, hace_dias=3)
    ultimo = _prestamo_devuelto(bd, pid, 1, hace_dias=1)
    bd.como(bd.d.op1)
    bd.rpc("cambiar_condicion_bici", p_numero=1, p_condicion="averiada", p_motivo="Freno trasero roto")
    bd.como("dueno")
    assert bd.uno("select foto_retener from public.prestamos where id = %s", (ultimo,)) is True
    assert bd.uno("select foto_retener from public.prestamos where id = %s", (anterior,)) is False
    bd.parametro("retencion.fotos_dias", 1)
    assert _ruta(ultimo) not in _por_purgar(bd)


def test_registrar_tarea_alimenta_el_tablero(bd):
    bd.como("servicio")
    assert bd.error("registrar_tarea", p_tarea="otra", p_inicio=None, p_resultado="ok") == "datos_invalidos"
    bd.rpc("registrar_tarea", p_tarea="purgar_fotos", p_inicio=None, p_resultado="error",
           p_detalle={"error": "prueba"})
    bd.como(bd.d.admin)
    assert bd.rpc("tablero_resumen")["ultima_purga"]["resultado"] == "error"


# --- 1f. Preinscripciones sin validar ----------------------------------------

def test_purgar_preinscripciones_sin_plazo_no_toca_nada_pero_registra(bd):
    pid = bd.persona("00100001")
    bd.como("dueno")
    bd.sql("update public.personas set creada_en = now() - interval '400 days' where id = %s", (pid,))
    bd.parametro("retencion.preinscripcion_sin_validar_dias", None)
    assert bd.uno("select privado.purgar_preinscripciones()") == 0
    assert bd.uno("select estado from public.personas where id = %s", (pid,)) == "preinscrita"
    assert bd.uno("select resultado from privado.ejecuciones_tareas where tarea = 'purgar_preinscripciones'") == "ok"


def test_purgar_preinscripciones_anonimiza_solo_las_viejas_sin_validar(bd):
    acudiente = {"tipo_documento": "CC", "numero_documento": "00300001", "nombres": "Acudiente",
                 "apellidos": "De Prueba", "telefono": "3000000001", "parentesco": "madre"}
    vieja = bd.persona("00100001")
    menor = bd.persona("00200001", tipo="TI", edad=12, acudiente=acudiente)
    reciente = bd.persona("00100002")
    validada = bd.persona("00100003", validar_con=bd.d.op1)
    bd.como("dueno")
    bd.sql("update public.personas set creada_en = now() - interval '40 days' where id = any(%s)",
           ([vieja, menor, validada],))
    bd.parametro("retencion.preinscripcion_sin_validar_dias", 30)

    assert bd.uno("select privado.purgar_preinscripciones()") == 2
    filas = dict(bd.sql("select id, estado from public.personas"))
    assert filas[vieja] == filas[menor] == "anonimizada"
    assert filas[reciente] == "preinscrita" and filas[validada] == "validada"
    anon = bd.sql("select tipo_documento, nombres, telefono, correo from public.personas where id = %s", (vieja,))[0]
    assert anon == ("AN", "Anonimizada", "0000000", None)
    assert bd.uno("select a.nombres from public.acudientes a join public.personas p on p.acudiente_id = a.id "
                  "where p.id = %s", (menor,)) == "Anonimizado"
    # Nadie la encuentra por su documento real.
    bd.como(bd.d.op1)
    assert bd.rpc("buscar_persona", p_tipo="CC", p_numero="00100001") is None


def test_anonimiza_a_quien_no_presta_en_el_plazo_y_respeta_las_excepciones(bd):
    """Política v1.0 §8: sin préstamos durante N meses → anonimizada; salvo préstamo activo,
    sanción vigente o novedad abierta. Si nunca prestó, cuenta desde la validación."""
    vieja = bd.persona("00100001", validar_con=bd.d.op1)          # prestó hace 30 meses
    _prestamo_devuelto(bd, vieja, 1, hace_dias=30 * 31)
    nunca = bd.persona("00100002", validar_con=bd.d.op1)          # validada hace 30 meses, nunca prestó
    reciente = bd.persona("00100003", validar_con=bd.d.op1)       # prestó hace 2 meses
    _prestamo_devuelto(bd, reciente, 2, hace_dias=60)
    sancionada = bd.persona("00100004", validar_con=bd.d.op1)     # inactiva pero con sanción vigente
    _prestamo_devuelto(bd, sancionada, 3, hace_dias=30 * 31)
    con_novedad = bd.persona("00100005", validar_con=bd.d.op1)    # inactiva con novedad abierta
    _prestamo_devuelto(bd, con_novedad, 4, hace_dias=30 * 31, con_novedad=True)
    bd.como("dueno")
    bd.sql("update public.personas set validada_en = now() - interval '30 months' where id = any(%s)",
           ([vieja, nunca, sancionada, con_novedad],))
    bd.sql("insert into public.sanciones (persona_id, tipo, motivo, desde, hasta, impuesta_por) "
           "values (%s, 'suspension', 'Motivo de prueba suficiente', current_date, current_date + 30, %s)",
           (sancionada, bd.d.admin))
    bd.parametro("retencion.preinscripcion_sin_validar_dias", None)
    bd.parametro("retencion.anonimizar_inactivos_meses", 24)

    assert bd.uno("select privado.purgar_preinscripciones()") == 2
    estados = dict(bd.sql("select id, estado from public.personas"))
    assert estados[vieja] == estados[nunca] == "anonimizada"
    assert estados[reciente] == estados[sancionada] == estados[con_novedad] == "validada"
    # El préstamo se conserva, sin identidad.
    assert bd.uno("select count(*) from public.prestamos where persona_id = %s", (vieja,)) == 1
    assert bd.uno("select nombres from public.personas where id = %s", (vieja,)) == "Anonimizada"
    detalle = bd.uno("select detalle from privado.ejecuciones_tareas where tarea = 'purgar_preinscripciones' order by id desc limit 1")
    assert detalle["inactivas_anonimizadas"] == 2 and detalle["plazo_meses"] == 24


def test_la_tarea_diaria_borra_las_huellas_de_ip_de_mas_de_dos_dias(bd):
    """Política v1.0 §8: la huella de la IP se borra a los 2 días aunque nadie más se preinscriba."""
    vieja, reciente = secrets.token_hex(32), secrets.token_hex(32)
    bd.como("dueno")
    bd.sql("insert into privado.intentos_preinscripcion (ip_huella, en) values "
           "(%s, now() - interval '3 days'), (%s, now() - interval '1 day')", (vieja, reciente))
    bd.parametro("retencion.preinscripcion_sin_validar_dias", None)
    bd.parametro("retencion.anonimizar_inactivos_meses", None)
    bd.uno("select privado.purgar_preinscripciones()")
    assert {h for (h,) in bd.sql("select ip_huella from privado.intentos_preinscripcion")} == {reciente}
    detalle = bd.uno("select detalle from privado.ejecuciones_tareas where tarea = 'purgar_preinscripciones' order by id desc limit 1")
    assert detalle["huellas_ip_borradas"] == 1
