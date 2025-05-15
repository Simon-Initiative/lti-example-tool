ARG GLEAM_VERSION=1.10.0

# Builder stage
FROM ghcr.io/gleam-lang/gleam:v${GLEAM_VERSION}-erlang-alpine AS builder

RUN apk update && apk add --no-cache build-base python3
RUN apk add --update nodejs npm elixir

WORKDIR /build

# copy source files
COPY package.json package-lock.json ./

# install node deps
RUN npm install

# copy source files
COPY . .

# install gleam deps
RUN gleam deps download

# build gleam app
RUN gleam build

# build tailwind styles
RUN npm run tailwind:build

# # build release
RUN gleam export erlang-shipment

RUN mv build/erlang-shipment /app

# Final stage
FROM ghcr.io/gleam-lang/gleam:v${GLEAM_VERSION}-erlang-alpine

WORKDIR /app
RUN chown nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app /app

USER nobody

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
