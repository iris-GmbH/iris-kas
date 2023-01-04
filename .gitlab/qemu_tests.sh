#!/bin/sh

# prepare kas environment for qemu testing
# we need to rebuild the qemu-native parts here due to absolute paths in the linked libraries.
# As we can  use the sstate-cache, this won't take long though.
kas shell -c "bitbake qemu-helper-native" "${MAIN_KAS_FILES}":include/kas-irma6-"${MULTI_CONF}".yml

# extract QEMU artifacts from build step
mkdir -p build/tmp/
tar -xf "${MULTI_CONF}"-deploy.tar.gz -C build/tmp/

echo "Info: Booting firmware in QEMU VM..."
# start QEMU in background, use 70% of total RAM and use slirp networking, which does not require root
# we only want to use kas-irma6-base.yml here, since qemu-helper-native is
# contained in openembedded-core and this can speed up the parsing
kas shell -c "runqemu qemux86-64 qemuparams=\"-m $(($(free -m | awk '/Mem:/ {print $2}') *70 /100))\" slirp" "${MAIN_KAS_FILES}" &

# wait for SSH to become available in QEMU
echo "Info: Waiting for SSH to become available..."
export TIMEOUT=0;
while true; do
  if ssh -p 2222 -o "StrictHostKeyChecking=no" root@127.0.0.1 "cat /dev/null"; then
    break;
  else
    [ $TIMEOUT -le 600 ] || { echo Error: Timeout waiting for SSH server; exit 1; }
    echo "Info: SSH not available yet. Waiting 5 seconds..."
    TIMEOUT=$((TIMEOUT+5));
    sleep 5;
  fi;
done

echo "Info: Starting tests..." 
ssh -p 2222 -o "StrictHostKeyChecking=no" root@127.0.0.1 "test_von_count --gtest_repeat=3 --gtest_break_on_failure --gtest_shuffle --gtest_output=xml:/tmp/gtest_results.xml"
exit_code=$?
scp -P 2222 -o "StrictHostKeyChecking=no" root@127.0.0.1:/tmp/gtest_results.xml "${MULTI_CONF}"-gtest_results.xml
exit "$exit_code"
