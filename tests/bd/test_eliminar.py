"""D-32: eliminar puntos y eventos nunca usados (sin préstamos ni bicis). Lo que tuvo
préstamos no se borra; el borrado queda en la auditoría con su motivo."""

import uuid

MOTIVO = "Creado de prueba por error en la demo"


def _punto(bd, codigo, tipo="fijo", evento=None, estado="activo"):
    bd.como("dueno")
    return bd.uno("insert into public.puntos (codigo, nombre, tipo, estado, evento_id, latitud, longitud) "
                  "values (%s, %s, %s, %s, %s, 10.47, -73.25) returning id",
                  (codigo, f"Punto {codigo}", tipo, estado, evento))


def _evento(bd, nombre="Evento de prueba", estado="planeado"):
    bd.como("dueno")
    return bd.uno("insert into public.eventos (nombre, inicia_en, termina_en, estado, publicado) "
                  "values (%s, now() - interval '1 hour', now() + interval '3 hours', %s, true) returning id",
                  (nombre, estado))


def test_el_admin_elimina_un_punto_nunca_usado_y_queda_en_la_auditoria(bd):
    punto = _punto(bd, "PZ9")
    bd.como(bd.d.admin)
    bd.rpc("eliminar_punto", p_punto_id=punto, p_motivo=MOTIVO)
    bd.como("dueno")
    assert bd.uno("select count(*) from public.puntos where id = %s", (punto,)) == 0
    assert bd.uno("select count(*) from public.disponibilidad_puntos where punto_id = %s", (punto,)) == 0
    assert bd.sql("select operacion, accion, motivo from public.auditoria where tabla = 'puntos' and registro_id = %s "
                  "and operacion = 'DELETE'", (str(punto),)) == [("DELETE", "punto.eliminar", MOTIVO)]


def test_no_se_elimina_un_punto_con_historial_ni_con_bicis(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    numero = bd.d.bicis[0]
    bd.prestar(pid, numero)                                    # sale de P01
    bd.como(bd.d.op1)
    bd.rpc("registrar_devolucion", p_id_operacion=uuid.uuid4(), p_numero_bici=numero, p_punto_id=bd.d.p02)
    bd.como(bd.d.admin)
    assert bd.error("eliminar_punto", p_punto_id=bd.d.p02, p_motivo=MOTIVO) == "punto_con_historial"
    vacio_con_bicis = _punto(bd, "PZ8")
    bd.como("dueno")
    bd.sql("update public.bicicletas set punto_actual_id = %s where numero = %s", (vacio_con_bicis, bd.d.bicis[1]))
    bd.como(bd.d.admin)
    assert bd.error("eliminar_punto", p_punto_id=vacio_con_bicis, p_motivo=MOTIVO) == "punto_con_bicis"


def test_solo_el_admin_y_con_motivo(bd):
    punto = _punto(bd, "PZ7")
    bd.como(bd.d.op1)
    assert bd.error("eliminar_punto", p_punto_id=punto, p_motivo=MOTIVO) == "no_autorizado"
    bd.como(bd.d.admin)
    assert bd.error("eliminar_punto", p_punto_id=punto, p_motivo="corto") == "motivo_insuficiente"
    assert bd.error("eliminar_punto", p_punto_id=uuid.uuid4(), p_motivo=MOTIVO) == "punto_no_existe"


def test_el_admin_elimina_un_evento_nunca_usado_con_sus_puntos(bd):
    evento = _evento(bd)
    _punto(bd, "EZ1", tipo="evento", evento=evento)
    _punto(bd, "EZ2", tipo="evento", evento=evento, estado="cerrado")
    bd.como(bd.d.admin)
    assert bd.rpc("eliminar_evento", p_evento_id=evento, p_motivo=MOTIVO) == 2
    bd.como("dueno")
    assert bd.uno("select count(*) from public.eventos where id = %s", (evento,)) == 0
    assert bd.uno("select count(*) from public.puntos where evento_id = %s", (evento,)) == 0
    assert bd.uno("select count(*) from public.auditoria where accion = 'evento.eliminar' and operacion = 'DELETE'") == 3


def test_no_se_elimina_un_evento_con_bicis_o_con_historial(bd):
    con_bicis = _evento(bd, "Evento con bicis")
    punto = _punto(bd, "EZ3", tipo="evento", evento=con_bicis)
    bd.como("dueno")
    bd.sql("update public.bicicletas set punto_actual_id = %s where numero = %s", (punto, bd.d.bicis[2]))
    bd.como(bd.d.admin)
    assert bd.error("eliminar_evento", p_evento_id=con_bicis, p_motivo=MOTIVO) == "evento_con_bicis"

    # El evento de la semilla (en curso) presta desde su punto E01.
    pid = bd.persona("00100002", validar_con=bd.d.op1)
    bd.como("dueno")
    bd.sql("update public.bicicletas set punto_actual_id = %s where numero = %s", (bd.d.e01, bd.d.bicis[3]))
    bd.prestar(pid, bd.d.bicis[3], punto=bd.d.e01)
    evento_semilla = bd.uno("select evento_id from public.puntos where id = %s", (bd.d.e01,))
    bd.como(bd.d.admin)
    assert bd.error("eliminar_evento", p_evento_id=evento_semilla, p_motivo=MOTIVO) == "evento_con_historial"
    assert bd.error("eliminar_evento", p_evento_id=uuid.uuid4(), p_motivo=MOTIVO) == "evento_no_existe"
