#!/usr/bin/env bash
set -euo pipefail

version=1.2.1
archive="qcom-sensors-prebuilts_${version}_armv8a.tar.gz"
url="https://qartifactory-edge.qualcomm.com/artifactory/qsc_releases/software/chip/component/sensors.lnx.0.0/260514.1/prebuilt_yocto/${archive}"
sha256="507652592b326bfeb1b31c4c37f61a5173439bd3dffa7ded72b675f834ea11bb"
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
archive_path="${root}/${archive}"
staging="${root}/staging"

verify_archive() {
    printf '%s  %s\n' "${sha256}" "$1" | sha256sum --check --status
}

if [[ -f "${archive_path}" ]] && ! verify_archive "${archive_path}"; then
    echo "Cached archive checksum mismatch: ${archive_path}" >&2
    exit 1
fi

if [[ ! -f "${archive_path}" ]]; then
    tmp_download="${archive_path}.tmp"
    rm -f "${tmp_download}"
    trap 'rm -f "${tmp_download}"' EXIT
    curl --fail --location --retry 3 --output "${tmp_download}" "${url}"
    verify_archive "${tmp_download}" || {
        echo "Downloaded archive checksum mismatch" >&2
        exit 1
    }
    mv "${tmp_download}" "${archive_path}"
    trap - EXIT
fi

unpack=$(mktemp -d)
trap 'rm -rf "${unpack}"' EXIT
tar -xzf "${archive_path}" -C "${unpack}"

test -f "${unpack}/LICENSE.qcom-2"
printf '%s  %s\n' 'f33ba334514c4dfabc6ab7377babb377' "${unpack}/LICENSE.qcom-2" | md5sum --check --status

rm -rf "${staging}"
install -d \
    "${staging}/usr/bin" \
    "${staging}/usr/lib/aarch64-linux-gnu/pkgconfig" \
    "${staging}/usr/include" \
    "${staging}/usr/lib/systemd/system" \
    "${staging}/usr/share/doc/qcom-sensors-binaries" \
    "${staging}/etc/sensors/config" \
    "${staging}/etc/sensors/registry"

cp -a "${unpack}/usr/bin/." "${staging}/usr/bin/"
for library in \
    libsensinghubapiprop \
    libQshQmiIDL \
    libQshSession \
    libsnsdiaglog \
    libUSTANative \
    libSEESalt \
    libsns_direct_channel_stub \
    libsns_remote_proc_state_stub; do
    cp -a "${unpack}/usr/lib/${library}.so"* "${staging}/usr/lib/aarch64-linux-gnu/"
done
cp -a "${unpack}/usr/lib/pkgconfig/." "${staging}/usr/lib/aarch64-linux-gnu/pkgconfig/"
cp -a "${unpack}/usr/include/." "${staging}/usr/include/"
cp -a "${unpack}/etc/sensors/config/." "${staging}/etc/sensors/config/"
cp -a "${unpack}/etc/sensors/registry/sns_reg_version" "${staging}/etc/sensors/registry/"
cp -a "${unpack}/etc/sensors/sns_reg_config" "${staging}/etc/sensors/"
cp -a "${unpack}/usr/lib/systemd/system/sscrpcd.service" "${staging}/usr/lib/systemd/system/"
install -m 0644 "${unpack}/LICENSE.qcom-2" "${staging}/usr/share/doc/qcom-sensors-binaries/"
install -m 0644 "${unpack}/CHANGES" "${staging}/usr/share/doc/qcom-sensors-binaries/changelog"

find "${staging}/usr/bin" -type f -exec chmod 0755 {} +
find "${staging}" -type f ! -path '*/usr/bin/*' -exec chmod 0644 {} +
