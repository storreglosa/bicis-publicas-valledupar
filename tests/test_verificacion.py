"""El escáner de publicación detecta lo que no debe salir y respeta la lista blanca."""

import importlib.util
import pathlib

RUTA = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "verificar_publicacion.py"
spec = importlib.util.spec_from_file_location("verificar_publicacion", RUTA)
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


# Las muestras se arman al ejecutar para que ningún dato con forma real quede literal
# en el repo (el propio escáner revisa este archivo antes de publicar).
CORREO = "persona.real" + "@" + "gmail.com"
CELULAR = "315 444" + " 5566"
CELULAR_57 = "+57 " + "315444" + "5566"
SECRETA = "sb_" + "secret_" + "AbCdEf123456"
CADENA = "postgresql://postgres.abc:" + "MiClave123" + "@host:5432/postgres"
LLAVE = "-----BEGIN " + "PRIVATE KEY-----"


def tipos(texto):
    return {h.split(": ")[1] for h in v.revisar_texto("x", texto)}


def test_detecta_correo_celular_y_secretos():
    assert "correo" in tipos(f"escribir a {CORREO}")
    assert "celular_colombia" in tipos(f"tel {CELULAR}")
    assert "celular_colombia" in tipos(CELULAR_57)
    assert "clave_secreta_supabase" in tipos(SECRETA)
    assert "cadena_con_contrasena" in tipos(CADENA)
    assert "llave_privada" in tipos(LLAVE)


def test_respeta_lista_blanca_y_marcadores():
    assert tipos("prueba@prueba.invalid y noreply@anthropic.com") == set()
    assert tipos("telefono 3000000000") == set()
    assert tipos("postgresql://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@host:5432/postgres") == set()
    assert tipos("marca de tiempo 1791409893 y hash a3001234567b") == set()


def test_el_hallazgo_no_repite_el_dato_completo():
    hallazgo = v.revisar_texto("x", CORREO)[0]
    assert CORREO not in hallazgo


def test_archivos_prohibidos():
    for ruta in (".env", ".env.local", "datos/personas.csv", "docs/privado/notas.md", "respaldo.dump"):
        assert v.revisar_nombre(ruta), ruta
    assert v.revisar_nombre(".env.example") == []
    assert v.revisar_nombre("src/App.vue") == []
