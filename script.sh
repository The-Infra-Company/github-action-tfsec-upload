#!/bin/bash

# Fail fast on errors, unset variables, and failures in piped commands
set -Eeuo pipefail

# If DEBUG_MODE is set to true, print all executed commands
if [ "${DEBUG_MODE:-false}" == "true" ]; then
  set -x
fi

if [[ -z "${INPUT_TRIVY_COMMAND}" ]]; then
  echo "Error: Missing required input 'trivy_command'."
  exit 1
fi

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

echo '::group::Preparing ...'
  unameOS="$(uname -s)"
  case "${unameOS}" in
    Linux*)     os=Linux;;
    Darwin*)    os=macOS;;
    CYGWIN*)    os=Windows;;
    MINGW*)     os=Windows;;
    MSYS_NT*)   os=Windows;;
    *)          echo "Unknown system: ${unameOS}" && exit 1
  esac

  unameArch="$(uname -m)"
  case "${unameArch}" in
    x86*)      arch=64bit;;
    aarch64)   arch=ARM64;;
    arm64)     arch=ARM64;;
    *)         echo "Unsupported architecture: ${unameArch}. Only AMD64 and ARM64 are supported by the action" && exit 1
    esac

  case "${os}" in
    Windows)   archive_extension="zip";;
    *)         archive_extension="tar.gz";;
  esac

  TEMP_PATH="$(mktemp -d)"
  echo "Detected ${os} running on ${arch}, will install tools in ${TEMP_PATH}"
  TRIVY_PATH="${TEMP_PATH}/trivy"
echo '::endgroup::'

echo "::group:: Installing trivy (${INPUT_TRIVY_VERSION}) ... https://github.com/aquasecurity/trivy"
  test ! -d "${TRIVY_PATH}" && install -d "${TRIVY_PATH}"

  PREV_DIR=$(pwd)
  TEMP_DOWNLOAD_PATH="$(mktemp -d)"
  cd "${TEMP_DOWNLOAD_PATH}" || exit

  archive="trivy.${archive_extension}"
  if [[ "${INPUT_TRIVY_VERSION}" = "latest" ]]; then
    # latest release is available on this url.
    # document: https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
    latest_url="https://github.com/aquasecurity/trivy/releases/latest/"
    release=$(curl $latest_url -s -L -I -o /dev/null -w '%{url_effective}' | awk -F'/' '{print $NF}')
  else
    release="${INPUT_TRIVY_VERSION}"
  fi
  release_num=${release/#v/}
  url="https://github.com/aquasecurity/trivy/releases/download/${release}/trivy_${release_num}_${os}-${arch}.${archive_extension}"
  # Echo url for testing
  echo "Downloading ${url} to ${archive}"
  curl --silent --show-error --fail \
    --location "${url}" \
    --output "${archive}"

  ### TEST
  echo "URL: ${url}"
  echo "ARCHIVE: ${archive}"
  ls
  ### TEST END

  if [[ "${os}" = "Windows" ]]; then
    unzip "${archive}"
  else
    tar -xzf "${archive}"
  fi
  install trivy "${TRIVY_PATH}"
  cd "${PREV_DIR}" || exit
echo '::endgroup::'

echo "::group:: Print trivy details ..."
  "${TRIVY_PATH}/trivy" --version
echo '::endgroup::'

echo '::group:: Running trivy ...'
  set +Eeuo pipefail

  SARIF_FILE="${GITHUB_WORKSPACE}/trivy-results.sarif"
  touch "$SARIF_FILE"

  # shellcheck disable=SC2086
  "${TRIVY_PATH}/trivy" --format=sarif ${INPUT_TRIVY_FLAGS:-} ${INPUT_TRIVY_COMMAND} 2> /dev/null | tee "$SARIF_FILE"

  # Validate SARIF file format
  if ! jq empty "$SARIF_FILE" 2>/dev/null; then
    echo "Trivy SARIF file is invalid. Exiting."
    exit 1
  fi

  # Check if SARIF file has results (non-empty "runs" key)
  if ! jq -e '.runs | length > 0' "$SARIF_FILE" >/dev/null; then
    echo "No trivy issues found. Generating an empty SARIF file."
    echo '{"version": "2.1.0", "runs": []}' | tee "$SARIF_FILE"
  fi

  echo "Trivy SARIF report is ready."
  exit_code=0
  echo "trivy-return-code=${exit_code}" >> "${GITHUB_OUTPUT}"
echo '::endgroup::'

exit "${exit_code}"
