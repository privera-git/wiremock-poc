Feature: Consultar pago (GET /payments/{id})

  Background:
    * url apiUrl

  Scenario Outline: Pagos semilla en cada estado (<estado>)
    Given path 'payments', '<id>'
    When method get
    Then status 200
    And match response == { id: '<id>', amount: <monto>, currency: 'CLP', status: '<estado>' }

    Examples:
      | id             | monto | estado   |
      | abcd-1234-0001 | 8000  | PENDING  |
      | abcd-1234-6789 | 15000 | APPROVED |
      | abcd-1234-0002 | 2500  | REJECTED |

  Scenario: Identificador con formato válido pero sin pago responde 404
    Given path 'payments', 'ffff-0000-0000'
    When method get
    Then status 404
    And match response == { code: 'PAGO_NO_ENCONTRADO', error: 'pago no encontrado' }

  Scenario Outline: Identificador con formato inválido (<id>) responde 400
    Given path 'payments', '<id>'
    When method get
    Then status 400
    And match response.code == 'ID_INVALIDO'

    Examples:
      | id             |
      | ABCD-1234-6789 |
      | xyz            |

  Scenario Outline: Método no permitido (<metodo>) responde 405
    Given path 'payments', 'abcd-1234-6789'
    When method <metodo>
    Then status 405
    And match response.code == 'METODO_NO_PERMITIDO'

    Examples:
      | metodo |
      | delete |
      | put    |
