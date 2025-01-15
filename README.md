# AndroidDocker

## android_env.sh

Setup libs and emulator for Android

### Functions:
- `check_dest`:
Check for valid copy/move destination

- `check_file`:
Check FILE exists and is a regular file

- `check_function`:
Check for command, install if not available

- `check_service`:
Check docker-compose service. "$1", if specified, is the service.

- `compose_run`:
Launch container, do stuff

- `compress_pkgs`:
Compress "packages" from host that will be copied to image. $1 is archive filename.

- `docker_build`:
Build image from dockerfile

- `docker_cmd`:
Check docker version, "$1", the docker command is optional

- `docker_compose`:
Check docker compose version, "$1", the docker compose argument is optional

- `docker_run`:
Launch container, do stuff

- `installer`:
Define $INSTALL. System/OS package installer

- `safe_cp`:
Safe copy

- `safe_mv`:
Safe move
