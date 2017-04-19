{ stdenv
, fetchurl
, lib

, cairo
, fontconfig
, freetype
, glib
, gobject-introspection
, harfbuzz
, xorg
}:

assert xorg != null ->
  xorg.libX11 != null
  && xorg.libXft != null
  && xorg.libXrender != null;

let
  inherit (lib)
    boolEn
    boolWt
    optionals
    optionalString;

  versionMajor = "1.40";
  versionMinor = "5";
  version = "${versionMajor}.${versionMinor}";
in
stdenv.mkDerivation rec {
  name = "pango-${version}";

  src = fetchurl {
    url = "mirror://gnome/sources/pango/${versionMajor}/${name}.tar.xz";
    hashOutput = false;
    sha256 = "24748140456c42360b07b2c77a1a2e1216d07c056632079557cd4e815b9d01c9";
  };

  buildInputs = [
    cairo
    fontconfig
    freetype
    glib
    gobject-introspection
    harfbuzz
  ] ++ optionals (xorg != null) [
    xorg.libX11
    xorg.libXft
    xorg.libXrender
  ];

  postPatch = /* Test fails randomly */ optionalString doCheck ''
    sed -i tests/Makefile.in \
      -e 's,\(am__append_4 = testiter\) test-pangocairo-threads,\1,g'
  '';

  configureFlags = [
    "--enable-rebuilds"
    "--${boolEn (gobject-introspection != null)}-introspection"
    "--disable-gtk-doc"
    "--disable-gtk-doc-html"
    "--disable-gtk-doc-pdf"
    "--disable-doc-cross-reference"
    "--enable-Bsymbolic"
    "--disable-installed-tests"
    "--${boolWt (xorg != null)}-xft"
    "--${boolWt (cairo != null)}-cairo"
  ];

  # Does not respect --disable-gtk-doc
  postInstall = "rm -rvf $out/share/gtk-doc";

  preCheck = /* Fontconfig fails to load default config in test */
      optionalString doCheck ''
    export FONTCONFIG_FILE="${fontconfig}/etc/fonts/fonts.conf"
  '';

  doCheck = true;

  passthru = {
    srcVerification = fetchurl {
      inherit (src)
        outputHash
        outputHashAlgo
        urls;
      sha256Url = "https://download.gnome.org/sources/pango/${versionMajor}/"
        + "${name}.sha256sum";
      failEarly = true;
    };
  };

  meta = with lib; {
    description = "A library for laying out and rendering of text";
    homepage = http://www.pango.org/;
    license = licenses.lgpl2Plus;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
