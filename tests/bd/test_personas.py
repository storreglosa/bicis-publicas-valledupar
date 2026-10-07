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
