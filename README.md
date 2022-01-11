# Pipe VMS Norway

Here will be hosted the code to fetch and normalize the [VMS](https://en.wikipedia.org/wiki/Vessel_monitoring_system) sources from `Norway`.

## How to run?

### Requirements

To run in your local machine you need:
- [docker](https://www.docker.com/)
- [docker-compose](https://docs.docker.com/compose/)

### Setup

1. Creates a docker volume `gcp` if it is not yet defined.
```bash
$ docker volume create --name=gcp
```
2. Build the docker-compose
```bash
$ docker-compose build
$ docker-compose run gcloud auth login
```
3. Install it to your local version of Apache Airflow
```bash
$ install.sh
```


## Collaboration

The folders have separate meanings when you need to implement or do a change in
this repository.  The folders contains:
* `assets`: Under the assets
forlder you will find all the Jinja and Json script having the Bigquery and
schemes needed for acomplish the purposes of fetch and normalize the VMS data
from `Norway`.
* `pipe_vms_norway`: Under the pipe_vms_norway folder you will find an
 `__init__.py` where the details, version and author are described.
* `scripts`: Under the scripts folder you will find the entrypoint of the
service specified in the `docker-compose.yaml` (usually `run.sh`) and the
bash scripts that the system uses to acomplish the fetch and normalize of the
VMS data from `Norway`.

## License

- [Apache License 2004](http://www.apache.org/licenses/LICENSE-2.0.txt)

