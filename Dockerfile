FROM ocaml/opam:ubuntu-24.04-ocaml-4.13 AS build

USER opam
WORKDIR /home/opam/marina

COPY --chown=opam:opam . .

RUN opam install -y ocamlfind ounit2 \
    && eval $(opam env) \
    && make \
    && make test \
    && make server

FROM ubuntu:24.04

RUN groupadd -r marina \
    && useradd -r -g marina -d /app marina \
    && mkdir -p /app \
    && chown -R marina:marina /app

WORKDIR /app
COPY --from=build --chown=marina:marina /home/opam/marina/marina /app/marina
COPY --from=build --chown=marina:marina /home/opam/marina/server /app/server

USER marina
EXPOSE 8080
CMD ["/app/server"]
