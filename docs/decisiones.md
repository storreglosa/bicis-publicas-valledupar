# Registro de decisiones

Cada decisión registra la fecha, qué se decidió, frente a qué alternativas y por qué. Si una decisión cambia, no se
borra: se agrega una nueva que la reemplaza y se marca la anterior como «Reemplazada por D-XX».

| ID | Fecha | Decisión | Alternativas consideradas | Razón | Decide |
|---|---|---|---|---|---|
| D-01 | 2026-10-07 | Préstamo **asistido por operador** | Autoservicio con candado de combinación (modelo OSBS); mixto | Sin GPS ni candados inteligentes, el operador es la única fuente confiable del préstamo; es el modelo de EnCicla manual, Megabici y BiSinú | Santiago |
| D-02 | 2026-10-07 | Puntos **fijos y de evento** | Solo fijos; solo eventos | La flota se usa en la ciudad y en eventos | Santiago |
| D-03 | 2026-10-07 | **Preinscripción web sin cuenta + validación presencial**; también inscripción en el punto | Solo en el punto; cuentas ciudadanas | Agiliza los eventos sin exigir correo ni contraseña; las cuentas requieren SMTP propio (F3) | Santiago |
| D-04 | 2026-10-07 | **GitHub Pages + Supabase Free**; alojamiento institucional en el backlog | Django en un PaaS; demo sin datos | Producto utilizable ya, sin servidor propio; Postgres estándar y Supabase autoalojable = migrable | Santiago (Pages); Claude recomendó Supabase |
| D-05 | 2026-10-07 | Repo **público** | Privado con GitHub Pro | Pages gratis exige repo público; no hay datos personales en el repo | Santiago |
| D-06 | 2026-10-07 | Reglas de uso **solo configurables** (NULL = no aplica) | Valores propuestos por defecto | No hay reglamento oficial todavía | Santiago |
| D-07 | 2026-10-07 | Menores **sí, con acudiente** | Solo mayores de 18; menores solo en eventos | Inclusión; D. 1377 art. 12 lo permite con autorización del representante | Santiago |
| D-08 | 2026-10-07 | **Edad declarada + fecha de declaración** (no fecha de nacimiento); la TI implica menor | Fecha de nacimiento | Más rápido de diligenciar; la edad estimada se recalcula con los años transcurridos | Santiago |
| D-09 | 2026-10-07 | Datos: identificación, contacto, edad y **sexo/género**; nada más | Barrio, motivo del viaje | Minimización (D. 1377 art. 4); el sexo/género sirve para análisis de movilidad con enfoque de género | Santiago |
| D-10 | 2026-10-07 | **Foto obligatoria de la persona con la bici**, como parámetro `evidencia.foto_persona_obligatoria` | Autorización aparte con plan B (solo la bici) | Evidencia del préstamo. **Riesgo:** D. 1377 art. 6 prohíbe condicionar un servicio a datos sensibles si la foto se considera biométrica → concepto de Jurídica antes del piloto; se cambia sin tocar código | Santiago |
| D-11 | 2026-10-07 | Fotos con **retención configurable** (N días tras devolución sin novedad) | Conservar siempre; solo la bici | Finalidad y conservación limitada (D. 1377 art. 11); 1 GB de Storage | Santiago |
| D-12 | 2026-10-07 | Región **EE. UU.** (us-east-1) | São Paulo | EE. UU. está nombrado en la lista de países adecuados de la SIC; Brasil solo por interpretación | Santiago |
| D-13 | 2026-10-07 | MVP **en línea**, con UUID de cliente por operación | Modo sin conexión desde el MVP | Complejidad y conflictos; los UUID permiten agregar offline después sin duplicar | Santiago |
| D-14 | 2026-10-07 | Nombre provisional **Bicis Públicas Valledupar**; prefijo fijo **BPV** para las bicis | — | El nombre vive en `sitio.config.js`; el prefijo no cambia aunque cambie el nombre, para no invalidar los QR impresos | Santiago |
| D-15 | 2026-10-07 | Roles **administrador** y **operador** | Agregar coordinador | Dos roles bastan para el MVP; el rol vive en una tabla, no en metadatos editables | Santiago |
| D-16 | 2026-10-07 | Frontend **Vue 3 + Vite en JavaScript**, rutas hash | JS sin build; Alpine/petite-vue; opciones en Python | SPA con formularios, sesión, tiempo real y mapa; las opciones en Python necesitan servidor | Claude (plan aprobado) |
| D-17 | 2026-10-07 | **Paleta cálida propia** (arena, mango, verde Guatapurí), solo tema claro | Paleta azul del observatorio; sistema editorial monocromo | Tono ciudadano; uso al sol; contraste AA verificado por prueba | Claude, pendiente de aprobación en C0 |
| D-18 | 2026-10-07 | Desarrollo **sin Docker**: proyectos Supabase dev/prod en la nube + Postgres 17 local (conda) para probar SQL | Activar Docker Desktop en WSL | WSL con 3,7 GiB de RAM; el stack local de Supabase es pesado | Claude (plan aprobado) |
| D-19 | 2026-10-07 | Modelo de datos, matriz RLS y wireframes viven en `diseno-detallado.md` (§3, §4, §6) y no se duplican en archivos aparte; `modelo-datos.md` se generará a partir de las migraciones | Un archivo por tema escrito a mano | Evita que dos copias diverjan | Claude |
| D-20 | 2026-10-07 | Licencia del código **pendiente**: la define la entidad antes del primer push público | MIT (propuesta) | Es una decisión institucional | Pendiente |
| D-21 | 2026-10-07 | Un **menor** presta solo si su acudiente **autorizó en persona**, en un punto (la autorización web del acudiente no basta) | Aceptar la autorización web del acudiente | Revisión de seguridad (M-2): por web cualquiera puede escribir el documento de un acudiente ya registrado y el sistema registraría que «el acudiente autorizó» sin que nadie lo verificara (D. 1377/2013 art. 12) | Claude, **pendiente de confirmación de Santiago** |
| D-22 | 2026-10-07 | El operador ve solo los préstamos activos de **su** punto | Ver los de todo el sistema | Minimización (revisión de seguridad I-3); la devolución se hace por número de bici y no necesita la lista global | Claude |

