#!/bin/bash
# Build + install the runtime data package the driver needs
# (ggiesen/libfprint-validity-data, pinned commit) with the patch from
# patches/ applied, so 138a:00ab gets HP's reset blob instead of Lenovo's.
# Does not open the sensor. Run as root.
set -euo pipefail

COMMIT=687c5ea51392582d5bcb1e4fa86eea0832a50c5f
HERE=$(cd "$(dirname "$0")/.." && pwd)
PATCH=0001-138a-00ab-use-HP-s-reset_blob.patch
BUILD_USER=${BUILD_USER:-${SUDO_USER:-}}
BUILD_DIR=${BUILD_DIR:-/var/tmp/libfprint-validity-data-build}

[[ $EUID -eq 0 ]] || { echo "run as root (sudo)"; exit 1; }
[[ -n $BUILD_USER && $BUILD_USER != root ]] || { echo "set BUILD_USER=<unprivileged user>"; exit 1; }

pacman -S --needed --noconfirm git python make

rm -rf "$BUILD_DIR"
install -d -o "$BUILD_USER" "$BUILD_DIR"
install -m644 -o "$BUILD_USER" "$HERE/patches/$PATCH" "$BUILD_DIR/"
cat > "$BUILD_DIR/PKGBUILD" <<EOF
pkgname=libfprint-validity-data
pkgver=0.2.0.${COMMIT:0:7}.hp00ab
pkgrel=1
pkgdesc="Sensor data files for the experimental libfprint Validity driver (138a:00ab with HP reset blob)"
arch=(any)
url="https://gitlab.freedesktop.org/ggiesen/libfprint-validity-data"
license=(MIT)
depends=(libfprint)
makedepends=(git python)
source=("data::git+https://gitlab.freedesktop.org/ggiesen/libfprint-validity-data.git#commit=$COMMIT"
        "$PATCH")
sha256sums=(SKIP SKIP)

prepare() {
  cd data
  git apply "\$srcdir/$PATCH"
}

build() {
  cd data
  python3 -I generate_data.py
  python3 -I generate_data.py --verify output/
  cmp output/138a_00ab/reset.bin output/06cb_00cb/reset.bin
}

package() {
  cd data
  make install DESTDIR="\$pkgdir"
  install -Dm644 LICENSE "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE"
}
EOF
chown "$BUILD_USER" "$BUILD_DIR/PKGBUILD"

cd "$BUILD_DIR"
runuser -u "$BUILD_USER" -- makepkg --noconfirm --clean --force

PKG=$(find "$BUILD_DIR" -maxdepth 1 -name 'libfprint-validity-data-*.pkg.tar.*' | head -1)
pacman -U --noconfirm "$PKG"
echo "a928b9e4f014c671c3c8bc0d787424ee13f6f45ae1e67e85b418f5479ea38d76 = Lenovo blob (rejected by HP sensors)"
sha256sum /usr/share/libfprint/validity/138a_00ab/reset.bin
