# wiremock-poc

Mock de una **API de pagos ficticia** construido con [WireMock](https://wiremock.org/) standalone y empaquetado como imagen Docker.

Esta prueba de concepto muestra cómo simular una dependencia HTTP **de forma completa**: respuestas exitosas, validaciones, casos de borde y fallas de red o de infraestructura. Así los consumidores pueden probar su manejo de errores sin depender de un sistema real.

- Contrato: [`openapi/pagos.yaml`](openapi/pagos.yaml) (OpenAPI 3.0.3).
- Stubs: [`wiremock/mappings/`](wiremock/mappings/), con un archivo por caso.
- Evidencia: [`tests/features/`](tests/features/), donde 35 escenarios Karate verifican cada caso descrito abajo.
- Imagen: `priveradocker/wiremock-poc` en Docker Hub (`linux/amd64` y `linux/arm64`).

## Uso rápido

Requisito único: Docker (Desktop o Engine con Compose v2).

```bash
make run     # levanta el mock en http://localhost:8080
make test    # ejecuta las pruebas Karate y abre el reporte HTML
make lint    # valida el contrato OpenAPI
make check   # lint + test (lo mismo que ejecuta CI)
make stop    # detiene todo
make help    # lista todos los comandos
```

Para usar la imagen publicada sin clonar el repo:

```bash
docker run --rm -p 8080:8080 priveradocker/wiremock-poc:latest
curl -s http://localhost:8080/payments/abcd-1234-6789
```

## Endpoints

| Método | Ruta | Descripción |
| --- | --- | --- |
| `POST` | `/payments` | Registra un pago en CLP. Responde `201` con estado `PENDING` |
| `GET` | `/payments/{id}` | Consulta un pago por identificador (`xxxx-xxxx-xxxx`, hexadecimal en minúsculas) |
| `GET` | `/health` | Disponibilidad del servicio |

Todas las respuestas de error usan el mismo esquema:

```json
{ "code": "MONTO_INVALIDO", "error": "el monto debe ser mayor a cero" }
```

`code` es estable y está pensado para la lógica del consumidor. `error` es un texto para personas y puede cambiar.

### Datos semilla

| `id` | Monto | Estado |
| --- | --- | --- |
| `abcd-1234-0001` | 8000 | `PENDING` |
| `abcd-1234-6789` | 15000 | `APPROVED` |
| `abcd-1234-0002` | 2500 | `REJECTED` |

> **El mock no guarda estado.** Un `POST /payments` exitoso devuelve un `id` aleatorio, pero ese pago no queda registrado: consultarlo después con `GET` responde `404`. Para consultar pagos existentes, usar los datos semilla.

## Tipos de error

| HTTP | `code` | Endpoint | Condición |
| --- | --- | --- | --- |
| 400 | `MONTO_INVALIDO` | `POST /payments` | `amount` es `0` o negativo |
| 400 | `MONTO_NO_ENTERO` | `POST /payments` | `amount` tiene decimales (`15000.5`, también `15000.0`) |
| 400 | `MONEDA_NO_SOPORTADA` | `POST /payments` | `currency` presente y distinta de `CLP` (incluye `clp`) |
| 400 | `SOLICITUD_INVALIDA` | `POST /payments` | Cuerpo que no es JSON, `{}`, falta `amount` o `currency`, `amount` nulo o como texto (`"15000"`) |
| 422 | `MONTO_EXCEDE_LIMITE` | `POST /payments` | `amount` mayor a `10000000` |
| 400 | `ID_INVALIDO` | `GET /payments/{id}` | `id` no calza con `^[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}$` (por ejemplo, mayúsculas) |
| 404 | `PAGO_NO_ENCONTRADO` | `GET /payments/{id}` | `id` con formato válido pero que no es un dato semilla |
| 405 | `METODO_NO_PERMITIDO` | `/payments`, `/payments/{id}` | Método no soportado (`GET /payments`, `PUT`, `DELETE`, etc.) |
| 404 | `RECURSO_NO_ENCONTRADO` | Cualquier otra ruta | Ruta no definida en el contrato |

## Condiciones de borde

| Caso | Entrada | Resultado |
| --- | --- | --- |
| Monto mínimo aceptado | `amount: 1` | `201` |
| Monto cero (límite inferior excluido) | `amount: 0` | `400 MONTO_INVALIDO` |
| Monto máximo aceptado | `amount: 10000000` | `201` |
| Máximo + 1 | `amount: 10000001` | `422 MONTO_EXCEDE_LIMITE` |
| Entero escrito con decimal | `amount: 15000.0` | `400 MONTO_NO_ENTERO` |
| Tipo incorrecto | `amount: "15000"` | `400 SOLICITUD_INVALIDA` |
| Moneda en minúsculas | `currency: "clp"` | `400 MONEDA_NO_SOPORTADA` |
| Varios errores a la vez | `amount: 0, currency: "USD"` | `400 MONTO_INVALIDO` (ver precedencia) |
| `id` en mayúsculas | `ABCD-1234-6789` | `400 ID_INVALIDO` |

**Precedencia de validaciones** (implementada con `priority` en los stubs, donde el número menor gana):

1. Fallas inyectadas (`X-Mock-Fault`).
2. Monto: no positivo o sobre el límite.
3. Monto con decimales.
4. Moneda.
5. Respuestas exitosas y datos semilla.
6. Validaciones genéricas: `404` por id, `400` por formato o cuerpo, `405`.
7. `404` para rutas no definidas.

## Fallas inyectables

Cualquier endpoint acepta el header **`X-Mock-Fault`** (solo existe en el mock) para simular una dependencia degradada. Si el valor no se reconoce, el header se ignora.

| Valor | Efecto | Qué permite probar en el consumidor |
| --- | --- | --- |
| `error-500` | `500 ERROR_INTERNO` | Manejo de error genérico del servidor |
| `unavailable-503` | `503 SERVICIO_NO_DISPONIBLE` + `Retry-After: 30` | Reintentos con backoff, circuit breaker |
| `rate-limit-429` | `429 LIMITE_EXCEDIDO` + `Retry-After: 60` | Respeto de límites de tasa |
| `timeout` | Espera 10 s y luego responde `504 TIEMPO_AGOTADO` | Timeouts del cliente (configurar < 10 s para verlo cortar) |
| `connection-reset` | Cierra la conexión con RST | Errores de E/S y reintentos |
| `empty-response` | Cierra la conexión sin enviar nada | Respuestas vacías |
| `malformed-response` | Envía `200` y luego bytes corruptos | Parsers robustos ante respuestas corruptas |

```bash
curl -i -H 'X-Mock-Fault: unavailable-503' http://localhost:8080/payments/abcd-1234-6789
```

> **Detrás de un proxy o balanceador** (Cloud Run, Ingress, API Gateway), las tres fallas de conexión (`connection-reset`, `empty-response`, `malformed-response`) las intercepta el proxy. El cliente probablemente recibirá un `502`/`503` del proxy en lugar del corte de conexión. Las fallas HTTP (`500`, `503`, `429`, `timeout`) llegan intactas.

## Estructura

```
openapi/pagos.yaml          Contrato OpenAPI 3 (fuente de verdad)
wiremock/mappings/
  payments/                 Stubs de /payments (un archivo por caso)
  faults/                   Fallas inyectables por header
  health/                   /health
  catch-all.json            404 para rutas no definidas
tests/features/             Pruebas Karate (evidencia de cada caso)
Dockerfile                  Imagen: wiremock/wiremock:3.13.2 + stubs, usuario sin privilegios
redocly.yaml                Reglas de lint del contrato
```

Para agregar un caso: crear un JSON en `wiremock/mappings/`, documentarlo en `openapi/pagos.yaml` y en este README, agregar su escenario en `tests/features/` y ejecutar `make check`.

## CI y publicación

El workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) hace lo siguiente:

| Evento | Qué hace |
| --- | --- |
| Pull request a `main` / push a `main` | Lint del contrato + pruebas Karate. **No publica** |
| Tag `vX.Y.Z` sobre un commit de `main` | Lo anterior + build multi-arquitectura + push a Docker Hub con tags `X.Y.Z` y `latest` |

Un tag de pre-release (`v1.2.0-rc.1`) publica solo `1.2.0-rc.1`, sin `latest`. Un tag que no apunte a un commit de `main` hace fallar el job.

```bash
git tag v0.1.0 && git push origin v0.1.0
```

Configuración necesaria en el repo de GitHub:

| Tipo | Nombre | Valor |
| --- | --- | --- |
| Variable | `DOCKERHUB_USERNAME` | Usuario de Docker Hub |
| Secret | `DOCKERHUB_TOKEN` | Personal Access Token con permiso *Read & Write* y con expiración |

## Consideraciones de despliegue

- **Puerto:** la imagen escucha en `$PORT` (por defecto `8080`), que es compatible con Cloud Run.
- **Admin API expuesta:** WireMock publica `/__admin`, que permite listar, **crear y borrar stubs** en tiempo de ejecución. En un despliegue con URL pública, cualquiera podría alterar el mock. Opciones, en orden de preferencia:
  1. Restringir el acceso al servicio. En Cloud Run: `--no-allow-unauthenticated` + IAM.
  2. Proteger el admin con Basic Auth mediante la variable `WIREMOCK_OPTIONS`, que la imagen agrega a los argumentos de arranque:

     ```bash
     docker run -e WIREMOCK_OPTIONS="--admin-api-basic-auth usuario:clave" ...
     ```

     En Cloud Run, la credencial debe venir de Secret Manager, no en texto plano.
- **Sin estado:** cada instancia responde igual. Escalar a varias réplicas no cambia el comportamiento.

## Licencia

[MIT](LICENSE)
