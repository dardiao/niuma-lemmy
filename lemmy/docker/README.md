# Building Lemmy Images

Lemmy's images are meant to be **built** on `linux/amd64`,
but they can be **executed** on both `linux/amd64` and `linux/arm64`.

To do so we need to use a _cross toolchain_ whose goal is to build
**from** amd64 **to** arm64.

Namely, we need to link the _lemmy_server_ with `pq` and `openssl`
shared libraries and a few others, and they need to be in `arm64`,
indeed.

The toolchain we use to cross-compile is specifically tailored for
Lemmy's needs, see [the image repository][image-repo].

#### References

- [The Linux Documentation Project on Shared Libraries][tldp-lib]

[tldp-lib]: https://tldp.org/HOWTO/Program-Library-HOWTO/shared-libraries.html
[image-repo]: https://github.com/raskyld/lemmy-cross-toolchains

## Running the whole stack locally

`docker-compose.yml` in this directory builds **and** runs everything: `lemmy`,
`lemmy-ui` (from the `lemmy-ui` checkout next to this repository), `postgres`,
`pictrs` and an nginx `proxy`. No public test instance is involved - the UI talks
to the local backend over the compose network (`LEMMY_UI_BACKEND=lemmy:8536`).

```bash
cd docker
docker compose up -d --build   # build images from the local checkouts and start
docker compose ps              # status, including health
docker compose logs -f lemmy   # follow one service
docker compose down            # stop and remove containers (data is kept)
```

The web UI is then on <http://localhost:1236>, the API on
<http://localhost:8536/api/v3/site>, and postgres is published on `5433`.

`lemmy-ui` needs two different backend urls, and they are not interchangeable:
`LEMMY_UI_BACKEND_INTERNAL` is what server-side rendering uses (over the compose
network), while `LEMMY_UI_BACKEND` is embedded into the page for the *browser*,
which cannot resolve compose service names. The compose file points the
browser-facing one at `localhost:1236` so that it stays on the same origin as the
UI and goes through the proxy. When the UI is served from somewhere else, pass
that address instead:

```bash
LEMMY_UI_PUBLIC_URL=https://niuma.club docker compose up -d
```

### Health checks and startup order

Every service defines a `healthcheck`, and `depends_on` uses
`condition: service_healthy`, so startup is deterministic instead of racing:

| service | starts once |
| --- | --- |
| `lemmy` | `postgres` and `pictrs` are healthy |
| `lemmy-ui` | `lemmy` is healthy |
| `proxy` | `lemmy`, `lemmy-ui` and `pictrs` are healthy |

`lemmy`'s check calls `/api/v3/site`, which only answers once the database
migrations have completed, so a slow first boot no longer produces a pile of
connection errors in the logs. The postgres check keeps the check that ships in
the `pgautoupgrade` image, since that one also waits for a pending major-version
upgrade to finish.

```bash
docker compose ps --format '{{.Name}} {{.Status}}'
docker inspect docker-lemmy-1 --format '{{json .State.Health}}' | jq
```

### Running the stack as x86_64

The default is the host's own architecture. To run everything under emulation
instead - to reproduce a bug that only happens on x86_64, or because an image has
no arm64 build - set `LEMMY_IMAGE_PLATFORM`:

```bash
LEMMY_IMAGE_PLATFORM=linux/amd64 docker compose up -d --build
LEMMY_IMAGE_PLATFORM=linux/arm64 docker compose up -d --build   # the other way round
```

This applies to all five services, so images are pulled *and* built for the
requested platform. On Apple Silicon this requires Rosetta, i.e. `rosetta: true`
in `~/.colima/default/colima.yaml` (`colima start --vm-type vz --vz-rosetta`, or
`colima start --arch x86_64` for a fully emulated VM). Everything still runs, but
the Rust build is noticeably slower.

### The Rust toolchain inside the build

The `lemmy` image pins `RUSTUP_TOOLCHAIN` to the toolchain that is already baked
into the `cargo-chef` builder image. This is required because `rust-toolchain.toml`
in the repository root declares a rustup *channel* (`channel = "1.95"`), and rustup
responds to a channel by syncing it from `static.rust-lang.org` on every build -
which fails on a restricted network. The pin is written without a host triple, so
rustup resolves the right one for the architecture doing the build, and a guard
step fails the build with a clear error if that toolchain is not present, rather
than silently falling back to a download.

### Data and resets

`postgres` and `pictrs` keep their state in host directories (`./volumes/postgres`
and `./volumes/pictrs`), not in named volumes. That means `docker compose down -v`
does **not** delete it. To start from an empty database, stop the stack and remove
those directories yourself.
