#!/bin/bash -e

# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is designed to be called from a terraform `external` data resource.
# Arguments are passed as JSON and evaluated as bash variables.
# The output format is JSON.

# Extract JSON args into shell variables
eval "$(jq -r '@sh "DEST=\(.dest) DATA=\(.data) KEYRING=\(.keyring) KEY=\(.key)"')"

mkdir -p $(dirname "${DEST}")

# Calculate the signature of the input data.
SIG=$(echo -n "${DATA}" | shasum | cut -d ' ' -f1)

# Break if dest file with same signature already exists
[[ -f "${DEST}" && -f "${DEST}.sig" && -z $(diff <(echo -n "$SIG") "${DEST}.sig") ]] && jq -n --arg file "${DEST}" '{"file":$file}' && exit 0

TEMP_FILE="${DEST}.tmp"
echo -n "${DATA}" > ${TEMP_FILE}

gcloud kms encrypt \
  --location=global \
  --keyring=${KEYRING} \
  --key=${KEY} \
  --plaintext-file=${TEMP_FILE} \
  --ciphertext-file=/dev/stdout | base64 > ${DEST}
rm -f ${TEMP_FILE}

echo -n "$SIG" > "${DEST}.sig"

# Output results in JSON format.
jq -n --arg file "${DEST}" '{"file":$file}'