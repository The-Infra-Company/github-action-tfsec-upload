#!/bin/bash

# Fail fast on errors, unset variables, and failures in piped commands
set -Eeuo pipefail

# If DEBUG_MODE is set to true, print all executed commands
if [ "${DEBUG_MODE:-false}" == "true" ]; then
  set -x
fi

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

echo '::group::Preparing ...'
  unameOS="$(uname -s)"
  case "${unameOS}" in
    Linux*)     os=linux;;
    Darwin*)    os=darwin;;
    CYGWIN*)    os=windows;;
    MINGW*)     os=windows;;
    MSYS_NT*)   os=windows;;
    *)          echo "Unknown system: ${unameOS}" && exit 1
  esac

  unameArch="$(uname -m)"
  case "${unameArch}" in
    x86*)      arch=amd64;;
    arm64)     arch=arm64;;
    *)         echo "Unsupported architecture: ${unameArch}. Only AMD64 and ARM64 are supported by the action" && exit 1
    esac

  TEMP_PATH="$(mktemp -d)"
  echo "Detected ${os} running on ${arch}, will install tools in ${TEMP_PATH}"
  TFSEC_PATH="${TEMP_PATH}/tfsec"
echo '::endgroup::'

echo "::group:: Installing tfsec (${INPUT_TFSEC_VERSION}) ... https://github.com/aquasecurity/tfsec"
  test ! -d "${TFSEC_PATH}" && install -d "${TFSEC_PATH}"

  binary="tfsec"
  if [[ "${INPUT_TFSEC_VERSION}" = "latest" ]]; then
    # latest release is available on this url.
    # document: https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
    url="https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-${os}-${arch}"
  else
    url="https://github.com/aquasecurity/tfsec/releases/download/${INPUT_TFSEC_VERSION}/tfsec-${os}-${arch}"
  fi
  if [[ "${os}" = "windows" ]]; then
    url+=".exe"
    binary+=".exe"
  fi

  curl --silent --show-error --fail \
    --location "${url}" \
    --output "${binary}"
  install tfsec "${TFSEC_PATH}"
echo '::endgroup::'

echo "::group:: Print tfsec details ..."
  "${TFSEC_PATH}/tfsec" --version
echo '::endgroup::'

echo '::group:: Running tfsec ...'
  set +Eeuo pipefail

  SARIF_FILE="${GITHUB_WORKSPACE}/tfsec-results.sarif"
  touch "$SARIF_FILE"

  # shellcheck disable=SC2086
  "${TFSEC_PATH}/tfsec" --format=sarif ${INPUT_TFSEC_FLAGS:-} . 2> /dev/null | tee "$SARIF_FILE"

    # Validate SARIF file format
  if ! jq empty "$SARIF_FILE" 2>/dev/null; then
    echo "tfsec SARIF file is invalid. Exiting."
    exit 1
  fi

  # Check if SARIF file has results (non-empty "runs" key)
  if ! jq -e '.runs | length > 0' "$SARIF_FILE" >/dev/null; then
    echo "No tfsec issues found. Generating an empty SARIF file."
    echo '{"version": "2.1.0", "runs": []}' | tee "$SARIF_FILE"
  fi

  echo "tfsec SARIF report is ready."
  exit_code=0
  echo "tfsec-return-code=${exit_code}" >> "${GITHUB_OUTPUT}"
echo '::endgroup::'

exit "${exit_code}"
