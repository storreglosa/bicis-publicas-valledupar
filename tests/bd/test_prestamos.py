"""Préstamo, devolución, reglas configurables y operaciones de administración (RF-23..27, RF-48, RN-01..09)."""

import uuid

import pytest


def _disponibles(bd, punto):
    bd.como("anon")
    filas = bd.sql("select bicis_disponibles from public.disponibilidad_puntos where punto_id = %s", (punto,))
    return filas[0][0] if filas else None


def test_flujo_completo_prestar_y_devolver(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    assert _disponibles(bd, bd.d.p01) == 10

    r = bd.prestar(pid, 3)
    assert r["codigo"] == "BPV-003" and r["vence_en"] is None   # sin regla de duración
    assert _disponibles(bd, bd.d.p01) == 9

    bd.como(bd.d.op1)
    assert bd.error("prestamos_activos") == "falta_punto"      # el operador ve solo su punto (I-3)
    activos = bd.rpc("prestamos_activos", p_punto_id=bd.d.p01)
    assert [fila[1] for fila in activos] == ["BPV-003"]

    bd.como(bd.d.op2)
    d = bd.rpc("registrar_devolucion", p_id_operacion=uuid.uuid4(), p_numero_bici=3, p_punto_id=bd.d.p02)
    assert d["codigo"] == "BPV-003" and d["excedio"] is None and d["persona"] == "Persona D."
    assert _disponibles(bd, bd.d.p02) == 1

    bd.como("dueno")
    estado, op_salida, op_devolucion = bd.sql(
        "select estado, operador_salida_id, operador_devolucion_id from public.prestamos")[0]
    assert (estado, op_salida, op_devolucion) == ("finalizado", bd.d.op1, bd.d.op2)
    acciones = {a for (a,) in bd.sql("select accion from public.auditoria where tabla = 'prestamos'")}
    assert acciones == {"prestamo.registrar", "prestamo.devolver"}


def test_anon_ve_disponibilidad_pero_no_puntos_ocultos_ni_talleres(bd):
    bd.como("anon")
    codigos = {c for (c,) in bd.sql("select codigo from public.disponibilidad_puntos")}
    assert codigos == {"P01", "P02", "E01", "P03"}       # T01 (taller) no aparece
    assert bd.sql("select abierto from public.disponibilidad_puntos where codigo = 'P03'") == [(False,)]


def test_persona_preinscrita_sin_validar_no_presta(bd):
    pid = bd.persona("00100001")
    with pytest.raises(Exception) as e:
        bd.prestar(pid, 1)
    assert "persona_no_validada" in str(e.value)


def test_sin_foto_no_hay_prestamo(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    prestamo = uuid.uuid4()
    bd.como(bd.d.op1)
    base = dict(p_id=prestamo, p_persona_id=pid, p_numero_bici=1, p_punto_id=bd.d.p01)
    assert bd.error("registrar_prestamo", **base, p_foto_ruta=f"prestamos/{prestamo}/salida.webp") == "falta_foto"
    assert bd.error("registrar_prestamo", **base, p_foto_ruta=f"prestamos/{uuid.uuid4()}/salida.webp") == "foto_ruta_invalida"


def test_foto_de_persona_exige_su_autorizacion_y_el_parametro_la_cambia_a_solo_bici(bd):
    pid = bd.persona("00100001", autoriza_foto=False, validar_con=bd.d.op1)
    with pytest.raises(Exception) as e:
        bd.prestar(pid, 1)
    assert "falta_autorizacion_foto" in str(e.value)
    bd.parametro("evidencia.foto_persona_obligatoria", False)
    bd.prestar(pid, 1)
    bd.como("dueno")
    assert bd.uno("select foto_contenido from public.prestamos") == "solo_bici"


def test_la_misma_bici_no_se_presta_dos_veces(bd):
    a = bd.persona("00100001", validar_con=bd.d.op1)
    b = bd.persona("00100002", validar_con=bd.d.op1)
    bd.prestar(a, 1)
    with pytest.raises(Exception) as e:
        bd.prestar(b, 1)
    assert "bici_ya_prestada" in str(e.value)


def test_indice_unico_impide_dos_prestamos_activos_aunque_se_salte_la_funcion(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.prestar(pid, 1)
    bd.como("dueno")
    otro = uuid.uuid4()
    with pytest.raises(Exception, match="prestamos_un_activo_por_bici"):
        bd.sql("""insert into public.prestamos (id, bicicleta_id, persona_id, autorizacion_id, punto_salida_id,
                    operador_salida_id, edad_estimada, es_menor, foto_ruta, foto_contenido)
                  select %s, pr.bicicleta_id, pr.persona_id, pr.autorizacion_id, pr.punto_salida_id,
                         pr.operador_salida_id, 30, false, %s, 'solo_bici' from public.prestamos pr""",
               (otro, f"prestamos/{otro}/salida.webp"))


def test_reintento_del_mismo_prestamo_es_idempotente(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    prestamo = uuid.uuid4()
    r1 = bd.prestar(pid, 1, prestamo_id=prestamo)
    bd.como(bd.d.op1)
    r2 = bd.rpc("registrar_prestamo", p_id=prestamo, p_persona_id=pid, p_numero_bici=1,
                p_punto_id=bd.d.p01, p_foto_ruta=f"prestamos/{prestamo}/salida.webp")
    assert r1["prestamo_id"] == r2["prestamo_id"]
    assert bd.error("registrar_prestamo", p_id=prestamo, p_persona_id=pid, p_numero_bici=2,
                    p_punto_id=bd.d.p01, p_foto_ruta=f"prestamos/{prestamo}/salida.webp") == "id_operacion_reutilizado"
    bd.como("dueno")
    assert bd.uno("select count(*) from public.prestamos") == 1


def test_devolucion_repetida_es_idempotente(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.prestar(pid, 1)
    op = uuid.uuid4()
    bd.como(bd.d.op1)
    r1 = bd.rpc("registrar_devolucion", p_id_operacion=op, p_numero_bici=1, p_punto_id=bd.d.p01)
    r2 = bd.rpc("registrar_devolucion", p_id_operacion=op, p_numero_bici=1, p_punto_id=bd.d.p01)
    assert r1["prestamo_id"] == r2["prestamo_id"]
    assert bd.error("registrar_devolucion", p_id_operacion=uuid.uuid4(), p_numero_bici=1,
                    p_punto_id=bd.d.p01) == "bici_no_prestada"


@pytest.mark.parametrize("numero, punto, error", [
    (999, "p01", "bici_no_existe"),
    (1, "p02", "bici_en_otro_punto"),
    (1, "t01", "punto_taller"),
    (1, "p03", "punto_inactivo"),
])
def test_validaciones_de_bici_y_punto(bd, numero, punto, error):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    with pytest.raises(Exception) as e:
        bd.prestar(pid, numero, punto=getattr(bd.d, punto))
    assert error in str(e.value)


def test_reglas_configurables_solo_aplican_con_valor(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.prestar(pid, 1)
    bd.prestar(pid, 2)                                    # sin límite: dos a la vez
    bd.parametro("reglas_uso.max_prestamos_activos_persona", 2)
    with pytest.raises(Exception) as e:
        bd.prestar(pid, 3)
    assert "limite_prestamos_activos" in str(e.value)
    bd.parametro("reglas_uso.max_prestamos_activos_persona", None)
    bd.parametro("reglas_uso.max_prestamos_dia_persona", 2)
    with pytest.raises(Exception) as e:
        bd.prestar(pid, 3)
    assert "limite_prestamos_dia" in str(e.value)


def test_horario_y_edad_minima(bd):
    pid = bd.persona("00100001", edad=30, validar_con=bd.d.op1)
    bd.parametro("horario.hora_limite_prestamos", "00:00")
    with pytest.raises(Exception) as e:
        bd.prestar(pid, 1)
    assert "fuera_de_horario" in str(e.value)
    bd.parametro("horario.hora_limite_prestamos", None)
    bd.parametro("reglas_uso.edad_minima", 18)
    menor = bd.persona("00200001", tipo="TI", edad=15, validar_con=bd.d.op1, acudiente={
        "tipo_documento": "CC", "numero_documento": "00900001", "nombres": "Padre",
        "apellidos": "De Prueba", "telefono": "3000000009", "parentesco": "padre"})
    with pytest.raises(Exception) as e:
        bd.prestar(menor, 2)
    assert "edad_minima" in str(e.value)


def test_duracion_maxima_calcula_vencimiento_y_retraso(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.parametro("reglas_uso.duracion_maxima_min", 60)
    r = bd.prestar(pid, 1)
    assert r["vence_en"] is not None
    bd.como("dueno")
    bd.sql("update public.prestamos set salida_en = now() - interval '90 minutes'")
    bd.como(bd.d.op1)
    d = bd.rpc("registrar_devolucion", p_id_operacion=uuid.uuid4(), p_numero_bici=1, p_punto_id=bd.d.p01)
    assert d["excedio"] is True and d["duracion_min"] >= 90


def test_parametro_fuera_de_rango_se_rechaza(bd):
    with pytest.raises(Exception, match="parametro_fuera_de_rango"):
        bd.parametro("reglas_uso.duracion_maxima_min", 2)


def test_persona_sancionada_no_presta(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.como(bd.d.admin)
    bd.sql("""insert into public.sanciones (persona_id, tipo, motivo, hasta)
              values (%s, 'suspension', 'Retraso reiterado (prueba)', current_date + 5)""", (pid,))
    with pytest.raises(Exception) as e:
        bd.prestar(pid, 1)
    assert "persona_sancionada" in str(e.value)


def test_menor_presta_con_acudiente_y_queda_registrado(bd):
    menor = bd.persona("00200001", tipo="TI", edad=12, validar_con=bd.d.op1, acudiente={
        "tipo_documento": "CC", "numero_documento": "00900001", "nombres": "Madre",
        "apellidos": "De Prueba", "telefono": "3000000009", "parentesco": "madre"})
    bd.prestar(menor, 1)
    bd.como("dueno")
    assert bd.sql("select es_menor, acudiente_id is not null from public.prestamos") == [(True, True)]


def test_prestamo_en_punto_de_evento_exige_evento_en_curso(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.como(bd.d.admin)
    bd.rpc("mover_bicis", p_numeros=[1], p_punto_destino=bd.d.e01, p_motivo="Llevar al evento")
    bd.prestar(pid, 1, punto=bd.d.e01)
    bd.como("dueno")
    bd.sql("update public.eventos set estado = 'finalizado'")
    bd.como(bd.d.op1)
    bd.rpc("mover_bicis", p_numeros=[2], p_punto_destino=bd.d.e01, p_motivo="Llevar al evento")
    with pytest.raises(Exception) as e:
        bd.prestar(pid, 2, punto=bd.d.e01)
    assert "evento_no_en_curso" in str(e.value)


def test_devolucion_con_novedad_deja_la_bici_fuera_de_servicio_y_retiene_la_foto(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.prestar(pid, 1)
    bd.como(bd.d.op1)
    bd.rpc("registrar_devolucion", p_id_operacion=uuid.uuid4(), p_numero_bici=1, p_punto_id=bd.d.p01,
           p_con_novedad=True, p_incidencia={"tipo": "dano", "gravedad": "moderada",
                                              "descripcion": "Freno trasero suelto", "deja_fuera_de_servicio": True})
    bd.como("dueno")
    assert bd.sql("select disponibilidad, condicion from public.bicicletas where numero = 1") == \
        [("no_disponible", "averiada")]
    assert bd.uno("select foto_retener from public.prestamos") is True
    bd.como(bd.d.op2)                                    # el siguiente operador ve la novedad abierta
    assert bd.sql("select descripcion from public.incidencias where estado <> 'cerrada'") == [("Freno trasero suelto",)]


def test_devolver_en_taller_deja_la_bici_no_disponible(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.prestar(pid, 1)
    bd.como(bd.d.op1)
    bd.rpc("registrar_devolucion", p_id_operacion=uuid.uuid4(), p_numero_bici=1, p_punto_id=bd.d.t01)
    bd.como("dueno")
    assert bd.uno("select disponibilidad from public.bicicletas where numero = 1") == "no_disponible"


def test_solo_el_admin_anula_y_la_bici_vuelve_al_punto(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    r = bd.prestar(pid, 1)
    bd.como(bd.d.op1)
    assert bd.error("anular_prestamo", p_prestamo_id=r["prestamo_id"], p_motivo="Registrado por error") == "no_autorizado"
    bd.como(bd.d.admin)
    assert bd.error("anular_prestamo", p_prestamo_id=r["prestamo_id"], p_motivo="corto") == "motivo_insuficiente"
    bd.rpc("anular_prestamo", p_prestamo_id=r["prestamo_id"], p_motivo="Registrado por error en la bici")
    assert _disponibles(bd, bd.d.p01) == 10
    bd.como("dueno")
    assert bd.uno("""select motivo from public.auditoria
                     where tabla = 'prestamos' and accion = 'prestamo.anular'""") == "Registrado por error en la bici"


def test_cerrar_no_devuelto_marca_extraviada_y_abre_incidencia(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    r = bd.prestar(pid, 1)
    bd.como(bd.d.admin)
    bd.rpc("cerrar_no_devuelto", p_prestamo_id=r["prestamo_id"], p_motivo="No regresó al cierre de la jornada")
    bd.como("dueno")
    assert bd.sql("select condicion, punto_actual_id from public.bicicletas where numero = 1") == [("extraviada", None)]
    assert bd.sql("select tipo, gravedad from public.incidencias") == [("perdida", "grave")]
    assert bd.uno("select foto_retener from public.prestamos") is True


def test_operador_solo_marca_averiada(bd):
    bd.como(bd.d.op1)
    assert bd.error("cambiar_condicion_bici", p_numero=1, p_condicion="baja", p_motivo="Muy dañada") == "no_autorizado"
    bd.rpc("cambiar_condicion_bici", p_numero=1, p_condicion="averiada", p_motivo="Cadena rota")
    bd.como(bd.d.admin)
    bd.rpc("cambiar_condicion_bici", p_numero=1, p_condicion="operativa", p_motivo="Cadena reparada")
    assert _disponibles(bd, bd.d.p01) == 10


def test_crear_bicicletas_es_idempotente_y_genera_el_codigo(bd):
    bd.como(bd.d.admin)
    assert bd.rpc("crear_bicicletas", p_desde=9, p_hasta=12, p_punto_id=bd.d.p02) == 2   # 9 y 10 ya existen
    bd.como("dueno")
    assert bd.sql("select codigo from public.bicicletas where numero in (12, 1)  order by numero") == \
        [("BPV-001",), ("BPV-012",)]
    bd.sql("insert into public.bicicletas (numero, disponibilidad, punto_actual_id) values (1234, 'no_disponible', %s)",
           (bd.d.p02,))
    assert bd.uno("select codigo from public.bicicletas where numero = 1234") == "BPV-1234"


def test_cerrar_punto_de_evento_exige_que_no_queden_bicis(bd):
    bd.como(bd.d.admin)
    bd.rpc("mover_bicis", p_numeros=[1], p_punto_destino=bd.d.e01, p_motivo="Llevar al evento")
    assert bd.error("cerrar_punto_evento", p_punto_id=bd.d.e01) == "punto_con_bicis"
    bd.rpc("mover_bicis", p_numeros=[1], p_punto_destino=bd.d.p01, p_motivo="Regreso del evento")
    bd.rpc("cerrar_punto_evento", p_punto_id=bd.d.e01)
    bd.como("anon")
    assert bd.sql("select codigo from public.disponibilidad_puntos where codigo = 'E01'") == []


def test_operador_no_edita_columnas_de_disponibilidad_ni_parametros(bd):
    bd.como(bd.d.op1)
    with pytest.raises(Exception):
        bd.sql("update public.bicicletas set disponibilidad = 'no_disponible' where numero = 1")
    assert bd.sql("update public.parametros set valor = '30' where clave = 'reglas_uso.duracion_maxima_min' returning clave") == []


def test_tablero_resumen_para_el_admin(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.prestar(pid, 1)
    bd.como(bd.d.admin)
    t = bd.rpc("tablero_resumen")
    assert t["bicis"]["prestada"] == 1 and t["prestamos_hoy"] == 1 and t["prestamos_activos"] == 1
    assert t["retencion_fotos_dias"] is None            # el tablero alerta que falta configurarla
    assert t["storage_bytes"] == 120000
    bd.como(bd.d.op1)
    assert bd.error("tablero_resumen") == "no_autorizado"


def test_solo_el_admin_ve_las_fotos(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.prestar(pid, 1)
    bd.como(bd.d.op1)
    assert bd.sql("select name from storage.objects") == []
    bd.como(bd.d.admin)
    assert len(bd.sql("select name from storage.objects")) == 1
    bd.como("anon")
    assert bd.sql("select name from storage.objects") == []


def test_personal_sin_administradores_activos_se_impide(bd):
    bd.como(bd.d.admin)
    with pytest.raises(Exception, match="no_puede_degradarse"):
        bd.sql("update public.personal set rol = 'operador' where id = %s", (bd.d.admin,))


# --- Correcciones de la revisión de seguridad 1a (docs/privado/revisiones) ------

def test_b1_devolucion_con_id_viejo_tras_un_nuevo_prestamo_no_finge_exito(bd):
    a = bd.persona("00100001", validar_con=bd.d.op1)
    b = bd.persona("00100002", validar_con=bd.d.op1)
    bd.prestar(a, 1)
    op = uuid.uuid4()
    bd.como(bd.d.op1)
    bd.rpc("registrar_devolucion", p_id_operacion=op, p_numero_bici=1, p_punto_id=bd.d.p01)
    bd.prestar(b, 1)
    bd.como(bd.d.op1)
    assert bd.error("registrar_devolucion", p_id_operacion=op, p_numero_bici=1,
                    p_punto_id=bd.d.p01) == "id_operacion_reutilizado"


def test_b2_foto_de_incidencia_solo_ruta_propia_y_subida(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    r = bd.prestar(pid, 1)
    bd.como(bd.d.op1)
    base = dict(p_id_operacion=uuid.uuid4(), p_numero_bici=1, p_punto_id=bd.d.p01, p_con_novedad=True)
    novedad = {"tipo": "dano", "gravedad": "leve", "descripcion": "Timbre suelto"}
    otra = f"prestamos/{r['prestamo_id']}/salida.webp"
    assert bd.error("registrar_devolucion", **base, p_incidencia={**novedad, "foto_ruta": otra}) == "foto_ruta_invalida"
    propia = f"incidencias/{uuid.uuid4()}/dano.webp"
    assert bd.error("registrar_devolucion", **base, p_incidencia={**novedad, "foto_ruta": propia}) == "falta_foto"


def test_b2_foto_minuscula_no_cuenta_como_evidencia(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    prestamo = uuid.uuid4()
    ruta = f"prestamos/{prestamo}/salida.webp"
    bd.como(bd.d.op1)
    bd.sql("insert into storage.objects (bucket_id, name, metadata) values ('evidencias', %s, %s)",
           (ruta, '{"size": 100}'))
    assert bd.error("registrar_prestamo", p_id=prestamo, p_persona_id=pid, p_numero_bici=1,
                    p_punto_id=bd.d.p01, p_foto_ruta=ruta) == "falta_foto"


def test_b4_no_se_mueven_bicis_a_un_punto_cerrado(bd):
    bd.como(bd.d.admin)
    bd.rpc("cerrar_punto_evento", p_punto_id=bd.d.e01)
    assert bd.error("mover_bicis", p_numeros=[1], p_punto_destino=bd.d.e01, p_motivo="Llevar al evento") == "punto_cerrado"


def test_b5_el_admin_no_cierra_puntos_con_bicis_ni_cambia_su_tipo(bd):
    bd.como(bd.d.admin)
    with pytest.raises(Exception, match="punto_con_bicis"):
        bd.sql("update public.puntos set estado = 'cerrado' where id = %s", (bd.d.p01,))
    with pytest.raises(Exception, match="permission denied"):
        bd.sql("update public.puntos set tipo = 'taller' where id = %s", (bd.d.p02,))


def test_b5_la_atribucion_de_sanciones_e_incidencias_la_fija_el_servidor(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.como(bd.d.admin)
    with pytest.raises(Exception, match="permission denied"):
        bd.sql("insert into public.sanciones (persona_id, tipo, motivo, hasta, impuesta_por) "
               "values (%s, 'suspension', 'Motivo de prueba suficiente', current_date + 1, %s)", (pid, bd.d.op1))
    bd.sql("insert into public.sanciones (persona_id, tipo, motivo, hasta) "
           "values (%s, 'suspension', 'Motivo de prueba suficiente', current_date + 1)", (pid,))
    assert bd.uno("select impuesta_por from public.sanciones") == bd.d.admin
    bd.sql("update public.sanciones set estado = 'anulada', motivo_anulacion = 'Error de digitación'")
    assert bd.uno("select anulada_por from public.sanciones") == bd.d.admin


def test_b5_el_operador_no_revive_bicis_dadas_de_baja(bd):
    bd.como(bd.d.admin)
    bd.rpc("cambiar_condicion_bici", p_numero=1, p_condicion="baja", p_motivo="Marco partido")
    bd.como(bd.d.op1)
    assert bd.error("cambiar_condicion_bici", p_numero=1, p_condicion="averiada", p_motivo="Revivir") == "no_autorizado"


def test_b10_textos_libres_tienen_limite(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    prestamo = uuid.uuid4()
    ruta = bd.subir_foto(prestamo)
    bd.como(bd.d.op1)
    assert bd.error("registrar_prestamo", p_id=prestamo, p_persona_id=pid, p_numero_bici=1, p_punto_id=bd.d.p01,
                    p_foto_ruta=ruta, p_observaciones="x" * 501) == "texto_demasiado_largo"


def test_m2_menor_preinscrito_por_web_no_presta_sin_autorizacion_presencial(bd):
    menor = bd.persona("00200001", tipo="TI", edad=12, acudiente={
        "tipo_documento": "CC", "numero_documento": "00900001", "nombres": "Madre",
        "apellidos": "De Prueba", "telefono": "3000000009", "parentesco": "madre"})
    bd.como(bd.d.op1)
    assert bd.error("validar_persona", p_persona_id=menor) == "falta_autorizacion_presencial"
    # Aunque alguien lo marcara validado por fuera de la función, no presta.
    bd.como("dueno")
    bd.sql("update public.personas set estado = 'validada', validada_en = now(), validada_por = %s where id = %s",
           (bd.d.op1, menor))
    with pytest.raises(Exception) as e:
        bd.prestar(menor, 1)
    assert "falta_autorizacion_presencial" in str(e.value)
    # Con el acudiente presente, el operador registra la autorización y el menor presta.
    bd.como(bd.d.op1)
    bd.rpc("validar_persona", p_persona_id=menor, p_autorizacion={
        "politica_version": "0.1", "autoriza_tratamiento": True, "autoriza_foto": True, "menor_escuchado": True})
    bd.prestar(menor, 1)
