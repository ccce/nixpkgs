{ stdenv
, fetchurl

, gnutls
, libgcrypt
, openssl
, zlib
}:

stdenv.mkDerivation rec {
  name = "libmicrohttpd-0.9.54";

  src = fetchurl {
    url = "mirror://gnu/libmicrohttpd/${name}.tar.gz";
    hashOutput = false;
    sha256 = "bcc721895d4a114b0548a39d2241c35caacb9e2e072d40e11b55c60e3d5ddcbe";
  };

  buildInputs = [
    gnutls
    libgcrypt
    openssl
    zlib
  ];

  configureFlags = [
    "--with-threads=posix"
    "--enable-doc"
    "--disable-examples"
    "--enable-poll=auto"
    "--enable-epoll=auto"
    "--enable-socketpair"
    "--disable-curl"
    "--enable-spdy"
    "--enable-messages"
    "--enable-postprocessor"
    "--with-gnutls"
    "--enable-https"
    "--enable-bauth"
    "--enable-dauth"
    "--disable-coverage"
  ];

  passthru = {
    srcVerification = fetchurl rec {
      failEarly = true;
      pgpsigUrls = map (n: "${n}.sig") src.urls;
      pgpKeyFingerprint = "D842 3BCB 326C 7907 0339  29C7 939E 6BE1 E29F C3CC";
      inherit (src) urls outputHash outputHashAlgo;
    };
  };

  meta = with stdenv.lib; {
    description = "Embeddable HTTP server library";
    homepage = http://www.gnu.org/software/libmicrohttpd/;
    license = licenses.lgpl2Plus;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
