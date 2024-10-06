# Build stage
FROM python:3.12-bookworm as build

ARG PIP_VERSION=24.2

WORKDIR /app

ENV VIRTUAL_ENV=/app/venv
RUN python3 -m venv ${VIRTUAL_ENV}
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN python -m pip install --upgrade --no-cache-dir pip==${PIP_VERSION}
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/app/ app/

# Release stage
FROM python:3.12-slim-bookworm as release

ARG APP_NAME
ARG APP_VERSION
ARG APP_REVISION

ARG APP_USER=app
ARG APP_UID=1000
ARG APP_GROUP=app
ARG APP_GID=2000

LABEL \
    org.opencontainers.image.title=${APP_NAME} \
    org.opencontainers.image.version=${APP_VERSION} \
    org.opencontainers.image.revision=${APP_REVISION}

RUN \
    apt-get update && \
    apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
        dumb-init=1.2.5-2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    addgroup --system --gid ${APP_GID} --no-create-home ${APP_GROUP} && \
    adduser --system \
        --uid ${APP_UID} \
        --ingroup ${APP_GROUP} \
        --disabled-password \
        --gecos "" ${APP_USER} && \
    chmod -R ug-s /bin /sbin /usr/bin && \
    rm -rf /tmp/*

WORKDIR /app
COPY --from=build --chown=root:app --chmod=640 /app /app
RUN chmod -R ug+x /app

ENV VIRTUAL_ENV=/app/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["python", "/app/main.py"]

USER ${APP_UID}
