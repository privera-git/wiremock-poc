Feature: Registrar pago (POST /payments) — éxito, límites y validaciones

  Background:
    * url apiUrl
    * path 'payments'

  Scenario Outline: Pago válido en los límites del rango permitido (<monto>)
    Given request { amount: <monto>, currency: 'CLP' }
    When method post
    Then status 201
    And match response == { id: '#regex [0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}', amount: <monto>, currency: 'CLP', status: 'PENDING' }

    Examples:
      | monto    |
      | 1        |
      | 15000    |
      | 10000000 |

  Scenario Outline: Monto no positivo (<monto>) se rechaza con 400
    Given request { amount: <monto>, currency: 'CLP' }
    When method post
    Then status 400
    And match response == { code: 'MONTO_INVALIDO', error: 'el monto debe ser mayor a cero' }

    Examples:
      | monto |
      | 0     |
      | -100  |

  Scenario: Monto sobre el máximo (límite + 1) se rechaza con 422
    Given request { amount: 10000001, currency: 'CLP' }
    When method post
    Then status 422
    And match response.code == 'MONTO_EXCEDE_LIMITE'

  Scenario Outline: Monto con decimales (<monto>) se rechaza: CLP no tiene decimales
    Given request { amount: <monto>, currency: 'CLP' }
    When method post
    Then status 400
    And match response.code == 'MONTO_NO_ENTERO'

    Examples:
      | monto   |
      | 15000.5 |
      | 15000.0 |

  Scenario Outline: Moneda no soportada ('<moneda>') se rechaza con 400
    Given request { amount: 15000, currency: '<moneda>' }
    When method post
    Then status 400
    And match response == { code: 'MONEDA_NO_SOPORTADA', error: 'moneda no soportada' }

    Examples:
      | moneda |
      | USD    |
      | clp    |

  Scenario: Con varios errores, la validación del monto tiene precedencia
    Given request { amount: 0, currency: 'USD' }
    When method post
    Then status 400
    And match response.code == 'MONTO_INVALIDO'

  Scenario Outline: Cuerpo inválido o incompleto se rechaza con 400 (<caso>)
    Given request <cuerpo>
    And header Content-Type = 'application/json'
    When method post
    Then status 400
    And match response.code == 'SOLICITUD_INVALIDA'

    Examples:
      | caso                 | cuerpo                                 |
      | monto como texto     | { amount: '15000', currency: 'CLP' }   |
      | monto nulo           | { amount: null, currency: 'CLP' }      |
      | sin moneda           | { amount: 15000 }                      |
      | sin monto            | { currency: 'CLP' }                    |
      | objeto vacío         | {}                                     |
      | no es JSON           | 'esto no es json'                      |
