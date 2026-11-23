Feature: Salud del mock (GET /health)

  Scenario: El mock responde UP
    Given url apiUrl
    And path 'health'
    When method get
    Then status 200
    And match response == { status: 'UP' }

  Scenario: Una ruta no definida responde 404 con el esquema de error
    Given url apiUrl
    And path 'ruta-inexistente'
    When method get
    Then status 404
    And match response == { code: 'RECURSO_NO_ENCONTRADO', error: '#string' }
