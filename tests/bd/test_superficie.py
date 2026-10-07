"""Superficie expuesta: qué puede tocar cada rol de la API.

Si alguien agrega una tabla o función y olvida cerrar permisos, esta prueba
falla. Agregar algo a una lista blanca exige justificarlo en la revisión.
"""

PRIVILEGIOS = ("SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER")

ANON_TABLAS = {
    ("disponibilidad_puntos", "SELECT"),
    ("eventos", "SELECT"),
    ("parametros", "SELECT"),
    ("politicas_tratamiento", "SELECT"),
    ("tipos_documento", "SELECT"),
}

AUTH_FUNCIONES = {
    "anular_prestamo", "buscar_persona", "cambiar_condicion_bici", "cerrar_no_devuelto",
    "cerrar_punto_evento", "crear_bicicletas", "forzar_devolucion", "marcar_clave_cambiada",
    "mi_perfil", "mover_bicis", "prestamos_activos", "publicar_politica", "registrar_autorizacion",
    "registrar_devolucion", "registrar_exportacion", "registrar_persona_en_punto", "registrar_prestamo",
    "tablero_resumen", "validar_persona", "vincular_personal",
}


def _privilegios_tabla(bd, rol):
    filas = bd.sql(
        """select c.relname, p.priv
             from pg_class c join pg_namespace n on n.oid = c.relnamespace
             cross join unnest(%s::text[]) p(priv)
            where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p')
              and has_table_privilege(%s, c.oid, p.priv)""",
        (list(PRIVILEGIOS), rol))
    return {(t, p) for t, p in filas}


def _funciones(bd, rol, esquema="public"):
    filas = bd.sql(
        """select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = %s and has_function_privilege(%s, p.oid, 'EXECUTE')""",
        (esquema, rol))
    return {f for (f,) in filas}


def test_anon_solo_lee_la_lista_blanca(bd):
    assert _privilegios_tabla(bd, "anon") == ANON_TABLAS


def test_anon_no_ejecuta_ninguna_funcion(bd):
    assert _funciones(bd, "anon") == set()
    assert _funciones(bd, "anon", "privado") == set()


def test_anon_no_entra_al_esquema_privado(bd):
    assert bd.uno("select has_schema_privilege('anon', 'privado', 'USAGE')") is False


def test_authenticated_ejecuta_exactamente_la_lista_blanca(bd):
    assert _funciones(bd, "authenticated") == AUTH_FUNCIONES


def test_authenticated_en_privado_solo_los_tres_auxiliares_de_rls(bd):
    assert _funciones(bd, "authenticated", "privado") == {"rol_actual", "es_admin", "es_personal"}


def test_preinscribir_solo_la_ejecuta_el_servicio(bd):
    assert "preinscribir" not in _funciones(bd, "authenticated")
    assert "preinscribir" in _funciones(bd, "service_role")


def test_nadie_de_la_api_borra_tablas_de_negocio(bd):
    for rol in ("anon", "authenticated"):
        borrados = {t for t, p in _privilegios_tabla(bd, rol) if p in ("DELETE", "TRUNCATE")}
        assert borrados == set(), (rol, borrados)


def test_todas_las_tablas_de_public_tienen_rls(bd):
    sin_rls = bd.sql(
        """select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity""")
    assert sin_rls == []


def test_disponibilidad_en_realtime_y_nada_mas(bd):
    tablas = bd.sql("select tablename from pg_publication_tables where pubname = 'supabase_realtime'")
    assert tablas == [("disponibilidad_puntos",)]


def test_funciones_security_definer_tienen_search_path_fijo(bd):
    sueltas = bd.sql(
        """select n.nspname || '.' || p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname in ('public', 'privado') and p.prosecdef
              and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%%')""")
    assert sueltas == []
