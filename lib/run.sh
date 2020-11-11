#!/usr/bin/env bash

set -euo pipefail

hash_key() {
	echo "${1}" | sha256sum | awk '{print $1}'
}

interpolate_harness() {
	# shellcheck disable=SC2002
	cat "${1}" \
		| sed "s/\${env.name}/$(echo "${GITHUB_DEPLOYMENT_ENVIRONMENT}" | cut -d '-' -f 1)/g" \
		| sed "s/\${workflow.name}/$(echo "${HARNESS_WORKFLOW_NAME}" | tr '/' '-')/g" \
		| sed "s/\${service.name}/${HARNESS_SERVICE_NAME}/g" \
		| sed "s/\${workflow.releaseNo}/${HARNESS_RELEASE_NO}/g" \
		| sed "s/\${workflow.variables.namespace}/${GITHUB_DEPLOYMENT_ENVIRONMENT}/g" \
		| sed "s/\${workflow.variables.GITHUB_DEPLOYMENT_ENVIRONMENT}/${GITHUB_DEPLOYMENT_ENVIRONMENT}/g" \
		| sed "s/\${workflow.variables.GITHUB_DEPLOYMENT_SHA}/${GITHUB_DEPLOYMENT_SHA}/g" \
		| sed "s/\${workflow.variables.GITHUB_DEPLOYMENT_TASK}/${GITHUB_DEPLOYMENT_TASK}/g"
}

main() {
	local helm="${HELM_BIN:-helm}"

	local -a args=()
	local scratch_dir shimmed_file

	scratch_dir="$(mktemp -d)"	

	while [ "${#@}" -ne 0 ]; do
		case "${1}" in
			-f=* | --values=*)
				echo "-f=FILE or --values=FILE unsupported. Use -f FILE or --values FILE instead." 1>&2
				return 1
				;;
			-f | --values)
				args+=("$1")
				shift

				if [ $# -eq 0 ]; then
					echo "missing file value for -f or --value" 1>&2
					return 1
				fi

				if [ ! -f "${1}" ]; then
					echo "No such file: ${1}" 1>&2
					return 1
				fi

				shimmed_file="${scratch_dir}/$(hash_key "${1}")/values.yaml"
				mkdir -p "$(dirname "${shimmed_file}")"
				interpolate_harness "${1}" > "${shimmed_file}"
				args+=("${shimmed_file}")

				shift
				;;
			*)
				# XXX: if this is the chart argument, check if there is a chart values
				# file. If so interpolate it and pass it as an explicit values file.
				# This ensures the default values file is interoplated as expected.
				if [ -f "${1}/values.yaml" ]; then
					shimmed_file="${scratch_dir}/$(hash_key "${1}/values.yaml")/values.yaml"
					mkdir -p "$(dirname "${shimmed_file}")"
					interpolate_harness "${1}/values.yaml" > "${shimmed_file}"

					args+=("${1}" -f "${shimmed_file}")
					shift
				else
					args+=("$1")
					shift
				fi
				;;
		esac
	done

	if [ "${HELM_DEBUG:-}" = "true" ]; then
		echo "ARGS: ${args[*]}" 1>&2
	fi

	exec "${helm}" "${args[@]}"
}

main "$@"
