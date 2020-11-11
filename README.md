# Harness Interpolation Helm Plugin

A [Helm](https://helm.sh/) plugin for interpolating Harness.io
expressions in values file.

## Interpolations

- `${env.name}` => `GITHUB_DEPLOYMENT_ENVIRONMENT}`
- `${workflow.name}` => `HARNESS_WORKFLOW_NAME`
- `${workflow.releaseNo}` => `HARNESS_RELEASE_NO`
- `${workflow.variables.namespace}` => `GITHUB_DEPLOYMENT_ENVIRONMENT`
- `${workflow.variables.GITHUB_DEPLOYMENT_ENVIRONMENT}` =>
	`GITHUB_DEPLOYMENT_ENVIRONMENT}`
- `${workflow.variables.GITHUB_DEPLOYMENT_SHA}` =>
	`GITHUB_DEPLOYMENT_SHA`
- `${workflow.variables.GITHUB_DEPLOYMENT_TASK}` =>
  `GITHUB_DEPLOYMENT_TASK`

## Installation

Install the plugin using the built-in plugin manager.

```
helm plugin install https://github.com/skillshare/helm-harness
```

## Usage

Use the `harness` plugin when installing a release or generating
templates.

```
$ helm harness release FOO chart/
$ helm template release FOO chart/
```

This plugin may be combined with other plugins as well. In these
examples, values files are interpolated after the secrets plugin.
These may be swapped depending on the use case.

```
$ helm secrets harness release FOO chart/
$ helm secrets template release FOO chart/
```
