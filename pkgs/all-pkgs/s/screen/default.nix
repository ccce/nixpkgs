{ stdenv
, fetchurl

, ncurses
, pam
}:

stdenv.mkDerivation rec {
  name = "screen-4.5.0";

  src = fetchurl {
    url = "mirror://gnu/screen/${name}.tar.gz";
    hashOutput = false;
    sha256 = "01c3a7c362185f35d6a95dff52d64337076496acd034d717de3c263500cfefb0";
  };

  buildInputs = [
    ncurses
    pam
  ];

  postPatch = ''
    find . -name Makefile.in | xargs sed -i \
      -e "s|/usr/local|/non-existent|g" \
      -e "s|/usr|/non-existent|g"
  '';

  preConfigure = ''
    configureFlagsArray+=(
      "--infodir=$out/share/info"
      "--mandir=$out/share/man"
    )
  '';

  configureFlags = [
    "--enable-telnet"
    "--enable-pam"
    "--with-sys-screenrc=/etc/screenrc"
    "--enable-colors256"
  ];

  doCheck = true;

  # Some generated headers are not ready when needed
  parallelBuild = false;

  passthru = {
    srcVerification = fetchurl {
      failEarly = true;
      pgpsigUrls = map (n: "${n}.sig") src.urls;
      pgpKeyFingerprints = [
        "2EE5 9A5D 0C50 167B 5535  BBF1 B708 A383 C53E F3A4"
        "71AA 09D9 E887 0FDB 0AA7  B61E 21F9 68DE F747 ABD7"
      ];
      inherit (src) urls outputHash outputHashAlgo;
    };
  };

  meta = with stdenv.lib; {
    homepage = http://www.gnu.org/software/screen/;
    description = "A window manager that multiplexes a physical terminal";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
