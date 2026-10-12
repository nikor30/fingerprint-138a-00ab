#!/bin/bash
# Build + install libfprint with the experimental Validity VCSFW driver
# (libfprint merge request 626, pinned commit) and fprintd.
# Does not open the sensor. Run as root; the build runs as an unprivileged user.
set -euo pipefail

COMMIT=1cf22b89c335b1b63efcccb1113234be9ba2e9d0
BUILD_USER=${BUILD_USER:-${SUDO_USER:-}}
BUILD_DIR=${BUILD_DIR:-/var/tmp/libfprint-validity-build}

[[ $EUID -eq 0 ]] || { echo "run as root (sudo)"; exit 1; }
[[ -n $BUILD_USER && $BUILD_USER != root ]] || { echo "set BUILD_USER=<unprivileged user>"; exit 1; }

pacman -S --needed --noconfirm git meson ninja pkgconf gcc glib2-devel \
    glib2 libgusb libgudev openssl pixman

rm -rf "$BUILD_DIR"
install -d -o "$BUILD_USER" "$BUILD_DIR"
cat > "$BUILD_DIR/PKGBUILD" <<EOF
pkgname=libfprint-validity-git
pkgver=1.94.100.mr626.${COMMIT:0:7}
pkgrel=1
pkgdesc="libfprint with the experimental Validity VCSFW driver (MR 626, 138a:00ab)"
arch=(x86_64)
url="https://gitlab.freedesktop.org/libfprint/libfprint/-/merge_requests/626"
license=(LGPL-2.1-or-later)
depends=(glib2 glibc libgcc libgudev libgusb openssl pixman)
makedepends=(git meson glib2-devel)
provides=(libfprint=1.94.100 libfprint-2.so=2-64)
conflicts=(libfprint)
source=("libfprint::git+https://gitlab.freedesktop.org/libfprint/libfprint.git#commit=$COMMIT")
sha256sums=(SKIP)

build() {
  arch-meson libfprint build -Ddrivers=default -Dintrospection=false \\
    -Ddoc=false -Dgtk-examples=false -Dinstalled-tests=false
  meson compile -C build
}

package() {
  meson install -C build --destdir "\$pkgdir"
}
EOF
chown "$BUILD_USER" "$BUILD_DIR/PKGBUILD"

cd "$BUILD_DIR"
runuser -u "$BUILD_USER" -- makepkg --noconfirm --clean --force

PKG=$(find "$BUILD_DIR" -maxdepth 1 -name 'libfprint-validity-git-[0-9]*.pkg.tar.*' | head -1)
COUNT=$(bsdtar -xOf "$PKG" usr/lib/libfprint-2.so.2.0.0 | grep -ac '6_07f_hp_cmit_mis_qm' || true)
[[ $COUNT -ge 1 ]] || { echo "validity driver not found in the built library - not installing"; exit 1; }

pacman -U --noconfirm "$PKG"
pacman -S --needed --noconfirm fprintd
udevadm control --reload
udevadm trigger --subsystem-match=usb --attr-match=idVendor=138a
pacman -Q libfprint-validity-git fprintd
