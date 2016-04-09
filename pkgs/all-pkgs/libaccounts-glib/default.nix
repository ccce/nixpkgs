{ stdenv
, autoreconfHook
, fetchFromGitLab
, gtk-doc
, libtool
, libxslt

, glib
, gobject-introspection
, libxml2
, sqlite
}:

let
  inherit (stdenv.lib)
    enFlag;
in

stdenv.mkDerivation rec {
  name = "libaccounts-glib-${version}";
  version = "1.21";

  src = fetchFromGitLab {
    owner = "accounts-sso";
    repo = "libaccounts-glib";
    rev = "VERSION_${version}";
    sha256 = "da830281059247fe30c6112b86e1226a3eea8020ce59d3015822570b16927356";
  };

  nativeBuildInputs = [
    autoreconfHook
    gtk-doc
    libtool
    libxslt
  ];

  buildInputs = [
    glib
    gobject-introspection
    libxml2
    sqlite
  ];

  postPatch = ''
    gtkdocize --copy --flavour no-tmpl
  '';

  configureFlags = [
    (enFlag "introspection" (gobject-introspection != null) null)
    "--disable-tests"
    "--disable-gcov"
    "--disable-gtk-doc"
    "--disable-gtk-doc-html"
    "--disable-gtk-doc-pdf"
    "--enable-cast-checks"
    "--enable-asserts"
    "--enable-checks"
    "--disable-debug"
    "--enable-wal"
    "--enable-python"
    "--disable-man"
  ];

  makeFlags = [
    "INTROSPECTION_TYPELIBDIR=$(out)/lib/girepository-1.0/"
  ];
}
