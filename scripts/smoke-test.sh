#!/bin/sh

set -eu

NAMESPACE="${1:?Usage: smoke-test.sh <namespace>}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/workspace-kube/config}"
SERVICE_NAME="${SERVICE_NAME:-final-project}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"

# Unique enough for Jenkins builds while staying within Kubernetes naming rules.
POD_NAME="${NAMESPACE}-smoke-test-${BUILD_NUMBER:-manual}"

KUBECTL="kubectl --kubeconfig ${KUBECONFIG_PATH} --namespace ${NAMESPACE}"

cleanup() {
    echo "Cleaning up smoke-test pod..."
    $KUBECTL delete pod "$POD_NAME" \
        --ignore-not-found=true \
        --wait=false >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

echo "========================================"
echo "Smoke test"
echo "Namespace: ${NAMESPACE}"
echo "Service:   http://${SERVICE_NAME}/"
echo "Pod:       ${POD_NAME}"
echo "========================================"

# Remove a pod left by an interrupted previous attempt.
cleanup

$KUBECTL run "$POD_NAME" \
    --image=curlimages/curl:8.12.1 \
    --restart=Never \
    --command -- \
    curl \
        --fail \
        --silent \
        --show-error \
        --retry 12 \
        --retry-all-errors \
        --retry-delay 5 \
        --connect-timeout 10 \
        --max-time 120 \
        "http://${SERVICE_NAME}/"

echo "Waiting for smoke-test pod to complete..."

elapsed=0
interval=3

while [ "$elapsed" -lt "$TIMEOUT_SECONDS" ]; do
    phase="$($KUBECTL get pod "$POD_NAME" \
        -o jsonpath='{.status.phase}' 2>/dev/null || true)"

    echo "Smoke-test pod phase: ${phase:-Pending}"

    case "$phase" in
        Succeeded)
            echo "Smoke-test output:"
            $KUBECTL logs "$POD_NAME"

            echo
            echo "Smoke test passed for ${NAMESPACE}."
            exit 0
            ;;

        Failed)
            echo "Smoke test failed for ${NAMESPACE}."

            echo "Container output:"
            $KUBECTL logs "$POD_NAME" || true

            echo "Pod details:"
            $KUBECTL describe pod "$POD_NAME" || true
            exit 1
            ;;
    esac

    sleep "$interval"
    elapsed=$((elapsed + interval))
done

echo "Smoke test timed out after ${TIMEOUT_SECONDS} seconds."

echo "Container output:"
$KUBECTL logs "$POD_NAME" || true

echo "Pod details:"
$KUBECTL describe pod "$POD_NAME" || true

exit 1