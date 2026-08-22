#!/usr/bin/env bash
# ==============================================================================
# XPadInput: Automated Priority Triage & Multi-Agent Orchestration Engine
# Integrates Beads (bd) local issue tracker with Gas Town (gt) dispatch scheduler.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GT_ROOT="${HOME}/gt"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}${BOLD}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}${BOLD}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}${BOLD}[ERROR]${NC} $1"
}

# ------------------------------------------------------------------------------
# 1. Health & Dependency Check
# ------------------------------------------------------------------------------
check_health() {
    log_info "Verifying Beads (bd) and Gas Town (gt) installation..."
    
    if ! command -v bd &> /dev/null; then
        log_error "Beads (bd) CLI is not installed or not in PATH."
        exit 1
    fi

    if ! command -v gt &> /dev/null; then
        log_error "Gas Town (gt) CLI is not installed or not in PATH."
        exit 1
    fi

    log_success "CLI dependencies verified: bd ($(bd --version 2>/dev/null || echo 'installed')), gt ($(gt --version 2>/dev/null || echo 'installed'))"
}

# ------------------------------------------------------------------------------
# 2. Priority Triage Matrix
# ------------------------------------------------------------------------------
show_triage() {
    cd "${REPO_ROOT}"
    echo -e "\n${BOLD}${CYAN}================================================================${NC}"
    echo -e "${BOLD}${CYAN}📊 XPadInput: Automated Priority Triage & Readiness Matrix${NC}"
    echo -e "${BOLD}${CYAN}================================================================${NC}\n"

    echo -e "${BOLD}Current Ready WorkQueue (Topological Priority Order):${NC}"
    bd ready

    echo -e "\n${BOLD}Issue Priority Breakdown:${NC}"
    echo -e "  ${RED}● P0 (Blockers / Critical Engine Failures)${NC}"
    echo -e "  ${YELLOW}● P1 (Core MIDI 2.0 / MPE / Concurrency Enhancements)${NC}"
    echo -e "  ${BLUE}● P2 (Theory Extensions / Integrations / Packaging)${NC}"
    echo -e "  ${NC}● P3 (Backlog polish / optimizations)${NC}"
}

# ------------------------------------------------------------------------------
# 3. Quality Gate (Build & Comprehensive Test Suite)
# ------------------------------------------------------------------------------
run_quality_gate() {
    cd "${REPO_ROOT}"
    log_info "Executing XPadInput Automated Quality Gate..."

    echo -e "  ↳ Compiling Swift packages..."
    if ! swift build -c debug; then
        log_error "Build failed! Quality gate rejected."
        return 1
    fi
    log_success "Compilation succeeded."

    echo -e "  ↳ Running exhaustive test suite (133+ assertions)..."
    if ! swift run XPadTests; then
        log_error "Unit test suite failed! Quality gate rejected."
        return 1
    fi
    log_success "All test suites passed with 100% success rate."
}

# ------------------------------------------------------------------------------
# 4. Next High-Priority Task Dispatch
# ------------------------------------------------------------------------------
get_next_task() {
    cd "${REPO_ROOT}"
    local next_id
    next_id=$(bd ready | grep -E '^○ xpi-' | head -n 1 | awk '{print $2}')
    echo "${next_id}"
}

dispatch_next() {
    cd "${REPO_ROOT}"
    local task_id
    task_id=$(get_next_task)

    if [ -z "${task_id}" ]; then
        log_warn "No unblocked tasks available in 'bd ready'."
        return 0
    fi

    log_info "Highest priority task identified: ${BOLD}${task_id}${NC}"
    bd show "${task_id}"

    echo -e "\n${CYAN}Dispatch Options for ${task_id}:${NC}"
    echo -e "  1. Claim locally:  ${BOLD}bd update ${task_id} --claim${NC}"
    echo -e "  2. Sling to Gas Town: ${BOLD}cd ~/gt && gt sling ${task_id}${NC}"
}

# ------------------------------------------------------------------------------
# 5. Gas Town Convoy Staging
# ------------------------------------------------------------------------------
stage_convoy() {
    if [ ! -d "${GT_ROOT}" ]; then
        log_error "Gas Town HQ not found at ${GT_ROOT}."
        exit 1
    fi

    log_info "Inspecting Gas Town HQ status at ${GT_ROOT}..."
    cd "${GT_ROOT}"
    gt status
}

# ------------------------------------------------------------------------------
# CLI Dispatcher
# ------------------------------------------------------------------------------
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  triage      Display the prioritized backlog and readiness matrix"
    echo "  next        Show and inspect the highest-priority unblocked task"
    echo "  gate        Run the full automated build & test suite quality gate"
    echo "  status      Check Beads and Gas Town orchestrator status"
    echo "  help        Show this help message"
}

case "${1:-triage}" in
    triage)
        check_health
        show_triage
        ;;
    next)
        check_health
        dispatch_next
        ;;
    gate)
        check_health
        run_quality_gate
        ;;
    status)
        check_health
        show_triage
        stage_convoy
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
