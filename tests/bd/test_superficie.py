"""Superficie expuesta: qué puede tocar cada rol de la API.

Si alguien agrega una tabla o función y olvida cerrar permisos, esta prueba
falla. Agregar algo a una lista blanca exige justificarlo en la revisión.
"""

PRIVILEGIOS = ("SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER")

# Permisos de anon a nivel de TABLA (todas las columnas).
ANON_TABLAS = {("disponibilidad_puntos", "SELECT")}

# Permisos de anon a nivel de COLUMNA: nada de UUID del personal ni columnas internas (I-2).
ANON_COLUMNAS = {
    "tipos_documento": {"codigo", "nombre", "implica_menor", "patron", "orden", "activo"},
    "politicas_tratamiento": {"id", "version", "vigente_desde", "texto_md", "texto_autorizacion",
                              "texto_autorizacion_foto", "sha256", "vigente", "publicada_en"},
    "parametros": {"clave", "categoria", "descripcion", "tipo", "unidad", "minimo", "maximo", "publico", "orden", "valor"},
    "eventos": {"id", "nombre", "descripcion", "lugar_texto", "inicia_en", "termina_en", "estado", "publicado"},
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


def test_anon_lee_solo_columnas_publicas(bd):
    filas = bd.sql(
        """select c.relname, a.attname
             from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'v') and a.attnum > 0 and not a.attisdropped
              and c.relname <> 'disponibilidad_puntos'
              and has_column_privilege('anon', c.oid, a.attnum, 'SELECT')""")
    columnas = {}
    for tabla, columna in filas:
        columnas.setdefault(tabla, set()).add(columna)
    assert columnas == ANON_COLUMNAS


def test_nadie_de_la_api_escribe_columnas_sueltas_salvo_el_admin_autenticado(bd):
    for rol in ("anon", "service_role"):
        escribibles = bd.sql(
            """select c.relname, a.attname, p.priv
                 from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
                 cross join unnest(array['INSERT', 'UPDATE']) p(priv)
                where n.nspname = 'public' and a.attnum > 0 and not a.attisdropped
                  and has_column_privilege(%s, c.oid, a.attnum, p.priv)""", (rol,))
        assert escribibles == [], (rol, escribibles)


def test_service_role_solo_ejecuta_preinscribir_y_no_toca_tablas(bd):
    assert _funciones(bd, "service_role") == {"preinscribir"}
    assert _funciones(bd, "service_role", "privado") == set()
    assert _privilegios_tabla(bd, "service_role") == set()


def test_public_no_ejecuta_ninguna_funcion_propia(bd):
    """El EXECUTE que Postgres concede a PUBLIC por defecto se revoca globalmente en la
    migración 1 (revisión de seguridad M-3 y B-7)."""
    abiertas = bd.sql(
        """select n.nspname || '.' || p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname in ('public', 'privado')
              and exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                           where a.grantee = 0 and a.privilege_type = 'EXECUTE')""")
    assert abiertas == []


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
