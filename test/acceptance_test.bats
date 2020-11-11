#!/usr/bin/env bats

load vendor/bats-support/load
load vendor/bats-assert/load

setup() {
	export HELM_BIN=./test/bin/helm
	export HARNESS_SERVICE_NAME=test-service
	export HARNESS_RELEASE_NO=0000
	export HARNESS_WORKFLOW_NAME=test-workflow
	export GITHUB_DEPLOYMENT_ENVIRONMENT=test
	export GITHUB_DEPLOYMENT_TASK=deploy
	export GITHUB_DEPLOYMENT_SHA=123af
}

assert_interpolated() {
	assert [ -f "${1}" ]
	refute grep -qF '${env.name}' "${1}"
	refute grep -qF '${workflow.name}' "${1}"
	refute grep -qF '${workflow.releaseNo}' "${1}"
	refute grep -qF '${workflow.variables.namespace}' "${1}"
	refute grep -qF '${workflow.variables.GITHUB_DEPLOYMENT_ENVIRONMENT}' "${1}"
	refute grep -qF '${workflow.variables.GITHUB_DEPLOYMENT_SHA}' "${1}"
	refute grep -qF '${workflow.variables.GITHUB_DEPLOYMENT_TASK}' "${1}"
}

@test 'harness interpolation' {
	values="$(mktemp)"

	yq w -i "${values}" 'env' '${env.name}'
	yq w -i "${values}" 'workflow' '${workflow.name}'
	yq w -i "${values}" 'service' '${service.name}'
	yq w -i "${values}" 'release_number' '${workflow.releaseNo}'
	yq w -i "${values}" 'namespace' '${workflow.variables.namespace}'
	yq w -i "${values}" 'environment' '${workflow.variables.GITHUB_DEPLOYMENT_ENVIRONMENT}'
	yq w -i "${values}" 'sha' '${workflow.variables.GITHUB_DEPLOYMENT_SHA}'
	yq w -i "${values}" 'task' '${workflow.variables.GITHUB_DEPLOYMENT_TASK}'

	run lib/run.sh -f "${values}"
	assert_success
	assert [ "${#lines[@]}" -eq 2 ]
	assert_interpolated "${lines[1]}"

	interpolated="${lines[1]}"

	run yq r "${interpolated}" 'env'
	assert_success
	assert_output "${GITHUB_DEPLOYMENT_ENVIRONMENT}"

	run yq r "${interpolated}" 'workflow'
	assert_success
	assert_output "${HARNESS_WORKFLOW_NAME}"

	run yq r "${interpolated}" 'service'
	assert_success
	assert_output "${HARNESS_SERVICE_NAME}"

	run yq r "${interpolated}" 'release_number'
	assert_success
	assert_output "${HARNESS_RELEASE_NO}"

	run yq r "${interpolated}" 'namespace'
	assert_success
	assert_output "${GITHUB_DEPLOYMENT_ENVIRONMENT}"

	run yq r "${interpolated}" 'environment'
	assert_success
	assert_output "${GITHUB_DEPLOYMENT_ENVIRONMENT}"

	run yq r "${interpolated}" 'sha'
	assert_success
	assert_output "${GITHUB_DEPLOYMENT_SHA}"

	run yq r "${interpolated}" 'task'
	assert_success
	assert_output "${GITHUB_DEPLOYMENT_TASK}"

	# XXX: ${env.name} does not reflect numbered environments
	run env GITHUB_DEPLOYMENT_ENVIRONMENT=sandbox-5 lib/run.sh -f "${values}"
	assert_success
	assert [ "${#lines[@]}" -eq 2 ]
	assert_interpolated "${lines[1]}"

	run yq r "${lines[1]}" 'env'
	assert_success
	assert_output sandbox

	# XXX: ${workflow.name} translated '/' to '-'
	run env HARNESS_WORKFLOW_NAME=deploy/rolling lib/run.sh -f "${values}"
	assert_success
	assert [ "${#lines[@]}" -eq 2 ]
	assert_interpolated "${lines[1]}"

	run yq r "${lines[1]}" 'workflow'
	assert_success
	assert_output 'deploy-rolling'
}

@test 'non-values files args are forwarded to helm' {
	run lib/run.sh template --generate-name --foo --bar
	assert_success
	assert [ "${#lines[@]}" -eq 4 ]
	assert_line -n 0 'template'
	assert_line -n 1 '--generate-name'
	assert_line -n 2 '--foo'
	assert_line -n 3 '--bar'
}

@test 'interpolates default values file' {
	scratch="$(mktemp -d)"

	touch "${scratch}/values.yaml"
	yq w -i "${scratch}/values.yaml" 'env' '${env.name}'

	run lib/run.sh template "${scratch}"
	assert_success
	assert [ "${#lines[@]}" -eq 4 ]
	assert_line -n 0 template
	assert_line -n 1 "${scratch}"
	assert_line -n 2 -f
	assert_interpolated "${lines[3]}"

	# XXX: These assert that various invocations of helm commands
	# are properly handled. Helm is loose with the specific order
	# and plugins may be chained so there is no way to no where
	# "chart" argument is.

	run lib/run.sh release "${scratch}"
	assert_success
	assert [ "${#lines[@]}" -eq 4 ]
	assert_line -n 0 release
	assert_line -n 1 "${scratch}"
	assert_line -n 2 -f
	assert_interpolated "${lines[3]}"

	run lib/run.sh release --foo "${scratch}" --bar
	assert_success
	assert [ "${#lines[@]}" -eq 6 ]
	assert_line -n 0 release
	assert_line -n 1 --foo
	assert_line -n 2 "${scratch}"
	assert_line -n 3 -f
	assert_interpolated "${lines[4]}"
	assert_line -n 5 --bar

	run lib/run.sh secrets template --foo "${scratch}" --bar
	assert_success
	assert [ "${#lines[@]}" -eq 7 ]
	assert_line -n 0 secrets
	assert_line -n 1 template
	assert_line -n 2 --foo
	assert_line -n 3 "${scratch}"
	assert_line -n 4 -f
	assert_interpolated "${lines[5]}"
	assert_line -n 6 --bar
}

@test 'interpolates files passed with -f' {
	local -a args=()
	local scratch
	scratch="$(mktemp)"

	yq w -i "${scratch}" 'env' '${env.name}'

	run lib/run.sh -f "${scratch}"
	assert_success

	args=(${output})
	assert [ "${#args}" -eq 2 ]
	assert [ "${args[0]}" = "-f" ]
	assert_interpolated "${args[1]}"
}

@test 'interpolates files passed with --values' {
	local scratch
	scratch="$(mktemp)"

	yq w -i "${scratch}" 'env' '${env.name}'

	run lib/run.sh --values "${scratch}"
	assert_success

	assert [ "${#lines[@]}" -eq 2 ]
	assert_line -n 0 --values
	assert_interpolated "${lines[1]}"
}

@test 'fails on missing values files' {
	run lib/run.sh --values junk
	assert_failure
	assert_output --partial 'junk'
}

@test 'fails on missing option value' {
	run lib/run.sh --values
	assert_failure
	assert_output --partial 'missing file'
}

@test 'fails on -f= or --values= form' {
	run lib/run.sh --values=foo
	assert_failure
	assert_output --partial '--values='
	assert_output --partial 'unsupported'

	run lib/run.sh -f=foo
	assert_failure
	assert_output --partial '-f='
	assert_output --partial 'unsupported'
}
