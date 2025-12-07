#!/usr/bin/env bash
set -euo pipefail

IN_TAR="${IN_TAR:-/in/ivi-theme-0.1.tar}"
LISTEN_PORT="${LISTEN_PORT:-8080}"
TEST_IMG="${TEST_IMG:-}"
OUT_DIR="/out"
ART_DIR="$OUT_DIR/artifacts"

mkdir -p "$ART_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

###############################################
# 0) OTA 이미지 tar이 있다면 → load 수행
###############################################
if [[ -z "$TEST_IMG" ]]; then
    if [[ -s "$IN_TAR" ]]; then
        log "Found tar: $IN_TAR → loading image"
        podman load -i "$IN_TAR" | tee "$OUT_DIR/podman_load.log"

        TEST_IMG=$(grep -Eo 'Loaded image: .+' "$OUT_DIR/podman_load.log" \
                    | sed 's/Loaded image: //g' \
                    | tail -n1 || true)

        [[ -z "$TEST_IMG" || "$TEST_IMG" == "null" ]] && {
            log "WARN: Could not detect loaded image, fallback → localhost/ivi-theme:0.1"
            TEST_IMG="localhost/ivi-theme:0.1"
        }
    else
        log "No tar found → using default image"
        TEST_IMG="localhost/ivi-theme:0.1"
    fi
fi

log "Using test image: $TEST_IMG"

###############################################
# 1) 기존 컨테이너 제거
###############################################
podman rm -f ivi-ng >/dev/null 2>&1 || true

###############################################
# 2) 테스트 컨테이너 실행 (원본 스크립트 동일)
###############################################
log "Starting test container..."
podman run -d --name ivi-ng \
    --user 0 \
    -p "${LISTEN_PORT}:80" \
    "$TEST_IMG" | tee "$OUT_DIR/run_id.txt"

###############################################
# 3) D1: health check
###############################################
log "Running D1 (health check)"
sleep 2
if curl -fsSL "http://127.0.0.1:${LISTEN_PORT}/assets/" >/dev/null; then
    echo "[D1 PASS] health OK" | tee -a "$OUT_DIR/report.txt"
else
    echo "[D1 FAIL] health check failed" | tee -a "$OUT_DIR/report.txt"
fi

###############################################
# 4) D4: 파일시스템 제약 확인
###############################################
log "Running D4 (filesystem test)"
podman exec ivi-ng sh -lc \
    'echo ok >/tmp/x && echo "[D4] /tmp OK" || echo "[D4] /tmp FAIL"' \
    | tee -a "$OUT_DIR/report.txt"

podman exec ivi-ng sh -lc \
    'echo bad >/etc/shadow && echo "[D4] should-not-see" || echo "[D4 PASS] RO root"' \
    | tee -a "$OUT_DIR/report.txt"

###############################################
# 5) D7: 프로세스 목록 확인
###############################################
log "Running D7 (process list)"
podman exec ivi-ng ps aux \
    | tee "$ART_DIR/proc_list.log" >/dev/null

echo "[D7] Process list saved -> $ART_DIR/proc_list.log" \
    | tee -a "$OUT_DIR/report.txt"

###############################################
# 6) 종료 처리
###############################################
log "Stopping test container"
podman rm -f ivi-ng >/dev/null 2>&1 || true

log "DONE. Results stored in $OUT_DIR"

