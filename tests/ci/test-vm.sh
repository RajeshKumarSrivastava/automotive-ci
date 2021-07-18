#!/bin/bash
set -euo pipefail

source /tmp/.env

IMAGE_KEY=${IMAGE_KEY:-}
GUEST_ADDRESS=${GUEST_ADDRESS:-}
SSH_KEY=${SSH_KEY:-}

# SSH setup.
SSH_OPTIONS=(-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i ${SSH_KEY} admin@${GUEST_ADDRESS})

ssh_run () {
    cmd="$*"
    ssh "${SSH_OPTIONS[@]}" "/bin/bash -c '${cmd}'"
}

# Wait for the ssh server up to be.
wait_for_ssh_up () {
    SSH_STATUS=$(ssh_run "echo -n READY")
    if [[ "$SSH_STATUS" == READY ]]; then
        echo 1
    else
        echo 0
    fi
}

# Helper function for the tests
assert () {
    local actual="$1"
    local expected="$2"

    if [[ "$actual" == "$expected" ]]; then
        greenprint "💚 Success"
    else
        greenprint "❌ Failed"
        ssh_run "free -h ; df -h ; ps aux | grep edge ; journalctl -p err -n 100"
        exit 1
    fi
}

assert_process_running () {
    process="$1"
    processes=$(ssh_run "ps -u edge a | grep -v grep | grep -c ${process}") || true

    assert "$processes" "1"
}

assert_package_installed () {
    package="$1"
    installed=$(ssh_run "rpm --quiet -q ${package} ; echo \$?")

    assert "$installed" "0"
}


# Start VM.
greenprint "Start VM"
virsh start "${IMAGE_KEY}"

# Check for ssh ready to go.
greenprint "🛃 Checking for SSH is ready to go"
for LOOP_COUNTER in $(seq 0 30); do
    RESULTS="$(wait_for_ssh_up $GUEST_ADDRESS)"
    if [[ "$RESULTS" == 1 ]]; then
        break
    fi
    sleep 10
done

# Check image installation result
check_result

greenprint "Here is the resulted VM: $LIBVIRT_IMAGE_PATH"

