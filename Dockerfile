# Imagen del mock de la API de pagos (WireMock standalone + stubs del repo).
# Versión fijada a propósito: actualizarla con un PR, nunca usar :latest.
FROM wiremock/wiremock:3.13.2

LABEL org.opencontainers.image.title="wiremock-poc" \
      org.opencontainers.image.description="Mock WireMock de una API de pagos ficticia, con casos de borde y fallas inyectables" \
      org.opencontainers.image.source="https://github.com/privera-git/wiremock-poc" \
      org.opencontainers.image.licenses="MIT"

COPY --chown=10001:10001 wiremock/ /home/wiremock/

# Usuario sin privilegios (Cloud Run y Kubernetes no requieren root).
USER 10001

# Cloud Run inyecta PORT; en local se usa 8080.
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", "exec /docker-entrypoint.sh --port \"${PORT}\" --disable-banner \"$@\"", "--"]
