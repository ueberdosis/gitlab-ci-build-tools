FROM golang:alpine AS golang
MAINTAINER "Kris Siepert <m@kris.cool>"

RUN apk add --no-cache git && \
    go get github.com/fraunhoferfokus/deckschrubber

FROM docker:git
MAINTAINER "Kris Siepert <m@kris.cool>"

ENV FORGE_VERSION "0.4.15"
ENV KUBECTL_VERSION "1.13.3"
ENV SONAR_SCANNER_VERSION 3.3.0.1492

# install bash & node
RUN apk add --no-cache bash nodejs

# install docker-compose
ENV COMPOSE_INTERACTIVE_NO_CLI 1
RUN apk add --no-cache py-pip py-paramiko && \
    pip install --user docker-compose && \
    mv /root/.local/bin/docker-compose /usr/local/bin/docker-compose

# install kubectl
ADD https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod a+x /usr/local/bin/kubectl

# install forge
ADD https://s3.amazonaws.com/datawire-static-files/forge/$FORGE_VERSION/forge /usr/local/bin/forge
RUN chmod a+x /usr/local/bin/forge

# install deckschrubber
COPY --from=golang /go/bin/deckschrubber /usr/local/bin/deckschrubber

# install sonar scanner
ADD https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip /tmp/sonar-scanner.zip
RUN apk add --no-cache openjdk8-jre && \
    cd /tmp && unzip sonar-scanner.zip && \
    mv -fv /tmp/sonar-scanner-${SONAR_SCANNER_VERSION}/bin/sonar-scanner /usr/bin && \
    chmod a+x /usr/bin/sonar-scanner && \
    mv -fv /tmp/sonar-scanner-${SONAR_SCANNER_VERSION}/lib/* /usr/lib

# copy ci script
ADD ./ci.sh /usr/local/bin/ci
RUN chmod a+x /usr/local/bin/ci
