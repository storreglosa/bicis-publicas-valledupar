"""Contraste WCAG 2.1 AA de la paleta (src/estilos/tokens.css).

Adaptado de ArcgisManage-rediseno/tests/test_contraste.py: un token no se mide
contra un fondo, se mide contra el PEOR de los fondos donde puede caer.

Umbrales:
  - texto: 4,5:1 (criterio 1.4.3)
  - bordes de controles, anillo de foco y marcadores del mapa: 3:1 (1.4.11)
"""

import re
from pathlib import Path

import pytest

TOKENS_CSS = Path(__file__).resolve().parent.parent / "src" / "estilos" / "tokens.css"

UMBRAL_TEXTO = 4.5
UMBRAL_NO_TEXTO = 3.0


def _luminancia(hexcolor: str) -> float:
    canales = [int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    canales = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
               for c in canales]
    return 0.2126 * canales[0] + 0.7152 * canales[1] + 0.0722 * canales[2]


def contraste(a: str, b: str) -> float:
    mayor, menor = sorted([_luminancia(a), _luminancia(b)], reverse=True)
    return (mayor + 0.05) / (menor + 0.05)


TK = dict(re.findall(r"(--[\w-]+):\s*(#[0-9a-fA-F]{6})\b", TOKENS_CSS.read_text()))

# Si se añade un fondo a la paleta, va también aquí.
FONDOS = ["--fondo", "--banda", "--superficie"]

# Colores que se usan como TEXTO sobre cualquiera de los fondos.
TEXTOS = ["--tinta-1", "--tinta-2", "--primario", "--primario-hover", "--secundario",
          "--estado-disponible", "--estado-pocas", "--estado-sin", "--estado-sin-dato",
          "--exito", "--aviso", "--error"]

# Pares (relleno, texto que lleva encima).
RELLENOS = [("--primario", "--sobre-primario"),
            ("--primario-hover", "--sobre-primario"),
            ("--secundario", "--sobre-secundario"),
            ("--secundario-hover", "--sobre-secundario"),
            ("--estado-disponible", "--sobre-estado"),
            ("--estado-pocas", "--sobre-estado"),
            ("--estado-sin", "--sobre-estado"),
            ("--estado-sin-dato", "--sobre-estado")]

# Mensajes: texto de color sobre su fondo tenue.
MENSAJES = [("--exito", "--exito-fondo"), ("--aviso", "--aviso-fondo"),
            ("--error", "--error-fondo"), ("--tinta-1", "--exito-fondo"),
            ("--tinta-1", "--aviso-fondo"), ("--tinta-1", "--error-fondo")]

# Elementos no textuales que deben distinguirse de los fondos a 3:1.
NO_TEXTO = ["--linea-fuerte", "--foco", "--primario", "--estado-disponible",
            "--estado-pocas", "--estado-sin", "--estado-sin-dato", "--serie-1"]


def test_el_archivo_declara_todos_los_tokens_usados_aqui():
    usados = set(FONDOS + TEXTOS + NO_TEXTO) | {t for par in RELLENOS + MENSAJES for t in par}
    faltan = sorted(usados - set(TK))
    assert not faltan, f"tokens sin definir en tokens.css: {faltan}"


@pytest.mark.parametrize("fondo", FONDOS)
@pytest.mark.parametrize("texto", TEXTOS)
def test_texto_cumple_aa_sobre_todos_los_fondos(texto, fondo):
    ratio = contraste(TK[texto], TK[fondo])
    assert ratio >= UMBRAL_TEXTO, (
        f"{texto} {TK[texto]} sobre {fondo} {TK[fondo]} da {ratio:.2f}:1")


@pytest.mark.parametrize("relleno, texto", RELLENOS)
def test_texto_sobre_relleno_se_lee(relleno, texto):
    ratio = contraste(TK[relleno], TK[texto])
    assert ratio >= UMBRAL_TEXTO, (
        f"{texto} {TK[texto]} sobre {relleno} {TK[relleno]} da {ratio:.2f}:1")


@pytest.mark.parametrize("texto, fondo", MENSAJES)
def test_mensajes_se_leen(texto, fondo):
    ratio = contraste(TK[texto], TK[fondo])
    assert ratio >= UMBRAL_TEXTO, (
        f"{texto} {TK[texto]} sobre {fondo} {TK[fondo]} da {ratio:.2f}:1")


@pytest.mark.parametrize("fondo", FONDOS)
@pytest.mark.parametrize("elemento", NO_TEXTO)
def test_elementos_no_textuales_se_distinguen(elemento, fondo):
    ratio = contraste(TK[elemento], TK[fondo])
    assert ratio >= UMBRAL_NO_TEXTO, (
        f"{elemento} {TK[elemento]} sobre {fondo} {TK[fondo]} da {ratio:.2f}:1")


def test_la_serie_se_distingue_de_su_pista():
    """El medidor: el relleno debe separarse de su pista (mismo tono, otro paso)."""
    assert contraste(TK["--serie-1"], TK["--serie-1-pista"]) >= UMBRAL_NO_TEXTO
