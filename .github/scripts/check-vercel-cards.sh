#!/usr/bin/env bash
set -u

readonly CONNECT_TIMEOUT_SECONDS=10
readonly MAX_TIME_SECONDS=30

readonly URLS=(
  "repos-per-language|https://github-profile-summary-cards.vercel.app/api/cards/repos-per-language?username=kanalsop&theme=github"
  "stats|https://github-profile-summary-cards.vercel.app/api/cards/stats?username=kanalsop&theme=github"
  "activity-graph|https://github-readme-activity-graph.vercel.app/graph?username=kanalsop&theme=github-compact&hide_border=true"
)

failures=0

for entry in "${URLS[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  headers_file="$(mktemp)"
  body_file="$(mktemp)"

  echo "::group::Checking ${name}"
  echo "URL: ${url}"

  http_code="$(
    curl \
      --silent \
      --show-error \
      --location \
      --connect-timeout "${CONNECT_TIMEOUT_SECONDS}" \
      --max-time "${MAX_TIME_SECONDS}" \
      --retry 2 \
      --retry-delay 5 \
      --dump-header "${headers_file}" \
      --output "${body_file}" \
      --write-out "%{http_code}" \
      "${url}"
  )"
  curl_exit=$?

  content_type="$(awk 'BEGIN { IGNORECASE = 1 } /^content-type:/ { value=$0; sub(/^[^:]+:[[:space:]]*/, "", value); print value }' "${headers_file}" | tail -n 1 | tr -d '\r')"

  echo "HTTP status: ${http_code}"
  echo "Content-Type: ${content_type:-<missing>}"

  if [[ "${curl_exit}" -ne 0 ]]; then
    echo "::error title=${name} request failed::curl exited with status ${curl_exit}"
    failures=$((failures + 1))
  elif [[ "${http_code}" != "200" ]]; then
    echo "::error title=${name} returned HTTP ${http_code}::Expected HTTP 200"
    head -c 500 "${body_file}" || true
    echo
    failures=$((failures + 1))
  elif [[ "${content_type}" != image/svg+xml* ]]; then
    echo "::error title=${name} returned unexpected content type::Expected image/svg+xml"
    failures=$((failures + 1))
  else
    echo "OK"
  fi

  rm -f "${headers_file}" "${body_file}"
  echo "::endgroup::"
done

if [[ "${failures}" -ne 0 ]]; then
  echo "::error::${failures} Vercel card check(s) failed"
  exit 1
fi

echo "All Vercel card checks passed."
