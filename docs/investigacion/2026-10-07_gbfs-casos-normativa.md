<!-- Informe de investigación generado por un subagente de Claude Code el 2026-10-07 (GBFS, casos de préstamo asistido y normativa colombiana). Material de trabajo: verificar las fuentes antes de citarlo como evidencia. -->

# Informe: sistema de bicicletas públicas de Valledupar (GBFS, casos de préstamo asistido y normas colombianas)

Fecha de consulta: 7 de octubre de 2026. Todo lo que aparece sin fuente o marcado como **[NO VERIFICADO]** no lo pude confirmar en una fuente oficial o primaria. Lo marcado como **[Inferencia]** es mi lectura de la norma o del estándar, no un texto literal.

---

## A. Estándar GBFS (MobilityData)

### A.1 Versión vigente
- **v3.0 es la "Current Version" (recomendada)**, publicada el 11-abr-2024. La **v3.1-RC3** salió como *pre-release* el 26-may-2026 y figura como "Ready for implementation", pero sigue siendo candidata. Las versiones v2.0 a v2.3 están "Supported" y las v1.x "Deprecated". Fuentes: https://github.com/MobilityData/gbfs/blob/master/README.md y https://api.github.com/repos/MobilityData/gbfs/releases
- La v3.1-RC3 añade sobre la 3.0: tiempo de respuesta menor de 1 s, `area` y `country_code` en `manifest`, `min_age` en `vehicle_types`, `city` en `station_information`, el archivo nuevo `vehicle_availability.json` y `fare_capping`. Es retrocompatible con la 3.0 (https://github.com/MobilityData/gbfs/releases/tag/v3.1-RC3).
- Política de versiones: las versiones soportadas no pueden abarcar más de dos versiones MAJOR. No hace falta publicar más de una MINOR por cada MAJOR (https://github.com/MobilityData/gbfs/blob/v3.0/gbfs.md#version-endpoints).

### A.2 Archivos obligatorios y opcionales (v3.0)
Fuente: https://github.com/MobilityData/gbfs/blob/v3.0/gbfs.md#files

| Archivo | Exigencia |
|---|---|
| `gbfs.json` | Obligatorio (no puede enlazar a `manifest.json`) |
| `manifest.json` | Obligatorio solo si el productor publica más de un dataset |
| `gbfs_versions.json` | Opcional |
| `system_information.json` | Obligatorio |
| `vehicle_types.json` | Obligatorio si `vehicle_status` trae tipos. Si no se publica, todos los vehículos se asumen "non-motorized bicycles" |
| `station_information.json` / `station_status.json` | Obligatorios para "systems utilizing docks" |
| `vehicle_status.json` (antes `free_bike_status`) | Obligatorio para vehículos *free floating*; opcional para vehículos que operan por estaciones |
| `system_regions`, `system_pricing_plans`, `system_alerts`, `geofencing_zones` | Opcionales (`system_hours` y `system_calendar` se eliminaron en la 3.0) |

Reglas generales de la misma fuente:
- HTTPS en todos los endpoints.
- Los archivos obligatorios no pueden devolver 404.
- Codificación UTF-8 y sin paginación.
- Cabecera común `last_updated` / `ttl` / `version` / `data`.
- Datos casi en tiempo real "in no case… more than 5 minutes out-of-date".
- "To be compliant with GBFS, all systems MUST have an entry in systems.csv".

### A.3 Campos obligatorios
Confirmados en el texto y en los JSON Schema oficiales (https://github.com/MobilityData/gbfs-json-schema/tree/master/v3.0):

- **`system_information`**: `system_id`, `languages`, `name` (Array&lt;Localized String&gt;), `opening_hours` (formato OSM), `feed_contact_email` y `timezone`.
  - Condicionales: `manifest_url`, y `license_id` o `license_url`.
  - El schema exige `terms_last_updated` si existe `terms_url`, y `privacy_last_updated` si existe `privacy_url`.
- **`station_information`**: `station_id`, `name`, `lat` y `lon`.
  - Opcionales relevantes: `is_virtual_station`, `station_area`, `capacity`, `station_opening_hours`, `address`, `rental_methods`.
- **`station_status`**: `station_id`, `num_vehicles_available`, `is_installed`, `is_renting`, `is_returning` y `last_reported`.
  - `vehicle_types_available` pasa a ser obligatorio si se publica `vehicle_types.json`.
  - `num_docks_available` es obligatorio "except for stations that have unlimited docking capacity (e.g. virtual stations)".
- **`vehicle_status`**: `vehicle_id`, `is_reserved` e `is_disabled`.
  - `lat` y `lon` son obligatorios solo si no se da `station_id`.
  - `vehicle_type_id` es obligatorio si existe `vehicle_types`.
  - **`vehicle_id` debe rotar a un valor aleatorio después de cada viaje** (privacidad).
  - Los vehículos en préstamo activo no pueden aparecer en el feed.

### A.4 ¿Puede publicar GBFS un sistema sin anclajes ni GPS?
- La especificación contempla expresamente las estaciones virtuales. `is_virtual_station: true` significa "a location without smart docking infrastructure… racks or geofenced areas designated for rental and/or return" (https://github.com/MobilityData/gbfs/blob/v3.0/gbfs.md#station_informationjson).
- **[Inferencia] Sí es válido.** El sistema de Valledupar no es *free floating* porque se presta y se devuelve en estaciones, así que `vehicle_status` no es obligatorio. Los archivos de estaciones quedan como "Conditionally REQUIRED"; fuera de esa condición son opcionales, pero son el contenido útil del feed. El feed mínimo coherente sería `gbfs.json` + `system_information` + `station_information` + `station_status`.
- **[Inferencia] La disponibilidad por estación sale del registro de préstamos y devoluciones:**
  - `num_vehicles_available` = bicicletas físicamente en la estación y operativas.
  - `last_reported` = la última transacción o el último inventario registrado por el operador. El spec la define como "the last time this station reported its status to the operator's backend".
  - Fuera de horario: `is_renting=false`, como pide la sección "Hours and Dates of Operation".
- Campos que quedan vacíos u omitidos:
  - `num_docks_available` (estación virtual), `vehicle_docks_*`, `rental_uris`, `purchase_url` y `system_pricing_plans`.
  - `vehicle_status`: se omite. Si se publica, sería sin lat/lon y con `station_id`.
  - `rental_methods`: **[Inferencia]** ningún valor del enum (`key`, `creditcard`, `accountnumber`, `phone`, …) describe "presentar documento ante un operador", así que conviene omitirlo.
- GBFS **no sirve para guardar viajes**: "not intended for historical or archival data such as trip records" (README, Guiding Principles). Para compartir viajes cuando haya GPS existe el **MDS** de la Open Mobility Foundation (v2.1.0). MDS exige que los proveedores expongan feeds GBFS (https://github.com/openmobilityfoundation/mobility-data-specification).
- Validador: https://gbfs-validator.mobilitydata.org/ (responde HTTP 200).

### A.5 Qué implica diseñar el modelo de datos "GBFS-ready"
Todo según https://github.com/MobilityData/gbfs/blob/v3.0/gbfs.md#field-types:
- **IDs** persistentes, en ASCII imprimible, idealmente `A-Za-z0-9.@:/_-`, y únicos por tipo de entidad.
- **Excepción para bicicletas:** separar el ID interno permanente (placa o número físico) del `vehicle_id` público, que debe rotar en cada viaje.
- **Nombres** como texto localizado (`[{text, language:"es"}]`), sin MAYÚSCULAS sostenidas y sin abreviaturas.
- **Coordenadas** con 6 decimales.
- **Formatos**: marcas de tiempo RFC 3339 (por ejemplo `-05:00`), zona IANA `America/Bogota`, teléfonos en E.164 (`+57…`), enums en minúscula y horarios en formato **OSM `opening_hours`** tanto del sistema como de cada estación.
- **`system_id`** único, verificado contra `systems.csv`. Se necesita además un correo técnico estable (`feed_contact_email`) y una licencia SPDX (`license_id`).
- **Tipos de vehículo:** si se definen (`form_factor: bicycle`, `propulsion_type: human`), se vuelven obligatorios `vehicle_types_available` y `vehicle_type_id`. Diseñarlos desde ya facilita sumar e-bikes después.
- **Capacidad de la estación** (`capacity`): para estaciones virtuales es "number of vehicles… that can be parked".
- **[Inferencia] Estaciones temporales para eventos:** pueden modelarse como estaciones virtuales con `station_opening_hours` e `is_installed=false` fuera del evento, y anunciar cierres en `system_alerts`. El spec pide anunciar en `system_alerts` las interrupciones y cierres temporales.

---

## B. Casos de préstamo asistido o de baja tecnología

### B.1 EnCicla (Valle de Aburrá): sigue operando
- **Préstamo en estación manual:** "Presenta su documento físico registrado en el sistema (importante debe ser un documento que contenga foto de la persona y el número de documento) – El anfitrión verifica la información en el sistema y asigna una bicicleta disponible – Se registra el préstamo en la plataforma". Las estaciones manuales no tienen módulos ni lectores (https://encicla.metropol.gov.co/preguntas-frecuentes/).
  - Documentos aceptados: CC, CE, pasaporte, TI o licencia (https://encicla.metropol.gov.co/condiciones-de-uso-del-sistema-encicla/).
- **Inscripción:**
  - Formulario web con carga de documentos.
  - La validación tarda hasta 3 días hábiles.
  - Los extranjeros se inscriben con CE o pasaporte.
  - Los datos se actualizan cada 12 meses ("residente… o mayor de 16 años") y cada 8 días si es visitante.
  - La tarjeta es "personal e intransferible" (misma FAQ).
  - **[NO VERIFICADO] la edad mínima exacta:** la redacción de la FAQ es ambigua.
- **Tiempo de préstamo:** 1 h en bicicleta mecánica y 30 min en eléctrica. Se puede renovar en cualquier estación y hacer varios préstamos al día.
- **Horario:**
  - Lunes a viernes de 5:30 a 22:00 (último préstamo 21:00).
  - Sábado de 6:30 a 20:00.
  - Domingo de 8:00 a 16:00, solo en estaciones automáticas.
  - Festivos sin servicio.
- **Sanciones** (28 conductas) en https://encicla.metropol.gov.co/sanciones/:

  | Conducta | Sanción |
  |---|---|
  | Exceder el tiempo entre 61 y 75 min | 3 días |
  | "No verificar la entrega en estaciones manuales" | 3 días |
  | Ceder la bicicleta a terceros no inscritos | 15 días |
  | Exceder ≥361 min | 60 días |
  | Abandonar la bicicleta en sitios inseguros | 60 días |
  | Hurto de la bicicleta por descuido | Cancelación del contrato |

  Para reactivar el servicio tras las faltas 12, 15 y 20 hay que radicar una PQRSD. Si hurtan la bicicleta, el usuario denuncia ante la Fiscalía y registra una PQRS.
- **Problemas reportados:**
  - Jun–ago 2021: 2.409 incidentes, la mayoría fallas de las estaciones automáticas ("no detectó bicicleta": 1.506). Ese año había 6.900 préstamos diarios frente a 16.500 antes de la pandemia (https://www.elcolombiano.com/antioquia/problemas-al-prestar-bicicletas-queja-recurrente-en-encicla-FC15716300, 21-sep-2021).
  - Usuarios: de 54.000 (2019) a 40.000 (2022). Préstamos: de 3,2 M a 1,5 M al año. No hubo contratos de mantenimiento en 2021–2022 (https://www.elcolombiano.com/antioquia/la-encrucijada-que-tiene-encicla-mas-bicicletas-pero-menos-usuarios-BE23274162, 4-dic-2023).
  - Unas 150 bicicletas robadas en 6 meses; de 103 bicicletas vandalizadas, 20 fueron dadas de baja; 1.433 personas sancionadas por abandono y mal uso (https://www.semana.com/nacion/medellin/articulo/recuperan-30-bicicletas-del-sistema-encicla-que-fueron-robadas-y-abandonadas-en-medellin/202227/, 4-oct-2022).
  - **[NO VERIFICADO]** "250 sancionados diarios, 50 % por exceder 60 min": aparece solo en un fragmento de búsqueda; la página de Telemedellín estaba bloqueada.

### B.2 BiSinú (Montería): opera, con altibajos
- Arrancó con **130 bicicletas, el mismo tamaño que Valledupar**. El registro era por aplicación web o con el operador de la estación ("en caso que la persona no tenga acceso a Internet"), y los préstamos duraban entre media y una hora (https://www.eluniversal.com.co/regional/cordoba/2015/08/08/monteria-tendra-bicicletas-gratis-para-la-movilidad/).
- En 2017 tenía 12 estaciones y 120 bicicletas. Al retirar la bicicleta se pedía **fotocopia de la cédula y un recibo de servicio público**, con préstamos de hasta 2 h. Ese año se suspendió por "problemas contractuales" (https://larazon.co/sistema-de-bicicletas-publicas-bisinu-opera-nuevamente-con-12-estaciones/, 15-jun-2017).
- Es gratuito y lo opera un privado con presupuesto municipal y **contrato anual**, por lo que "no se ha garantizado su continuidad operacional" (Guía GIZ/ITDP/Despacio 2022, pp. 106–107: https://www.giz.de/sites/default/files/media/pkb-document/2025-07/giz-2022-es-guia-bicicleta-compartida.pdf).
- En enero de 2026: 12 estaciones, solo bicicletas mecánicas, equipos deteriorados; el plan es llegar a 20 estaciones con e-bikes (https://larazon.co/monteria-ampliara-bisinu-a-20-estaciones-con-bicicletas-electricas-en-2026/). **[NO VERIFICADO en fuente oficial]** quién es el operador actual.

### B.3 Megabici (Pereira): opera
- Inició el 9-ago-2018 con 4 estaciones.
- En 2021 tenía 7 estaciones y 109 bicicletas (99 mecánicas y 10 eléctricas). Un operador en cada estación controla entradas y salidas y registra a los usuarios nuevos en la plataforma "Ibici". Ese año hubo 5.771 préstamos y 2.076 usuarios (Guía GIZ, pp. 34–35, que cita el informe de gestión del IMP).
- En 2025: 13.227 préstamos, incorporación de GPS y "puntos púrpura" (https://concejopereira.gov.co/es/el-instituto-de-movilidad-presento-su-informe-de-gestion-2025-ante-el-concejo-de-pereira-EV2897, 5-mar-2026).
- Punto en la UTP (2025): inscripción presencial con cédula y celular; 1 h renovable en otra estación; lunes a viernes de 7:00 a 17:00 (https://comunicaciones.utp.edu.co/87984/rectoria/a-estan-abiertas-las-inscribciones-para-formar-parte-de-una-experiencia-sostenible-y-gratuita-en-la-utp-megabici/).
- **[NO VERIFICADO]** "156 bicicletas / 8 estaciones / jóvenes de 16–17 años con adulto": aparece solo en fragmentos de búsqueda.

### B.4 Clobi BGA (Bucaramanga, Metrolínea): cerrado
- La Guía GIZ lo muestra como "Sistema manual" (p. 33).
- En 2021 tenía 16 estaciones con paneles solares; 220 bicicletas mecánicas gratuitas, 16 eléctricas y 32 patinetas a $1.000 por hora. Horario: lunes a viernes de 6:00 a 18:00 y sábado de 6:00 a 13:00. Unos 9.000 inscritos y cerca de 60.000 recorridos (https://www.vanguardia.com/area-metropolitana/bucaramanga/clobibga-evoluciona-con-bicicletas-y-patinetas-electricas-ED4270677, 21-sep-2021).
- **Se suspendió a inicios de noviembre de 2023** por terminación del contrato y falta de recursos. Tenía unos 23.000 usuarios y más de 47.000 viajes en 2023; las estaciones quedaron convertidas en basureros (https://www.vanguardia.com/area-metropolitana/bucaramanga/2024/09/25/video-como-basureros-asi-se-ven-estaciones-de-clobi-bga-el-sistema-de-bicicletas-publicas-de-bucaramanga/). En junio de 2026 "permanece en el limbo" (Vanguardia, 12-jun-2026, contenido para registrados).
- **[NO VERIFICADO]** el requisito del recibo de servicios públicos y el retiro de la infraestructura (Blu Radio, error de certificado).

### B.5 Otros casos
- **BiciRio (Rionegro):** empezó en 2016 con 80 bicicletas y 4 estaciones. Tuvo un receso en febrero de 2018 por vandalismo y luego evolucionó hacia 13 estaciones con pantalla táctil (Guía GIZ, p. 38).
- **BicirrUN (UNAL Bogotá):**
  - Relanzamiento de octubre de 2014 con 115 bicicletas.
  - Requisitos: carné vigente y registro en línea, con 24 h de espera.
  - **15 min** entre estaciones, renovable el mismo día.
  - Horario: lunes a jueves de 6:30 a 17:30 y viernes de 6:30 a 13:00.
  - Sanción: pérdida del servicio.
  - Fuente: https://bienestar.bogota.unal.edu.co/ver_noticia.php?id_noticia=373. **[NO VERIFICADO]** su estado actual (la página de planeación devuelve 404).
- **Ecobici Buenos Aires (2010–2015, manual):** se pedía DNI más una factura como prueba de domicilio; estaciones con personal y "jaulas" sin anclajes. En 2013 tenía 29 estaciones, 1.000 bicicletas, 72.000 usuarios y unos 5.000 viajes diarios. El personal "aseguraba la devolución" (https://blogs.worldbank.org/en/latinamerica/most-human-bike-sharing-system-world-lives-buenos-aires, 30-jul-2013). **[NO VERIFICADO en fuente primaria]** la automatización en 2015.
- **Antecedente en Valledupar:** en noviembre de 2023 se reactivó un programa con bicicletas donadas por MinTransporte en 2019, sin uso desde diciembre de 2019. Tenía 2 biciestaciones, horario de lunes a viernes de 7:30 a 18:30, y registro en valleduparvaenbici.com; se recuperaron unas 200 bicicletas (https://www.radionacional.co/actualidad/salud/valledupar-reactiva-programa-de-bicicletas-publicas-como-participar). **Hoy el dominio no resuelve (ENOTFOUND).** No verifiqué si son las mismas 130 bicicletas.

### B.6 Lecciones transversales (Guía GIZ 2022, pp. 32–37, 90–91)
- **Ventajas del sistema manual:** menor inversión inicial (CAPEX), implementación rápida, útil como piloto.
- **Desventajas del sistema manual:**
  - Mayor costo de operación (OPEX) por el personal.
  - Poca escalabilidad.
  - Horario limitado al personal disponible.
  - Vulnerabilidad en pandemia.
  - Puede exigir "dejar una identificación oficial como fianza".
- **Métricas recomendadas:** viajes diarios por bicicleta y viajes diarios por cada 1.000 residentes.
- Los sistemas con más de 20 estaciones tienen mayor probabilidad de sobrevivir.

### B.7 Préstamos en eventos (caso documentado: IDRD, Ciclovía de Bogotá)
- Piloto de marzo de 2014: 40 bicicletas, máximo 30 min, requisito de documento de identidad (https://bogota.gov.co/mi-ciudad/cultura-deporte-y-recreacion/con-prestamo-gratis-de-bicicletas-inicia-celebracion-de-40).
- Septiembre de 2014: 120 bicicletas domingos y festivos de 8:30 a 13:00. La **cédula se dejaba a cambio de un recibo**; se llenaba un formulario con datos personales y de afiliación de salud (EPS/Sisbén) y se firmaba una exoneración de responsabilidad; 30 min (https://bogota.gov.co/mi-ciudad/cultura-deporte-y-recreacion/tres-nuevas-estaciones-de-prestamo-de-bicicletas-en-la).
- **Alerta legal:** el art. 18 del Decreto 2150 de 1995 (modificado por el art. 23 de la Ley 962 de 2005) dice: "Ninguna autoridad de la Administración Pública podrá retener la tarjeta de identidad, la cédula de ciudadanía… Si se exige la identificación… cumplirá la obligación mediante la exhibición… Queda prohibido retenerlos" (https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=1208). La STTV **no debería retener la cédula como garantía**. Además, el dato de salud es sensible (art. 5 de la Ley 1581).

---

## C. Marco normativo colombiano

### C.1 Ley 1581 de 2012: vigente, reglamentada
Fuente: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=49981
- **Art. 3:** definiciones de autorización, responsable, encargado, etc.
- **Art. 4:** principios de finalidad, libertad, seguridad, confidencialidad, etc.
- **Art. 5:** datos sensibles (salud, biométricos, origen étnico…).
- **Art. 6:** el tratamiento de datos sensibles está prohibido salvo excepciones.
- **Art. 7:** derechos de niños, niñas y adolescentes.
- **Art. 8:** derechos del titular: conocer, actualizar, rectificar, prueba de la autorización, ser informado, quejarse ante la SIC, revocar o suprimir, acceso gratuito.
- **Art. 9:** autorización "previa e informada… por cualquier medio que pueda ser objeto de consulta posterior".
- **Art. 10:** no se necesita autorización para "información requerida por una entidad pública… en ejercicio de sus funciones legales". **[Inferencia]** Un programa voluntario de préstamo difícilmente encaja ahí; es más seguro pedir la autorización.
- **Art. 12:** deber de informar la finalidad, el carácter facultativo de las respuestas sobre datos sensibles o de menores, los derechos y la identificación y contacto del responsable, **y conservar prueba**.
- **Arts. 14 y 15:** consultas en 10 días hábiles (más 5); reclamos en 15 días hábiles (más 8), con la leyenda "reclamo en trámite" en un máximo de 2 días.
- **Art. 17:** deberes del responsable, entre ellos el manual interno de políticas.
- **Art. 18:** deberes del encargado.
- **Art. 23, parágrafo:** las sanciones de la SIC aplican solo a privados. Si se trata de una autoridad pública, la SIC remite a la **Procuraduría**.
- **Art. 25:** Registro Nacional de Bases de Datos (RNBD).
- **Art. 26:** transferencia internacional (ver C.2).

### C.2 Decreto 1377 de 2013, compilado en el Decreto 1074 de 2015 (Cap. 25)
Fuentes: https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=53646 y …?i=76608

| Decreto 1377 | Decreto 1074 | Contenido |
|---|---|---|
| Art. 3 | 2.2.2.25.1.3 | Define "aviso de privacidad". **Transferencia** = el receptor es *Responsable*. **Transmisión** = el tratamiento lo hace un *Encargado* por cuenta del Responsable |
| Art. 4 | 2.2.2.25.2.1 | Recoger solo los datos pertinentes y adecuados |
| Art. 5 | 2.2.2.25.2.2 | Autorización a más tardar al recolectar, informando todas las finalidades; nueva autorización si cambia la finalidad |
| Art. 6 | 2.2.2.25.2.3 | Datos sensibles: informar que son facultativos; "Ninguna actividad podrá condicionarse" a darlos |
| Art. 7 | 2.2.2.25.2.4 | Autorización por escrito, de forma oral o por conducta inequívoca; "En ningún caso el silencio" cuenta |
| Arts. 8 y 9 | 2.2.2.25.2.5 y .6 | Prueba de la autorización; revocatoria y supresión por mecanismos gratuitos |
| Art. 11 | 2.2.2.25.2.8 | Conservar los datos solo el tiempo necesario y luego suprimirlos |
| Art. 12 | 2.2.2.25.2.9 | Menores (ver C.4) |
| Art. 13 | 2.2.2.25.3.1 | Contenido mínimo de la política de tratamiento, incluida la **fecha de entrada en vigencia** y el período de vigencia de la base. Los cambios sustanciales se comunican antes de implementarse |
| Arts. 14–16 | 2.2.2.25.3.2 a .4 | Contenido mínimo del aviso de privacidad y **deber de conservar el modelo del aviso** |
| Arts. 24 y 25 | 2.2.2.25.5.1 y .2 | Transferencia y transmisión internacional; contrato de transmisión |
| Arts. 26 y 27 | 2.2.2.25.6.1 y .2 | Responsabilidad demostrada |

**RNBD:** art. 2.2.2.26.1.2 (modificado por el Decreto 90 de 2018): deben inscribirse las "Personas jurídicas de naturaleza pública". Cada base se inscribe por separado (2.2.2.26.1.3) y las bases nuevas, dentro de los 2 meses siguientes a su creación (2.2.2.26.3.1). **[Inferencia]** El Responsable sería el Municipio de Valledupar, porque la STTV es una dependencia. **[NO VERIFICADO]** la personería de la STTV.

### C.3 Base de datos en Supabase (pregunta adicional del coordinador)
1. **Transferencia o transmisión.**
   - Si Supabase actúa como *encargado*, es una **transmisión**. Según el art. 24.2 del Decreto 1377 (2.2.2.25.5.1), las transmisiones internacionales a un encargado "no requerirán ser informadas al Titular ni contar con su consentimiento **cuando exista un contrato** en los términos del artículo 25".
   - Ese contrato debe fijar el alcance, las actividades y las obligaciones del encargado: tratar los datos según los principios, garantizar la seguridad y la confidencialidad.
   - **[Inferencia] Sí, el contrato basta en lo que respecta al consentimiento**, pero conviene revisar el contenido mínimo exigido.
   - El DPA de Supabase dice "Supabase acts as a processor"; notifica incidentes en ≤48 h "where feasible"; borra los datos al terminar la retención; avisa con 30 días los cambios de subprocesadores (https://supabase.com/legal/dpa).
   - **[NO VERIFICADO]** que ese DPA cubra todo lo del art. 25: está redactado en clave GDPR. Recomiendo un anexo que remita a la Ley 1581 y a la política de la entidad.
2. **Lista de países de la SIC** (Circular Única, Título V, Cap. 3, num. 3.2; versión consolidada del 29-sep-2022: https://www.sic.gov.co/sites/default/files/normatividad/092022/T%C3%ADtulo%20V%20Versi%C3%B3n%2029-09-2022.pdf).
   - La lista **incluye "Estados Unidos de América"**, además de Japón (Circular 08 de 2017) y Australia (Circular 02 de 2018).
   - **No nombra a Brasil**, aunque incluye "los países que han sido declarados con el nivel adecuado de protección por la Comisión Europea".
   - La UE declaró adecuado a Brasil mediante la Decisión de Ejecución (UE) 2026/179 del 26-ene-2026 (https://www.boe.es/buscar/doc.php?id=DOUE-L-2026-80106).
   - **[Inferencia / NO VERIFICADO por la SIC]** que Brasil quede cubierto por esa cláusula.
   - Parágrafo 4: "Es posible realizar la transmisión de datos personales a los países que cuentan con un nivel adecuado… en los términos que rigen la transferencia".
   - Parágrafo 3: el mero tránsito transfronterizo no constituye transferencia.
   - La Circular SIC 002 de 2025 (7-oct-2025) **no modifica** la lista; da instrucciones contractuales para procesos de transferencia de tecnología (https://cancilleria.gov.co/normograma/compilacion/docs/circular_superindustria_0002_2025.htm).
   - No encontré modificaciones de la lista posteriores a 2018, pero **no pude confirmar** que no exista una versión consolidada de 2026.
   - Supabase ofrece la región São Paulo (`sa-east-1`) (https://supabase.com/docs/guides/platform/regions).
3. **Menores:** ver C.4.

### C.4 Datos de menores
- **Art. 7 de la Ley 1581:** "Queda proscrito el Tratamiento de datos personales de niños, niñas y adolescentes, salvo aquellos datos que sean de naturaleza pública".
- **Art. 12 del Decreto 1377 (2.2.2.25.2.9):** se permite cuando responde al interés superior del menor y asegura sus derechos fundamentales. En ese caso "**el representante legal… otorgará la autorización previo ejercicio del menor de su derecho a ser escuchado**".
- **[NO VERIFICADO en esta sesión]** la cita de la norma que fija la mayoría de edad en 18 años.

### C.5 Resolución MinTIC 1519 de 2020 (24-ago-2020)
Fuente: https://www.cancilleria.gov.co/sites/default/files/Normograma/docs/resolucion_mintic_1519_2020.htm. No encontré nota de derogatoria y aparece como vigente; derogó la Resolución 3564 de 2015.
- **Art. 2:** aplica a los sujetos obligados del art. 5 de la Ley 1712.
- **Art. 3 y Anexo 1:** **WCAG 2.1 nivel AA** desde el 1-ene-2022 en "portales web y sedes electrónicas".
- **Anexo 2, num. 2.3:** en el pie de página deben ir los Términos y condiciones "de todos sus sitios web, plataformas, **aplicaciones, trámites y servicios**", la política de privacidad y la política de derechos de autor. También hay que tener un formulario de PQRSD.
- **Anexo 3:** controles de seguridad para "sitios web y aplicaciones":
  - Autenticación, roles y separación de funciones.
  - Exigir medidas de seguridad al proveedor de hosting.
  - Hardening.
  - Validación y sanitización de entradas; cookies con `Secure` y `HttpOnly`; token CSRF.
  - Logs de auditoría y copias de respaldo.
  - HTTPS más cabeceras de seguridad (CSP, HSTS, etc.), con cifrado adicional para "portales transaccionales".
  - Mensajes de error genéricos y accesibles; OWASP.
  - DRP/BCP "7/24".
  - Reporte de incidentes graves al CSIRT-Gobierno en 24 h.
- **Anexo 4:** datos abiertos en datos.gov.co.
- **[Inferencia] Sí aplica a la aplicación transaccional**, porque el Anexo 2 y el Anexo 3 mencionan expresamente aplicaciones y portales transaccionales.
- Nota técnica mía, no de la norma: algunas cabeceras que lista (HPKP, X-XSS-Protection) están obsoletas en los navegadores actuales.

### C.6 Ley 1712, Gobierno Digital y seguridad digital
- **Ley 1712 de 2014** (https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=56882):
  - Art. 5(a): obliga a las entidades del orden municipal.
  - Art. 8: criterio diferencial de accesibilidad.
  - Art. 13: Registro de Activos de Información.
  - Art. 18(a): la información que afecta la intimidad es clasificada.
  - Art. 20: índice de información clasificada y reservada.
- **Decreto 767 de 2022** (subroga el Cap. 1, Tít. 9 del Decreto 1078 de 2015; https://normograma.dian.gov.co/dian/compilacion/docs/decreto_0767_2022.htm):
  - Ámbito (2.2.9.1.1.2): la administración pública según el art. 39 de la Ley 489 de 1998.
  - Habilitadores (2.2.9.1.2.1): 3.2 "Seguridad y privacidad de la información" en "todos sus procesos, trámites, servicios, sistemas de información"; 3.4 Servicios ciudadanos digitales.
  - Promueve software libre y código abierto.
  - Los proyectos de transformación digital deben integrarse al PETI.
- **Resolución MinTIC 500 de 2021** (MSPI; https://normograma.mintic.gov.co/mintic/compilacion/docs/resolucion_mintic_0500_2021.htm):
  - Art. 9: gestión de incidentes con bitácora.
  - Art. 10: estrategia de privacidad conforme a la Ley 1581.
  - Art. 11: mecanismos de autenticación y segregación de privilegios de administrador.
- **[NO VERIFICADO]** la Resolución MinTIC 2893 de 2020 (sedes electrónicas y GOV.CO): no la consulté.

### C.7 Normas de tránsito esenciales para mostrar al usuario
- **Art. 94 de la Ley 769 de 2002** (https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=5557):
  - Circular por la derecha, a no más de 1 m de la acera.
  - Prenda reflectiva entre las 18:00 y las 6:00.
  - En grupo, uno detrás de otro.
  - No sujetarse de otros vehículos.
  - No circular por andenes.
  - Respetar señales y límites de velocidad.
  - No adelantar por la derecha ni entre vehículos.
  - Usar señales manuales.
  - Casco "de acuerdo como fije el Ministerio de Transporte". **[NO VERIFICADO]** que exista una reglamentación que lo haga obligatorio para ciclistas.
- **Art. 95** (texto del art. 9 de la Ley 1811 de 2016):
  - Ocupar un carril.
  - No llevar acompañante sin un dispositivo diseñado para ello.
  - Luz blanca adelante y reflectivo rojo atrás de noche.
  - 25 km/h en vías con actividades recreativas.
- **Art. 131, literal A:** multa de 4 SMLDV para vehículos no automotores. Ejemplos: A.4 andenes, A.6 sin luces, A.7 sin frenos o con frenos defectuosos.
- **Ley 2486 de 2025** (16-jul-2025; https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=260802):
  - Art. 5 (modifica el art. 63): prelación de ciclistas.
  - Art. 6 (modifica el art. 60, par. 3): **adelantar a ciclistas a no menos de 1,50 m**.
  - Deroga los arts. 14 y 17 de la Ley 1811.
- **Ley 1811, art. 7** (https://normograma.mintic.gov.co/mintic/compilacion/docs/ley_1811_2016.htm): las Secretarías de Movilidad de entes de más de 100.000 habitantes consolidarán, "siempre y cuando existan los recursos", un sistema de información de modos no motorizados y un registro de PQRS. Esto respalda el proyecto.

---

## Requisitos derivados para el diseño de la web

**Datos personales y consentimiento**
1. Casilla de autorización **no premarcada**, separada de los términos, con finalidades específicas. Guardar fecha y hora, versión de la política y del aviso, canal (web u operador), ID del operador y evidencia (Ley 1581 arts. 9 y 12; D. 1377 arts. 5, 7, 8 y 16).
2. Versionar la política: si cambia la finalidad, pedir **nueva autorización** al siguiente préstamo (D. 1377 arts. 5 y 13).
3. En el registro asistido, el operador lee el aviso y deja constancia (autorización oral o por conducta inequívoca, nunca por silencio).
4. Minimización: nombre, tipo y número de documento, teléfono y, como opcional, el correo. **No** pedir recibo de servicios, foto del documento, EPS ni datos de salud. Si se pide un dato sensible, debe ser facultativo y señalado como tal (D. 1377 arts. 4 y 6).
5. **No retener la cédula**: verificar por exhibición y registrar el número (D. 2150/1995 art. 18).
6. Módulo de derechos ARCO con radicado y control de plazos de 10+5 y 15+8 días hábiles, más la leyenda "reclamo en trámite" (Ley 1581 arts. 14 y 15).
7. Política de retención por tipo de dato, supresión o anonimización automática y bloqueo de cuentas inactivas (D. 1377 art. 11).
8. Inscribir la base en el RNBD dentro de los 2 meses siguientes a su creación (D. 1074 art. 2.2.2.26.3.1) y llevarla al Registro de Activos e Índice de Información Clasificada (Ley 1712 arts. 13 y 20).

**Menores**

9. Campo de fecha de nacimiento. Si la persona es menor, flujo obligatorio de autorización del representante legal (identificación y parentesco) y constancia de que se escuchó al menor (D. 1377 art. 12).

**Nube (Supabase)**

10. Firmar el DPA más un anexo de "contrato de transmisión" (D. 1377 art. 25). Documentar la región elegida. EE. UU. figura expresamente en la lista de la SIC; Brasil solo por interpretación de la cláusula de la Comisión Europea.
11. Activar Row Level Security, cifrado y respaldos. Exigir medidas al proveedor (Res. 1519, Anexo 3 num. 3).

**Seguridad (Res. 1519 Anexo 3, Res. 500/2021)**

12. Roles: administrador, coordinador y operador de estación. MFA para cuentas privilegiadas y separación de funciones.
13. Bitácora inmutable de préstamos, devoluciones, cambios de estado e ingresos (quién, cuándo, desde dónde).
14. HTTPS con HSTS y CSP; validación de formularios en cliente y servidor; límite de intentos de inicio de sesión; errores genéricos; procedimiento de incidentes con reporte al CSIRT-Gobierno.

**Accesibilidad y transparencia**

15. Cumplir WCAG 2.1 AA (contraste, teclado, lectores de pantalla, formularios etiquetados), también en la interfaz del operador.
16. En el pie de página: Términos y condiciones, Política de tratamiento y Derechos de autor, más un canal de PQRSD (Res. 1519, Anexo 2 num. 2.3).
17. Publicar datos abiertos agregados (uso por estación y día, sin datos personales) en datos.gov.co (Res. 1519 Anexo 4; Ley 1811 art. 7).

**Modelo de datos GBFS-ready**

18. Tablas `system`, `station` (ID ASCII estable, nombre en español, coordenadas con 6 decimales, `is_virtual_station`, `capacity`, `opening_hours` en formato OSM), `vehicle_type` (`bicycle`/`human`), `vehicle` (ID interno permanente separado del `vehicle_id` público rotativo) y `trip`/`loan` (privado, nunca en GBFS).
19. Calcular `station_status` desde las transacciones: `num_vehicles_available`, `num_vehicles_disabled`, `is_renting` según horario y `last_reported` = última transacción o inventario. Endpoints `gbfs.json`, `system_information`, `station_information` y `station_status` en v3.0, con `ttl` 0 y desfase menor de 5 min. Correo técnico, licencia SPDX y registro en `systems.csv`.
20. Estado de bicicleta disponible / prestada / en taller / perdida, más un inventario periódico por estación para cuadrar el stock calculado. Dejar previsto el campo de dispositivo GPS para la migración a `vehicle_status` y MDS.

**Operación de préstamo asistido**

21. Préstamo en máximo 3 toques: buscar por documento, elegir la bicicleta (número físico o QR) y confirmar. Hora de vencimiento visible y renovación en otra estación.
22. Al devolver, el usuario o el operador confirma el estado de la bicicleta (EnCicla sanciona "no verificar la entrega").
23. Tabla de sanciones parametrizable por minutos de retraso, daño y abandono, con suspensión automática, notificación y recurso por PQRSD. **Recomendación (no verificada como exigencia legal):** adoptarla mediante un acto administrativo de la STTV, como hace EnCicla con su reglamento.
24. Modo **evento**: estaciones temporales con horario propio, preinscripción por QR o enlace, préstamo por exhibición del documento sin retenerlo, límite de tiempo corto (las referencias usan 30 min) y cierre automático de la estación al terminar.
25. Modo sin conexión o de contingencia para el operador, con sincronización posterior y marca de transacciones diferidas. **[Inferencia]** Las fallas técnicas fueron la queja principal en EnCicla.

**Información al usuario**

26. Una tarjeta de normas al aceptar el préstamo: derecha y a no más de 1 m de la acera, prohibido circular por andenes, luces y reflectivo de noche, sin acompañante, señales manuales, adelantamiento a 1,50 m y prelación del ciclista, multa de 4 SMLDV (art. 131 A). Más el procedimiento en caso de hurto (denuncia y PQRS).

**Sostenibilidad**

27. Tablero de indicadores: viajes por bicicleta al día, viajes por cada 1.000 habitantes, bicicletas fuera de servicio, pérdidas y sanciones. Así se demuestra el valor del programa y se protege su continuidad, que es lo que falló en BiSinú y en Clobi por la dependencia de contratos anuales.
