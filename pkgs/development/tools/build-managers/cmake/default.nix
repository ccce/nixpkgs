{ stdenv, fetchurl
, bzip2, curl, expat, libarchive, xz, zlib
, useNcurses ? true, ncurses
}:

with stdenv.lib;

let
  os = stdenv.lib.optionalString;
  majorVersion = "3.4";
  minorVersion = "3";
  version = "${majorVersion}.${minorVersion}";
in

stdenv.mkDerivation rec {
  name = "cmake-${version}";

  inherit majorVersion;

  src = fetchurl {
    url = "${meta.homepage}files/v${majorVersion}/cmake-${version}.tar.gz";
    sha256 = "1yl0z422gr7zfc638chifv343vx0ig5gasvrh7nzf7b15488qgxp";
  };

  enableParallelBuilding = true;

  patches =
    # Don't search in non-Nix locations such as /usr, but do search in
    # Nixpkgs' Glibc.
    optional (stdenv ? libc) ./search-path-3.2.patch;

  buildInputs = [ bzip2 curl expat libarchive xz zlib ]
    ++ optional useNcurses ncurses;

  CMAKE_PREFIX_PATH = stdenv.lib.concatStringsSep ":" buildInputs;

  configureFlags = [
    "--docdir=/share/doc/${name}"
    "--mandir=/share/man"
    "--no-system-jsoncpp"
  ] ++ ["--"]
    ++ optional (!useNcurses) "-DBUILD_CursesDialog=OFF";

  setupHook = ./setup-hook.sh;

  dontUseCmakeConfigure = true;

  preConfigure = optionalString (stdenv ? libc) ''
    source $setupHook
    fixCmakeFiles .
    substituteInPlace Modules/Platform/UnixPaths.cmake \
      --subst-var-by libc ${stdenv.libc}
  '';

  meta = {
    homepage = http://www.cmake.org/;
    description = "Cross-Platform Makefile Generator";
    platforms = stdenv.lib.platforms.all;
    maintainers = with stdenv.lib.maintainers; [ urkud mornfall ttuegel ];
  };
}
