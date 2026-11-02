[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/cosmoblonde/ddev-project-status/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/cosmoblonde/ddev-project-status/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/cosmoblonde/ddev-project-status)](https://github.com/cosmoblonde/ddev-project-status/commits)
[![release](https://img.shields.io/github/v/release/cosmoblonde/ddev-project-status)](https://github.com/cosmoblonde/ddev-project-status/releases/latest)

# DDEV Project Status

## Overview

This add-on integrates Project Status into your [DDEV](https://ddev.com/) project.

## Installation

```bash
ddev add-on get cosmoblonde/ddev-project-status
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Usage

| Command | Description |
| ------- | ----------- |
| `ddev describe` | View service status and used ports for Project Status |
| `ddev logs -s project-status` | Check Project Status logs |

## Advanced Customization

To change the Docker image:

```bash
ddev dotenv set .ddev/.env.project-status --project-status-docker-image="ddev/ddev-utilities:latest"
ddev add-on get cosmoblonde/ddev-project-status
ddev restart
```

Make sure to commit the `.ddev/.env.project-status` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `PROJECT_STATUS_DOCKER_IMAGE` | `--project-status-docker-image` | `ddev/ddev-utilities:latest` |

## Credits

**Contributed and maintained by [@cosmoblonde](https://github.com/cosmoblonde)**
