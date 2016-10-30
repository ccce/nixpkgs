{ stdenv
, docbook_xml_dtd_412
, docbook-xsl
, fetchurl
, gettext
, glibcLocales
, libxslt
, makeWrapper
, perlPackages
}:

let
  version = "0.48";
  id = "4176";
in
stdenv.mkDerivation rec {
  name = "po4a-${version}";

  src = fetchurl {
    url = "https://alioth.debian.org/frs/download.php/file/${id}/${name}.tar.gz";
    multihash = "QmdSkx1isZmu4u6XbfaL8H6VKx4Xos2e9oSShV8hDvq3fz";
    sha256 = "a89595ca42e896c97ce4ffc231a075cc88692216b4bc05df40414d7428c4286c";
  };

  # Perl needs en_US.UTF-8
  LOCALE_ARCHIVE = "${glibcLocales}/lib/locale/locale-archive";

  nativeBuildInputs = [
    docbook_xml_dtd_412
    docbook-xsl
    gettext
    libxslt
    makeWrapper
    perlPackages.LocaleGettext
    perlPackages.ModuleBuild
    perlPackages.perl
    perlPackages.SGMLSpm
    perlPackages.TermReadKey
    perlPackages.TextWrapI18N
    perlPackages.UnicodeLineBreak
  ];

  configurePhase = ''
    perl Build.PL installdirs=vendor create_packlist=0
  '';

  buildPhase = ''
    LC_ALL=en_US.UTF-8 perl Build
  '';

  installPhase = ''
    find . -name \*.pm
    perl Build destdir=$out install
    dir="$out/${perlPackages.perl}"
    mv "$dir"/* "$out"
    while [ "$dir" != "$out" ]; do
      rmdir "$dir"
      dir="$(dirname "$dir")"
    done

    mkdir -p "$out/${perlPackages.perl.libPrefix}"
    cp -r blib/lib/* "$out/${perlPackages.perl.libPrefix}"
  '';

  preFixup = ''
    progs=($(find $out/bin -type f))
    for prog in "''${progs[@]}"; do
      wrapProgram "$prog" \
        --prefix PATH : "$out/bin:${gettext}/bin" \
        --prefix PERL5LIB : "$out/${perlPackages.perl.libPrefix}"
    done
  '';

  meta = with stdenv.lib; {
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
