{ stdenv
, fetchurl
, libarchive
}:

let
  version = "20160607";
  id = "26083";
in
stdenv.mkDerivation rec {
  name = "microcode-intel-${version}";

  src = fetchurl {
    url = "https://downloadmirror.intel.com/${id}/eng/microcode-${version}.tgz";
    sha256 = "db821eb47af2caa39613caee0eb89a9584b2ebc4a9ab1b9624fe778f9a41fa7d";
  };

  nativeBuildInputs = [
    libarchive
  ];

  sourceRoot = ".";

  buildPhase = ''
    gcc -O2 -Wall -o intel-microcode2ucode ${./intel-microcode2ucode.c}
    ./intel-microcode2ucode microcode.dat
  '';

  installPhase = ''
    mkdir -p $out kernel/x86/microcode
    mv microcode.bin kernel/x86/microcode/GenuineIntel.bin
    echo kernel/x86/microcode/GenuineIntel.bin | bsdcpio -o -H newc -R 0:0 > $out/intel-ucode.img
  '';

  meta = with stdenv.lib; {
    homepage = http://www.intel.com/;
    description = "Microcode for Intel processors";
    license = licenses.unfreeRedistributableFirmware;
    maintainers = with maintainers; [ wkennington ];
    platforms = platforms.linux;
  };
}
