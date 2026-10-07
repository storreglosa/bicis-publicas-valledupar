<!-- Informe de investigación generado por un subagente de Claude Code el 2026-10-07 (Análisis de OpenSourceBikeShare y OpenBike). Material de trabajo: verificar las fuentes antes de citarlo como evidencia. -->

# Informe: OpenSourceBikeShare, OpenBike y otros proyectos para diseñar el sistema de Valledupar

**Resumen:** OpenSourceBikeShare (OSBS) es el referente más útil para su caso: está activo en 2026 y funciona con candados mecánicos de combinación, sin hardware, igual que en su escenario. Su modelo de datos, en cambio, es débil: no tiene claves foráneas ni transacciones, y el estado de la bicicleta no se guarda, se deduce de otros campos. OpenBike está abandonado (último código de 2021), pero su modelo para GPS, candados y ubicaciones es justo lo que necesitan para crecer a GPS. Leí todo directamente del código fuente con la API de GitHub y `raw.githubusercontent.com`, en las versiones de 2026-10-07.

---

## (a) OpenSourceBikeShare: estado actual y esquema de datos

### Estado del proyecto (verificado)

| Aspecto | Hallazgo | Fuente |
|---|---|---|
| Licencia | GPL-3.0 (`"license": "GPL-3.0-only"`) | [composer.json](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/composer.json), [LICENSE](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/LICENSE) |
| Actividad | Muy activo: 98 commits en `main` desde el 1-ene-2026. Último merge el 2026-09-20 (PR #368). Hay PRs abiertos de sep–oct 2026. El mantenedor principal es `sveneld` (324 commits). | API de GitHub, `/commits?since=2026-01-01` |
| Releases | Solo hay dos: v0.6 "breakthrough" (2015) y v1.0.0 "breakthrough 2" (2024-02-26). Las notas de la 1.0.0 dicen: *"It have many bugs and problems. Just keep it for history"*. La descripción del repo, que pide usar "breakthrough", está desactualizada. Hoy el producto real es `main`, que no tiene versión etiquetada. | [Releases](https://github.com/cyklokoalicia/OpenSourceBikeShare/releases) |
| Framework | **Ya migró a Symfony** (FrameworkBundle, Security, Twig, Form, Translator). composer.json fija `^6.0` y pone un `conflict` con `symfony/security-http &gt;=7.4.18`. Hubo un intento de pasar a Symfony 7.4/8 (PR #366) que se revirtió el 2026-09-17 (PR #367). **No hay `composer.lock` en el repo**, así que no pude saber qué versión exacta se instala. | [composer.json](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/composer.json), [ROADMAP.md](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/ROADMAP.md) |
| PHP y base de datos | PHP `^8.4` (imagen `php:8.4-apache`) y MariaDB 10.3. **No usa ORM**: todo es SQL a mano sobre un envoltorio PDO. | [Dockerfile](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/Dockerfile), [INSTALL.md](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/INSTALL.md), [src/Db/PdoDb.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Db/PdoDb.php) |
| Instalación | Docker Compose con Nginx, PHP/Apache, MariaDB y phpMyAdmin. El esquema sale de `create-database.sql`, y los cambios de versión se aplican con ALTERs manuales descritos en MIGRATION.MD. Para tener el primer admin hay que registrarse y luego poner `privileges = 7` directamente en la tabla. | [INSTALL.md](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/INSTALL.md), [MIGRATION.MD](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/MIGRATION.MD) |
| Extras recientes | API `/api/v1` con tokens JWT y refresh tokens que rotan, contrato OpenAPI, app Android y feed GBFS 2.3. | [README.md](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/README.md), [openapi.yaml](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/openapi.yaml), [GbfsFeedBuilder.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Gbfs/GbfsFeedBuilder.php) |

### Esquema tabla por tabla

Fuente: [docker-data/mysql/create-database.sql](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/docker-data/mysql/create-database.sql).

**Advertencia general:** el esquema no declara ni una FOREIGN KEY; las relaciones de abajo solo existen en la lógica del código. Usa charset `utf8` (3 bytes) y guarda el dinero como `float`.

| Tabla | Campos | Relaciones y notas |
|---|---|---|
| **bikes** | `bikeNum` (PK, se asigna a mano), `currentUser`, `currentStand`, `currentCode` (int) | `currentUser` apunta a users y `currentStand` a stands. **No hay campo de estado**: una bici está prestada si `currentUser` no es NULL y está aparcada si `currentStand` no es NULL. `currentCode` es el código actual del candado; al leerlo se rellena con ceros a 4 dígitos (`LPAD`). |
| **stands** | `standId` (PK), `standName` (UNIQUE, varchar 50), `standDescription`, `standPhoto` (URL), `status` ENUM(`active`, `technical`, `hidden`, `inactive`, `virtual`), `placeName`, `longitude`, `latitude`, `city` | El nombre en MAYÚSCULAS es el identificador público: se usa en SMS y en las URL de los QR. No tiene campo de capacidad. Una "estación de servicio" (taller) además se detecta por el nombre con `REGEXP 'SERVIS$'` ([BikeRepository.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Repository/BikeRepository.php)). `virtual` sirve para eventos fuera de la ciudad ([PR #320](https://github.com/cyklokoalicia/OpenSourceBikeShare/pull/320)). |
| **users** | `userId`, `userName`, `password` (hash), `mail`, `number` (teléfono, es el login), `privileges` (int), `userLimit`, `city`, `isNumberConfirmed`, `registrationDate` | `userLimit` reemplazó la antigua tabla `limits` ([MIGRATION.MD](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/MIGRATION.MD)). La semántica de `privileges` se explica en la sección (c). |
| **history** | `id`, `userId`, `bikeNum`, `time`, `action` ENUM(RENT, RETURN, REVERT, FORCERENT, FORCERETURN, PHONE_CONFIRM_REQUEST, PHONE_CONFIRMED, EMAIL_CONFIRMED, CREDITCHANGE, CREDIT, CHANGECODE), `parameter` (text), `standId`, `pairActionId` | Es a la vez bitácora de eventos y libro contable. `parameter` cambia de significado según la acción: en RENT es el código nuevo, en RETURN el standId, en REVERT `"standId\|código"` y en CREDITCHANGE un JSON `{amount, balance, reason}` (en ese caso `bikeNum = 0`). `pairActionId` enlaza cada RETURN con su RENT; se agregó en 2026 ([PR #362](https://github.com/cyklokoalicia/OpenSourceBikeShare/pull/362) y siguientes). |
| **notes** | `noteId`, `bikeNum` (nullable), `standId` (nullable), `userId`, `note` (varchar 255), `time`, `deleted` | Reportes de daños de una bici o una estación. Se borran de forma lógica (campo `deleted`). |
| **credit** | `userId` (PK), `credit` float(5,2) | Saldo de cada usuario; máximo 999.99. |
| **coupons** | `coupon` (varchar 6, único), `value`, `status` | Estados 0 = activo, 1 = vendido, 2 = usado ([CouponStatus.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Enum/CouponStatus.php)). |
| **registration** | `userId`, `userKey` | Token de confirmación de email. No tiene PK ni fecha de expiración. |
| **received / sent** | Bitácora de SMS entrantes (`sms_uuid`, `sender`, `sms_text`, `IP`) y salientes (`number`, `text`) | `sent` también guarda las respuestas del canal QR ([ScanController.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Controller/ScanController.php)). |
| **remember_me_token** | Tokens persistentes de "recordarme" de Symfony | — |
| **api_refresh_tokens** | `tokenHash`, `userId`, `familyId`, `parentTokenHash`, `replacedByHash`, `expiresAt`, `revokedAt`, `userAgent`, `ipAddress` | Rotación de refresh tokens con revocación por familia. Está bien hecho. |
| **userSettings** | `userId` (único), `settings` (JSON) | Idioma, preferencia de geolocalización, etc. |
| **userClient** | `userId`, `platform` (android/ios), `version`, `lastSeenAt` | Seguimiento de versiones de la app. |
| **geolocation** | `bikeNum`, `longitude`, `latitude`, `time` | Restos sin uso: revisé todos los `.php` de `src/` y ninguno la menciona. |
| **pairing** | `time`, `standid` | Restos sin uso. El propio SQL dice: *"THIS TABLE IS MISSED IN CODE, DO WE NEED IT?"* |

---

## (b) Flujo de préstamo y devolución en OSBS

### Candado mecánico con código rotativo (confirmado)

- Las bicis llevan **candados en U con combinación de 4 dígitos** ([README.md](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/README.md)).
- **El sistema fija el código nuevo, no el usuario.** Se genera con `random_int(100, 9900)` y formato `%04d`. El rango evita los códigos que se ven raros en el dial: 0000–0099 y 9901–9999 ([BikeCodeGenerator.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Rent/BikeCodeGenerator/BikeCodeGenerator.php)).

**Préstamo (RENT)** — [AbstractRentSystem.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Rent/AbstractRentSystem.php) y [BikeRepository.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Repository/BikeRepository.php):

1. Comprueba que la bici exista.
2. Si ya la tiene ese mismo usuario, le devuelve su código. Si la tiene otro, da error.
3. Si los créditos están activados, exige un saldo mínimo (`CREDIT_SYSTEM_MIN_BALANCE`).
4. Comprueba el límite: bicis prestadas &lt; `userLimit`. Con límite 0 responde "Contact the admins to lift the ban".
5. **Solo si `FORCE_STACK` o `WATCHES_STACK` están activos**, revisa también:
   - que la estación exista;
   - que no esté `inactive`;
   - que no sea `technical` ni `hidden`, salvo para usuarios con privilegios ≥ 1;
   - la regla de la "pila": avisa al admin o bloquea si la bici no es la última que se devolvió en esa estación.
6. Lee `currentCode` (el código que tiene puesto el candado ahora) y genera `newCode`.
7. Ejecuta `UPDATE bikes SET currentUser=?, currentCode=newCode, currentStand=NULL`.
8. Escribe en `history` una fila RENT con `parameter = newCode`.
9. Responde (texto de [rentSystem+intl-icu.en.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/translations/rentSystem+intl-icu.en.php)): *"Open with code {currentCode}. Change code immediately to {newCode}… (open, rotate metal part, set new code, rotate metal part back)"*. También muestra las notas de daños abiertas.

**Devolución (RETURN):**

1. Busca la estación por nombre. **No valida el estado de la estación**; el propio código lo admite en un comentario de `GbfsFeedBuilder.php`: *"returnBike() does not gate by stand status"*.
2. Comprueba que la bici sea de ese usuario.
3. Ejecuta `UPDATE … SET currentUser=NULL, currentStand=? WHERE bikeNum=? AND currentUser=?`.
4. Guarda la nota de daños, si la hay.
5. Calcula los cargos de crédito.
6. Escribe una fila RETURN con `parameter = standId` y el `pairActionId` del RENT.
7. Responde: *"Lock with code {currentCode}. Please, rotate the lockpad to 0000 when leaving"*.

En la devolución **el código no cambia**: se queda el que se fijó al prestar, y es el que recibirá el siguiente usuario como "abrir con".

**Consecuencia (inferencia mía, no documentada):** el último usuario conoce el código hasta el siguiente préstamo, así que puede volver a llevarse la bici sin registrarlo. El sistema lo mitiga con control social y con alertas: la regla de la pila y el informe de bicis inactivas. Existe el issue [#119](https://github.com/cyklokoalicia/OpenSourceBikeShare/issues/119) sobre la política de cambio de código.

**Validaciones y concurrencia:**

- **Falla de concurrencia:** `PdoDb` no ofrece transacciones (solo `query`, `exec` y `getLastInsertId`), y `assignToUser` no lleva `AND currentUser IS NULL`. Si dos personas prestan la misma bici a la vez, ambos préstamos se aceptan y el último en escribir sobrescribe al primero. La devolución sí lleva la guarda, pero no revisa cuántas filas cambió.
- **Bug:** si las dos opciones de pila están apagadas, se puede prestar desde estaciones `inactive` o `technical`.

### Revertir, forzar, notas y bicis perdidas

- **Revertir (solo admin):** se usa cuando alguien prestó la bici equivocada o leyó mal el número; así lo describe el botón en [fleet.html.twig](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/templates/admin/fleet.html.twig). Funciona así:
  1. Exige que la bici esté prestada.
  2. Toma la estación de la última devolución y el código del último préstamo.
  3. Devuelve la bici a esa estación con ese código.
  4. Escribe tres filas: REVERT `"standId|código"` y además un RENT y un RETURN sintéticos.
  5. Envía un SMS al usuario anterior si no es el mismo admin ([BikeRevertEventListener.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/EventListener/BikeRevertEventListener.php)).

  No cobra créditos y no se puede hacer por QR ([RentSystemQR.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Rent/RentSystemQR.php)).
- **Préstamo y devolución forzados (admin):** se saltan todas las validaciones (crédito, límite, pila, dueño de la bici). Una devolución forzada de una bici aparcada sirve para reubicarla. No se cobran créditos y quedan registradas como FORCERENT y FORCERETURN.
- **Notas y daños:** el usuario las deja así:
  - al devolver: `RETURN 42 ESTACION texto`;
  - sobre una bici o una estación: `NOTE 42 texto` o `NOTE ESTACION texto`;
  - sobre todas las bicis de una estación: `TAG ESTACION texto`.

  El siguiente usuario las ve al prestar, y los admins reciben aviso por SMS y email. Los admins las borran con `DELNOTE` o `UNTAG` usando un patrón de texto.
  - **Bug:** [UnTagCommand.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/SmsCommand/UnTagCommand.php) no fija `MIN_PRIVILEGES_LEVEL` (el valor por defecto es 0). Cualquier usuario puede borrar las notas de todas las bicis de una estación, aunque la ayuda diga "(for admins)".
- **Bicis perdidas:** **no existe un estado "perdida" o "robada".** Se detectan de forma indirecta con tareas de cron:
  - `app:long_rental_check` avisa de préstamos de más de `WATCHES_LONG_RENTAL` horas ([LongRentalCheckCommand.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Command/LongRentalCheckCommand.php));
  - `app:inactive_stand_bikes_check` avisa de bicis que no se mueven en más de 7 días;
  - otra alerta salta con demasiados préstamos en poco tiempo ([TooManyBikeRentEventListener.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/EventListener/TooManyBikeRentEventListener.php));
  - los comandos `WHERE` y `LAST` muestran quién la tuvo y su teléfono.
- **Créditos (opcional):** [RentalCreditCalculator.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Rent/RentalCreditCalculator.php) maneja:
  - tiempo gratis y tarifa al pasarse;
  - ciclos de precio fijo o que se duplica;
  - cargo por préstamo largo;
  - penalización por volver a prestar en menos de 10 minutos;
  - bono por mover una bici que llevaba mucho tiempo quieta.

  También hay cupones. Las tarifas por "aumentar el límite" y por "infracción" están configuradas, pero **ningún archivo de src/, templates/ ni config/ las usa** (los revisé todos).
- **Registro:**
  1. El usuario se registra y empieza con `userLimit = 0`.
  2. Confirma su teléfono por SMS, si el SMS está activo. Hasta entonces tiene `ROLE_NEWBIE`.
  3. Confirma su email.
  4. Su límite pasa a `USER_BIKE_LIMIT_AFTER_REGISTRATION`, que vale 0 por defecto: un admin tiene que habilitarlo a mano ([UserRegistration.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/User/UserRegistration.php), [EmailConfirmController.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Controller/EmailConfirmController.php)).

### Canales

- **Web:** Twig con Bootstrap, jQuery y DataTables. Incluye un mapa con marcadores de estaciones.
- **SMS:** el webhook es `/receive.php` y hay conectores para EuroSMS y Textmagic.
  - Comandos de usuario: HELP, FREE, RENT, RETURN, WHERE, INFO, NOTE, TAG, UNTAG, CREDIT.
  - Comandos de admin (privilegios ≥ 1): FORCERENT, FORCERETURN, REVERT, LAST, LIST, ADD, CODE, DELNOTE ([src/SmsCommand/](https://github.com/cyklokoalicia/OpenSourceBikeShare/tree/main/src/SmsCommand)).
  - **Falla grave:** el webhook es `PUBLIC_ACCESS` ([security.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/config/packages/security.php)). EuroSMS toma `sender` y `sms_text` de la URL (GET) y Textmagic los toma del cuerpo POST, en ambos casos sin firma ni lista de IPs ([EuroSmsConnector.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/SmsConnector/EuroSmsConnector.php), [TextmagicSmsConnector.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/SmsConnector/TextmagicSmsConnector.php)). Quien conozca el teléfono de un usuario puede suplantarlo. La configuración de nginx del repo tampoco restringe ese endpoint.
- **QR: hay códigos en la bici y en la estación** ([routes.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/config/routes.php)):
  - **QR de la bici:** `{base}/scan.php/rent/{bikeNumber}`. Abre una página de confirmación con la estación y las notas, y el préstamo se hace por POST `rent=yes`. No vi token CSRF en [scan/rent.html.twig](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/templates/scan/rent.html.twig).
  - **QR de la estación:** `{base}/scan.php/return/{standName}`. **Devuelve en el mismo GET** la única bici que tenga el usuario; si tiene más de una, se niega.
  - Ambos exigen sesión iniciada.
  - El PDF con todos los QR se genera en `/admin/qrCodeGenerator` (solo superadmin): TCPDF, A5 apaisado, una página por bici y por estación activa o técnica ([QrCodeGeneratorController.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Controller/QrCodeGeneratorController.php)).
  - `/.well-known/assetlinks.json` hace que al escanear se abra directamente la app Android.
- **API v1 con JWT** ([config/routes/api.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/config/routes/api.php)) y **GBFS 2.3**. En el feed GBFS, `num_docks_available` va en `null` y `is_returning` siempre en `true`.

---

## (c) Funciones de administración en OSBS

- **Roles** ([User.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/App/Entity/User.php)):

  | Condición | Rol |
  |---|---|
  | Teléfono sin confirmar | `ROLE_NEWBIE` |
  | `privileges ≥ 1` | `ROLE_ADMIN` |
  | `privileges ≥ 7` | `ROLE_SUPER_ADMIN` |

  Además, el **bit 2** (`privileges &amp; 2`) decide quién recibe las notificaciones de admin ([AdminNotifier.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Notifier/AdminNotifier.php)). El mismo campo mezcla umbral y máscara de bits.
  - **Escalada de privilegios:** cualquier `ROLE_ADMIN` puede usar `PATCH /api/v1/admin/users/{id}` para poner cualquier valor en `privileges`, incluido 7 sobre sí mismo. No hay ninguna comprobación ni registro de auditoría ([Admin/UsersController.php](https://github.com/cyklokoalicia/OpenSourceBikeShare/blob/main/src/Controller/Api/V1/Admin/UsersController.php)).
- **Pestaña Flota:** buscar dónde está una bici, ver su último uso (10 eventos y notas), préstamo y devolución forzados, revertir, fijar código (queda en el historial como CHANGECODE) y borrar notas.
- **Pestaña Estaciones:** **solo se puede cambiar el estado** (`PATCH /admin/stands/{id}`). **No hay alta ni edición de estaciones ni de bicicletas** en la interfaz ni en la API, y `StandRepository` y `BikeRepository` no tienen ningún INSERT. Las estaciones y bicis se crean directamente en la base de datos; por eso phpMyAdmin viene en el docker.
- **Pestaña Usuarios:** editar nombre, email, teléfono, privilegios y límite; ver la fecha de registro y las versiones de app; añadir crédito (1 a 10 veces el saldo mínimo).
- **Pestaña Crédito:** generar cupones y marcarlos como vendidos.
- **Pestaña Informes:** estadísticas diarias, estadísticas por usuario y año, y bicis inactivas. Cada usuario ve además sus propias estadísticas anuales y su historial de crédito.
- **Tareas de cron:** `app:long_rental_check` y `app:inactive_stand_bikes_check`.

---

## (d) Lecciones de OSBS

**Para adoptar:**
1. El código de candado que rota en cada préstamo: lo genera el servidor, usa un rango sin códigos ambiguos, el usuario recibe el código actual y el nuevo, y se le pide girar el dial a 0000 al irse. Es perfecto para funcionar sin hardware.
2. QR en la bici para prestar y QR en la estación para devolver. Son URL simples y se generan en un PDF imprimible.
3. Estados de estación (active, technical, hidden, inactive, virtual) y una estación "taller" para bicis en reparación.
4. Las notas de daños visibles para el siguiente usuario, con aviso a los admins y borrado lógico.
5. Un límite de bicis por usuario que empieza en 0 y lo habilita un admin. Encaja con un programa municipal que verifique la identidad.
6. Las operaciones de admin: forzar, revertir, fijar código, ver dónde está una bici y quién la tuvo.
7. Las alertas automáticas: préstamo largo, demasiados préstamos, bicis inactivas, regla de la pila.
8. Emparejar cada préstamo con su devolución. El propio proyecto está pasando a un "libro de préstamos con máquina de estados" ([PR #347](https://github.com/cyklokoalicia/OpenSourceBikeShare/pull/347)); conviene hacerlo así desde el día uno.
9. GBFS, una API con contrato OpenAPI, la rotación de refresh tokens y la migración gradual de hashes de contraseña.

**Para evitar:**
1. Sin claves foráneas, sin transacciones y SQL a mano: hay carreras al prestar.
2. Dinero en `float`.
3. La columna `parameter` con distinto significado según la acción.
4. `history` como cajón de sastre: mezcla préstamos, crédito y confirmaciones.
5. El estado de la bici deducido de campos NULL: no hay forma de marcar taller, perdida o dada de baja, y el taller se detecta por el nombre `SERVIS$`.
6. `privileges` como entero ambiguo, que permite la escalada descrita arriba.
7. El webhook de SMS sin autenticar.
8. Cambiar datos con un GET (la devolución por QR).
9. El estado de la estación no se valida al devolver.
10. Usar el nombre de la estación como identificador: si se renombra, los QR impresos dejan de servir.
11. No poder dar de alta bicis ni estaciones desde la interfaz.
12. Tokens generados con `mt_rand`/`md5` en el registro y en el comando ADD.
13. Migraciones manuales, sin `composer.lock` y sin releases etiquetadas desde 2024.

---

## (e) OpenBike (transportkollektiv)

- **Estado:** licencia MIT ([docs.openbike.dev](https://docs.openbike.dev/)).
  - Último commit de código del backend `cykel`: 2021-11-04.
  - Último commit del repo de documentación: 2022-04-06.
  - El adaptador del candado BL10 se actualizó por última vez en feb-2024.
  - **En la práctica está sin mantenimiento.** Usa Django 3.1.13 ([requirements.txt](https://github.com/transportkollektiv/cykel/blob/master/requirements.txt)), una versión que por lo que sé ya no recibe soporte.
  - Según la documentación, funcionó en Ulm entre 2019 y 2022.
- **Stack y módulos** ([README de openbike](https://github.com/transportkollektiv/openbike), [requirements.rst](https://github.com/transportkollektiv/openbike/blob/main/docs/administrator/requirements.rst)):
  - **cykel:** backend en Django y Django REST Framework, con PostgreSQL y PostGIS obligatorios y Redis con Celery.
  - **voorwiel:** web pública en Vue y Vuetify, como PWA, con mapa Leaflet que lee el GBFS.
  - **skoetsel:** mapa de mantenimiento.
  - **Adaptadores:** `cykel-ttn` y `cykel-ttn-wifi` para rastreadores LoRaWAN; `cykel-lock-bl10` y `cykel-lock-omni` para candados electrónicos.
  - **El login es solo OAuth** (django-allauth); no tiene registro propio.
- **Modelo de datos** ([bikesharing/models/](https://github.com/transportkollektiv/cykel/tree/master/bikesharing/models)):
  - **Bike:**
    - dos campos de estado independientes: **`availability_status`** (deshabilitada, en uso, disponible) y **`state`** (usable, rota, en reparación, perdida);
    - relaciones: `vehicle_type`, `lock` (uno a uno) y `current_station`;
    - datos de seguimiento: `last_reported`, `internal_note`, `photo`, el número de bastidor (`vehicle_identification_number`) y `current_range_meters`;
    - `non_static_bike_uuid`, que **rota en cada préstamo** para proteger la privacidad en el GBFS.
  - **Station:** `status`, `station_name`, `location` (Point de PostGIS) y `max_bikes`.
  - **Rent:** `rent_start` y `rent_end`, `start/end_location` (apuntan a Location), `start/end_station`, `bike` y `user`.
  - **Location:** `geo`, **`source`** (candado, rastreador, usuario o sistema), `accuracy`, `reported_at` y **`internal`** (oculta al público).
  - **LocationTracker:** `device_id`, `battery_voltage`, `tracker_status` (activo, inactivo, perdido, retirado) y `internal`. Una bici puede tener varios rastreadores. **LocationTrackerType** guarda los umbrales de batería.
  - **Lock:** `lock_id` y `unlock_key`. **LockType** tiene `form_factor` (combinación o electrónico) y `endpoint_url`.
  - **VehicleType:** tipo de vehículo y propulsión según GBFS 2.1.
  - **CykelLogEntry** ([cykel_log_entry.py](https://github.com/transportkollektiv/cykel/blob/master/cykel/models/cykel_log_entry.py)): bitácora con relación genérica a cualquier objeto, `action_type` y `data` en JSON.
- **Flujo** ([api/views.py](https://github.com/transportkollektiv/cykel/blob/master/api/views.py), [rent.py](https://github.com/transportkollektiv/cykel/blob/master/bikesharing/models/rent.py)):
  - **Préstamo:** exige que la bici esté disponible y que el usuario tenga el permiso `add_rent`. Guarda como origen la ubicación del móvil o la última ubicación pública de la bici, y pone la bici en "en uso".
  - **Desbloqueo:** con candado de combinación devuelve un `unlock_key` **fijo, que no rota** (es más débil que OSBS). Con candado electrónico hace un POST a `{endpoint_url}/{lock_id}/unlock`.
  - **Devolución:** la bici se **asigna a la estación activa más cercana dentro de `station_match_max_distance`** (20 m por defecto). Si no hay ninguna, queda como "flotante" (aparcada fuera de estación).
  - No hay límite por usuario ni pagos.
- **GPS:** los adaptadores envían POST a `/api/bike/updatelocation` con una API key, `device_id`, latitud, longitud, precisión y batería. Con eso se crea una Location, se reasigna la estación y se registran los avisos de bici perdida.
  - Tareas Celery ([tasks.py](https://github.com/transportkollektiv/cykel/blob/master/bikesharing/tasks.py)): préstamos de más de 4 h, bicis sin uso en 3 días, rastreadores sin reportar en 2 h.
  - La documentación sobre rastreadores ([trackers.rst](https://github.com/transportkollektiv/openbike/blob/main/docs/operator/trackers.rst)) es una buena guía de compra: GNSS frente a wifi, LoRaWAN, el apagado de las redes 2G y la advertencia de que la ubicación que manda el móvil se puede falsear.
- **GBFS 2.1**, con `free_bike_status`.
- **Lo que pueden aprovechar** para empezar sin hardware y crecer a GPS:
  - separar disponibilidad y estado físico en dos campos;
  - una tabla de ubicaciones con fuente y precisión: hoy fuente "sistema" (las coordenadas de la estación) o "usuario", mañana "rastreador";
  - Lock y Tracker como entidades propias con un "tipo" y adaptadores, de modo que el núcleo no conozca los protocolos;
  - asignar la estación por distancia, lo que permite un sistema mixto de estaciones y bicis flotantes;
  - el identificador público que rota, la bitácora genérica y la salud de los rastreadores.

---

## (f) Otros proyectos con actividad reciente

1. **CommonsBooking** — [github.com/wielebenwir/commonsbooking](https://github.com/wielebenwir/commonsbooking). Plugin de WordPress en PHP, GPL-2.0, versión 2.11.2 del 2026-08-26. Es el estándar alemán para compartir bicis de carga.
   - **Modelo:** Item, Location, Timeframe, Booking y Restriction.
     - Timeframe tiene tipos: horario de apertura, reservable, festivos, reparación, reserva y reserva cancelada.
     - Restriction tiene tipo "reparación" o "aviso" y estado ninguno, activa o resuelta.
   - **Lo que aporta:**
     - reservas por adelantado;
     - ventanas de "fuera de servicio" con aviso a los usuarios;
     - reglas de límite configurables (máximo de días por semana o mes, sin reservas encadenadas ni simultáneas), en [BookingRule.php](https://github.com/wielebenwir/commonsbooking/blob/master/src/Service/BookingRule.php);
     - **códigos de candado por bici y por día**, generados con antelación, en [BookingCodes.php](https://github.com/wielebenwir/commonsbooking/blob/master/src/Repository/BookingCodes.php).
2. **Traccar** — [github.com/traccar/traccar](https://github.com/traccar/traccar). En Java, Apache-2.0, versión 6.16.0 del 2026-09-27, compatible con más de 200 protocolos de dispositivos GPS.
   - **Modelo:** Device, Position, Event, Geofence, Maintenance y otros ([org/traccar/model](https://github.com/traccar/traccar/tree/master/src/main/java/org/traccar/model)).
   - **Lo que aporta:** en la fase GPS no tendrían que escribir decodificadores. Traccar reenvía posiciones (`forward.url`, en JSON y con reintentos) y eventos (`event.forward.url`) a su backend ([traccar.org/forward](https://www.traccar.org/forward/)). Sería el mismo patrón de adaptador que usa cykel.
3. **GBFS y pybikes/CityBikes:**
   - **GBFS:** la versión estable es la 3.0 (2024-04-11) y la 3.1-RC3 salió el 2026-05-26 ([MobilityData/gbfs](https://github.com/MobilityData/gbfs)). En la 3.0, `free_bike_status` pasó a llamarse `vehicle_status`. Para estaciones sin anclajes electrónicos existe `is_virtual_station`, y `num_docks_available` no es obligatorio cuando la capacidad es ilimitada ([gbfs.md](https://github.com/MobilityData/gbfs/blob/master/gbfs.md)).
   - **pybikes** ([eskerda/pybikes](https://github.com/eskerda/pybikes), AGPL-3.0, actualizado el 2026-10-05) es el agregador que lee esos feeds. No es un sistema de gestión, pero publicar el feed haría visible el sistema de Valledupar en CityBikes y otras apps.

**Descartados:** dragorhast/server (archivado en 2023), JoeCao/qbike (demo de arquitectura) y ubahnverleih/WoBike (solo documenta APIs de terceros).

---

## Lo que no pude verificar

- La versión exacta de Symfony que se instala: no hay `composer.lock`.
- Si el sistema en producción (whitebikes.info) protege el webhook de SMS desde el servidor.
- Las fechas de Ulm (2019–2022): salen de la página de documentación ya publicada, no de un archivo fuente.
- La falta de token CSRF en el préstamo por QR podría estar mitigada por la cookie SameSite; no revisé esa configuración.
- Que el último usuario pueda volver a llevarse la bici con el código que conoce es una inferencia lógica del flujo, no algo que el proyecto documente.
