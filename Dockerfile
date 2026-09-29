FROM --platform=$BUILDPLATFORM eclipse-temurin:21-jdk-jammy AS engine
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# Pin the original engine, including its instrumentation, maps and rules.
ARG BATTLECODE_REVISION=28975a487c1a30ed2b5bed644fe6ecd2c3dd1482
RUN git init . && git remote add origin https://github.com/battlecode/battlecode25.git \
    && git fetch --depth 1 origin "$BATTLECODE_REVISION" && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "$BATTLECODE_REVISION"
# The original JSI snapshot repository has disappeared. Recover only that
# dependency's unchanged classes from the official 2025 release (hash pinned).
ADD --checksum=sha256:14fab721eefa9bfc9f01922193ceb88826934429e703ca7b197b0ace97bceed0 https://releases.battlecode.org/maven/org/battlecode/battlecode25-java/1.0.0/battlecode25-java-1.0.0.jar /released-engine.jar
RUN mkdir /jsi && cd /jsi && jar xf /released-engine.jar net/sf/jsi META-INF/maven/net.sf.jsi build.properties \
    && jar cf /jsi.jar . \
    && sed -i "s@\[group: 'net.sf.jsi', name: 'jsi', version: '1.1.0-SNAPSHOT'\]@files('/jsi.jar')@" /build/engine/build.gradle
RUN ./gradlew --no-daemon :engine:jar
RUN mkdir /engine && cp engine/build/libs/*.jar /engine/battlecode.jar \
    && cp -r engine/src/main/battlecode/world/resources /engine/maps && git rev-parse HEAD > /engine/revision.txt
COPY java /adapter-src
RUN javac --release 21 -cp /engine/battlecode.jar -d /engine/adapter /adapter-src/softmax/ReplayResult.java

FROM --platform=$BUILDPLATFORM node:22-bookworm-slim AS viewer
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates python3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=engine /build/schema /build/schema
COPY --from=engine /build/client /build/client
COPY scripts/prepare_viewer.py /build/prepare_viewer.py
RUN git config --global url."https://github.com/".insteadOf ssh://git@github.com/ \
    && cd /build/schema && npm ci --ignore-scripts \
    && cd /build/client && npm ci --ignore-scripts
RUN python3 /build/prepare_viewer.py /build/client && cd /build/client && npm run build

FROM eclipse-temurin:21-jdk-jammy
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=engine /engine /opt/battlecode
COPY --from=viewer /build/client/dist /opt/battlecode/viewer
WORKDIR /opt/runner
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel \
    && pip3 install --no-cache-dir .
# The existing game-hosted runner stages root-owned output directories.
# Match that contract; uploaded Java remains subject to Battlecode instrumentation.
ENV BATTLECODE_HOME=/opt/battlecode PYTHONUNBUFFERED=1
ENTRYPOINT ["battlecode2025"]
CMD ["serve"]
