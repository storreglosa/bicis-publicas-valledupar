<!-- Informe del agente verificador-normativo (Claude Code), 2026-10-09. Devuelto en la respuesta porque el agente no tenía herramienta de escritura; guardado tal cual por la sesión principal. Todas las citas se extrajeron con una herramienta de lectura web que entrega fragmentos de 125 caracteres o menos; en el Régimen Legal de Bogotá la herramienta reconstruyó las tildes que la página muestra dañadas. Jurídica debe cotejar con el Diario Oficial antes de transcribir cualquier cita en un acto. Las correcciones (a) se aplicaron en la política v1.0 antes de publicarla en la demo (ver el commit que la publica). -->

# Verificación normativa: política de tratamiento v1.0, Inscribirme.vue, Reglas.vue y pie de página (App.vue)

**Alcance.** Solo las citas y afirmaciones jurídicas nuevas o cambiadas desde la v0.3. No repito lo ya verificado en los informes del 2026-10-07 (A1–A10, B1–B8) y del 2026-10-08 (E1–E4, I-1 a I-9, P-1 a P-5, R-1 a R-5); cuando hace falta, los cito por su código. También cotejé la política con el código del sistema. Las decisiones de fondo que ya están anotadas para Jurídica (foto, representación) no las resuelvo.

## 0. Fuentes y límites

**Fuentes oficiales usadas:**
- Régimen Legal de Bogotá (sisjur): Ley 1581 de 2012, D. 1377 de 2013, Ley 153 de 1887, Ley 1712 de 2014 y Ley 23 de 1982.
- Normograma de la DIAN: Res. MinTIC 1519 de 2020 con su Anexo 2.
- Normograma de Cancillería: D. 1377 de 2013 (compilación actualizada al 30-09-2024) y D. 090 de 2018.

**Fuentes primarias de los proveedores** (no son normas; prueban hechos de §7): GitHub Docs (GitHub Pages; General Privacy Statement); Supabase (Privacy Policy; "Regional Invocations"); Cloudflare (Privacy Policy; Turnstile Privacy Policy; documentación de *siteverify*).

**Fuentes que no abrieron:** Función Pública (dominio rechazado o certificado inválido); SUIN-Juriscol (certificado); Colpensiones (rechazado); normograma MinTIC (rechazado); PDFs del Anexo 2 (sin texto extraíble); sitio de la Alcaldía de Valledupar (contenido dinámico); concepto MinTransporte radicado 20231341160041 (error 403).

**Fuentes secundarias:** prensa, vLex, DMS Jurídica y Ámbito Jurídico solo sirvieron para ubicar normas.

**Código cotejado:** `supabase/functions/preinscribir/nucleo.js`; migraciones `20261008150000_preinscripcion_y_retencion.sql`, `20261009100000_anonimizar_inactivos.sql`, `20261007120000_esquema.sql`, `20261007120300_funciones.sql`; `supabase/tareas_programadas.sql`; `docs/runbook.md` §3; `sitio.config.js`; `src/componentes/operador/CasillasAutorizacion.vue`.

## 1. Política v1.0

**V-1. §1 Responsable «Alcaldía de Valledupar, a través de la Secretaría de Tránsito y Transporte»; sin NIT ni teléfono.**
- NIT: omitirlo es CORRECTO. Ninguna norma lo exige: D. 1377, art. 13 num. 1 («Nombre o razón social, domicilio, dirección, correo electrónico y teléfono del Responsable.») y Ley 1581, art. 12 lit. d) («La identificación, dirección física o electrónica y teléfono del Responsable del Tratamiento.»).
- Teléfono: INCOMPLETO. Ambas normas lo exigen; en el lit. d) la alternativa «física o electrónica» es de la dirección y el teléfono va unido con «y». §10 no lo subsana.
- Persona jurídica: IMPRECISO (menor). Ley 1581, art. 3 lit. e) (Responsable: «Persona natural o jurídica, pública o privada…») y Ley 153 de 1887, art. 80 («…los Municipios… son personas jurídicas»): la persona jurídica es el Municipio; la Alcaldía es su administración. La v1.0 ya es coherente consigo misma (cierra A10).
- Riesgo: con datos reales, incumplimiento formal; por ser autoridad pública, Ley 1581, art. 23, parágrafo: la SIC remite a la Procuraduría (riesgo disciplinario).
- Corrección: el teléfono lo aporta la entidad; nombrar al Municipio lo decide Jurídica (b1, b2).

**V-2. §3 Foto «de la persona que presta junto con la bicicleta» y «No recogemos datos de salud, afiliación a seguridad social, origen étnico ni la ubicación de su celular».**
- Descripción de la foto: CORRECTA frente al sistema. Si es sensible y exigible sigue en I-5.
- La negación es IMPRECISA: Ley 1581, art. 5 (sensibles: «aquellos que revelen el origen racial o étnico», «los datos relativos a la salud»). Una foto puede revelar origen étnico; las novedades admiten `tipo = 'accidente'`, una descripción libre y una foto opcional, donde pueden quedar lesiones (datos de salud). Reglas.vue invita a reportar accidentes por correo.
- Omisión: §3 no menciona la foto de la novedad (carpeta `incidencias/`). Ley 1581, art. 12 lit. a).
- Corrección: mencionar la foto de la novedad (a2); datos de salud en novedades por accidente (b7).

**V-3. §3 «huella cifrada e irreversible durante dos (2) días» y §8 «se borra a los dos (2) días» — IMPRECISA en tres puntos.**
1. «Cifrada»: es un HMAC-SHA256 (resumen con clave), no cifrado.
2. «Irreversible»: el secreto es fijo y la fecha va en el mensaje; quien tenga el secreto puede recalcular la huella de las 2^32 direcciones IPv4. Es un dato seudonimizado, que para el Responsable sigue siendo dato personal (Ley 1581, art. 3 lit. c).
3. «Dos días»: la función solo borra al llegar una preinscripción nueva; ninguna tarea de pg_cron lo hace. Además los respaldos guardan `privado` hasta 12 meses (V-7).
- Hecho para §7: la Edge Function envía la IP a Cloudflare en `remoteip`, campo que según Cloudflare es opcional.
- Corrección: a1 y a9.

**V-4. §5 Ratificación en persona y carácter facultativo.**
- Carácter facultativo: CORRECTO (Ley 1581, art. 12 lit. b). Lo que añade la política («sin esos datos no es posible inscribir al menor») no choca con las normas verificadas: la prohibición del D. 1377, art. 6, se limita a datos sensibles (salvedad: la foto, I-5).
- Ratificación en persona: redacción coherente; el fondo sigue abierto (en línea no se verifica que quien marca sea el representante; D. 1377, art. 20 num. 3). Jurídica confirma (b5).
- Incoherencias con Inscribirme.vue: «autorizar en persona» frente a «ratificar la autorización en persona» (a14); la nota de lo voluntario está en el grupo del representante, no en el del menor (a15). El momento de la nota es correcto.

**V-5. §6 «(o su representante legal, si es menor de edad; D. 1377 de 2013, art. 20)» — CORRECTA** (P-4, I-2). Opcional: añadir «D. 1074 de 2015, art. 2.2.2.25.4.1» (a16).

**V-6. §7 Tres encargados con servidores en EE. UU. y «La transmisión… se realiza en los términos del artículo 25» — IMPRECISA (Supabase), INCORRECTA en la calificación (Cloudflare en parte; GitHub) y NO VERIFICABLE (art. 25).**
- Definiciones: Ley 1581, art. 3 lit. d) (Encargado: trata «por cuenta del Responsable»); D. 1377, art. 3 num. 4 (transferencia: a un receptor que «a su vez es Responsable») y num. 5 (transmisión: «por el Encargado por cuenta del Responsable»); D. 1377, art. 24; Ley 1581, art. 26.
- Supabase: encargado y transmisión CORRECTOS («We use such Customer Data primarily as a processor»). Ubicación IMPRECISA: las Edge Functions «automatically execute in the region closest to the user», y la lista incluye sa-east-1 (São Paulo). §7 no dice que Supabase procesa el formulario y la IP.
- Cloudflare Turnstile: encargado solo en parte; es «data controller of Signals that we process to improve Turnstile's bot detection capabilities». Como el sistema le envía la IP (`remoteip`), esa parte se parece a una transferencia. Ubicación: «primarily… the United States and the European Economic Area», con acceso «from around the world».
- GitHub Pages: no es encargado. Registra la IP de los visitantes «for security purposes» como «Data Controller», y la recibe directamente del navegador. Ubicación: «your local region, the United States, and other countries».
- Frase sobre el art. 25: NO VERIFICABLE y probablemente falsa para dos de los tres proveedores (el art. 25 exige un contrato que «suscriba el Responsable»; con Cloudflare y GitHub no consta ninguno; las cuentas no parecen institucionales).
- §4 («no se comparten con terceros distintos de los encargados») no se sostiene si Cloudflare y GitHub actúan en parte como responsables.
- EE. UU. está en la lista de la SIC (A7): el art. 26 no prohíbe la transferencia; falta decidir cómo calificarla e informarla (b3). Matizar la ubicación (a4).

**V-7. §8 Conservación — cotejo con el código** (marco: D. 1377, art. 11, tiempo «razonable y necesario», supresión cumplida la finalidad, procedimientos documentados).

| Afirmación de la política | Lo que hace el sistema | Veredicto |
|---|---|---|
| Fotos sin novedad o anuladas: «a los siete (7) días» | 7 días desde `devuelto_en` o desde `cerrado_en` | CORRECTA; precisar el punto de partida (a5) |
| Fotos con novedad, del último préstamo de una bici averiada o extraviada, o conservadas para un reclamo: «mientras se resuelve el caso» | Se excluyen de la purga sin límite; ningún proceso las borra al cerrar el caso | **INCORRECTA**: promete un límite que no existe (a6, b6) |
| (no aparece) | Las fotos de la novedad (`incidencias/`) no se purgan nunca | OMISIÓN (a2, b6) |
| Preinscripciones: anonimizadas a los 90 días; «se conservan solo la edad declarada y el sexo / género» | Reemplaza la identidad y la sal; conserva además fechas, origen y la fila de autorización | CORRECTA en lo esencial; «solo» levemente inexacto (P-3, b6) |
| Inactivos: anonimizados a los 24 meses | Con excepciones (préstamo activo, sanción vigente, novedad abierta) | IMPRECISA por omisión de las excepciones (a7) |
| Huella de la IP: «se borra a los dos (2) días» | Solo al entrar una preinscripción nueva | IMPRECISA (a9) |
| Respaldos: «hasta doce (12) meses» | 8 semanales y uno mensual por 12 meses, con datos anteriores a la anonimización | CORRECTA en el plazo; IMPRECISA por omisión (a8, b6) |

No verificado: si el registro de préstamos es documento de archivo sujeto a tablas de retención (b6).

**V-8. §10 Canal: CORRECTA en lo que cubre.** Cierra A10 (área responsable) y aplica bien P-2. La falta de teléfono es de V-1.

**V-9. §11 Vigencia — IMPRECISA; en manos de Jurídica.** D. 1377, art. 13 num. 6 («Fecha de entrada en vigencia… y período de vigencia de la base de datos.»). «Rige desde» afirma la vigencia de un documento no aprobado (Res. 1519, Anexo 2, num. 2.3, pide publicar «documentos aprobados»; en la demo lo mitiga la franja DEMO). «Mientras funcione el programa» es término determinable, no período. «En todo caso, solo durante los plazos del numeral 8» no es cierto mientras haya fotos sin plazo (a10). Los cambios sustanciales deben comunicarse «de una manera eficiente» (art. 13, inciso final).

**V-10. Textos de autorización.**
- Tratamiento: «mis datos personales (o los del menor que represento)» — IMPRECISA: el representante también entrega sus datos; con «o» parece cubrir solo los del menor (a11).
- Foto: «se elimina… a los siete (7) días… sin novedad» — IMPRECISA por omisión de los casos en que se conserva (a12).
- Constancia del menor: CORRECTA en el fondo, pero el punto usa otro texto (tercera persona) y ninguno se lee de la política versionada (D. 1377, art. 8) (a13).

## 2. Inscribirme.vue

**V-11.** Los textos nuevos están evaluados en V-4 y V-10. Siguen sin cambio: «(necesaria para prestar)» (I-5) e «Inscribir a otra persona» (I-4).

## 3. Reglas.vue

**V-12. «Usa las ciclorrutas donde existan; fuera de ellas, circula por la calzada. Nunca por los andenes ni por las vías exclusivas del transporte público.»**
- «Nunca por los andenes»: CORRECTA (art. 68, par. 1). «Ni por las vías exclusivas del transporte público»: CORRECTA (art. 94; art. 95 num. 2).
- «Usa las ciclorrutas donde existan»: NO VERIFICABLE como norma (ningún texto verificado la contiene; concepto MinTransporte 20231341160041 no legible; Ley 2486 sin texto). Además es una regla de posición, contra el comentario de R-4 («no se publica ninguna versión»).
- Corrección: b9.

**V-13.** El aviso por correo no hace afirmaciones jurídicas (ver V-2 sobre datos de salud).

## 4. App.vue: pie de página frente a la Res. MinTIC 1519 de 2020

Aplica a «Toda entidad pública… municipal» (Res. 1519, art. 2; Ley 1712, art. 5 lit. a). Si este sitio en `github.io` debe cumplir todo el Anexo 2 lo deciden Jurídica y la oficina TIC (b10).

**V-14. El pie NO CUMPLE el mínimo del Anexo 2, si el sitio está obligado:**

| Exigencia | Pie actual |
|---|---|
| 2.2.1 ítem 1: imagen del Portal Único del Estado y logo marca país CO | No está |
| 2.2.1 ítem 2: nombre de la entidad y una dirección con municipio | **Cumple** |
| 2.2.1 ítem 3: vínculo a redes sociales | **Cumple** |
| 2.2.1 ítem 4: conmutador, línea gratuita o de servicio, línea anticorrupción, canales físicos y electrónicos, correo de notificaciones judiciales, mapa del sitio, enlaces a las políticas | Solo canales físicos y electrónicos |
| 2.1.1: barra superior GOV.CO | No está |
| 2.3: publicar «los documentos aprobados» | La política no está aprobada aún (V-9) |
| 2.3.1: términos y condiciones con contenido mínimo | INEXACTO: el enlace lleva a «Reglas de uso» (a17, b10) |
| 2.3.2: política de tratamiento de datos | Enlazada |
| 2.3.3: política de derechos de autor | No está; el «©» es un aviso (D-20) |

«©… Alcaldía de Valledupar»: coherente con la Ley 23 de 1982, art. 91, si lo crearon servidores en ejercicio de su cargo (la persona jurídica es el Municipio, V-1). Contratistas y herramientas externas: no verificado (b10).

Accesibilidad (Res. 1519, art. 3: WCAG 2.1 AA): NO VERIFICABLE con una lectura estática.

## 5. Fuera del texto, para Jurídica

**V-15. RNBD (verificado).** D. 090 de 2018, art. 1 (modifica el D. 1074, art. 2.2.2.26.1.2): se inscriben las bases de «b) Personas jurídicas de naturaleza pública»; art. 2: las creadas después de los plazos «deberán inscribirse dentro de los dos (2) meses siguientes contados a partir de su creación». Aplica a la base de producción con datos reales.

**V-16. Política general de la Alcaldía: NO VERIFICABLE en línea.** Jurídica debe verificar si existe y armonizar.

## 6. (a) Correcciones aplicables ya, sin decisión de fondo

1. a1. §3: quitar «cifrada e irreversible»; es una huella con clave secreta (HMAC), un dato seudonimizado.
2. a2. §3 y §8: mencionar la foto opcional de la novedad y que hoy no se elimina.
3. a3. §7: Supabase también procesa el formulario y la IP en sus funciones.
4. a4. §7: matizar «servidores en los Estados Unidos» según cada proveedor.
5. a5. §8 y autorización de la foto: «a los siete (7) días de la devolución o de la anulación».
6. a6. §8: quitar «mientras se resuelve el caso», o implementar el borrado al cerrar el caso.
7. a7. §8: añadir las excepciones de los 24 meses.
8. a8. §8: los respaldos contienen los datos de su fecha, incluidos los luego anonimizados, hasta que rotan.
9. a9. Borrar la huella de IP en la tarea diaria, no solo con la siguiente preinscripción; si no, no afirmar el plazo.
10. a10. §11: quitar «en todo caso, solo durante los plazos de conservación del numeral 8».
11. a11. Autorización: «mis datos personales y, si es el caso, los del menor que represento».
12. a12. Autorización de la foto: añadir que se conserva en los casos del numeral 8.
13. a13. Constancia del menor: un solo texto en el formulario y en el punto (idealmente leído de la política versionada).
14. a14. Inscribirme.vue: «ratificar la autorización en persona».
15. a15. Inscribirme.vue: aclarar que lo voluntario son los datos del menor.
16. a16. §6: añadir «D. 1074 de 2015, art. 2.2.2.25.4.1» (opcional).
17. a17. App.vue: rotular el enlace como «Reglas de uso».
18. a18. Fijar la región us-east-1 en la llamada a la Edge Function y comprobarlo con `x-sb-edge-region`; el envío de `remoteip` a Cloudflare es opcional.

## 7. (b) Puntos que debe decidir Jurídica (o aportar la entidad)

1. b1. Teléfono del responsable (Ley 1581, art. 12 lit. d; D. 1377, art. 13 num. 1; Res. 1519, Anexo 2, 2.2.1 ítem 4).
2. b2. Si se nombra al «Municipio de Valledupar» como persona jurídica responsable.
3. b3. Calificación de cada proveedor en §7: Cloudflare (encargado y, para mejorar su detección, responsable: transferencia a informar); GitHub Pages (responsable de sus registros, recolección directa); armonización con §4.
4. b4. Contratos del art. 25: quién los suscribe (cuentas no institucionales), si el DPA de Supabase cumple (A8), si se mantiene la frase.
5. b5. Marca en línea del menor: confirmar autorización en línea más ratificación en persona, y el tratamiento de hasta 90 días sobre una autorización sin verificar.
6. b6. Plazos: confirmar 90 días y 24 meses; plazo para fotos con novedad y fotos de la novedad; si anonimizar equivale a suprimir; respaldos ante una supresión; normativa archivística.
7. b7. Datos de salud en novedades por accidente y en reportes por correo; «No recogemos… origen étnico» frente a la foto (Ley 1581, art. 5).
8. b8. Vigencia: si «mientras funcione el programa» basta; qué acto adopta la política y qué fecha se publica; cómo comunicar cambios «de una manera eficiente».
9. b9. Línea de ciclorrutas: fundamento o presentarla como recomendación, coherente con R-4.
10. b10. Res. 1519: si el sitio está sujeto al Anexo 2; aprobar términos y condiciones y política de derechos de autor; titularidad (Ley 23 de 1982, art. 91) y licencia (D-20).
11. b11. Inscribir la base de producción en el RNBD y armonizar con la política general de la Alcaldía, si existe.
12. Sin cambio: I-5 (foto), I-2 (representación conjunta y acreditación), I-4 (inscripción de adultos por terceros), R-4 (posición del ciclista).

## 8. Veredicto

- Política v1.0: APTA CON CORRECCIONES para la DEMO con datos ficticios (a1–a13, a16; D-27 vigente). NO APTA con datos reales mientras sigan abiertos b1, b3, b4, b6, b8 y el concepto sobre la foto (I-5).
- Inscribirme.vue: APTA CON CORRECCIONES para la demo (a14, a15).
- Reglas.vue: APTA CON CORRECCIONES; «Usa las ciclorrutas donde existan» no debe figurar como norma hasta b9.
- App.vue (pie): APTA CON CORRECCIONES para la demo (a17); no cumple el mínimo del Anexo 2 si el sitio está obligado (b10).

## Fuentes consultadas

- Ley 1581 de 2012: https://www.alcaldiabogota.gov.co/sisjur/normas/Norma1.jsp?i=49981
- D. 1377 de 2013: https://www.alcaldiabogota.gov.co/sisjur/normas/Norma1.jsp?i=53646 y https://cancilleria.gov.co/sites/default/files/Normograma/docs/decreto_1377_2013.htm
- Ley 153 de 1887: https://www.alcaldiabogota.gov.co/sisjur/normas/Norma1.jsp?i=15805
- Ley 1712 de 2014: https://www.alcaldiabogota.gov.co/sisjur/normas/Norma1.jsp?i=56882
- Ley 23 de 1982: https://www.alcaldiabogota.gov.co/sisjur/normas/Norma1.jsp?i=3431
- Res. MinTIC 1519 de 2020 y Anexo 2: https://normograma.dian.gov.co/dian/compilacion/docs/resolucion_mintic_1519_2020.htm
- D. 090 de 2018: https://cancilleria.gov.co/sites/default/files/Normograma/docs/decreto_0090_2018.htm
- Proveedores: https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages · https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement · https://supabase.com/privacy · https://supabase.com/docs/guides/functions/regional-invocation · https://www.cloudflare.com/turnstile-privacy-policy/ · https://www.cloudflare.com/privacypolicy/ · https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
- Solo para ubicar: concepto MinTransporte 20231341160041 (Ámbito Jurídico, error 403).
