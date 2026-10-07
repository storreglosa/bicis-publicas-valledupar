"""Preinscripción, inscripción en el punto, validación y autorizaciones (RF-05..07, RF-21..22, RN-03..04)."""

import uuid

import pytest

ACUDIENTE = {"tipo_documento": "CC", "numero_documento": "00900001", "nombres": "Madre",
             "apellidos": "De Prueba", "telefono": "3000000009", "parentesco": "madre"}


def _solicitud(bd, documento="00100001", tipo="CC", edad="30", **extra):
    p = {
        "id_operacion": str(uuid.uuid4()), "tipo_documento": tipo, "numero_documento": documento,
        "nombres": "  Ana   María ", "apellidos": "Pérez", "telefono": "300 000 0001",
        "correo": " Ana@Ejemplo.INVALID ", "edad": edad, "sexo_genero": "mujer",
        "autorizacion": {"id": str(uuid.uuid4()), "politica_version": bd.d.version_politica,
                         "autoriza_tratamiento": True, "autoriza_foto": True},
    }
    p.update(extra)
    return p


def test_preinscripcion_crea_persona_preinscrita_con_autorizacion_web(bd):
    bd.como("servicio")
    r = bd.rpc("preinscribir", p=_solicitud(bd))
    assert r == {"resultado": "inscrito"}          # no devuelve ningún dato personal
    bd.como("dueno")
    nombres, telefono, correo, estado, origen = bd.sql(
        "select nombres, telefono, correo, estado, origen from public.personas where numero_documento = '00100001'")[0]
    assert (nombres, telefono, correo) == ("Ana María", "3000000001", "ana@ejemplo.invalid")
    assert (estado, origen) == ("preinscrita", "web")
    otorgada_por, canal, registrada_por = bd.sql(
        """select a.otorgada_por, a.canal, a.registrada_por from public.autorizaciones_datos a
             join public.personas p on p.id = a.persona_id where p.numero_documento = '00100001'""")[0]
    assert (otorgada_por, canal, registrada_por) == ("titular", "web", None)


def test_documento_repetido_responde_ya_inscrito_sin_modificar_nada(bd):
    bd.como("servicio")
    bd.rpc("preinscribir", p=_solicitud(bd))
    otra = _solicitud(bd, nombres="Intruso", telefono="3111111111")
    assert bd.rpc("preinscribir", p=otra) == {"resultado": "ya_inscrito"}
    bd.como("dueno")
    assert bd.sql("select nombres, telefono from public.personas where numero_documento = '00100001'") == \
        [("Ana María", "3000000001")]


def test_reintento_con_el_mismo_id_de_operacion_no_duplica(bd):
    p = _solicitud(bd)
    bd.como("servicio")
    assert bd.rpc("preinscribir", p=p) == {"resultado": "inscrito"}
    assert bd.rpc("preinscribir", p=p) == {"resultado": "inscrito"}
    bd.como("dueno")
    assert bd.uno("select count(*) from public.personas where numero_documento = '00100001'") == 1


def test_menor_sin_acudiente_se_rechaza(bd):
    bd.como("servicio")
    assert bd.error("preinscribir", p=_solicitud(bd, tipo="TI", documento="00200001", edad="14")) == "falta_acudiente"


def test_menor_con_acudiente_lo_autoriza_el_acudiente_y_se_escucha_al_menor(bd):
    p = _solicitud(bd, tipo="TI", documento="00200001", edad="14", acudiente=ACUDIENTE)
    p["autorizacion"]["menor_escuchado"] = True
    bd.como("servicio")
    assert bd.rpc("preinscribir", p=p) == {"resultado": "inscrito"}
    bd.como("dueno")
    otorgada_por, escuchado, con_acudiente = bd.sql(
        """select a.otorgada_por, a.menor_escuchado, a.acudiente_id is not null
             from public.autorizaciones_datos a join public.personas p on p.id = a.persona_id
            where p.numero_documento = '00200001'""")[0]
    assert (otorgada_por, escuchado, con_acudiente) == ("acudiente", True, True)


def test_menor_sin_constancia_de_ser_escuchado_se_rechaza(bd):
    p = _solicitud(bd, tipo="TI", documento="00200001", edad="14", acudiente=ACUDIENTE)
    bd.como("servicio")
    assert bd.error("preinscribir", p=p) == "falta_menor_escuchado"


def test_tarjeta_de_identidad_implica_menor_aunque_declare_18(bd):
    bd.como("servicio")
    assert bd.error("preinscribir", p=_solicitud(bd, tipo="TI", documento="00200001", edad="18")) == "falta_acudiente"


def test_menor_por_edad_con_pasaporte_exige_acudiente(bd):
    bd.como("servicio")
    assert bd.error("preinscribir", p=_solicitud(bd, tipo="PA", documento="00AB1234", edad="12")) == "falta_acudiente"


def test_cedula_con_edad_de_menor_es_inconsistente(bd):
    bd.como("servicio")
    assert bd.error("preinscribir", p=_solicitud(bd, edad="16")) == "edad_no_coincide_documento"


def test_acudiente_no_puede_ser_menor(bd):
    acu = dict(ACUDIENTE, tipo_documento="TI", numero_documento="00200099")
    p = _solicitud(bd, tipo="TI", documento="00200001", edad="14", acudiente=acu)
    p["autorizacion"]["menor_escuchado"] = True
    bd.como("servicio")
    assert bd.error("preinscribir", p=p) == "acudiente_debe_ser_adulto"


def test_parentesco_fuera_de_la_lista_se_rechaza(bd):
    acu = dict(ACUDIENTE, parentesco="vecina")
    p = _solicitud(bd, tipo="TI", documento="00200001", edad="14", acudiente=acu)
    p["autorizacion"]["menor_escuchado"] = True
    bd.como("servicio")
    assert bd.error("preinscribir", p=p) == "parentesco_invalido"


@pytest.mark.parametrize("cambio, error", [
    ({"numero_documento": "12"}, "documento_invalido"),
    ({"tipo_documento": "XX"}, "tipo_documento_invalido"),
    ({"telefono": "123"}, "telefono_invalido"),
    ({"correo": "no-es-correo"}, "correo_invalido"),
    ({"edad": "4"}, "edad_invalida"),
    ({"edad": "treinta"}, "edad_invalida"),
    ({"sexo_genero": "x"}, "sexo_genero_invalido"),
    ({"nombres": "   "}, "nombre_invalido"),
    ({"nombres": "<script>"}, "nombre_invalido"),
    ({"id_operacion": "no-uuid"}, "id_operacion_invalido"),
])
def test_validaciones_de_entrada(bd, cambio, error):
    bd.como("servicio")
    assert bd.error("preinscribir", p=_solicitud(bd, **cambio)) == error


def test_autorizacion_obligatoria_y_sobre_la_politica_vigente(bd):
    sin_aut = _solicitud(bd)
    sin_aut["autorizacion"]["autoriza_tratamiento"] = False
    vieja = _solicitud(bd)
    vieja["autorizacion"]["politica_version"] = "0.0"
    bd.como("servicio")
    assert bd.error("preinscribir", p=sin_aut) == "falta_autorizacion"
    assert bd.error("preinscribir", p=vieja) == "politica_desactualizada"


def test_operador_busca_solo_por_documento_exacto_y_queda_en_bitacora(bd):
    pid = bd.persona("00100001")
    bd.como(bd.d.op1)
    r = bd.rpc("buscar_persona", p_tipo="CC", p_numero="00.100.001")   # con puntos: se normaliza
    assert r["id"] == str(pid)
    assert r["documento_enmascarado"] == "****0001"
    assert r["telefono_enmascarado"] == "****0000"
    assert "numero_documento" not in r and "telefono" not in r
    assert r["estado"] == "preinscrita" and r["autorizacion_vigente"] is True
    assert bd.rpc("buscar_persona", p_tipo="CC", p_numero="00999999") is None
    bd.como("dueno")
    assert bd.sql("select encontrada from public.bitacora_consultas where actor_id = %s order by id",
                  (bd.d.op1,)) == [(True,), (False,)]


def test_operador_no_lee_la_tabla_de_personas(bd):
    bd.persona("00100001")
    bd.como(bd.d.op1)
    assert bd.sql("select * from public.personas") == []
    bd.como(bd.d.admin)
    assert len(bd.sql("select * from public.personas")) == 1


def test_anon_y_usuario_sin_rol_no_pueden_buscar(bd):
    bd.como(bd.d.sin_rol)
    assert bd.error("buscar_persona", p_tipo="CC", p_numero="00100001") == "no_autorizado"
    bd.como("anon")
    assert bd.error("buscar_persona", p_tipo="CC", p_numero="00100001").startswith("sin_permiso")


def test_validacion_presencial_con_correcciones(bd):
    pid = bd.persona("00100001")
    bd.como(bd.d.op1)
    r = bd.rpc("validar_persona", p_persona_id=pid, p_correcciones={"telefono": "3009998877", "edad": "31"})
    assert r["estado"] == "validada" and r["edad_estimada"] == 31
    bd.como("dueno")
    assert bd.sql("select telefono, validada_por from public.personas where id = %s", (pid,)) == \
        [("3009998877", bd.d.op1)]


def test_inscripcion_en_el_punto_queda_validada_y_registra_al_operador(bd):
    p = _solicitud(bd, documento="00300001")
    bd.como(bd.d.op1)
    r = bd.rpc("registrar_persona_en_punto", p=p)
    assert r["resultado"] == "inscrito"
    bd.como("dueno")
    assert bd.sql("select estado, origen, validada_por from public.personas where numero_documento = '00300001'") == \
        [("validada", "punto", bd.d.op1)]
    assert bd.uno("""select registrada_por from public.autorizaciones_datos a join public.personas p
                     on p.id = a.persona_id where p.numero_documento = '00300001'""") == bd.d.op1


def test_nueva_politica_exige_nueva_autorizacion_para_prestar(bd):
    pid = bd.persona("00100001", validar_con=bd.d.op1)
    bd.como(bd.d.admin)
    bd.rpc("publicar_politica", p_version="0.2", p_vigente_desde="2026-10-07",
           p_texto_md="Nueva política ficticia. " * 20,
           p_texto_autorizacion="Autorizo el tratamiento (v0.2).", p_texto_autorizacion_foto="Autorizo la foto (v0.2).")
    bd.como(bd.d.op1)
    assert bd.rpc("buscar_persona", p_tipo="CC", p_numero="00100001")["autorizacion_vigente"] is False
    r = bd.rpc("registrar_autorizacion", p_persona_id=pid,
               p_autorizacion={"politica_version": "0.2", "autoriza_tratamiento": True, "autoriza_foto": True})
    assert r["autorizacion_vigente"] is True


def test_politica_publicada_es_inmutable(bd):
    bd.como("dueno")
    with pytest.raises(Exception, match="politica_inmutable"):
        bd.sql("update public.politicas_tratamiento set texto_md = texto_md || ' cambio' where vigente")


def test_auditoria_guarda_huellas_y_no_datos_personales(bd):
    bd.persona("00100001")
    bd.como("dueno")
    despues = bd.uno("select despues from public.auditoria where tabla = 'personas' and operacion = 'INSERT'")
    for campo in ("numero_documento", "nombres", "apellidos", "telefono"):
        assert despues[campo].startswith("huella:"), campo
    assert "00100001" not in str(despues)


def test_auditoria_es_inmutable(bd):
    bd.persona("00100001")
    bd.como("dueno")
    with pytest.raises(Exception, match="registro_inmutable"):
        bd.sql("delete from public.auditoria")


# --- Correcciones de la revisión de seguridad 1a ---------------------------------

ESPACIOS_RAROS = ["\t", "\n", "\u00a0", "\u2003", "\u3000", "   ", "\t\u2003 "]


@pytest.mark.parametrize("valor", ESPACIOS_RAROS)
@pytest.mark.parametrize("campo", ["nombres", "apellidos"])
def test_a1_espacios_raros_no_filtran_la_fila_en_el_detail(bd, campo, valor):
    pid = bd.persona("00100001")
    bd.como(bd.d.op1)
    e = bd.excepcion("validar_persona", p_persona_id=pid, p_correcciones={campo: valor})
    assert str(e) == "nombre_invalido" and e.detalle is None
    bd.como("servicio")
    e = bd.excepcion("preinscribir", p=_solicitud(bd, documento="00100009", **{campo: valor}))
    assert str(e) == "nombre_invalido" and e.detalle is None


def test_a1_ningun_error_de_inscripcion_trae_detail(bd):
    casos = [{"telefono": "1"}, {"correo": "x@"}, {"edad": "200"}, {"nombres": "a" * 81},
             {"acudiente": {"tipo_documento": "CC", "numero_documento": "00900001", "nombres": "\t",
                            "apellidos": "X", "telefono": "3000000009", "parentesco": "madre"},
              "tipo_documento": "TI", "numero_documento": "00200001", "edad": "12"}]
    bd.como(bd.d.op1)
    for caso in casos:
        e = bd.excepcion("registrar_persona_en_punto", p=_solicitud(bd, **caso))
        assert e.detalle is None, (caso, e.detalle)


def test_m1_ya_inscrito_en_el_punto_no_devuelve_id_y_queda_en_bitacora(bd):
    bd.persona("00100001")
    bd.como(bd.d.op1)
    assert bd.rpc("registrar_persona_en_punto", p=_solicitud(bd)) == {"resultado": "ya_inscrito"}
    bd.como("dueno")
    assert bd.sql("select tipo, encontrada from public.bitacora_consultas where actor_id = %s", (bd.d.op1,)) == \
        [("buscar_persona", True)]


def test_m1_validar_y_autorizar_quedan_en_bitacora_como_ver_persona(bd):
    pid = bd.persona("00100001")
    bd.como(bd.d.op1)
    bd.rpc("validar_persona", p_persona_id=pid)
    bd.rpc("registrar_autorizacion", p_persona_id=pid, p_autorizacion={
        "politica_version": "0.1", "autoriza_tratamiento": True, "autoriza_foto": True})
    bd.como("dueno")
    assert bd.sql("select tipo from public.bitacora_consultas where actor_id = %s order by id", (bd.d.op1,)) == \
        [("ver_persona",), ("ver_persona",)]


def test_m4_la_sal_no_llega_a_la_auditoria_y_cambiarla_desvincula_las_huellas(bd):
    pid = bd.persona("00100001")
    bd.como("dueno")
    despues = bd.uno("select despues from public.auditoria where tabla = 'personas' and operacion = 'INSERT'")
    assert "sal_huella" not in despues
    huella_auditada = despues["numero_documento"].removeprefix("huella:")
    assert bd.uno("select privado.huella(numero_documento, sal_huella) from public.personas where id = %s",
                  (pid,)) == huella_auditada
    bd.sql("update public.personas set sal_huella = 'sal-nueva-tras-anonimizar' where id = %s", (pid,))
    assert bd.uno("select privado.huella(numero_documento, sal_huella) from public.personas where id = %s",
                  (pid,)) != huella_auditada
    assert "sal-nueva" not in str(bd.sql("select antes, despues from public.auditoria"))


def test_m4_la_bitacora_no_guarda_huella_de_documentos_no_inscritos(bd):
    bd.como(bd.d.op1)
    assert bd.rpc("buscar_persona", p_tipo="CC", p_numero="00999999") is None
    bd.como("dueno")
    assert bd.sql("select huella_documento, encontrada from public.bitacora_consultas") == [(None, False)]


def test_b6_consentimiento_solo_con_booleano_true(bd):
    p = _solicitud(bd)
    p["autorizacion"]["autoriza_tratamiento"] = "yes"
    bd.como("servicio")
    assert bd.error("preinscribir", p=p) == "datos_invalidos"


def test_b6_id_de_autorizacion_de_otra_persona_no_se_reutiliza_en_silencio(bd):
    a = _solicitud(bd, documento="00100001")
    bd.como(bd.d.op1)
    bd.rpc("registrar_persona_en_punto", p=a)
    b = _solicitud(bd, documento="00100002")
    b["autorizacion"]["id"] = a["autorizacion"]["id"]
    assert bd.error("registrar_persona_en_punto", p=b) == "id_operacion_reutilizado"


def test_b9_solo_se_vinculan_cuentas_con_correo_confirmado(bd):
    bd.como("dueno")
    bd.sql("insert into auth.users (email) values ('nuevo@prueba.invalid')")
    bd.como(bd.d.admin)
    assert bd.error("vincular_personal", p_correo="nuevo@prueba.invalid", p_nombre="Operador Nuevo",
                    p_rol="operador") == "usuario_no_confirmado"
    bd.como("dueno")
    bd.sql("update auth.users set email_confirmed_at = now() where email = 'nuevo@prueba.invalid'")
    bd.como(bd.d.admin)
    assert bd.rpc("vincular_personal", p_correo="nuevo@prueba.invalid", p_nombre="Operador Nuevo", p_rol="operador")


def test_b10_limite_de_busquedas_por_operador(bd):
    bd.como("dueno")
    bd.sql("""insert into public.bitacora_consultas (actor_id, tipo, encontrada)
              select %s, 'buscar_persona', false from generate_series(1, 120)""", (bd.d.op1,))
    bd.como(bd.d.op1)
    assert bd.error("buscar_persona", p_tipo="CC", p_numero="00100001") == "demasiadas_busquedas"
    bd.como(bd.d.op2)                                    # otro operador no queda bloqueado
    assert bd.rpc("buscar_persona", p_tipo="CC", p_numero="00100001") is None


def test_resumen_indica_si_la_autorizacion_fue_presencial(bd):
    pid = bd.persona("00100001")                       # preinscrita por web
    bd.como(bd.d.op1)
    assert bd.rpc("buscar_persona", p_tipo="CC", p_numero="00100001")["autorizacion_presencial"] is False
    r = bd.rpc("registrar_autorizacion", p_persona_id=pid, p_autorizacion={
        "politica_version": "0.1", "autoriza_tratamiento": True, "autoriza_foto": True})
    assert r["autorizacion_presencial"] is True
