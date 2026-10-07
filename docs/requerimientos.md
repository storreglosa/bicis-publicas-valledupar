# Requerimientos — Bicis Públicas Valledupar

Versión 1 · 2026-10-07 · Fuente de las decisiones: sesión de planificación con Santiago Torreglosa (STTV).

**Origen** de cada requerimiento:
- **D**: decisión de la STTV en la sesión de planificación.
- **N**: norma (ver `investigacion/2026-10-07_gbfs-casos-normativa.md`, sección C).
- **L**: lección de sistemas de referencia (ver `investigacion/2026-10-07_osbs-openbike.md` y la sección B del informe de normativa).
- **T**: requisito técnico del alojamiento elegido.

**Fase:** MVP = Fase 1; F2 y F3 = backlog.

## 1. Público (sin cuenta)
| ID | Requerimiento | Origen | Fase |
|---|---|---|---|
| RF-01 | Portada: qué es el sistema y cómo funciona en tres pasos (inscribirse, ir a un punto con el documento, prestar y devolver). | D | MVP |
| RF-02 | Mapa de puntos con bicicletas disponibles **en tiempo real**, con vista en lista; cada marcador muestra el número, no solo un color. | D, N (WCAG 1.4.1) | MVP |
| RF-03 | Página de reglas: muestra solo los parámetros que tienen valor, además de las normas del ciclista y qué hacer ante un hurto (denuncia + PQRSD). | D, N (Ley 769 arts. 94–95; Ley 2486/2025) | MVP |
| RF-04 | Lista de eventos publicados con sus puntos temporales. | D | MVP |
| RF-05 | Preinscripción en línea **sin cuenta**: nombre, tipo y n.º de documento, teléfono, correo (opcional), edad, sexo/género; si es menor, los datos del acudiente. | D | MVP |
| RF-06 | Si el documento ya está inscrito: mensaje amable ("ya estás inscrito, acércate a un operador"), **sin mostrar ni modificar** sus datos. | D | MVP |
| RF-07 | Casilla de autorización de tratamiento de datos **no premarcada**, con enlace a la política vigente; autorización separada de la foto. | N (Ley 1581 art. 9; D. 1377 arts. 5 y 7) | MVP |
| RF-08 | Página de la política de tratamiento (versión vigente y anteriores). | N (D. 1377 art. 13) | MVP |
| RF-09 | Página de destino del QR de cada bici (`#/b/BPV-015`): qué bici es y cómo reportar un problema. | D, L (OSBS) | MVP |
| RF-10 | Pie de página: Términos y condiciones, Política de datos, Derechos de autor y canal de PQRSD de la Alcaldía. | N (Res. MinTIC 1519/2020, Anexo 2 num. 2.3) | MVP |

## 2. Operador (cuenta del personal)
| ID | Requerimiento | Origen | Fase |
|---|---|---|---|
| RF-20 | Al iniciar el turno, el operador elige su punto de trabajo. | D | MVP |
| RF-21 | Buscar a una persona **solo por documento exacto**; ve un resumen: nombre, documento enmascarado, estado, edad estimada, si es menor y su acudiente, si tiene autorización vigente, si tiene sanción y préstamos activos. | D, N (minimización) | MVP |
| RF-22 | Validar a la persona preinscrita con el documento **exhibido** (no retenido), corregir datos e inscribir en el punto a quien no se preinscribió. | D, N (D. 2150/1995 art. 18) | MVP |
| RF-23 | Prestar en cuatro pasos: persona → bici (por n.º del sticker) → **foto obligatoria** de la persona con la bici → confirmar. | D | MVP |
| RF-24 | Al elegir la bici, ver sus novedades abiertas (daños reportados). | L (OSBS notas) | MVP |
| RF-25 | Devolver: n.º de bici → "sin novedad" o "con novedad" (tipo, descripción, foto opcional; genera una incidencia) → confirmar. | D, L (EnCicla "verificar la entrega") | MVP |
| RF-26 | Ver los préstamos activos del punto con el tiempo transcurrido y la hora de vencimiento (si hay regla). | D | MVP |
| RF-27 | Mover bicis entre puntos (reubicación, taller), indicando el motivo. | L (OSBS force-return) | MVP |
| RF-28 | Cerrar turno manualmente; la sesión se cierra sola tras 20 min de inactividad. | N (Res. 1519 Anexo 3) | MVP |
| RF-29 | Escanear el QR de la bici con la cámara dentro de la app. | D | F2 |
| RF-30 | Operar sin conexión y sincronizar después. | D | F3 |

## 3. Administrador
| ID | Requerimiento | Origen | Fase |
|---|---|---|---|
| RF-40 | Tablero: bicis disponibles, prestadas y no disponibles, préstamos de hoy, préstamos por hora, bicis por punto, activos; alertas de préstamos vencidos (si hay regla), retención de fotos sin configurar, uso de Storage y BD, último respaldo y última purga. | D, L (GIZ: indicadores) | MVP |
| RF-41 | Bicicletas: alta del 1 al 130 (código `BPV-###`), datos descriptivos, condición física (operativa, averiada, en reparación, extraviada, baja) e historial. | D, L (OpenBike) | MVP |
| RF-42 | Puntos fijos, de evento y taller con mapa para ubicarlos; eventos con fechas; cierre del punto de evento (exige que no le queden bicis). | D | MVP |
| RF-43 | Parámetros de uso configurables con la opción "No aplica" (NULL): duración máxima, horarios, límites, edad mínima, sanciones, alertas, retención. | D | MVP |
| RF-44 | Parámetro `evidencia.foto_persona_obligatoria` (sí = persona con bici; no = solo la bici). | D, N (D. 1377 art. 6: pendiente concepto de Jurídica) | MVP |
| RF-45 | Personal: vincular cuentas creadas en Supabase, asignar rol (administrador/operador), desactivar. | D | MVP |
| RF-46 | Personas: buscar, ver detalle e historial, suspender. | D | MVP |
| RF-47 | Historial de préstamos con filtros y exportación **CSV utf-8-sig**, seudonimizado por defecto; incluir datos personales exige un motivo y queda registrado. | D, N (Ley 1581 seguridad) | MVP |
| RF-48 | Anular un préstamo, forzar la devolución y cerrar como "no devuelto", **siempre con motivo y auditado**. | L (OSBS revert/force) | MVP |
| RF-49 | Ver la auditoría: quién hizo qué, cuándo y por qué. | N (Res. 1519 Anexo 3) | MVP |
| RF-50 | Generar la hoja de **etiquetas QR** imprimible (código + QR + logo). | D | MVP |
| RF-51 | Publicar una nueva versión de la política de tratamiento; las autorizaciones anteriores siguen asociadas a su versión. | N (D. 1377 arts. 5 y 13) | MVP |
| RF-52 | Ver las fotos de evidencia (enlace temporal). | D | MVP |
| RF-53 | Módulo completo de incidencias y sanciones (manuales y luego automáticas por parámetros). | D, L (EnCicla) | F2 |
| RF-54 | Derechos del titular: consulta, corrección y supresión con control de plazos (10+5 y 15+8 días hábiles). | N (Ley 1581 arts. 14–15) | F2 |
| RF-55 | Alertas de préstamo largo y bici inactiva; consultas anómalas por operador. | L (OSBS cron) | F2 |
| RF-56 | Feed GBFS 3.0 y datos abiertos agregados. | L, N (Res. 1519 Anexo 4) | F3 |
| RF-57 | GPS: dispositivos y ubicaciones con fuente (sistema/operador/rastreador). | D | F3 |

## 4. Reglas de negocio
| ID | Regla | Origen |
|---|---|---|
| RN-01 | Una bici tiene **a lo sumo un préstamo activo**; dos operadores que la presten a la vez: uno falla con un mensaje claro. | L (falla de OSBS) |
| RN-02 | Solo se presta a personas **validadas**, con autorización vigente de la política vigente y sin sanción vigente. | D, N |
| RN-03 | Una persona es **menor** si su documento implica minoría de edad (TI) o si su edad estimada es menor de 18; edad estimada = edad declarada + años transcurridos desde la declaración. | D |
| RN-04 | Un menor solo presta con acudiente registrado; la autorización la otorga el acudiente, con constancia de que se escuchó al menor. | D, N (D. 1377 art. 12) |
| RN-05 | Cada regla configurable se aplica **solo si su parámetro tiene valor**; NULL = la regla no aplica. | D |
| RN-06 | Si `evidencia.foto_persona_obligatoria` es verdadero, no hay préstamo sin foto subida. | D |
| RN-07 | La foto de un préstamo devuelto sin novedad se borra pasados `retencion.fotos_dias` días; se conserva si hubo novedad o incidencia. | D, N (D. 1377 art. 11) |
| RN-08 | Nada se borra de las tablas de negocio: los préstamos se anulan y las personas se anonimizan. | N (trazabilidad) |
| RN-09 | Cada operación lleva un identificador generado en el cliente; repetirla no la duplica. | D (offline futuro) |
| RN-10 | Disponibilidad (disponible/prestada/no disponible) y condición física (operativa/averiada/…) son estados separados y explícitos. | L (OpenBike) |

## 5. No funcionales
| ID | Requerimiento | Origen |
|---|---|---|
| RNF-01 | WCAG 2.1 AA: contraste ≥ 4,5:1, teclado, etiquetas en formularios, también en la interfaz del operador. | N (Res. 1519 Anexo 1) |
| RNF-02 | Móvil primero: usable a 320 px; botones grandes para el operador, que trabaja al sol. | D |
| RNF-03 | Seguridad: RLS en todas las tablas, permisos explícitos, funciones con `search_path` fijo, CSP, sin secretos en el frontend, 2FA en las cuentas de GitHub y Supabase. | N (Res. 1519 Anexo 3), T |
| RNF-04 | Auditoría de solo inserción; bitácora de consultas con datos personales. | N (Res. 1519 Anexo 3; Res. 500/2021) |
| RNF-05 | Respaldo semanal cifrado fuera del repo y una restauración de prueba antes del piloto. | T (Free sin backups), N |
| RNF-06 | Repo público **sin datos personales**: escáner en CI y en pre-commit. | D, regla de la STTV |
| RNF-07 | Fotos de 80–150 KB, sin EXIF. | T (1 GB de Storage) |
| RNF-08 | Disponibilidad pública con un desfase menor de 5 min (en vivo; sondeo si cae el canal). | L (GBFS) |
| RNF-09 | Dependencias con versión exacta; migraciones versionadas; datos de prueba con semilla fija. | Regla de reproducibilidad |
| RNF-10 | Datos alojados en EE. UU. (país con nivel adecuado según la SIC) y DPA de Supabase como contrato de transmisión. | N (Ley 1581 art. 26; D. 1377 art. 25) |
