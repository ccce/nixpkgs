{ stdenv
, cmake
, fetchTritonPatch
, fetchurl
, lib

, curl
, cairo
, freetype
, fontconfig
, glib
, gobject-introspection
, libtiff
, lcms2
, libjpeg
, libpng
, nspr
, nss
, openjpeg
, qt5
, zlib

, utils ? false
, suffix ? "glib"
}:

# FIXME: gobject-introspection and openjpeg support is not working currently

assert (
  suffix == "glib" ||
  suffix == "qt5" ||
  suffix == "utils"
);

let
  inherit (lib)
    boolOn
    boolString;

  version = "0.57.0";
in
stdenv.mkDerivation rec {
  name = "poppler-${suffix}-${version}";

  src = fetchurl {
    url = "https://poppler.freedesktop.org/poppler-${version}.tar.xz";
    multihash = "QmRR3WwoFFYcCDwjYxQKZzSS7oKDTaUNR4HMi2f2PH6khv";
    sha256 = "0ea37de71b7db78212ebc79df59f99b66409a29c2eac4d882dae9f2397fe44d8";
  };

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    cairo
    curl
    fontconfig
    freetype
    glib
    #gobject-introspection
    lcms2
    libjpeg
    libpng
    libtiff
    nspr
    nss
    openjpeg
    qt5
    zlib
  ];

  postUnpack = ''
    rm -v $sourceRoot/configure{,.ac}
  '';

  patches = [
    (fetchTritonPatch {
      rev = "d3fc5e59bd2b4b465c2652aae5e7428b24eb5669";
      file = "poppler/poppler-datadir_env.patch";
      sha256 = "da3dd1d57a7ef0dcda7442dff2fff5375e249ba85caba9828be4fc51bfa300ff";
    })
  ];

  cmakeFlags = [
    "-DBUILD_CPP_TESTS=OFF"
    "-DBUILD_GTK_TESTS=OFF"
    "-DBUILD_QT4_TESTS=OFF"
    "-DBUILD_QT5_TESTS=OFF"
    "-DENABLE_CMS=${boolString (lcms2 != null) "lcms2" "OFF"}"
    "-DENABLE_CPP=ON"
    "-DENABLE_LIBCURL=${boolOn (curl != null)}"
    "-DENABLE_LIBOPENJPEG=${boolString (openjpeg != null) "openjpeg2" "OFF"}"
    #"-DENABLE_SPLASH=ON"
    "-DENABLE_UTILS=${boolOn utils}"
    "-DENABLE_XPDF_HEADERS=ON"
    "-DENABLE_ZLIB=${boolOn (zlib != null)}"
    "-DENABLE_ZLIB_UNCOMPRESS=${boolOn (zlib != null)}"
    "-DFONT_CONFIGURATION=${boolString (fontconfig != null) "fontconfig" "OFF"}"
    "-DSPLASH_CMYK=ON"
    "-DUSE_FIXEDPOINT=OFF"
    "-DUSE_FLOAT=ON"
    "-DWITH_Cairo=${boolOn (cairo != null)}"
    "-DWITH_GLIB=${boolOn (
      cairo != null
      && glib != null
      && gobject-introspection != null)}"
    #"-DWITH_GObjectIntrospection=${boolOn (gobject-introspection != null)}"
    #"-DWITH_GTK=${boolOn (gtk3 != null)}"
    "-DWITH_Iconv=ON"
    "-DWITH_JPEG=${boolOn (libjpeg != null)}"
    "-DWITH_NSS3=${boolOn (nss != null)}"
    "-DWITH_PNG=${boolOn (libpng != null)}"
    "-DWITH_Qt4=OFF"
    "-DWITH_TIFF=${boolOn (libtiff != null)}"
  ];

  NIX_CFLAGS_COMPILE = [
    "-Wno-deprecated-declarations"
  ];

  meta = with lib; {
    description = "A PDF rendering library";
    homepage = http://poppler.freedesktop.org/;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
