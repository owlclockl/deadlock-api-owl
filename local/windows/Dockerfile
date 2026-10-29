FROM rust:slim-trixie AS rust
FROM node:26-trixie-slim
COPY --from=rust /usr/local/cargo /usr/local/cargo
COPY --from=rust /usr/local/rustup /usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo RUSTUP_HOME=/usr/local/rustup
ENV PATH="/usr/local/cargo/bin:$PATH"
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates build-essential protobuf-compiler pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
RUN npm install -g pnpm@12.15.0 && rustup target add wasm32-unknown-unknown
WORKDIR /app
COPY . .
WORKDIR /app/website
RUN pnpm install --frozen-lockfile
RUN node scripts/build-wasm.mjs
ENV VITE_API_BASE_URL=https://api.deadlock-api.com
EXPOSE 3000
CMD ["pnpm", "dev", "--host", "0.0.0.0", "--port", "3000", "--strictPort"]
