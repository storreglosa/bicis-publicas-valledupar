"""Escáner anti-datos-personales y anti-secretos antes de publicar (repo PÚBLICO).

    python scripts/verificar_publicacion.py --historial   # todo lo que git subiría (todas las versiones)
    python scripts/verificar_publicacion.py dist           # un directorio (p. ej. el build)

Sale con código 1 si encuentra algo. Cada excepción de la lista blanca va con
su razón. Patrón adaptado de ArcgisManage-rediseno/arcgis_manage/publicacion/verificacion.py.
"""

import pathlib
import re
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parents[1]

PATRONES = {
    "correo": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    "celular_colombia": re.compile(r"(?<![\w.])(?:\+?57[ -]?)?3\d{2}[ -]?\d{3}[ -]?\d{4}(?![\w.])"),
    "clave_secreta_supabase": re.compile(r"sb_secret_[A-Za-z0-9_-]{8,}"),
    "jwt": re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
    "cadena_con_contrasena": re.compile(r"postgres(?:ql)?://[A-Za-z0-9._%-]+:[^@\s\[\]<>…*]{6,}@"),
    "llave_privada": re.compile(r"-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----"),
}

# Lista blanca: valor exacto → razón.
PERMITIDOS = {
    # Correos que no identifican a una persona
    "noreply@anthropic.com": "atribución de commits (Co-Authored-By)",
    "125851405+storreglosa@users.noreply.github.com": "dirección privada de GitHub (no expone el correo real)",
    "user@example.com": "ejemplo genérico",
    "atencionusuariotransito@valledupar-cesar.gov.co": "canal institucional público de la Secretaría (PQRSD y datos personales)",
    # Celulares ficticios de las pruebas (tests/bd), patrón 300000000x / repetidos
    "3000000000": "ficticio de pruebas", "3000000001": "ficticio de pruebas",
    "3000000009": "ficticio de pruebas", "3009998877": "ficticio de pruebas",
    "3111111111": "ficticio de pruebas", "3999999999": "ficticio de pruebas",
    "300 000 0001": "ficticio de pruebas (con espacios)",
    # Secuencia 123-4567 usada como ejemplo de formato en tests/unit (no corresponde a nadie)
    "3001234567": "ejemplo de formato en pruebas unitarias",
    "300 123-4567": "ejemplo de formato en pruebas unitarias",
    "+57 300 123 4567": "ejemplo de formato en pruebas unitarias",
}
DOMINIOS_PERMITIDOS = (".invalid",)  # RFC 2606: nunca existen

ARCHIVOS_PROHIBIDOS = re.compile(
    r"(^|/)(\.env(\..*)?|\.pgpass|pg_service\.conf)$|\.(csv|xlsx|xls|dump|sql\.gz|pem|key)$|^docs/privado/")
EXCEPCIONES_ARCHIVO = {".env.example"}


def _permitido(tipo: str, valor: str) -> bool:
    if valor in PERMITIDOS:
        return True
    if tipo == "correo":
        dominio = valor.rsplit("@", 1)[-1].lower()
        return dominio.endswith(DOMINIOS_PERMITIDOS) or dominio in {"supabase.co", "supabase.com"} and valor.startswith(("support@", "noreply@"))
    return False


def _enmascarar(valor: str) -> str:
    return valor[:3] + "…" + valor[-2:] if len(valor) > 6 else "…"


def revisar_texto(nombre: str, texto: str) -> list[str]:
    hallazgos = []
    for n, linea in enumerate(texto.splitlines(), 1):
        for tipo, patron in PATRONES.items():
            for m in patron.finditer(linea):
                if not _permitido(tipo, m.group(0)):
                    hallazgos.append(f"{nombre}:{n}: {tipo}: {_enmascarar(m.group(0))}")
    return hallazgos


def revisar_nombre(ruta: str) -> list[str]:
    if ruta in EXCEPCIONES_ARCHIVO or not ARCHIVOS_PROHIBIDOS.search(ruta):
        return []
    return [f"{ruta}: archivo que no debe publicarse"]


def _git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=RAIZ, check=True, capture_output=True, text=True).stdout


def revisar_historial() -> list[str]:
    """Cada versión de cada archivo alcanzable desde alguna rama (lo que subiría un push)."""
    hallazgos, vistos = [], set()
    for linea in _git("rev-list", "--objects", "--all").splitlines():
        partes = linea.split(" ", 1)
        if len(partes) < 2:
            continue
        sha, ruta = partes
        hallazgos += revisar_nombre(ruta)
        if sha in vistos or _git("cat-file", "-t", sha).strip() != "blob":
            continue
        vistos.add(sha)
        datos = subprocess.run(["git", "cat-file", "blob", sha], cwd=RAIZ, check=True, capture_output=True).stdout
        if b"\x00" in datos[:8000]:
            continue  # binario (imágenes, fuentes)
        hallazgos += revisar_texto(f"{ruta}@{sha[:7]}", datos.decode("utf-8", "replace"))
    for linea in _git("log", "--all", "--format=%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B%x01").split("\x01"):
        if linea.strip():
            hallazgos += revisar_texto(f"commit {linea.strip()[:7]}", linea.replace("\x00", " "))
    return sorted(set(hallazgos))


def revisar_directorio(carpeta: pathlib.Path) -> list[str]:
    hallazgos = []
    for ruta in sorted(p for p in carpeta.rglob("*") if p.is_file()):
        relativa = ruta.relative_to(carpeta).as_posix()
        hallazgos += revisar_nombre(relativa)
        datos = ruta.read_bytes()
        if b"\x00" in datos[:8000]:
            continue
        hallazgos += revisar_texto(relativa, datos.decode("utf-8", "replace"))
    return hallazgos


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    objetivo = sys.argv[1]
    hallazgos = revisar_historial() if objetivo == "--historial" else revisar_directorio(pathlib.Path(objetivo))
    if hallazgos:
        print(f"{len(hallazgos)} hallazgo(s) — NO publicar:")
        for h in hallazgos:
            print("  " + h)
        return 1
    print(f"Sin hallazgos en {objetivo}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
