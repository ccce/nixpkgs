{ stdenv
, fetchurl

, coreutils
, libselinux
, libsepol
, readline
, systemd_lib
, thin-provisioning-tools
, util-linux_full
, util-linux_lib
}:

let
  baseUrls = [
    "ftp://sources.redhat.com/pub/lvm2/releases"
  ];

  version = "2.02.175";
in
stdenv.mkDerivation rec {
  name = "lvm2-${version}";

  src = fetchurl {
    urls = map (n: "${n}/LVM2.${version}.tgz") baseUrls;
    multihash = "QmcuMs9So1yzmAkUig3NxYirkFqb48fkvRRVaC42G3ypxE";
    hashOutput = false;
    sha512 = "73837edcad6c4165211be6a3528da62a189f1c97bcdd73a69746df9459d3716c0c44580a654b55e2bcafea48797ce4ecee0f1df22e32e599ddebf942807b2638";
  };

  buildInputs = [
    libselinux
    libsepol
    readline
    thin-provisioning-tools
    systemd_lib
    util-linux_lib
  ];

  configureFlags = [
    "--enable-udev_rules"
    "--enable-udev_sync"
    "--enable-pkgconfig"
    "--enable-applib"
    "--enable-cmdlib"
    "--enable-dmeventd"
  ];

  preConfigure = ''
    substituteInPlace scripts/lvmdump.sh \
      --replace /usr/bin/tr ${coreutils}/bin/tr
    substituteInPlace scripts/lvm2_activation_generator_systemd_red_hat.c \
      --replace /usr/sbin/lvm $out/sbin/lvm \
      --replace /usr/bin/udevadm ${systemd_lib}/bin/udevadm

    sed -i /DEFAULT_SYS_DIR/d Makefile.in
    sed -i /DEFAULT_PROFILE_DIR/d conf/Makefile.in
  '';

  # To prevent make install from failing.
  preInstall = ''
    installFlagsArray+=(
      "OWNER="
      "GROUP="
      "confdir=$out/etc"
    )
  '';

  # Install systemd stuff.
  installTargets = [
    "install"
    "install_systemd_generators"
    "install_systemd_units"
    "install_tmpfiles_configuration"
  ];

  postInstall = ''
    substituteInPlace $out/lib/udev/rules.d/13-dm-disk.rules \
      --replace $out/sbin/blkid ${util-linux_full}/bin/blkid

    # Systemd stuff
    mkdir -p $out/etc/systemd/system $out/lib/systemd/system-generators
    cp scripts/blk_availability_systemd_red_hat.service $out/etc/systemd/system
    cp scripts/lvm2_activation_generator_systemd_red_hat $out/lib/systemd/system-generators

    # Fix extraneous @RT_LIB@
    grep -q '@RT_LIB@' "$out"/lib/pkgconfig/devmapper.pc
    sed -i 's,@RT_LIB@,,g' "$out"/lib/pkgconfig/devmapper.pc
  '';

  passthru = {
    srcVerification = fetchurl rec {
      failEarly = true;
      sha512Urls = map (n: "${n}/sha512.sum") baseUrls;
      pgpsigUrls = map (n: "${n}.asc") src.urls;
      pgpKeyFingerprint = "8843 7EF5 C077 BD11 3D3B  7224 2281 91C1 567E 2C17";
      inherit (src) urls outputHash outputHashAlgo;
    };
  };

  meta = with stdenv.lib; {
    homepage = http://sourceware.org/lvm2/;
    descriptions = "Tools to support Logical Volume Management (LVM) on Linux";
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
