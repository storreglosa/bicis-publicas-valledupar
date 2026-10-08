<!-- Informe del agente verificador-normativo (Claude Code). Devuelto en la respuesta porque el agente no tenía herramienta de escritura; guardar tal cual. El reloj del entorno marcaba 2026-10-07; el nombre del archivo (2026-10-08) lo fijó la sesión principal. Todas las citas se extrajeron con una herramienta de lectura web: Jurídica debe cotejarlas con el Diario Oficial antes de transcribirlas en un acto. -->

# Verificación normativa — Preinscripción pública (Inscribirme.vue) y pendientes de la política v0.2 y de Reglas.vue

Alcance: citas y afirmaciones con implicación jurídica. No es redacción. No repito lo que el informe del 2026-10-07 ya verificó y que no cambió: A1, A2, A4, A7, A8, B3, B5, B6 y B8.

## 0. Fuentes y límites

- **Fuentes que no se pudieron abrir:** Función Pública (Gestor Normativo), Secretaría del Senado, SUIN-Juriscol, Régimen Legal de Bogotá y www.cancilleria.gov.co. La herramienta de lectura las rechazó ("no se pudo verificar que el dominio sea seguro"). Por eso no doy URL verificadas de esas tres fuentes oficiales. Jurídica debe cotejar ahí.
- **Fuentes oficiales usadas:**
  - Normograma de Colpensiones (compilación de Avance Jurídico).
  - Normograma de Cancillería (dirección sin "www").
  - Portal normativo Eureka de la ANLA.
  - Para Turnstile, la política de privacidad publicada por Cloudflare, que es la fuente primaria del proveedor y no una norma.
- **Límite de la herramienta:** cada cita literal se entrega en fragmentos de 125 caracteres o menos. Las citas de este informe unen fragmentos consecutivos. "[…]" marca una omisión.
- **Fechas de las compilaciones de la Ley 769:** la de Colpensiones se actualizó por última vez el **31-03-2018** y la de Cancillería el **31-07-2019**. Ninguna de las dos refleja las Leyes 2486 de 2025 ni 2635 de 2026.
- **Lo que no pude obtener:**
  - El texto de la Ley 2635 de 2026 (el sitio que aloja la copia no resolvió DNS).
  - El texto completo de la Ley 2486 de 2025 (solo un resumen oficial de la ANLA).
  - El RESUELVE dentro del texto de la C-748 de 2011 en la relatoría (la página llega truncada).
  - Los conceptos del MinTransporte sobre los arts. 94 y 95 (no los reintenté).
- Las fuentes secundarias (prensa, vLex, un PDF alojado por un despacho de abogados) solo sirvieron para ubicar normas. No las uso como evidencia.

## 1. Correcciones al informe del 2026-10-07

**E1. B2/B4: "art. 94 sin modificaciones registradas en el normograma de Colpensiones" — límite no declarado**
- Esa compilación se actualizó por última vez el 31-03-2018, así que no prueba que el art. 94 siga sin modificar después de esa fecha.
- Hoy es **no verificable** si las Leyes 2486 de 2025 o 2635 de 2026 tocaron los arts. 94 o 95.
- Fuente: https://normativa.colpensiones.gov.co/colpens/docs/ley_0769_2002_pr002.htm ("Última actualización: 31 de marzo de 2018").

**E2. B1: numeración de la Ley 2486 de 2025 — discrepancia sin resolver**
- El informe anterior afirmó que el art. 18 contiene "La presente ley rige a partir de su promulgación y deroga los artículos 14 y 17 de la Ley 1811 de 2016". El resumen oficial de la ANLA ubica ese texto en el **art. 16**, igual que la nota del Régimen Legal de Bogotá que el informe anterior descartó.
- El mismo resumen indica que el art. 5 modifica el **art. 63** de la Ley 769 ("Respeto a los derechos de los peatones, ciclistas y usuarios de vehículos eléctricos livianos"). No menciona el art. 60, y por tanto no confirma ni desmiente que el art. 6 modifique el art. 60.
- No afecta el texto público, porque Reglas.vue no cita números de artículo de la Ley 2486. Jurídica debe resolverlo en el D.O. 53.183 o en SUIN (https://www.suin-juriscol.gov.co/viewDocument.asp?ruta=Leyes/30055263, enlace que da la ANLA; no pude abrirlo).
- Fuente: https://www.anla.gov.co/wanla/eureka/normativa/leyes/ley-2486-de-2025-vehiculos-electricos-livianos-de-movilidad-personal-urbana-como-alternativas-de-movilidad-sostenible

**E3. A9: inciso de la Ley 1581, art. 14 que quedó pendiente — RESUELTO**
- Texto: "Cuando no fuere posible atender la consulta dentro de dicho término, se informará al interesado, expresando los motivos de la demora y señalando la fecha en que se atenderá su consulta, la cual en ningún caso podrá superar los cinco (5) días hábiles siguientes al vencimiento del primer término."
- La política v0.2, §10 (consultas), es coherente con este texto.

**E4. A10(c): redacción ambigua del propio informe anterior**
- El informe anterior escribió: el requerimiento para completar un reclamo "dentro de los cinco (5) días siguientes". Esa redacción ambigua pasó a la política v0.2 con un sentido equivocado (ver P-2).

## 2. Inscribirme.vue (página nueva)

**I-1. "el operador mira tu documento original (no lo retiene)" — l. 132–133; también l. 113–115, 124, 137–138 y 167–168 — CORRECTA**
- Norma: Decreto Ley 2150 de 1995, art. 18, modificado por la Ley 962 de 2005, art. 23 (verificado en A4 del informe anterior; no lo reconsulté).
- Texto: "Si se exige la identificación de una persona, ella cumplirá la obligación mediante la exhibición del correspondiente documento."
- Corrección: ninguna.
- No verificado: si la exigencia de "documento original" excluye la cédula digital. Si Jurídica quiere precisarlo, debe consultar la reglamentación de la Registraduría.

**I-2. Quién autoriza por el menor — CORRECTA en el fondo; IMPRECISA en la terminología; queda un vacío sobre la acreditación**
- **Textos:**
  - "Eres menor de edad: tu madre, padre o representante legal debe llenar esta parte contigo y acompañarte al punto la primera vez, con su documento original." (l. 167–168)
  - Opciones de parentesco: Madre / Padre / Representante legal (l. 20).
  - La palabra "Acudiente" en l. 114, 166, 186 y 192.
- **D. 1377 de 2013, art. 12** (D. 1074, art. 2.2.2.25.2.9): "el representante legal del niño, niña o adolescente otorgará la autorización […]".
- **Código Civil, art. 62** (modificado por el D. 2820 de 1974, art. 1; ordinal 1 por el D. 772 de 1975; ordinal 2 por la Ley 1996 de 2019, art. 59):
  - "Las personas incapaces de celebrar negocios serán representadas:"
  - "1. […] Por los padres, quienes ejercerán conjuntamente la patria potestad sobre sus hijos menores de 21 años. Si falta uno de los padres la representación legal será ejercida por el otro."
  - "2. […] Por el tutor o curador que ejerciere la guarda sobre menores de edad no sometidos a patria potestad."
  - El límite de edad es hoy 18 años: Ley 27 de 1977, art. 1.
- **Código Civil, art. 307** (D. 2820 de 1974, art. 40): "Los derechos de administración de los bienes, el usufructo legal y la representación extrajudicial del hijo de familia serán ejercidos conjuntamente por el padre y la madre. Lo anterior no obsta para que uno de los padres delegue por escrito al otro, total o parcialmente, dicha administración o representación."
- **D. 1377, art. 20** (D. 1074, art. 2.2.2.25.4.1), al que remite el art. 7 ("de los titulares o de quien se encuentre legitimado de conformidad con lo establecido en el artículo 20"):
  - num. 3: "Por el representante y/o apoderado del Titular, previa acreditación de la representación o apoderamiento."
  - inciso final: "Los derechos de los niños, niñas o adolescentes se ejercerán por las personas que estén facultadas para representarlos."
- **Análisis:**
  - "Madre, padre o representante legal" es correcto: los padres son representantes legales, y "representante legal" cubre al tutor o curador.
  - Hay tres puntos abiertos:
    - (a) "Acudiente" no es una categoría legal y en el uso común incluye a abuelos, tíos o hermanos mayores, que no están legitimados.
    - (b) El art. 307 CC dice que la representación extrajudicial es conjunta. Que baste uno de los padres es una decisión de Jurídica.
    - (c) El art. 20 num. 3 exige acreditar la representación. El documento de identidad del adulto prueba su identidad, no su parentesco ni su calidad de guardador. Lo segundo se probaría, por ejemplo, con el registro civil del menor o con el acto que designó al guardador; eso lo define Jurídica.
- **Riesgo:** la autorización la otorga una persona no legitimada, y la entidad no puede probar la representación.
- **Corrección:** usar un solo término (p. ej., "representante legal: madre, padre, tutor o curador") o definir "acudiente" en la propia página. El requisito de acreditación lo decide Jurídica.

**I-3. "Como acudiente, declaro que escuché la opinión del menor antes de autorizar y la tuve en cuenta." — l. 191–192 — CORRECTA (con una incoherencia de versión)**
- **D. 1377, art. 12:** "[…] otorgará la autorización previo ejercicio del menor de su derecho a ser escuchado, opinión que será valorada teniendo en cuenta la madurez, autonomía y capacidad para entender el asunto."
- **Ley 1098 de 2006, art. 26, inciso 2:** "En toda actuación administrativa, judicial o de cualquier otra naturaleza en que estén involucrados, […] tendrán derecho a ser escuchados y sus opiniones deberán ser tenidas en cuenta." (D.O. 46.446; no aparecen notas de modificación).
- **C-748 de 2011** (según el normograma de Colpensiones): "la opinión del menor de 18 años siempre se debe tener en cuenta para el tratamiento de sus datos personales."
- **Incoherencia:**
  - La política v0.2 (l. 152–155) fija otro texto: "Declaro que soy [madre / padre / representante legal] del menor, que escuché su opinión […]".
  - El texto del formulario está fijo en el código. No viene de la política versionada, como sí ocurre con `texto_autorizacion`.
  - El D. 1377, art. 8, exige: "Los Responsables deberán conservar prueba de la autorización otorgada por los Titulares […]". Hoy la constancia que acepta el acudiente no queda atada a la versión aprobada.
- **Corrección:** que el texto de la casilla sea el mismo que apruebe Jurídica y que quede versionado con la política.

**I-4. Casillas sin marcar y "Léela y marca solo si estás de acuerdo (la marca tu acudiente)." — l. 28 y 186–188 — CORRECTA en la forma; INCOHERENTE con la política §5 y con D-21**
- **D. 1377, art. 7** (D. 1074, art. 2.2.2.25.2.4): "Se entenderá que la autorización cumple con estos requisitos cuando se manifieste (i) por escrito, (ii) de forma oral o (iii) mediante conductas inequívocas del titular […]. En ningún caso el silencio podrá asimilarse a una conducta inequívoca." Las casillas sin marcar por defecto cumplen.
- **Ley 1581, art. 9:** "en el Tratamiento se requiere la autorización previa e informada del Titular, la cual deberá ser obtenida por cualquier medio que pueda ser objeto de consulta posterior."
- **D. 1377, art. 5:** "[…] solicitar, a más tardar en el momento de la recolección de sus datos, la autorización del Titular […]".
- **Incoherencia, menores:**
  - La política §5 dice que la autorización del menor se otorga "en persona, en un punto de préstamo".
  - La decisión D-21 dice que "la autorización web del acudiente no basta".
  - Pero el formulario pide marcarla en línea y guarda desde ese momento los datos del menor y del acudiente (preinscripción).
  - Si la marca web no es autorización, los datos del menor se tratan sin autorización previa durante la preinscripción. Si sí lo es, la política describe mal cuándo se otorga.
- **Incoherencia, adultos:**
  - El botón "Inscribir a otra persona" (l. 118 y 127) invita a que una persona inscriba a otra.
  - La autorización está redactada en primera persona ("tratar mis datos personales").
  - Si un tercero marca por otro adulto, esa autorización no es del titular (Ley 1581, art. 9; D. 1377, art. 20).
- **Corrección:** decisión de Jurídica sobre la naturaleza de la marca en línea (ver §6).

**I-5. Foto: "(necesaria para prestar)" (l. 190) y "la autorización de la foto (sin ella no se puede prestar)" (l. 56) — NO VERIFICABLE hasta el concepto sobre la foto; RIESGO ALTO**
- **D. 1377, art. 6** (D. 1074, art. 2.2.2.25.2.3):
  - num. 1: "Informar al titular que por tratarse de datos sensibles no está obligado a autorizar su Tratamiento."
  - inciso final: "Ninguna actividad podrá condicionarse a que el Titular suministre datos personales sensibles."
- Si Jurídica concluye que la foto es un dato biométrico (Ley 1581, art. 5, verificado en A3), estos textos públicos materializan justamente la conducta que prohíbe el art. 6.
- **Agravantes:**
  - La política v0.2 presenta la autorización de la foto "sin marcar por defecto" y no como obligatoria. El formulario la declara necesaria cuando el parámetro está activo.
  - En el caso de menores se suman los dos regímenes: dato sensible y dato de un menor.
- **Riesgo:** publicar como requisito del servicio la entrega de un dato que podría ser sensible.
- **Corrección:** no publicar con `evidencia.foto_persona_obligatoria` activo mientras no exista el concepto (D-10 ya lo prevé). La redacción depende del concepto.

**I-6. Lo que hay que informar al pedir la autorización — INCOMPLETO**
- **Ley 1581, art. 12:**
  - lit. b): "El carácter facultativo de la respuesta a las preguntas que le sean hechas, cuando estas versen sobre datos sensibles o sobre los datos de las niñas, niños y adolescentes;"
  - lit. d): "La identificación, dirección física o electrónica y teléfono del Responsable del Tratamiento."
  - parágrafo: el responsable debe conservar prueba de haber cumplido este deber.
- **Estado:**
  - Ni el formulario ni la política informan que responder sobre los datos del menor es facultativo. Para menores, todos los campos son obligatorios en el formulario (l. 42–56).
  - El lit. d) depende de los marcadores pendientes de la política (§1 y texto de autorización).
- **Riesgo:** una autorización sin la información mínima de ley.
- **Corrección:** Jurídica define cómo informar el carácter facultativo, dado que el servicio necesita esos datos (§6). Mientras `texto_autorizacion` tenga marcadores, el formulario no puede salir a producción.

**I-7. Umbral de edad (`esMenor`: edad < 18 o tarjeta de identidad; aviso "Eres menor de edad") — l. 39 y 167 — CORRECTA**
- Ley 27 de 1977, art. 1: "Para todos los efectos legales llámase mayor de edad, o simplemente mayor, a quien ha cumplido diez y ocho (18) años." (D.O. 34.902).
- Ley 1098, art. 3: niño o niña, "entre los 0 y los 12 años"; adolescente, "entre 12 y 18 años de edad."

**I-8. "Ese documento ya está inscrito." — l. 123; el comentario del código (l. 5) dice que la función "nunca devuelve datos" — IMPRECISO**
- **Ley 1581, art. 3 lit. c):** dato personal es "Cualquier información vinculada o que pueda asociarse a una o varias personas naturales determinadas o determinables".
- **Art. 4 lit. f):** "Los datos personales, salvo la información pública, no podrán estar disponibles en Internet u otros medios de divulgación o comunicación masiva, salvo que el acceso sea técnicamente controlable para brindar un conocimiento restringido sólo a los Titulares o terceros autorizados conforme a la presente ley;"
- **Análisis:**
  - Cualquiera que escriba un número de documento sabe si esa persona está inscrita en un programa municipal, y eso incluye tarjetas de identidad de menores.
  - Es información asociada a una persona determinable. Turnstile y el límite de intentos la mitigan, pero no la eliminan.
- **Riesgo:** medio-bajo; queda en manos de Jurídica y del equipo técnico.
- **Corrección:** decisión de diseño. Una opción a evaluar es un mensaje único para los dos casos.

**I-9. Verificación anti-robots (Cloudflare Turnstile, `src/componentes/publico/Turnstile.vue`) frente a la política — INCOHERENTE**
- **Política:**
  - §3: "recogemos únicamente […]"
  - §4, l. 57–58: "Los datos no se venden, no se usan con fines comerciales ni se comparten con terceros distintos del encargado indicado en el numeral 7" (Supabase).
- **Fuente del proveedor** (https://www.cloudflare.com/turnstile-privacy-policy/):
  - Turnstile procesa: "client IP address, TLS Fingerprint, User-Agent Header and Sitekey and associated origin".
  - Como encargado: "Cloudflare is a data processor of Signals that we process to provide the Turnstile service to our customers".
  - Como responsable: "Cloudflare is a data controller of Signals that we process to improve Turnstile's bot detection capabilities."
  - Sobre identificación: "Cloudflare does not have the ability to directly identify any individuals".
- **Análisis:**
  - Un segundo proveedor extranjero recibe datos técnicos de quien diligencia el formulario y los usa en parte para fines propios.
  - Jurídica debe decidir si esos datos son personales a la luz del art. 3 lit. c). Si lo son, la política omite a Cloudflare en §3, §4 y §7.
  - No revisé otros proveedores de la web pública, como el hosting.
- **Corrección:** decisión de Jurídica (§6).

## 3. Política v0.2 (cambios desde v0.1 y pendientes)

**P-1. §5: "(Ley 1581 de 2012, art. 7, en la interpretación de la Corte Constitucional, sentencia C-748 de 2011; Decreto 1377 de 2013, art. 12; D. 1074 de 2015, art. 2.2.2.25.2.9)" — l. 60–68 — CORRECTA; el pendiente queda resuelto en parte**
- **Resolutivo**, sección "Decisión", numeral Segundo: "Declarar EXEQUIBLES los artículos 1, 2, 3, 4, 5, 7, 9, 10, […] del proyecto de ley, de conformidad con lo expuesto en la parte motiva de esta providencia." No hay "en el entendido".
- **Precisiones sobre el art. 7:** "El artículo 7, que hace referencia a los datos de los niños, niñas y adolescentes, se declaró exequible con las siguientes precisiones: la Sala indicó que el inciso segundo debe interpretarse en el sentido de que el tratamiento de los datos personales de los menores de 18 años, al margen de su naturaleza, pueden ser objeto de tratamiento, siempre y cuando no se ponga en riesgo la prevalencia de sus derechos fundamentales e inequívocamente responda a la realización del principio de su interés superior. Además, se señaló que la opinión del menor de 18 años siempre se debe tener en cuenta para el tratamiento de sus datos personales."
- **Límite:** la página mezcla la ficha de la sentencia con el Comunicado de Prensa No. 40 de 5 y 6 de octubre de 2011. Por la estructura ("1. Norma revisada / Decisión / Fundamentos"), estos apartes parecen del comunicado y no del texto de la sentencia. Jurídica debe confirmarlos en la sentencia.
- La redacción de §5 coincide con estas precisiones y con el D. 1377, art. 12. Se eliminó el requisito del "acuerdo del menor" (A5).
- Quedan abiertos los puntos de I-2 (representación conjunta y acreditación) y de I-4 ("en persona" frente a la marca web).
- §5 también mezcla la autorización para *usar* el sistema con la autorización de *datos*. Jurídica decide si la primera necesita otro soporte (CC, art. 62: "Las personas incapaces de celebrar negocios serán representadas […]").
- Fuentes:
  - https://normativa.colpensiones.gov.co/colpens/docs/sc748_11.htm
  - https://www.corteconstitucional.gov.co/relatoria/2011/C-748-11.htm (truncada)

**P-2. §10: "Si el reclamo está incompleto, se le pedirá completarlo dentro de los cinco (5) días siguientes; si pasan dos (2) meses sin que lo complete, se entiende que desistió." — l. 121–123 — IMPRECISA (error nuevo en v0.2)**
- Ley 1581, art. 15 num. 1: "Si el reclamo resulta incompleto, se requerirá al interesado dentro de los cinco (5) días siguientes a la recepción del reclamo para que subsane las fallas. Transcurridos dos (2) meses desde la fecha del requerimiento, sin que el solicitante presente la información requerida, se entenderá que ha desistido del reclamo."
- Los 5 días son el plazo de la **entidad** para requerir. El titular tiene **2 meses desde el requerimiento**. Como está escrita, la política puede leerse como que el titular tiene 5 días.
- **Riesgo:** inducir al titular a creer que tiene un plazo menor que el legal.
- **Corrección evidente:** "…se le pedirá completarlo dentro de los cinco (5) días siguientes a su recepción; si pasan dos (2) meses desde ese requerimiento sin que lo complete, se entiende que desistió."

**P-3. §8: "Las preinscripciones que nunca se validan en un punto se eliminan a los [N] días." — l. 101 — INCOHERENTE con lo que hace el sistema**
- La migración `supabase/migrations/20261008150000_preinscripcion_y_retencion.sql` (l. 237–305) dice: "Preinscripciones nunca validadas: se anonimizan (nada se borra)". Conserva edad y sexo o género. Al acudiente lo anonimiza solo si ya no responde por nadie más.
- D. 1377, art. 13 num. 2 (verificado en A10): la política debe describir el "Tratamiento al cual serán sometidos los datos".
- **Corrección:** que la política diga lo que el sistema hace. Jurídica decide si anonimizar equivale a lo que se promete como supresión.

**P-4. §6: "(o su representante, si es menor de edad)" — l. 72 — CORRECTA**
- D. 1377, art. 20, inciso final (citado en I-2). Se puede añadir la cita.
- El resto de §6 coincide con A6 corregido: D. 1377, art. 9 y Ley 1581, art. 16.

**P-5. §3 y §4 frente a Turnstile** — ver I-9.

## 4. Reglas.vue

**R-1. Línea de fuentes: "Código Nacional de Tránsito (Ley 769 de 2002, arts. 60 parágrafo 3, 94 y 95), con las modificaciones de la Ley 1811 de 2016, la Ley 2486 de 2025 y la Ley 2635 de 2026." — l. 76–77 — CORRECTA en lo que se pudo verificar**
- Aplica la corrección de B1.
- El art. 95 vigente sigue con "<Artículo modificado por el artículo 9 de la Ley 1811 de 2016 […]>".
- No verificable: si las Leyes 2486 o 2635 tocan los arts. 94 o 95 (E1). La línea no cita números de artículo de esas leyes, así que la discrepancia E2 no la afecta.
- Fuente: https://normativa.colpensiones.gov.co/colpens/docs/ley_0769_2002_pr002.htm

**R-2. "Circula por la calzada: nunca por los andenes ni por los carriles exclusivos del transporte público." — l. 84 (texto nuevo) — IMPRECISA (menor)**
- **"Nunca por los andenes": CORRECTO.**
  - Art. 68, par. 1: "En todo caso, estará prohibido transitar por los andenes o aceras, o puentes de uso exclusivo para los peatones."
  - Art. 2: acera o andén, "Franja longitudinal de la vía urbana, destinada exclusivamente a la circulación de peatones".
- **"Carriles exclusivos del transporte público":** la ley dice "vías exclusivas para servicio público colectivo" (art. 94; art. 95 num. 2). Es una paráfrasis aceptable.
- **"Circula por la calzada":**
  - Art. 2: "Ciclorruta: Vía o sección de la calzada destinada al tránsito de bicicletas en forma exclusiva."
  - Donde la ciclorruta es una vía aparte y no una sección de la calzada, la instrucción leída al pie de la letra la excluye.
  - Es compatible con los arts. 94 y 95, pero no comunica ninguna regla de posición (ver R-4).
- **Corrección:** decisión de la Secretaría o de Jurídica. Por ejemplo, mencionar la ciclorruta.
- Fuentes:
  - https://normativa.colpensiones.gov.co/colpens/docs/ley_0769_2002.htm
  - https://normativa.colpensiones.gov.co/colpens/docs/ley_0769_2002_pr001.htm

**R-3. Líneas 86, 88 y 89 — CORRECTAS**
- l. 86 (acompañante): art. 95 num. 4, "No podrán llevar acompañante excepto mediante el uso de dispositivos diseñados especialmente para ello".
- l. 88 (prenda reflectiva): ya incluye "siempre que haya poca visibilidad" (B7 corregido).
- l. 89 (1,50 m): igual que en B8.
- l. 68 ("El operador solo lo mira; nunca se lo queda"): coherente con I-1.

**R-4. Comentario PENDIENTE DE JURÍDICA (l. 79–82): tensión entre los arts. 94 y 95 — material para la decisión, sin resolverla**
- **Art. 94** (texto de 2002; no se sabe si fue modificado después de 2018, ver E1):
  - Encabezado: "Los conductores de bicicletas, triciclos, motocicletas, motociclos y mototriciclos, estarán sujetos a las siguientes normas:"
  - "Deben transitar por la derecha de las vías a distancia no mayor de un (1) metro de la acera u orilla […]"
  - "Los conductores que transiten en grupo lo harán uno detrás de otro."
- **Art. 95** (texto de la Ley 1811 de 2016, art. 9):
  - Encabezado: "Las bicicletas y triciclos se sujetarán a las siguientes normas específicas:"
  - "1. Debe transitar ocupando un carril, observando lo dispuesto en los artículos 60 y 68 del presente código."
  - "2. Los conductores que transiten en grupo deberán ocupar un carril y nunca podrán utilizar las vías exclusivas para servicio público colectivo."
  - "3. Los conductores podrán compartir espacios garantizando la prioridad de estos en el entorno vial."
- **Normas conexas verificadas:**
  - Art. 2: "Carril: Parte de la calzada destinada al tránsito de una sola fila de vehículos."
  - Art. 68, vías de doble sentido de dos carriles: "Por el carril de su derecha y utilizar con precaución el carril de su izquierda para maniobras de adelantamiento […]".
  - Art. 68, par. 1: "Sin perjuicio de las normas que sobre el particular se establecen en este código, las bicicletas, motocicletas, motociclos, mototriciclos y vehículos de tracción animal e impulsión humana, transitarán de acuerdo con las reglas que en cada caso dicte la autoridad de tránsito competente."
- **Reglas de interpretación disponibles (verificadas):**
  - Ley 57 de 1887, art. 5: "La disposición relativa a un asunto especial prefiere a la que tenga carácter general"; entre normas de igual especialidad del mismo código, "preferirá la disposición consignada en artículo posterior".
  - Ley 153 de 1887, art. 2: "La ley posterior prevalece sobre la ley anterior."
  - Ley 153 de 1887, art. 3: "Estímase insubsistente una disposición legal por declaración expresa del legislador, ó por incompatibilidad con disposiciones especiales posteriores, ó por existir una ley nueva que regula íntegramente la materia a que la anterior disposición se refería."
- **Hechos relevantes, sin conclusión:**
  - (i) El art. 95 se denomina a sí mismo "específico" para bicicletas; el art. 94 aplica también a motos.
  - (ii) El texto del art. 95 es de 2016; el del art. 94, de 2002.
  - (iii) En las compilaciones consultadas, la Ley 1811 no derogó expresamente el art. 94.
  - (iv) Queda abierto si "ocupando un carril" y "a no más de un metro de la acera" son incompatibles o armonizables.
  - (v) El art. 68, par. 1, abre la vía a que la autoridad de tránsito local dicte reglas.
- **Sobre el comentario:** cita entre «» paráfrasis que no son literales (p. ej., «por la derecha, a no más de un metro de la acera»). No hay riesgo público, pero si pasan a un acto deben usarse los textos literales de arriba.
- **Estado de la página:** hoy no publica ninguna de las dos reglas de posición, lo que es coherente con el comentario.
- Fuentes:
  - https://normativa.colpensiones.gov.co/colpens/docs/ley_0057_1887.htm
  - https://normativa.colpensiones.gov.co/colpens/docs/ley_0153_1887.htm

**R-5. "llama a la línea de emergencias 123" y "Denuncia el hurto ante la Policía o la Fiscalía." — l. 94–95 — NO VERIFICADO**
- No citan norma y no los verifiqué.
- Si Jurídica quiere confirmarlos: que el 123 opere en Valledupar (Policía o Alcaldía) y quién debe denunciar el hurto de un bien del Municipio (régimen de denuncia y querella de la Ley 906 de 2004).

## 5. Veredicto

- **Inscribirme.vue: NO APTA PARA PRODUCCIÓN** mientras:
  - (a) pueda mostrarse "(necesaria para prestar)" sin el concepto sobre la foto (I-5);
  - (b) la autorización que se muestra tenga marcadores y no informe lo que exige el art. 12 lit. b) y d) (I-6);
  - (c) Jurídica no defina qué vale la marca en línea, para menores y para terceros (I-4).
- Los demás textos propios de la página quedan **aptos con correcciones**: terminología de "acudiente" (I-2) y constancia versionada (I-3).
- **Política v0.2: APTA CON CORRECCIONES para Jurídica** (P-2, P-3, I-9). **NO APTA PARA PUBLICAR** mientras sigan los marcadores y los pendientes del informe anterior.
- **Reglas.vue: APTA CON CORRECCIONES MENORES** (R-2). La regla de posición del ciclista sigue en manos de Jurídica (R-4).

## 6. Lo que debe decidir la Oficina Jurídica

1. Si la foto de la persona es un dato biométrico o sensible, y por tanto si se puede exigir para prestar (I-5).
2. Qué vale la marca en línea, del acudiente o de un tercero que inscribe a otro adulto. Si la preinscripción puede guardar datos de un menor antes de la autorización en persona (I-4; Ley 1581, art. 9; D. 1377, art. 5).
3. Si basta uno de los padres (CC, art. 307) y qué prueba de la representación se exige en el punto (D. 1377, art. 20 num. 3) (I-2).
4. Cómo informar el carácter facultativo de las respuestas sobre datos del menor (Ley 1581, art. 12 lit. b) (I-6).
5. Si los datos técnicos que procesa Cloudflare Turnstile son datos personales y cómo reflejarlo en la política (I-9).
6. Si es aceptable que la página revele "ya inscrito", y si anonimizar cumple lo que la política promete en §8 (I-8, P-3).
7. Cómo comunicar la posición del ciclista ante la tensión entre los arts. 94 y 95, y si la STTV dicta reglas propias con base en el art. 68, par. 1 (R-4).
8. Confirmaciones de fuente:
   - En el Diario Oficial: la numeración de la Ley 2486 de 2025 (E2) y si la Ley 2635 de 2026 modifica los arts. 94, 95 o 131 respecto a ciclistas.
   - En la sentencia misma: el resolutivo de la C-748 de 2011.

## Fuentes consultadas

- Ley 1581 de 2012 — https://normativa.colpensiones.gov.co/colpens/docs/ley_1581_2012.htm
- Decreto 1377 de 2013 — https://normativa.colpensiones.gov.co/colpens/docs/decreto_1377_2013.htm
- Ley 1098 de 2006 — https://normativa.colpensiones.gov.co/colpens/docs/ley_1098_2006.htm
- Código Civil — https://normativa.colpensiones.gov.co/colpens/docs/codigo_civil.htm
- Ley 27 de 1977 — https://normativa.colpensiones.gov.co/colpens/docs/ley_0027_1977.htm
- Sentencia C-748 de 2011 — https://normativa.colpensiones.gov.co/colpens/docs/sc748_11.htm y https://www.corteconstitucional.gov.co/relatoria/2011/C-748-11.htm (truncada)
- Ley 769 de 2002 — https://normativa.colpensiones.gov.co/colpens/docs/ley_0769_2002.htm, …_pr001.htm, …_pr002.htm; https://cancilleria.gov.co/sites/default/files/Normograma/docs/ley_0769_2002_pr002.htm
- Ley 153 de 1887 — https://normativa.colpensiones.gov.co/colpens/docs/ley_0153_1887.htm
- Ley 57 de 1887 — https://normativa.colpensiones.gov.co/colpens/docs/ley_0057_1887.htm
- Ley 2486 de 2025 — https://www.anla.gov.co/wanla/eureka/normativa/leyes/ley-2486-de-2025-vehiculos-electricos-livianos-de-movilidad-personal-urbana-como-alternativas-de-movilidad-sostenible
- Política de privacidad de Turnstile — https://www.cloudflare.com/turnstile-privacy-policy/
- Solo para ubicar normas (no son evidencia): vLex (Ley 2486 de 2025), El País (sanciones a ciclistas), Noticias RCN (Ley 2635), copia de la Ley 2635 de 2026 alojada por un despacho (no accesible).
