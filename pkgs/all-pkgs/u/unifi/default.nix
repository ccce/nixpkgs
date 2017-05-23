{ stdenv
, fetchurl
, unzip
}:

let
  version = "5.4.16";
in
stdenv.mkDerivation rec {
  name = "unifi-controller-${version}";

  src = fetchurl {
    url = "https://www.ubnt.com/downloads/unifi/${version}/UniFi.unix.zip";
    sha256 = "32e8024f6d5d0323f365790ca157597c71f0dbe0a540ecfb6e8bc6106e381de5";
  };

  nativeBuildInputs = [
    unzip
  ];

  buildPhase = ''
    rm -rf bin conf readme.txt
    for so in $(find . -name \*.so\*); do
      chmod +x "$so"
      patchelf --set-rpath "${stdenv.cc.cc}/lib:${stdenv.libc}/lib" \
        "$so"
      if ldd "$so" | grep -q 'not found'; then
        echo "Didn't completely patch $so"
        exit 1
      fi
    done
  '';

  installPhase = ''
    mkdir -p $out
    cp -ar * $out
  '';

  meta = with stdenv.lib; {
    homepage = http://www.ubnt.com/;
    description = "Controller for Ubiquiti UniFi accesspoints";
    license = licenses.unfree;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
