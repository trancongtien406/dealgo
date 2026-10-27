# Photon (komoot) OSM geocoder, Vietnam-only index, for DealGo place search.
# Official release jar from https://github.com/komoot/photon/releases ; data © OpenStreetMap contributors (ODbL).
FROM eclipse-temurin:21-jre-jammy
ARG PHOTON_VERSION=1.3.0
RUN apt-get update && apt-get install -y --no-install-recommends curl zstd ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -u 2322 -m -d /photon photon \
 && curl -fsSL -o /opt/photon.jar "https://github.com/komoot/photon/releases/download/${PHOTON_VERSION}/photon-${PHOTON_VERSION}.jar"
COPY photon-import.sh /usr/local/bin/photon-import
RUN chmod 755 /usr/local/bin/photon-import
USER photon
WORKDIR /photon
EXPOSE 2322
CMD ["sh", "-c", "exec java $JAVA_OPTS -jar /opt/photon.jar serve -data-dir /photon -listen-ip 0.0.0.0 -listen-port 2322 -max-results 15 -max-reverse-results 5"]
