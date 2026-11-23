Feature: Fallas inyectadas con el header X-Mock-Fault

  Background:
    * url apiUrl
    * path 'payments', 'abcd-1234-6789'

  Scenario: error-500 simula un error interno
    Given header X-Mock-Fault = 'error-500'
    When method get
    Then status 500
    And match response == { code: 'ERROR_INTERNO', error: '#string' }

  Scenario Outline: <falla> incluye Retry-After para que el consumidor reintente
    Given header X-Mock-Fault = '<falla>'
    When method get
    Then status <status>
    And match response.code == '<codigo>'
    And match responseHeaders['Retry-After'][0] == '<retry>'

    Examples:
      | falla           | status | codigo                 | retry |
      | unavailable-503 | 503    | SERVICIO_NO_DISPONIBLE | 30    |
      | rate-limit-429  | 429    | LIMITE_EXCEDIDO        | 60    |

  Scenario: timeout responde recién a los 10 segundos
    * configure readTimeout = 15000
    Given header X-Mock-Fault = 'timeout'
    When method get
    Then status 504
    And match response.code == 'TIEMPO_AGOTADO'
    And assert responseTime >= 10000

  Scenario Outline: <falla> corta la conexión sin respuesta HTTP válida
    * assert failsAtConnectionLevel('<falla>')

    Examples:
      | falla              |
      | connection-reset   |
      | empty-response     |
      | malformed-response |

  Scenario: Un valor desconocido del header se ignora
    Given header X-Mock-Fault = 'no-existe'
    When method get
    Then status 200
    And match response.status == 'APPROVED'
