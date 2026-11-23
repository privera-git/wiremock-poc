FROM eclipse-temurin:21-jre
ARG KARATE_VERSION=2.1.3
WORKDIR /karate
ADD https://github.com/karatelabs/karate/releases/download/v${KARATE_VERSION}/karate-${KARATE_VERSION}.jar lib/karate.jar
WORKDIR /work
ENTRYPOINT ["java", "-jar", "/karate/lib/karate.jar"]
CMD ["run", "features"]
