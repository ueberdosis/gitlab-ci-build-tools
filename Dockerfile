FROM golang:alpine AS golang
MAINTAINER "Kris Siepert <m@kris.cool>"

RUN apk add --no-cache git && \
    go get github.com/fraunhoferfokus/deckschrubber

FROM docker:git
MAINTAINER "Kris Siepert <m@kris.cool>"

ENV SONAR_SCANNER_VERSION 3.3.0.1492

# install tools
RUN apk add --no-cache bash nodejs curl jq gettext ca-certificates git

# install docker-compose
ENV COMPOSE_INTERACTIVE_NO_CLI 1
RUN apk add --no-cache py-pip python-dev libffi-dev openssl-dev gcc libc-dev make && \
    pip install --upgrade pip && \
    pip install --user docker-compose && \
    mv /root/.local/bin/docker-compose /usr/local/bin/docker-compose

# install deckschrubber
COPY --from=golang /go/bin/deckschrubber /usr/local/bin/deckschrubber

# install sonar scanner
ADD https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip /tmp/sonar-scanner.zip
RUN apk add --no-cache openjdk8-jre && \
    cd /tmp && unzip sonar-scanner.zip && \
    mv -fv /tmp/sonar-scanner-${SONAR_SCANNER_VERSION}/bin/sonar-scanner /usr/bin && \
    chmod a+x /usr/bin/sonar-scanner && \
    mv -fv /tmp/sonar-scanner-${SONAR_SCANNER_VERSION}/lib/* /usr/lib

# install trivy
COPY --from=aquasec/trivy /usr/local/bin/trivy /usr/local/bin/trivy
RUN chmod +x /usr/local/bin/trivy

# copy ci script
ADD ./ci.sh /usr/local/bin/ci
RUN chmod a+x /usr/local/bin/ci

ENTRYPOINT []
