function fn() {
  var System = Java.type('java.lang.System');
  var apiUrl = System.getenv('API_URL') || 'http://localhost:8080';

  // Hace una llamada que debe fallar a nivel de conexión (sin respuesta HTTP válida).
  // Devuelve true si el cliente recibió un error de E/S, como ocurriría con una dependencia caída.
  var failsAtConnectionLevel = function (fault) {
    try {
      var URL = Java.type('java.net.URL');
      var conn = new URL(apiUrl + '/payments/abcd-1234-6789').openConnection();
      conn.setRequestProperty('X-Mock-Fault', fault);
      conn.setConnectTimeout(3000);
      conn.setReadTimeout(5000);
      conn.getResponseCode();
      conn.getInputStream().readAllBytes();
      return false;
    } catch (e) {
      return true;
    }
  };

  return { apiUrl: apiUrl, failsAtConnectionLevel: failsAtConnectionLevel };
}
