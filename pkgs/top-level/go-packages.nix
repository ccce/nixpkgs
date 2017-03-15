/* This file defines the composition for Go packages. */

{ stdenv
, buildGoPackage
, fetchbzr
, fetchFromBitbucket
, fetchFromGitHub
, fetchgit
, fetchhg
, fetchpatch
, fetchurl
, fetchzip
, git
, go
, overrides
, pkgs
}:

let
  self = _self // overrides; _self = with self; {

  inherit go buildGoPackage;

  fetchGxPackage = { src, sha256 }: stdenv.mkDerivation {
    name = "gx-src-${src.name}";

    impureEnvVars = [ "IPFS_API" ];

    buildCommand = ''
      if ! [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        echo "Missing /etc/ssl/certs/ca-certificates.crt" >&2
        echo "Please update to a version of nix which supports ssl." >&2
        exit 1
      fi

      start="$(date -u '+%s')"

      unpackDir="$TMPDIR/src"
      mkdir "$unpackDir"
      cd "$unpackDir"
      unpackFile "${src}"
      cd *

      echo "Environment:" >&2
      echo "  IPFS_API: $IPFS_API" >&2

      mtime=$(find . -type f -print0 | xargs -0 -r stat -c '%Y' | sort -n | tail -n 1)
      if [ "$start" -lt "$mtime" ]; then
        str="The newest file is too close to the current date:\n"
        str+="  File: $(date -u -d "@$mtime")\n"
        str+="  Current: $(date -u)\n"
        echo -e "$str" >&2
        exit 1
      fi
      echo -n "Clamping to date: " >&2
      date -d "@$mtime" --utc >&2

      gx --verbose install --global

      echo "Building GX Archive" >&2
      cd "$unpackDir"
      ${src.tar}/bin/tar --sort=name --owner=0 --group=0 --numeric-owner \
        --no-acls --no-selinux --no-xattrs \
        --mode=go=rX,u+rw,a-s \
        --clamp-mtime --mtime=@$mtime \
        -c . | ${src.brotli}/bin/brotli --quality 6 --output "$out"
    '';

    buildInputs = [ gx.bin ];
    outputHashAlgo = "sha256";
    outputHashMode = "flat";
    outputHash = sha256;
    preferLocalBuild = true;
  };

  buildFromGitHub =
    { rev
    , date ? null
    , owner
    , repo
    , sha256
    , version
    , gxSha256 ? null
    , goPackagePath ? "github.com/${owner}/${repo}"
    , name ? baseNameOf goPackagePath
    , ...
    } @ args:
    buildGoPackage (args // (let
        name' = "${name}-${if date != null then date else if builtins.stringLength rev != 40 then rev else stdenv.lib.strings.substring 0 7 rev}";
      in {
        inherit rev goPackagePath;
        name = name';
        src = let
          src' = fetchFromGitHub {
            name = name';
            inherit rev owner repo sha256 version;
          };
        in if gxSha256 == null then
          src'
        else
          fetchGxPackage { src = src'; sha256 = gxSha256; };
      })
  );

  ## OFFICIAL GO PACKAGES

  appengine = buildFromGitHub {
    version = 2;
    rev = "v1.0.0";
    owner = "golang";
    repo = "appengine";
    sha256 = "0z0vrrwh4f4ji2v3sv40db7m5l31mw08mjwlgzibf0nfjaganwgl";
    goPackagePath = "google.golang.org/appengine";
    propagatedBuildInputs = [
      protobuf
      net
    ];
  };

  crypto = buildFromGitHub {
    version = 2;
    rev = "728b753d0135da6801d45a38e6f43ff55779c5c2";
    date = "2017-03-07";
    owner    = "golang";
    repo     = "crypto";
    sha256 = "1qi1b689y73is9hvydlnqlqyp41bwyja7grxx3s53nniczzx26np";
    goPackagePath = "golang.org/x/crypto";
    goPackageAliases = [
      "code.google.com/p/go.crypto"
      "github.com/golang/crypto"
    ];
    buildInputs = [
      net_crypto_lib
    ];
  };

  debug = buildFromGitHub {
    version = 2;
    rev = "fb508927b491eca48a708e9d000fdb7afa53c32b";
    date = "2016-06-20";
    owner  = "golang";
    repo   = "debug";
    sha256 = "19g7hcsp24z5plbb2d2y5z16h0z0nc4fmf3lx7m3avf60zvwhns9";
    goPackagePath = "golang.org/x/debug";
    excludedPackages = "\\(testdata\\)";
  };

  geo = buildFromGitHub {
    version = 2;
    rev = "f819552e7195873dbc628554929703291cecbea0";
    owner = "golang";
    repo = "geo";
    sha256 = "0j1viy2yl4rdlvivyp64nbn8qmq3px4514zdjxp878jgxn883648";
    date = "2017-01-12";
  };

  glog = buildFromGitHub {
    version = 1;
    rev = "23def4e6c14b4da8ac2ed8007337bc5eb5007998";
    date = "2016-01-25";
    owner  = "golang";
    repo   = "glog";
    sha256 = "0wj30z2r6w1zdbsi8d14cx103x13jszlqkvdhhanpglqr22mxpy0";
  };

  net = buildFromGitHub {
    version = 2;
    rev = "a6577fac2d73be281a500b310739095313165611";
    date = "2017-03-08";
    owner  = "golang";
    repo   = "net";
    sha256 = "1z8y2gjkzs1y9d8ysw0s2nx4dy4mjgkfy6hh3mk7xx4sipzg94v0";
    goPackagePath = "golang.org/x/net";
    goPackageAliases = [
      "github.com/hashicorp/go.net"
      "github.com/golang/net"
    ];
    propagatedBuildInputs = [
      text
      crypto
    ];
  };

  net_crypto_lib = buildFromGitHub {
    inherit (net) rev date owner repo sha256 version goPackagePath;
    subPackages = [
      "context"
    ];
  };

  oauth2 = buildFromGitHub {
    version = 2;
    rev = "30fcca6531eb4bb278493c9fb299295b3b145934";
    date = "2017-03-15";
    owner = "golang";
    repo = "oauth2";
    sha256 = "05lyw0bl04h0kl69nigi2zpamh7flxj87da0djqf7vkl3ph65s3s";
    goPackagePath = "golang.org/x/oauth2";
    goPackageAliases = [ "github.com/golang/oauth2" ];
    propagatedBuildInputs = [
      net
      google-cloud-go-compute-metadata
    ];
  };


  protobuf = buildFromGitHub {
    version = 2;
    rev = "c9c7427a2a70d2eb3bafa0ab2dc163e45f143317";
    date = "2017-03-07";
    owner = "golang";
    repo = "protobuf";
    sha256 = "17rrbl543n6v12ip1pfscxm2cgv9wq1rfb3488m274phc8f0n5h4";
    goPackagePath = "github.com/golang/protobuf";
    goPackageAliases = [
      "code.google.com/p/goprotobuf"
    ];
    buildInputs = [
      genproto_protobuf
    ];
  };

  protobuf_genproto = buildFromGitHub {
    inherit (protobuf) version rev date owner repo goPackagePath sha256;
    subPackages = [
      "proto"
      "ptypes/any"
    ];
  };

  snappy = buildFromGitHub {
    version = 2;
    rev = "553a641470496b2327abcac10b36396bd98e45c9";
    date = "2017-02-16";
    owner  = "golang";
    repo   = "snappy";
    sha256 = "1p27dax5jy6isvxmhnssz99pz9mzwcr1wbvdp1m3s6ap0qq708gg";
    goPackageAliases = [
      "code.google.com/p/snappy-go/snappy"
    ];
  };

  sync = buildFromGitHub {
    version = 2;
    rev = "a60ad46e0ed33d02e09bda439efaf9c9727dbc6c";
    date = "2017-03-15";
    owner  = "golang";
    repo   = "sync";
    sha256 = "1h02a97w52hs08h857h9yh52vh7jaq1wzcg1vgl6yv7mz6r679b5";
    goPackagePath = "golang.org/x/sync";
    propagatedBuildInputs = [
      net
    ];
  };

  sys = buildFromGitHub {
    version = 2;
    rev = "99f16d856c9836c42d24e7ab64ea72916925fa97";
    date = "2017-03-08";
    owner  = "golang";
    repo   = "sys";
    sha256 = "17ax27sa7src8mh946xz667nlm5h2r0ms4lh5khaam4ayw59y3x8";
    goPackagePath = "golang.org/x/sys";
    goPackageAliases = [
      "github.com/golang/sys"
    ];
  };

  text = buildFromGitHub {
    version = 2;
    rev = "f28f36722d5ef2f9655ad3de1f248e3e52ad5ebd";
    date = "2017-03-03";
    owner = "golang";
    repo = "text";
    sha256 = "1jvchi8df0r92df7r7lvkf25hpbrlawmfgbs49mnwnq0411nq2f4";
    goPackagePath = "golang.org/x/text";
    goPackageAliases = [ "github.com/golang/text" ];
    excludedPackages = "cmd";
  };

  time = buildFromGitHub {
    version = 2;
    rev = "f51c12702a4d776e4c1fa9b0fabab841babae631";
    date = "2016-10-27";
    owner  = "golang";
    repo   = "time";
    sha256 = "0p46261y3p546n3gbv6w1r32m0743s7zkr899sgd5jfpws6l114n";
    goPackagePath = "golang.org/x/time";
    propagatedBuildInputs = [
      net
    ];
  };

  tools = buildFromGitHub {
    version = 2;
    rev = "b282a57667dab7f4b905b91a925f097fe0d1c48c";
    date = "2017-03-15";
    owner = "golang";
    repo = "tools";
    sha256 = "0i3nvkmd6dxirkwjf5lfyzlvjliqz0frl6p4k8rp0dzhx8kwyng5";
    goPackagePath = "golang.org/x/tools";
    goPackageAliases = [ "code.google.com/p/go.tools" ];

    preConfigure = ''
      # Make the builtin tools available here
      mkdir -p $bin/bin
      eval $(go env | grep GOTOOLDIR)
      find $GOTOOLDIR -type f | while read x; do
        ln -sv "$x" "$bin/bin"
      done
      export GOTOOLDIR=$bin/bin
    '';

    excludedPackages = "\\("
      + stdenv.lib.concatStringsSep "\\|" ([ "testdata" ] ++ stdenv.lib.optionals (stdenv.lib.versionAtLeast go.meta.branch "1.5") [ "vet" "cover" ])
      + "\\)";

    buildInputs = [ appengine net ];

    # Do not copy this without a good reason for enabling
    # In this case tools is heavily coupled with go itself and embeds paths.
    allowGoReference = true;

    # Set GOTOOLDIR for derivations adding this to buildInputs
    postInstall = ''
      mkdir -p $bin/nix-support
      echo "export GOTOOLDIR=$bin/bin" >> $bin/nix-support/setup-hook
    '';
  };


  ## THIRD PARTY

  ace = buildFromGitHub {
    version = 2;
    owner = "yosssi";
    repo = "ace";
    rev = "v0.0.5";
    sha256 = "0i3jfkgwvaz5w1cgz7sqqa7pnpz6hd0dniw2j89yhq6qgb4ikjy0";
    buildInputs = [
      gohtml
    ];
  };

  aeshash = buildFromGitHub {
    version = 2;
    rev = "8ba92803f64b76c91b111633cc0edce13347f0d1";
    owner  = "tildeleb";
    repo   = "aeshash";
    sha256 = "0p1nbk5nx2xhl8kan4bd6lcpmjrh7c60lyy9nf4rafyv2j7qqhnk";
    goPackagePath = "leb.io/aeshash";
    date = "2016-11-30";
    subPackages = [
      "."
    ];
    propagatedBuildInputs = [
      hashland_for_aeshash
    ];
  };

  afero = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "afero";
    rev = "9be650865eab0c12963d8753212f4f9c66cdcf12";
    date = "2017-02-17";
    sha256 = "0xg09gigsv4c57zixvwnhfh2vfbg5banyhp426kbfs57hda697l8";
    propagatedBuildInputs = [
      sftp
      text
    ];
  };

  amber = buildFromGitHub {
    version = 2;
    owner = "eknkc";
    repo = "amber";
    rev = "d15eb996544134263b00cce829b5bc4988fdb2df";
    date = "2017-03-11";
    sha256 = "1n0bgl3kczlran3i7c6rnbbsz42r23syrw83a0g529lq75r83q37";
  };

  amqp = buildFromGitHub {
    version = 2;
    owner = "streadway";
    repo = "amqp";
    rev = "afe8eee29a74d213b1f3fb2586058157c397da60";
    date = "2017-03-13";
    sha256 = "1pmpmy8miiimibhkmznz17fawhnvkl0l2jnl30aj302l2lshil9d";
  };

  ansi = buildFromGitHub {
    version = 2;
    owner = "mgutz";
    repo = "ansi";
    rev = "9520e82c474b0a04dd04f8a40959027271bab992";
    date = "2017-02-06";
    sha256 = "1180ng6y5b1cnxschbswxaq2cp4yjchhwqjzimspnxj2mh16syhd";
    propagatedBuildInputs = [
      go-colorable
    ];
  };

  ansicolor = buildFromGitHub {
    version = 1;
    date = "2015-11-20";
    rev = "a422bbe96644373c5753384a59d678f7d261ff10";
    owner  = "shiena";
    repo   = "ansicolor";
    sha256 = "1qfq4ax68d7a3ixl60fb8kgyk0qx0mf7rrk562cnkpgzrhkdcm0w";
  };

  asn1-ber = buildFromGitHub {
    version = 2;
    rev = "b144e4fe15d4968eb8d6e33d70761727d124814e";
    owner  = "go-asn1-ber";
    repo   = "asn1-ber";
    sha256 = "1n5x5y71f8g1p63x5dnpj2pj79625j2j3d8swgyrbi845frrskdd";
    goPackageAliases = [
      "github.com/nmcclain/asn1-ber"
      "github.com/vanackere/asn1-ber"
      "gopkg.in/asn1-ber.v1"
    ];
    date = "2016-09-13";
  };

  auroradnsclient = buildFromGitHub {
    version = 2;
    rev = "v1.0.1";
    owner  = "edeckers";
    repo   = "auroradnsclient";
    sha256 = "0pcjz19aycd01v4v52zbfldhr81rxy6aj7jh1y09issnqr8kgc4h";
    propagatedBuildInputs = [
      logrus
    ];
  };

  aws-sdk-go = buildFromGitHub {
    version = 2;
    rev = "v1.7.9";
    owner  = "aws";
    repo   = "aws-sdk-go";
    sha256 = "1f9xygnm0k1idkwvrg83sixy18l8qdwjg5qi9vc17qyb8zv5d280";
    excludedPackages = "\\(awstesting\\|example\\)";
    buildInputs = [
      tools
    ];
    propagatedBuildInputs = [
      ini
      go-jmespath
      net
    ];
    preBuild = ''
      pushd go/src/$goPackagePath
      make generate
      popd
    '';
  };

  azure-sdk-for-go = buildFromGitHub {
    version = 2;
    date = "2017-03-02";
    rev = "4897648e310020dae650a89c31ff633284c13a24";
    owner  = "Azure";
    repo   = "azure-sdk-for-go";
    sha256 = "1wwmkap03f4iq6yd11qcbpr7m7l9g5hzms732aj6byhpvsg2lw57";
    excludedPackages = "Gododir";
    buildInputs = [
      decimal
      go-autorest
      satori_uuid
    ];
  };

  b = buildFromGitHub {
    version = 1;
    date = "2016-07-16";
    rev = "bcff30a622dbdcb425aba904792de1df606dab7c";
    owner  = "cznic";
    repo   = "b";
    sha256 = "0zjr4spbgavwq4lvxzl3h8hrkbyjk49vq14jncpydrjw4a9qql95";
  };

  bigfft = buildFromGitHub {
    version = 1;
    date = "2013-09-13";
    rev = "a8e77ddfb93284b9d58881f597c820a2875af336";
    owner = "remyoudompheng";
    repo = "bigfft";
    sha256 = "1cj9zyv3shk8n687fb67clwgzlhv47y327180mvga7z741m48hap";
  };

  binary = buildFromGitHub {
    version = 2;
    owner = "alecthomas";
    repo = "binary";
    rev = "ec810c4448fb8161fd00898b18c6f72ec661216a";
    date = "2017-01-11";
    sha256 = "1lpaqcxgd0pgrawn1hfss0mcv7wp1h0xdy5q3w75ydblay9g7ri8";
  };

  binding = buildFromGitHub {
    version = 2;
    date = "2016-12-22";
    rev = "48920167fa152d02f228cfbece7e0f1e452d200a";
    owner = "go-macaron";
    repo = "binding";
    sha256 = "0dnkwgdx9y2dq7x3q9703371c7ph8w3aqr9q64vcrb086lisbj7z";
    buildInputs = [
      com
      compress
      macaron_v1
    ];
  };

  blackfriday = buildFromGitHub {
    version = 2;
    owner = "russross";
    repo = "blackfriday";
    rev = "5f33e7b7878355cd2b7e6b8eefc48a5472c69f70";
    sha256 = "15j4y3a3s0p0phdi5wyzz8c4v7zlvpy78f2nkczm8k15syyrjih8";
    propagatedBuildInputs = [
      sanitized-anchor-name
    ];
    date = "2016-10-03";
  };

  blake2b-simd = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "blake2b-simd";
    date = "2016-07-23";
    rev = "3f5f724cb5b182a5c278d6d3d55b40e7f8c2efb4";
    sha256 = "5ead55b23a24393a96cb6504b0a64c48812587c4af12527101c3a7c79c2d35e5";
  };

  bolt = buildFromGitHub {
    version = 1;
    rev = "v1.3.0";
    owner  = "boltdb";
    repo   = "bolt";
    sha256 = "1kjbih12cs9x380d5fb0qrx6n63pkfb2j9hnqrr95gz2215pqczp";
  };

  btcd = buildFromGitHub {
    version = 2;
    owner = "btcsuite";
    repo = "btcd";
    date = "2017-02-16";
    rev = "583684b21bfbde9b5fc4403916fd7c807feb0289";
    sha256 = "1mgqq61fr76p1jhs3bc1xqg7bginmhhdxix3mbvz5wcva3mjy3vz";
    subPackages = [
      "btcec"
    ];
  };

  btree = buildFromGitHub {
    version = 2;
    rev = "316fb6d3f031ae8f4d457c6c5186b9e3ded70435";
    owner  = "google";
    repo   = "btree";
    sha256 = "1wjicavprwxpa0rmvc8wz6k0gxl2q4rpsg7ci5hjvkb2j56r4rwk";
    date = "2016-12-17";
  };

  bufio_v1 = buildFromGitHub {
    version = 1;
    date = "2014-06-18";
    rev = "567b2bfa514e796916c4747494d6ff5132a1dfce";
    owner  = "go-bufio";
    repo   = "bufio";
    sha256 = "07dwsbh2c584wrm72hwnqsk22mr936hshsxma2jaxpgpkf6z1f3c";
    goPackagePath = "gopkg.in/bufio.v1";
  };

  bufs = buildFromGitHub {
    version = 1;
    date = "2014-08-18";
    rev = "3dcccbd7064a1689f9c093a988ea11ac00e21f51";
    owner  = "cznic";
    repo   = "bufs";
    sha256 = "0551h2slsb7lg3r6yif65xvf6k8f0izqwyiigpipm3jhlln37c6p";
  };

  cachecontrol = buildFromGitHub {
    version = 2;
    owner = "pquerna";
    repo = "cachecontrol";
    rev = "c97913dcbd76de40b051a9b4cd827f7eaeb7a868";
    date = "2016-04-21";
    sha256 = "0w55l15zswdq1l9ngrp8yw96cd9sml49xiprcc4yw3avjh0k7i83";
  };

  cascadia = buildFromGitHub {
    version = 2;
    date = "2016-12-24";
    rev = "349dd0209470eabd9514242c688c403c0926d266";
    owner  = "andybalholm";
    repo   = "cascadia";
    sha256 = "0xhdlrsvzsv3va4in3iw9v1nz2f6n8zca98mq4swl8zwfdly2jj8";
    propagatedBuildInputs = [
      net
    ];
  };

  cast = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "cast";
    rev = "v1.0.0";
    sha256 = "028msnqk26973ikn96nlq212b6vbgab1vpiny3h05qyi6670yi2v";
    buildInputs = [
      jwalterweatherman
    ];
  };

  cbauth = buildFromGitHub {
    version = 1;
    date = "2016-06-09";
    rev = "ae8f8315ad044b86ced2e0be9e3598e9dd94f38e";
    owner = "couchbase";
    repo = "cbauth";
    sha256 = "185c10ab80cn4jxdp915h428lm0r9zf1cqrfsjs71im3w3ankvsn";
  };

  certificate-transparency = buildFromGitHub {
    version = 2;
    owner = "google";
    repo = "certificate-transparency";
    rev = "173728300b695a5336f65f4dfb6645ad1b1665e2";
    date = "2017-02-24";
    sha256 = "73627100e0e5874e268903118a4a7852ece1bcb78a18cfc99136cacd850deaa5";
    propagatedBuildInputs = [
      go-sqlite3
      net
      ratelimit
    ];
  };

  chalk = buildFromGitHub {
    version = 2;
    rev = "22c06c80ed312dcb6e1cf394f9634aa2c4676e22";
    owner  = "ttacon";
    repo   = "chalk";
    sha256 = "0s5ffh4cilfg77bfxabr5b07sllic4xhbnz5ck68phys5jq9xhfs";
    date = "2016-06-26";
  };

  check = buildFromGitHub {
    version = 2;
    date = "2016-12-08";
    rev = "20d25e2804050c1cd24a7eea1e7a6447dd0e74ec";
    owner = "go-check";
    repo = "check";
    goPackagePath = "gopkg.in/check.v1";
    goPackageAliases = [
      "github.com/go-check/check"
    ];
    sha256 = "003qj5rpr27923bjvgd3mbgack3blw0m4izrq9plpxkha1glylz3";
  };

  circbuf = buildFromGitHub {
    version = 1;
    date = "2015-08-26";
    rev = "bbbad097214e2918d8543d5201d12bfd7bca254d";
    owner  = "armon";
    repo   = "circbuf";
    sha256 = "0wgpmzh0ga2kh51r214jjhaqhpqr9l2k6p0xhy5a006qypk5fh2m";
  };

  circonus-gometrics = buildFromGitHub {
    version = 2;
    date = "2017-03-02";
    rev = "e3b02ed3e42457aad17f03ccdc50b10f3451fd58";
    owner  = "circonus-labs";
    repo   = "circonus-gometrics";
    sha256 = "099zxk4b61i6xp40p0p7lyq41z7f475p8ad57af05d9n5ni4p2ny";
    propagatedBuildInputs = [
      circonusllhist
      go-retryablehttp
    ];
  };

  circonusllhist = buildFromGitHub {
    version = 2;
    date = "2016-11-21";
    rev = "7d649b46cdc2cd2ed102d350688a75a4fd7778c6";
    owner  = "circonus-labs";
    repo   = "circonusllhist";
    sha256 = "0hp4s4zvkwnd3q6s06mhwxi8hhdhcpsp2911qkrq4m8r670xhzc1";
  };

  cli_minio = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "cli";
    rev = "v1.3.0";
    sha256 = "08z1g5g3f07inpgyb93ip037f4y1cnhsm2wvg63qnnnry9chwy36";
    buildInputs = [
      elastic_v5
      toml
      urfave_cli
      yaml_v2
    ];
  };

  AudriusButkevicius_cli = buildFromGitHub {
    version = 2;
    rev = "7f561c78b5a4aad858d9fd550c92b5da6d55efbb";
    owner = "AudriusButkevicius";
    repo = "cli";
    sha256 = "0m9vi5cw611mddyxs7i7ss0j45xq2zmjdrf4mzi5d2khija7iirm";
    date = "2014-07-27";
  };

  mitchellh_cli = buildFromGitHub {
    version = 2;
    date = "2017-03-03";
    rev = "8d6d9ab3c912dcb005ece87c40a41b9e73e1999a";
    owner = "mitchellh";
    repo = "cli";
    sha256 = "0xznimqnfiqnlaq5c2mqz49xhvr5xy36ld3am7dn8w3ambbzxlld";
    propagatedBuildInputs = [
      crypto
      go-isatty
      go-radix
      speakeasy
    ];
  };

  urfave_cli = buildFromGitHub {
    version = 2;
    rev = "v1.19.1";
    owner = "urfave";
    repo = "cli";
    sha256 = "0083s7jjxcgkssh5kpr34f5razf1x04f6n1kk9mrdsk1s1xw6h1k";
    goPackagePath = "gopkg.in/urfave/cli.v1";
    goPackageAliases = [
      "github.com/codegangsta/cli"
      "github.com/urfave/cli"
    ];
    buildInputs = [
      toml
      yaml_v2
    ];
  };

  clock = buildFromGitHub {
    version = 2;
    owner = "jmhodges";
    repo = "clock";
    rev = "880ee4c335489bc78d01e4d0a254ae880734bc15";
    date = "2016-05-18";
    sha256 = "6290b02c154e2ac0a6360133cef7584a9fe2008086002dff94846bcbc167109b";
  };

  clockwork = buildFromGitHub {
    version = 2;
    rev = "v0.1.0";
    owner = "jonboulle";
    repo = "clockwork";
    sha256 = "1hwdrck8k4nxdc0zpbd4hbxsyh8xhip9k7d71cv4ziwlh71sci5g";
  };

  clog = buildFromGitHub {
    version = 1;
    date = "2016-06-09";
    rev = "ae8f8315ad044b86ced2e0be9e3598e9dd94f38e";
    owner = "couchbase";
    repo = "clog";
    sha256 = "185c10ab80cn4jxdp915h428lm0r9zf1cqrfsjs71im3w3ankvsn";
  };

  cmux = buildFromGitHub {
    version = 2;
    date = "2017-01-10";
    rev = "30d10be492927e2dcae0089c374c455d42414fcb";
    owner = "cockroachdb";
    repo = "cmux";
    sha256 = "07g8dff49mg9plpd3v23bgbfyaj3g1vj38yixay1sgl2k4p6ip98";
    propagatedBuildInputs = [
      net
    ];
  };

  cobra = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "cobra";
    rev = "7be4beda01ec05d0b93d80b3facd2b6f44080d94";
    date = "2017-03-14";
    sha256 = "1vl5bxvdgcva2lrkfwchf9y065gq64ihzxfx7iabphxc2n8mspyw";
    buildInputs = [
      pflag
      viper
    ];
    propagatedBuildInputs = [
      go-md2man
      yaml_v2
    ];
  };

  color = buildFromGitHub {
    version = 2;
    rev = "v1.4.1";
    owner  = "fatih";
    repo   = "color";
    sha256 = "1g3z1344vjkl1aqxbmvaz43lvfm6pzinaz15zbrq6h4ir72i9hdm";
    propagatedBuildInputs = [
      go-colorable
      go-isatty
    ];
  };

  colorstring = buildFromGitHub {
    version = 1;
    rev = "8631ce90f28644f54aeedcb3e389a85174e067d1";
    owner  = "mitchellh";
    repo   = "colorstring";
    sha256 = "14dgak39642j795miqg5x7sb4ncpjgikn7vvbymxc5azy7z764hx";
    date = "2015-09-17";
  };

  columnize = buildFromGitHub {
    version = 2;
    rev = "ddeb643de91b4ee0d9d87172c931a4ea3d81d49a";
    owner  = "ryanuber";
    repo   = "columnize";
    sha256 = "0r26l715451slfx62f7m92w7c5dqcxmz1adzx2p84w2y77bphy71";
    date = "2017-02-08";
  };

  com = buildFromGitHub {
    version = 2;
    rev = "0db4a625e949e956314d7d1adea9bf82384cc10c";
    owner  = "Unknwon";
    repo   = "com";
    sha256 = "0flgww88p314wh3nikmmqmrnx2p7nq523cx40dsj2rh3kyxchy6i";
    date = "2017-02-13";
  };

  compress = buildFromGitHub {
    version = 2;
    rev = "v1.2.1";
    owner  = "klauspost";
    repo   = "compress";
    sha256 = "0ycfchs0brgxlvz48km955pzw0b71a9ipx3r2dqdawbf6zds5ix4";
    propagatedBuildInputs = [
      cpuid
      crc32
    ];
  };

  configure = buildFromGitHub {
    version = 2;
    rev = "4e0f2df8846ee9557b5c88307a769ff2f85e89cd";
    owner = "gravitational";
    repo = "configure";
    sha256 = "04qdmaz5pyd6nn7r5mdc2chzsx1zr2q0wv245xzzahx5n9m2x34x";
    date = "2016-10-02";
    propagatedBuildInputs = [
      gojsonschema
      kingpin_v2
      trace
      yaml_v2
    ];
    excludedPackages = "test";
  };

  consul = buildFromGitHub rec {
    version = 2;
    rev = "v0.7.5";
    owner = "hashicorp";
    repo = "consul";
    sha256 = "1czz99gf1wgml9iiy8aw6z0glihwzvpq86fzdwn6awkchhw8rh5j";

    buildInputs = [
      datadog-go circbuf armon_go-metrics go-radix speakeasy bolt
      go-bindata-assetfs go-dockerclient errwrap go-checkpoint
      go-immutable-radix go-memdb ugorji_go go-multierror go-reap go-syslog
      golang-lru hcl logutils memberlist net-rpc-msgpackrpc raft_v2 raft-boltdb_v2
      scada-client yamux muxado dns mitchellh_cli mapstructure columnize
      copystructure hil hashicorp-go-uuid crypto sys aws-sdk-go go-sockaddr
      google-api-go-client oauth2 gopsutil
    ];

    propagatedBuildInputs = [
      go-cleanhttp
      serf
    ];

    postPatch = let
      v = stdenv.lib.substring 1 (stdenv.lib.stringLength rev - 1) rev;
    in ''
      sed \
        -e 's,\(Version[ \t]*= "\)unknown,\1${v},g' \
        -e 's,\(VersionPrerelease[ \t]*= "\)unknown,\1,g' \
        -i version/version.go
    '';

    # Keep consul.ui for backward compatability
    passthru.ui = pkgs.consul-ui;
  };

  consul_api = buildFromGitHub {
    inherit (consul) rev owner repo sha256 version;
    propagatedBuildInputs = [
      go-cleanhttp
      serf
    ];
    subPackages = [
      "api"
      "lib"
      "tlsutil"
    ];
  };

  consulfs = buildFromGitHub {
    version = 2;
    rev = "6e4498b7b673f45b190f2fef31d79935385e87e3";
    owner = "bwester";
    repo = "consulfs";
    sha256 = "16n8g6vgaxbykxnal7vrnmj77n984ip4p9kcxg1akqdxz77r92dd";
    date = "2017-01-20";
    buildInputs = [
      consul_api
      fuse
      logrus
      net
    ];
  };

  consul-template = buildFromGitHub {
    version = 2;
    rev = "v0.18.1";
    owner = "hashicorp";
    repo = "consul-template";
    sha256 = "146xckc1iyxf2yz61ranpyslv4wsv9r8019sbhzbfp65wb7vana6";

    propagatedBuildInputs = [
      consul_api
      errors
      go-cleanhttp
      go-homedir
      go-multierror
      go-reap
      go-shellwords
      go-syslog
      logutils
      mapstructure
      serf
      toml
      yaml_v2
      vault_api
    ];
  };

  consul-template_for_nomad = buildFromGitHub {
    version = 2;
    rev = "v0.18.1";
    owner = "hashicorp";
    repo = "consul-template";
    sha256 = "146xckc1iyxf2yz61ranpyslv4wsv9r8019sbhzbfp65wb7vana6";
    propagatedBuildInputs = [
      consul_api
      go-multierror
      go-rootcerts
      go-shellwords
      go-syslog
      hcl
      logutils
      mapstructure
      toml
      yaml_v2
      vault_api
    ];
    meta.autoUpdate = false;
  };

  context = buildFromGitHub {
    version = 1;
    rev = "v1.1";
    owner = "gorilla";
    repo = "context";
    sha256 = "0fsm31ayvgpcddx3bd8fwwz7npyd7z8d5ja0w38lv02yb634daj6";
  };

  copystructure = buildFromGitHub {
    version = 2;
    date = "2017-01-15";
    rev = "f81071c9d77b7931f78c90b416a074ecdc50e959";
    owner = "mitchellh";
    repo = "copystructure";
    sha256 = "0d4bjp8dhzxjgwsxrjcysyhjwjxifpbq1d5p6j6vq6kyjncslbli";
    propagatedBuildInputs = [ reflectwalk ];
  };

  core = buildFromGitHub {
    version = 2;
    rev = "7daacb215ed03af093a72e0af32a5fe79458613d";
    owner = "go-xorm";
    repo = "core";
    sha256 = "1aq1plrrizcjhxjz79757y6l0gbl7kpchj5c903x88fiy4gc3j7s";
    date = "2017-02-07";
  };

  cors = buildFromGitHub {
    version = 2;
    owner = "rs";
    repo = "cors";
    rev = "v1.0";
    sha256 = "018bf66d3425cffafa913e6ebf4d5ba26a5c22313e041140ed177921b53e4852";
    propagatedBuildInputs = [
      net
      xhandler
    ];
  };

  cpuid = buildFromGitHub {
    version = 1;
    rev = "v1.0";
    owner  = "klauspost";
    repo   = "cpuid";
    sha256 = "1bwp3mx8dik8ib8smf5pwbnp6h8p2ai4ihqijncd0f981r31c6ms";
    buildInputs = [
      net
    ];
  };

  crc32 = buildFromGitHub {
    version = 2;
    rev = "v1.1";
    owner  = "klauspost";
    repo   = "crc32";
    sha256 = "0kzb3yhk6s0919b5w0xy99fwv0xw02k79iw8issy07mx6an9dh31";
  };

  cronexpr = buildFromGitHub {
    version = 2;
    rev = "d520615e531a6bf3fb69406b9eba718261285ec8";
    owner  = "gorhill";
    repo   = "cronexpr";
    sha256 = "0cjnck67s18sdrlx8cv0yys5vaf1sknywbzd2dyq2l144cjrsj7h";
    date = "2016-12-05";
  };

  cuckoo = buildFromGitHub {
    version = 2;
    rev = "44c50ab64b38d3a9e59e352d1f316ba363d66d3b";
    owner  = "tildeleb";
    repo   = "cuckoo";
    sha256 = "12q72scaa5h3dnzf9qhj5a75nzg4dq6ahlfsfvwa6rra0x9ylap6";
    date = "2016-12-04";
    goPackagePath = "leb.io/cuckoo";
    goPackageAliases = [
      "github.com/tildeleb/cuckoo"
    ];
    excludedPackages = "\\(example\\|dstest\\|primes/primes\\)";
    propagatedBuildInputs = [
      aeshash
      binary
    ];
  };

  crypt = buildFromGitHub {
    version = 1;
    owner = "xordataexchange";
    repo = "crypt";
    rev = "749e360c8f236773f28fc6d3ddfce4a470795227";
    date = "2015-05-23";
    sha256 = "0zc00mpvqv7n1pz6fn6570wf9j8dc5d2m49yrqqygs52r2iarpx5";
    propagatedBuildInputs = [
      consul_api
      crypto
      go-etcd
    ];
    postPatch = ''
      sed -i backend/consul/consul.go \
        -e 's,"github.com/armon/consul-api",consulapi "github.com/hashicorp/consul/api",'
    '';
  };

  cssmin = buildFromGitHub {
    version = 1;
    owner = "dchest";
    repo = "cssmin";
    rev = "fb8d9b44afdc258bfff6052d3667521babcb2239";
    date = "2015-12-10";
    sha256 = "1m9zqdaw2qycvymknv6vx2i4jlpdj6lcjysxd18czbf5kp6pcri4";
  };

  datadog-go = buildFromGitHub {
    version = 1;
    rev = "1.0.0";
    owner = "DataDog";
    repo = "datadog-go";
    sha256 = "13kjgqx5bs187fapqiirsaig950n2is0a35y2b7ap07dazxxxh3m";
  };

  dbus = buildFromGitHub {
    version = 2;
    rev = "fe0e1d54eaeda11a9979659a8d32f459e88bee75";
    owner = "godbus";
    repo = "dbus";
    sha256 = "0q0ykd403k5j830xa7xl81hr1m5677lnvyzlhi9cjr17vnf47ms7";
    date = "2017-03-03";
  };

  decimal = buildFromGitHub {
    version = 2;
    rev = "3526cd0bdb7f64e1178943b7dee81a0cc3d86a69";
    owner  = "shopspring";
    repo   = "decimal";
    sha256 = "1804v4jabw93kbswybdl1kf5g0y9yvgbkdlh1jhl78mx7m6lsdzv";
    date = "2017-02-23";
  };

  distribution = buildFromGitHub {
    version = 2;
    rev = "08b06dc023674763e7b36d404cf0c7664cee1f5e";
    owner = "docker";
    repo = "distribution";
    sha256 = "107h0y0ym72dwvb4mzbqcp4nx2s8m49fhnvz5yjzgr97n461zq91";
    propagatedBuildInputs = [
      cobra
      gorelic
      logrus
      mux
      net
      pflag
      resumable
      swift
    ];
    meta.useUnstable = true;
    date = "2017-03-03";
  };

  distribution_for_engine-api = buildFromGitHub {
    inherit (distribution) date rev owner repo sha256 version meta;
    subPackages = [
      "digestset"
      "reference"
    ];
    propagatedBuildInputs = [
      go-digest
    ];
  };

  distribution_for_docker = buildFromGitHub {
    inherit (distribution) date rev owner repo sha256 version meta;
    subPackages = [
      "."
      "context"
      "digestset"
      "reference"
      "registry/api/v2"
      "registry/api/errcode"
      "registry/client"
      "registry/client/auth"
      "registry/client/auth/challenge"
      "registry/client/transport"
      "registry/storage/cache"
      "registry/storage/cache/memory"
      "uuid"
    ];
    propagatedBuildInputs = [
      go-digest
      logrus
      mux
      net
    ];
  };

  dns = buildFromGitHub {
    version = 2;
    rev = "c862b7e359850847d4945cce311db2ea90cab7c0";
    date = "2017-03-10";
    owner  = "miekg";
    repo   = "dns";
    sha256 = "1h7kxshcg1jhbx3bmd1wkjm88yz4kr9qlsf5xp0mrycjdpynq9qc";
  };

  weppos-dnsimple-go = buildFromGitHub {
    version = 1;
    rev = "65c1ca73cb19baf0f8b2b33219b7f57595a3ccb0";
    date = "2016-02-04";
    owner  = "weppos";
    repo   = "dnsimple-go";
    sha256 = "0v3vnp128ybzmh4fpdwhl6xmvd815f66dgdjzxarjjw8ywzdghk9";
  };

  dnspod-go = buildFromGitHub {
    version = 2;
    rev = "68650ee11e182e30773781d391c66a0c80ccf9f2";
    owner = "decker502";
    repo = "dnspod-go";
    sha256 = "0iinhizgg6882nrbbvwhyw10g8p50gc45z9ycj1dr09rhpiw2k30";
    date = "2017-01-26";
  };

  docker = buildFromGitHub {
    version = 2;
    rev = "595ea2f12096e668977808ccea72f74a9e7c2ab7";
    owner = "docker";
    repo = "docker";
    sha256 = "0089kviyd0hfm9zgn1lsmx5gs84jf4s776l8i5g1n110qvy79q2x";
    meta.useUnstable = true;
    date = "2017-03-15";
    propagatedBuildInputs = [
      distribution_for_docker
      errors
      gotty
      go-connections
      go-digest
      go-units
      libtrust
      net
      pflag
      logrus
    ];
  };

  docker_for_nomad = buildFromGitHub {
    inherit (docker) rev date owner repo sha256 version meta;
    subPackages = [
      "cli/config/configfile"
      "pkg/httputils"
      "pkg/random"
      "pkg/stringid"
      "pkg/tarsum"
      "reference"
      "registry"
    ];
    propagatedBuildInputs = [
      distribution_for_docker
      errors
      gotty
      go-connections
      go-digest
      go-units
      net
      pflag
      logrus
    ];
  };

  docker_for_runc = buildFromGitHub {
    inherit (docker) rev date owner repo sha256 version meta;
    subPackages = [
      "pkg/mount"
      "pkg/symlink"
      "pkg/system"
      "pkg/term"
    ];
    propagatedBuildInputs = [
      go-units
    ];
  };

  docker_for_go-dockerclient = buildFromGitHub {
    inherit (docker) rev date owner repo sha256 version meta;
    subPackages = [
      "api/types"
      "api/types/blkiodev"
      "api/types/container"
      "api/types/filters"
      "api/types/mount"
      "api/types/strslice"
      "api/types/swarm"
      "api/types/versions"
      "opts"
      "pkg/archive"
      "pkg/fileutils"
      "pkg/homedir"
      "pkg/idtools"
      "pkg/ioutils"
      "pkg/jsonlog"
      "pkg/jsonmessage"
      "pkg/pools"
      "pkg/promise"
      "pkg/stdcopy"
    ];
    propagatedBuildInputs = [
      check
      engine-api
      gotty
      go-units
      logrus
      net
      runc
    ];
  };

  docker_for_teleport = buildFromGitHub {
    inherit (docker) rev date owner repo sha256 version meta;
    subPackages = [
      "pkg/term"
    ];
  };

  docopt-go = buildFromGitHub {
    version = 1;
    rev = "0.6.2";
    owner  = "docopt";
    repo   = "docopt-go";
    sha256 = "11cxmpapg7l8f4ar233f3ybvsir3ivmmbg1d4dbnqsr1hzv48xrf";
  };

  du = buildFromGitHub {
    version = 1;
    rev = "v1.0.0";
    owner  = "calmh";
    repo   = "du";
    sha256 = "02gri7xy9wp8szxpabcnjr18qic6078k213dr5k5712s1pg87qmj";
  };

  duo_api_golang = buildFromGitHub {
    version = 2;
    date = "2016-06-27";
    rev = "2b2d787eb38e28ce4fd906321d717af19fad26a6";
    owner = "duosecurity";
    repo = "duo_api_golang";
    sha256 = "17vi9qg1dd02pmqjajqkspvdl676f0jhfzh4vzr4rxrcwgnqxdwx";
  };

  dropbox = buildFromGitHub {
    version = 2;
    owner = "stacktic";
    repo = "dropbox";
    rev = "58f839b21094d5e0af7caf613599830589233d20";
    date = "2016-04-24";
    sha256 = "4e9d14fa3be992f94b7672a21a90abfa746429d5ee260dcbfa11b391012595ad";
    propagatedBuildInputs = [
      net
      oauth2
    ];
  };

  dsync = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "dsync";
    date = "2017-02-09";
    rev = "b9f7da73b9147ab22ebd4630bed34f5a6f289123";
    sha256 = "0all2bpsapnczyl0aa37lc4kfxvdy4i4bba21b4n6hs3bb69hnks";
  };

  ed25519 = buildFromGitHub {
    version = 2;
    owner = "agl";
    repo = "ed25519";
    rev = "5312a61534124124185d41f09206b9fef1d88403";
    sha256 = "0kb8jidncc30cn3dwwczxl7wnzjl862vy6p3rcrcnbgpygz6jhjf";
    date = "2017-01-16";
  };

  egoscale = buildFromGitHub {
    version = 2;
    rev = "ab4b0d7ff424c462da486aef27f354cdeb29a319";
    date = "2017-01-11";
    owner  = "pyr";
    repo   = "egoscale";
    sha256 = "5af0d24c309225f7243d71665b7f5558ae4403179663f40c01b1ba62a405eae5";
    meta.autoUpdate = false;
    subPackages = [
      "src/egoscale"
    ];
  };

  elastic_v2 = buildFromGitHub {
    version = 2;
    owner = "olivere";
    repo = "elastic";
    rev = "v2.0.54";
    sha256 = "9360c71601d67abd5b611ff6221ad92d02985d555046c874af61ef1d9bdb7fb7";
    goPackagePath = "gopkg.in/olivere/elastic.v2";
  };

  elastic_v3 = buildFromGitHub {
    version = 2;
    owner = "olivere";
    repo = "elastic";
    rev = "v3.0.59";
    sha256 = "dc2549cfdb71d8cbd901d339f3bb8a8844eede858f96842661986e990735aade";
    goPackagePath = "gopkg.in/olivere/elastic.v3";
    propagatedBuildInputs = [
      net
    ];
    meta.autoUpdate = false;
  };

  elastic_v5 = buildFromGitHub {
    version = 2;
    owner = "olivere";
    repo = "elastic";
    rev = "v5.0.29";
    sha256 = "0ik5kgic3y6mp8srhwicyp8k8109gmmis3ic48nqkk3p986da50m";
    goPackagePath = "gopkg.in/olivere/elastic.v5";
    propagatedBuildInputs = [
      net
      sync
    ];
  };

  eme = buildFromGitHub {
    version = 2;
    owner = "rfjakob";
    repo = "eme";
    rev = "01668ae55fe0b79a483095689043cce3e80260db";
    date = "2017-03-05";
    sha256 = "1067hdmfwb74b93idlhr31nkj9qslr1569w9srgnbhq36l4r32in";
    meta.useUnstable = true;
  };

  emoji = buildFromGitHub {
    version = 2;
    owner = "kyokomi";
    repo = "emoji";
    rev = "v1.5";
    sha256 = "0m41n13m8r0i6b75zv297fg6bdd82vrz3klxlkc855is079i0v4f";
  };

  encoding = buildFromGitHub {
    version = 2;
    owner = "jwilder";
    repo = "encoding";
    date = "2017-02-09";
    rev = "27894731927e49b0a9023f00312be26733744815";
    sha256 = "0sha9ghh6i9ca8bkw7qcjhppkb2dyyzh8zm760y4yi9i660r95h4";
  };

  engine-api = buildFromGitHub {
    version = 1;
    rev = "v0.4.0";
    owner = "docker";
    repo = "engine-api";
    sha256 = "1cgqhlngxlvplp6p560jvh4p003nm93pl4wannnlhwhcjrd34vyy";
    propagatedBuildInputs = [
      distribution_for_engine-api
      go-connections
      go-digest
    ];
  };

  envpprof = buildFromGitHub {
    version = 1;
    rev = "0383bfe017e02efb418ffd595fc54777a35e48b0";
    owner = "anacrolix";
    repo = "envpprof";
    sha256 = "0i9d021hmcfkv9wv55r701p6j6r8mj55fpl1kmhdhvar8s92rjgl";
    date = "2016-05-28";
  };

  errors = buildFromGitHub {
    version = 2;
    owner = "pkg";
    repo = "errors";
    rev = "v0.8.0";
    sha256 = "00fi35kiry67anhr4lxryyw5l9c26xj2zc5wzspr4z39paxgb4km";
  };

  errwrap = buildFromGitHub {
    version = 1;
    date = "2014-10-27";
    rev = "7554cd9344cec97297fa6649b055a8c98c2a1e55";
    owner  = "hashicorp";
    repo   = "errwrap";
    sha256 = "02hsk2zbwg68w62i6shxc0lhjxz20p3svlmiyi5zjz988qm3s530";
  };

  escaper = buildFromGitHub {
    version = 2;
    owner = "lucasem";
    repo = "escaper";
    rev = "17fe61c658dcbdcbf246c783f4f7dc97efde3a8b";
    sha256 = "1k0cbipikxxqc4im8dhkiq30ziakbld6h88vzr099c4x00qvpanf";
    goPackageAliases = [
      "github.com/10gen/escaper"
    ];
    date = "2016-08-02";
  };

  etcd = buildFromGitHub {
    version = 2;
    owner = "coreos";
    repo = "etcd";
    rev = "5856c8bce9778a12d79038fdb1f3fba9416bd297";
    sha256 = "153yy7by4pca5ckqgj14fjszmhzwbrmzr1y4ym108j59xydcjgrn";
    buildInputs = [
      bolt
      btree
      urfave_cli
      clockwork
      cobra
      cmux
      go-grpc-prometheus
      go-humanize
      go-semver
      go-systemd
      gopcap
      groupcache
      grpc
      grpc-gateway
      loghisto
      net
      pb_v1
      pflag
      pkg
      probing
      procfs
      prometheus_client_golang
      pty
      gogo_protobuf
      speakeasy
      tablewriter
      time
      ugorji_go
      yaml

      pkgs.libpcap
    ];
    meta.useUnstable = true;
    date = "2017-03-15";
  };

  etcd_client = buildFromGitHub {
    inherit (etcd) rev owner repo sha256 version meta;
    subPackages = [
      "client"
      "pkg/fileutil"
      "pkg/pathutil"
      "pkg/tlsutil"
      "pkg/transport"
      "pkg/types"
      "version"
    ];
    buildInputs = [
      go-systemd
      net
    ];
    propagatedBuildInputs = [
      go-semver
      pkg
      ugorji_go
    ];
    date = "2017-03-15";
  };

  etcd_for_vault = buildFromGitHub {
    inherit (etcd) rev owner repo sha256 version meta;
    subPackages = [
      "auth/authpb"
      "etcdserver/api/v3rpc/rpctypes"
      "etcdserver/etcdserverpb"
      "mvcc/mvccpb"
    ];
    propagatedBuildInputs = [
      grpc
      grpc-gateway
      net
      protobuf
    ];
    date = "2017-03-15";
  };

  ewma = buildFromGitHub {
    version = 2;
    owner = "VividCortex";
    repo = "ewma";
    rev = "c595cd886c223c6c28fc9ae2727a61b5e4693d85";
    date = "2016-08-22";
    sha256 = "0367b039e90b5e08abd501874aeab77ba1c597f7395d5e3b2762642caf653ab9";
    meta.useUnstable = true;
  };

  exp = buildFromGitHub {
    version = 1;
    date = "2016-07-11";
    rev = "888ba4519f76bfc1e26a9b32e52c6775677b36fd";
    owner  = "cznic";
    repo   = "exp";
    sha256 = "1a32kv2wjzz1yfgivrm1bp4hzg878jwfmv9qy9hvdx0kccy7rvpw";
    propagatedBuildInputs = [ bufs fileutil mathutil sortutil zappy ];
  };

  fifo = buildFromGitHub {
    version = 2;
    owner = "tonistiigi";
    repo = "fifo";
    rev = "8cf41abe4d87641cd48738771bf25a20d06ca0b2";
    date = "2017-02-24";
    sha256 = "83ef31b8e00f05d73bc0a2070c4d9a84e65cb1bb1541d6b80ed01ccbaca397d3";
    propagatedBuildInputs = [
      errors
      net
    ];
  };

  fileutil = buildFromGitHub {
    version = 2;
    date = "2016-12-22";
    rev = "e618435e3202890725c12ccff676e9e3b2592c71";
    owner  = "cznic";
    repo   = "fileutil";
    sha256 = "1da5lhaq1fjd9rxhdr82namrpfmydj5sry5jm1r0v0ism68mbbj2";
    buildInputs = [
      mathutil
    ];
  };

  flagfile = buildFromGitHub {
    version = 2;
    date = "2017-02-23";
    rev = "3836a321743b3e6c4c4585da402fd2390b358c86";
    owner  = "spacemonkeygo";
    repo   = "flagfile";
    sha256 = "17sg1ydkr84j3sqkbd7ij06awdcmla5vj0br473mvichkck37i30";
  };

  fs = buildFromGitHub {
    version = 1;
    date = "2013-11-07";
    rev = "2788f0dbd16903de03cb8186e5c7d97b69ad387b";
    owner  = "kr";
    repo   = "fs";
    sha256 = "16ygj65wk30cspvmrd38s6m8qjmlsviiq8zsnnvkhfy5l0gk4c86";
  };

  fsnotify = buildFromGitHub {
    version = 2;
    owner = "fsnotify";
    repo = "fsnotify";
    rev = "v1.4.2";
    sha256 = "1kbs526vl358dd9rrcdnniwnzhcxkbswkmkl80dl2sgi9x0w45g6";
    propagatedBuildInputs = [
      sys
    ];
  };

  fsnotify_v1 = buildFromGitHub {
    version = 2;
    owner = "fsnotify";
    repo = "fsnotify";
    rev = "v1.4.2";
    sha256 = "1f3zshxdd3kj08b87106gxj68fjljfb7b3r9i8xjrj0i79wy6phn";
    goPackagePath = "gopkg.in/fsnotify.v1";
    propagatedBuildInputs = [
      sys
    ];
  };

  fsync = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "fsync";
    rev = "cb2da332d00cbc04e4f3f677520dc3e7cc11874b";
    date = "2016-11-29";
    sha256 = "06fbr2yjnzgqcbscg09csjvbk9zxszwvmmfib8k4vqwwvpj1iq58";
    buildInputs = [
      afero
    ];
  };

  fuse = buildFromGitHub {
    version = 2;
    owner = "bazil";
    repo = "fuse";
    rev = "371fbbdaa8987b715bdd21d6adc4c9b20155f748";
    date = "2016-08-11";
    sha256 = "1f3cb9274f037e14c2437126fa17d39e6284f40f0ddb93b2dbb59d5bab6b97d0";
    goPackagePath = "bazil.org/fuse";
    propagatedBuildInputs = [
      net
      sys
    ];
  };

  fwd = buildFromGitHub {
    version = 2;
    date = "2016-01-28";
    rev = "98c11a7a6ec829d672b03833c3d69a7fae1ca972";
    owner  = "philhofer";
    repo   = "fwd";
    sha256 = "15wamyn4xfxvdnf6d2figrl8my1lm00n49m6l3qxdxcdkfa69qnv";
  };

  gabs = buildFromGitHub {
    version = 2;
    owner = "Jeffail";
    repo = "gabs";
    rev = "1.0";
    sha256 = "1pbsgk0pmhzi8crds5ys8nsrxyra6q6w9rmv6i09zqyf7icn9wwa";
  };

  gateway = buildFromGitHub {
    version = 1;
    date = "2016-05-22";
    rev = "edad739645120eeb82866bc1901d3317b57909b1";
    owner  = "calmh";
    repo   = "gateway";
    sha256 = "0gzwns51jl2jm62ii99c7caa9p7x2c8p586q1cjz8bpv2mcd8njg";
    goPackageAliases = [
      "github.com/jackpal/gateway"
    ];
  };

  gax-go = buildFromGitHub {
    version = 2;
    date = "2017-03-05";
    rev = "8c5154c0fe5bf18cf649634d4c6df50897a32751";
    owner  = "googleapis";
    repo   = "gax-go";
    sha256 = "02w22y0caaa3yamf1jf44r3pks1bqz96zaaciz95pi02dv2n6qfn";
    propagatedBuildInputs = [
      grpc_for_gax-go
      net
    ];
  };

  genproto = buildFromGitHub {
    version = 2;
    date = "2017-03-03";
    rev = "1e95789587db7d93ebbaa5eb65da17d3dbf8ab64";
    owner  = "google";
    repo   = "go-genproto";
    goPackagePath = "google.golang.org/genproto";
    sha256 = "1359q9ip6kfwc25fj43xb6blidgv3p4c805ddkqf7kfqxkzdd2ya";
    propagatedBuildInputs = [
      grpc
      net
      protobuf
    ];
  };

  genproto_protobuf = buildFromGitHub {
    inherit (genproto) version date rev owner repo goPackagePath sha256;
    subPackages = [
      "protobuf"
    ];
    buildInputs = [
      protobuf_genproto
    ];
  };

  geoip2-golang = buildFromGitHub {
    version = 2;
    rev = "0fd242da7906550802871efe101abfdb1cc550a8";
    owner = "oschwald";
    repo = "geoip2-golang";
    sha256 = "0l4ck9z7cw9jwyg2qxbcvnavpmsjmhaqdmdjcasl06rlf56rhs7w";
    propagatedBuildInputs = [
      maxminddb-golang
    ];
    date = "2017-03-14";
  };

  gettext = buildFromGitHub {
    version = 2;
    rev = "v0.9";
    owner = "gosexy";
    repo = "gettext";
    sha256 = "1zrxfzwlv04gadxxyn8whmdin83ij735bbggxrnf3mcbxs8svs96";
    buildInputs = [
      go-flags
      go-runewidth
    ];
  };

  ginkgo = buildFromGitHub {
    version = 2;
    rev = "5ca121185e255e5041d7727d77992618545a93d2";
    owner = "onsi";
    repo = "ginkgo";
    sha256 = "0c7l4gfbd8020gj6ml8534svx6m51gnlz0jwnbmczyymbyjp9pik";
    date = "2017-03-15";
  };

  gjson = buildFromGitHub {
    version = 2;
    owner = "tidwall";
    repo = "gjson";
    date = "2017-02-05";
    rev = "09d1c5c5bc64e094394dfe2150220d906c55ac37";
    sha256 = "1x7bjwifjn46mk7294gc8nnp6b5l15jglpg6schbrakllmdinnch";
    propagatedBuildInputs = [
      match
    ];
  };

  glob = buildFromGitHub {
    version = 2;
    rev = "v0.2.2";
    owner = "gobwas";
    repo = "glob";
    sha256 = "1mzn45p24qn7qdagfb9mlj96jlmwk3kgk637kxnb4qaqnl8bkkh1";
  };

  siddontang_go = buildFromGitHub {
    version = 2;
    date = "2016-10-05";
    rev = "1e9ce2a5ac4092fdf61e293634e40bfb49595105";
    owner = "siddontang";
    repo = "go";
    sha256 = "0gvvbvpk9yn24lhg4fzncwrs32awmll8s27qvsz2an0lvscqbhcz";
  };

  ugorji_go = buildFromGitHub {
    version = 2;
    date = "2017-03-12";
    rev = "708a42d246822952f38190a8d8c4e6b16a0e600c";
    owner = "ugorji";
    repo = "go";
    sha256 = "0jx44bnpx3wy6ka3pidsfjp0n0ns1spcp7wy3ixvcfpixz3pfl46";
    goPackageAliases = [
      "github.com/hashicorp/go-msgpack"
    ];
  };

  go-acd = buildFromGitHub {
    version = 2;
    owner = "ncw";
    repo = "go-acd";
    rev = "96a49aad3fc3889629f2eceb004927386884bd92";
    date = "2017-03-06";
    sha256 = "0a737iq3chdsgl1wwmk5vjppkpb60qpj6pmma5k2hmbh9p2d51nz";
    propagatedBuildInputs = [
      go-querystring
    ];
  };

  go-httpclient = buildFromGitHub {
    version = 2;
    owner = "mreiferson";
    repo = "go-httpclient";
    rev = "31f0106b4474f14bc441575c19d3a5fa21aa1f6c";
    date = "2016-06-30";
    sha256 = "e9fb80be94f61a8df23ee201be2988688cceba4d1c7339b60b955a66daebd3e3";
  };

  go4 = buildFromGitHub {
    version = 2;
    date = "2017-03-14";
    rev = "169ea6cabe2a4888dba958edaecc9e9751adc711";
    owner = "camlistore";
    repo = "go4";
    sha256 = "0ymrf0vzgywxm49la0f4wj0r10z27wkp1inqgb2v5jkpc58xgyla";
    goPackagePath = "go4.org";
    goPackageAliases = [ "github.com/camlistore/go4" ];
    buildInputs = [
      google-cloud-go
      oauth2
      net
      sys
    ];
  };

  goamz = buildFromGitHub {
    version = 2;
    rev = "c35091c30f44b7f151ec9028b895465a191d1ea7";
    owner  = "goamz";
    repo   = "goamz";
    sha256 = "0xfv1q2a9vqwmq2qilq0gxi29pkn6j2kh4hlqk045zyfx4i7ac28";
    date = "2017-02-11";
    goPackageAliases = [
      "github.com/mitchellh/goamz"
    ];
    excludedPackages = "testutil";
    buildInputs = [
      go-ini
      go-simplejson
      sets
    ];
  };

  goautoneg = buildGoPackage rec {
    name = "goautoneg-2012-07-07";
    goPackagePath = "bitbucket.org/ww/goautoneg";
    rev = "75cd24fc2f2c2a2088577d12123ddee5f54e0675";

    src = fetchFromBitbucket {
      version = 1;
      inherit rev;
      owner  = "ww";
      repo   = "goautoneg";
      sha256 = "9acef1c250637060a0b0ac3db033c1f679b894ef82395c15f779ec751ec7700a";
    };

    meta.autoUpdate = false;
  };

  gocapability = buildFromGitHub {
    version = 2;
    rev = "e7cb7fa329f456b3855136a2642b197bad7366ba";
    owner = "syndtr";
    repo = "gocapability";
    sha256 = "0k8nbsg4h9b8srd2ykkilf73m19b8lm6ib2cx98n5s6m0af4m7y7";
    date = "2016-09-28";
  };

  gocql = buildFromGitHub {
    version = 2;
    rev = "ecc3fdbeba666ee3d083e6491309eca7f48c5382";
    owner  = "gocql";
    repo   = "gocql";
    sha256 = "1ys1kh1l4m8ml51yjvldy2187lfqralrx1wkv1hqqax6qxlas1by";
    propagatedBuildInputs = [
      inf_v0
      snappy
      hailocab_go-hostpool
      net
    ];
    date = "2017-03-14";
  };

  gojsonpointer = buildFromGitHub {
    version = 2;
    rev = "6fe8760cad3569743d51ddbb243b26f8456742dc";
    owner  = "xeipuuv";
    repo   = "gojsonpointer";
    sha256 = "0gfg90ibq0f6smmysj5svn1b04a39sc4w7xw38rgr4kyszhv4zj5";
    date = "2017-02-25";
  };

  gojsonreference = buildFromGitHub {
    version = 1;
    rev = "e02fc20de94c78484cd5ffb007f8af96be030a45";
    owner  = "xeipuuv";
    repo   = "gojsonreference";
    sha256 = "1c2yhjjxjvwcniqag9i5p159xsw4452vmnc2nqxnfsh1whd8wpi5";
    date = "2015-08-08";
    propagatedBuildInputs = [ gojsonpointer ];
  };

  gojsonschema = buildFromGitHub {
    version = 2;
    rev = "ff0417f4272e480246b4507459b3f6ae721a87ac";
    owner  = "xeipuuv";
    repo   = "gojsonschema";
    sha256 = "12za4xycq4hxvf7wxhmvp6rjn0irigby5yb9frip9z144x93hgvj";
    date = "2017-02-25";
    propagatedBuildInputs = [ gojsonreference ];
  };

  gollectd = buildFromGitHub {
    version = 2;
    owner = "kimor79";
    repo = "gollectd";
    rev = "v1.0.0";
    sha256 = "16ax20j3ji6zqxii16kinvgrxb0xjn9qhfhhiin7k40w0aas5dhi";
  };

  gomemcache = buildFromGitHub {
    version = 2;
    rev = "1952afaa557dc08e8e0d89eafab110fb501c1a2b";
    date = "2017-02-08";
    owner = "bradfitz";
    repo = "gomemcache";
    sha256 = "1h1sjgjv4ay6y26g25vg2q0iawmw8fnlam7r66qiq0hclzb72fcn";
  };

  gomemcached = buildFromGitHub {
    version = 2;
    rev = "c4dd8c29a4da4bae7744878b84f7adde80d252d4";
    date = "2017-03-07";
    owner = "couchbase";
    repo = "gomemcached";
    sha256 = "1hfsjlpxsjjyklccb623naxcz1mi29aks2qxnzyga5j335bqivar";
    propagatedBuildInputs = [
      goutils_logging
    ];
  };

  gopacket = buildFromGitHub {
    version = 2;
    rev = "v1.1.12";
    owner = "google";
    repo = "gopacket";
    sha256 = "0bgmj6njrqcb6rzcm915mgy0j9cf0r51ha0gnxvqvkak6fs2xa0m";
    buildInputs = [
      pkgs.libpcap
      pkgs.pf-ring
    ];
  };

  google-cloud-go = buildFromGitHub {
    version = 2;
    date = "2017-03-15";
    rev = "3f8a5072eb1701e5ede64adbe70a932b9851eb28";
    owner = "GoogleCloudPlatform";
    repo = "google-cloud-go";
    sha256 = "0bn44a6jrpx4w99z64xzcfwxi2jrwn3pavnab7r2ss0i5v8ikhhl";
    goPackagePath = "cloud.google.com/go";
    goPackageAliases = [
      "google.golang.org/cloud"
    ];
    propagatedBuildInputs = [
      debug
      gax-go
      genproto
      geo
      google-api-go-client
      grpc
      net
      oauth2
      protobuf
      time
    ];
    postPatch = ''
      sed -i 's,bundler.Close,bundler.Stop,g' logging/logging.go
    '';
    excludedPackages = "oauth2";
    meta.useUnstable = true;
  };

  google-cloud-go-compute-metadata = buildFromGitHub {
    inherit (google-cloud-go) rev date owner repo sha256 version goPackagePath goPackageAliases meta;
    subPackages = [
      "compute/metadata"
      "internal"
    ];
    propagatedBuildInputs = [
      gax-go
      net
    ];
  };

  gopcap = buildFromGitHub {
    version = 2;
    rev = "00e11033259acb75598ba416495bb708d864a010";
    date = "2015-07-28";
    owner = "akrennmair";
    repo = "gopcap";
    sha256 = "189skp51bd7aqpqs63z20xqm0pj5dra23g51m993rbq81zsvp0yq";
    buildInputs = [
      pkgs.libpcap
    ];
  };

  goprocess = buildFromGitHub {
    version = 2;
    rev = "b497e2f366b8624394fb2e89c10ab607bebdde0b";
    date = "2016-08-25";
    owner = "jbenet";
    repo = "goprocess";
    sha256 = "1i4spw84hlka1l8xxizpiqklsqyc3hxxjz3wbpn3i2ql68raylbx";
  };

  goredis = buildFromGitHub {
    version = 1;
    rev = "760763f78400635ed7b9b115511b8ed06035e908";
    date = "2015-03-24";
    owner = "siddontang";
    repo = "goredis";
    sha256 = "193n28jaj01q0k8lx2ijvgzmlh926jy6cg2ph3446k90pl5r118c";
  };

  gorelic = buildFromGitHub {
    version = 2;
    rev = "ae09aa139a2b7f638e2412baceaceebd41eff115";
    date = "2016-06-16";
    owner = "yvasiyarov";
    repo = "gorelic";
    sha256 = "1x9hd2hlq796lf87h1jipqrf7vj7c1qxmg49f3qk5s4cvs5gzb5m";
  };

  goreq = buildFromGitHub {
    version = 1;
    rev = "fc08df6ca2d4a0d1a5ae24739aa268863943e723";
    date = "2016-05-07";
    owner = "franela";
    repo = "goreq";
    sha256 = "152fmchwwwgyg16i79vl09cyid8ry3ddhj09nzx2xrfg5632sn7s";
  };

  goterm = buildFromGitHub {
    version = 2;
    rev = "cc3942e537b1ab00de92d348c40acbfa6565d20f";
    date = "2016-11-03";
    owner = "buger";
    repo = "goterm";
    sha256 = "0m7q1bccdjgijhrq056rs8brizrvsiyr8k0iphprs8wmlr0hz5vi";
  };

  gotty = buildFromGitHub {
    version = 2;
    rev = "cd527374f1e5bff4938207604a14f2e38a9cf512";
    date = "2012-06-04";
    owner = "Nvveen";
    repo = "Gotty";
    sha256 = "16slr2a0mzv2bi90s5pzmb6is6h2dagfr477y7g1s89ag1dcayp8";
  };

  goutils = buildFromGitHub {
    version = 1;
    rev = "5823a0cbaaa9008406021dc5daf80125ea30bba6";
    date = "2016-03-10";
    owner = "couchbase";
    repo = "goutils";
    sha256 = "0053nk5jhn3lcwb8sg2bv39gy841ldgcl3cnvwn5mmx3658il0kn";
    buildInputs = [
      cbauth
      go-couchbase
      gomemcached
    ];
  };

  goutils_logging = buildFromGitHub {
    inherit (goutils) rev date owner repo sha256 version;
    subPackages = [
      "logging"
    ];
  };

  golang-lru = buildFromGitHub {
    version = 1;
    date = "2016-08-13";
    rev = "0a025b7e63adc15a622f29b0b2c4c3848243bbf6";
    owner  = "hashicorp";
    repo   = "golang-lru";
    sha256 = "1nq6q2l5ml3dljxm0ks4zivcci1yg2f2lmam9kvykkwm03m85qy1";
  };

  golang-petname = buildFromGitHub {
    version = 2;
    rev = "242afa0b4f8af1fa581e7ea7f4b6d51735fa3fef";
    owner  = "dustinkirkland";
    repo   = "golang-petname";
    sha256 = "0n9l98bwv0gf8rvv3sclc63qr350m4kb0k7wczrvqrsz916p0vjh";
    date = "2017-01-05";
  };

  golang_protobuf_extensions = buildFromGitHub {
    version = 1;
    rev = "v1.0.0";
    owner  = "matttproud";
    repo   = "golang_protobuf_extensions";
    sha256 = "0r1sv4jw60rsxy5wlnr524daixzmj4n1m1nysv4vxmwiw9mbr6fm";
    buildInputs = [ protobuf ];
  };

  goleveldb = buildFromGitHub {
    version = 2;
    rev = "3c5717caf1475fd25964109a0fc640bd150fce43";
    date = "2017-03-02";
    owner = "syndtr";
    repo = "goleveldb";
    sha256 = "1dma2a24g4f7519ym70ws1ylzy5bhzf1hmvgz361xffiq95dw878";
    propagatedBuildInputs = [ ginkgo gomega snappy ];
  };

  gomega = buildFromGitHub {
    version = 2;
    rev = "1de7ab2df9105aa5c15c4d7e14a8a514e3cb8d4b";
    owner  = "onsi";
    repo   = "gomega";
    sha256 = "08v9pi2bdkkcdybjybgwk663yzq9fss47jjp8ynhmgy7l658h359";
    propagatedBuildInputs = [
      protobuf
      yaml_v2
    ];
    date = "2017-03-06";
  };

  google-api-go-client = buildFromGitHub {
    version = 2;
    rev = "1202890e803f07684581b575fda809bf335a533f";
    date = "2017-03-10";
    owner = "google";
    repo = "google-api-go-client";
    sha256 = "1wc7kddlqs894d75ir7ffpbnfjqy8ax0bkxbjr94bbrg2w66sjhi";
    goPackagePath = "google.golang.org/api";
    buildInputs = [
      genproto
      grpc
      net
      oauth2
    ];
  };

  gopass = buildFromGitHub {
    version = 2;
    date = "2017-01-09";
    rev = "bf9dde6d0d2c004a008c27aaee91170c786f6db8";
    owner = "howeyc";
    repo = "gopass";
    sha256 = "0chij9mja3pwgmyvjcbp86xh9h9v1ljgpvscph6jxa1k1pp9dfah";
    propagatedBuildInputs = [
      crypto
    ];
  };

  gopsutil = buildFromGitHub {
    version = 2;
    rev = "v2.17.02";
    owner  = "shirou";
    repo   = "gopsutil";
    sha256 = "14fj1894cdgd1jcyhfdyvnzi5y5ncl98yhg1aqhi30l9jfanr602";
  };

  goquery = buildFromGitHub {
    version = 2;
    rev = "v1.1.0";
    owner  = "PuerkitoBio";
    repo   = "goquery";
    sha256 = "1c8q4ijhdm7ly26cvhr61kqla9gqc49c9s4v906k0shnbf3ygmm5";
    propagatedBuildInputs = [
      cascadia
      net
    ];
  };

  goskiplist = buildFromGitHub {
    version = 1;
    rev = "2dfbae5fcf46374f166f8969cb07e167f1be6273";
    owner  = "ryszard";
    repo   = "goskiplist";
    sha256 = "1dr6n2w5ikdddq9c1fwqnc0m383p73h2hd04302cfgxqbnymabzq";
    date = "2015-03-12";
  };

  govalidator = buildFromGitHub {
    version = 2;
    rev = "fdf19785fd3558d619ef81212f5edf1d6c2a5911";
    owner = "asaskevich";
    repo = "govalidator";
    sha256 = "1zk6pzv5lb969qvh8kg4jzx25gp28c997lzbjsjrdma6gqsmmllj";
    date = "2017-01-05";
  };

  go-autorest = buildFromGitHub {
    version = 2;
    rev = "v7.3.0";
    owner  = "Azure";
    repo   = "go-autorest";
    sha256 = "0vl56rq0kzi6164kg92l5n3x71fgabg4yg741v2as1jjj0rmhm3s";
    propagatedBuildInputs = [
      crypto
      jwt-go
    ];
  };

  go-base58 = buildFromGitHub {
    version = 1;
    rev = "1.0.0";
    owner  = "jbenet";
    repo   = "go-base58";
    sha256 = "0sbss2611iri3mclcz3k9b7kw2sqgwswg4yxzs02vjk3673dcbh2";
  };

  go-bindata-assetfs = buildFromGitHub {
    version = 2;
    rev = "30f82fa23fd844bd5bb1e5f216db87fd77b5eb43";
    owner   = "elazarl";
    repo    = "go-bindata-assetfs";
    sha256 = "0pval4z7k1bbcdx1hqd4cw9x5l01pikkya0n61c4wrfi0ghx25ln";
    date = "2017-02-27";
  };

  go-bits = buildFromGitHub {
    version = 2;
    owner = "dgryski";
    repo = "go-bits";
    date = "2016-06-01";
    rev = "2ad8d707cc05b1815ce6ff2543bb5e8d8f9298ef";
    sha256 = "d77d906fb806bb9bd9af7f54f0c3277d6b86d84015e198cb367f1d7788c8b938";
  };

  go-bitstream = buildFromGitHub {
    version = 2;
    owner = "dgryski";
    repo = "go-bitstream";
    date = "2016-07-01";
    rev = "7d46cd22db7004f0cceb6f7975824b560cf0e486";
    sha256 = "32a82d1220c6d2ec05cf2d6150ed8f2a3ce6c544f626cc7574acaa57e31bbd9c";
  };

  go-buffruneio = buildFromGitHub {
    version = 2;
    owner = "pelletier";
    repo = "go-buffruneio";
    rev = "v0.2.0";
    sha256 = "080mjg20yp2h04pk5g2ls3jg7z2h80wjj0qv254k2hga63xkk3k6";
  };

  go-cache = buildFromGitHub {
    version = 2;
    rev = "e7a9def80f35fe1b170b7b8b68871d59dea117e1";
    owner = "patrickmn";
    repo = "go-cache";
    sha256 = "17zkd2lyjfp8rzn3z0d59rbjbkv5w5c7wsb7h33d81rrlj9af7ai";
    date = "2016-11-25";
  };
  go-checkpoint = buildFromGitHub {
    version = 1;
    date = "2016-08-16";
    rev = "f8cfd20c53506d1eb3a55c2c43b84d009fab39bd";
    owner  = "hashicorp";
    repo   = "go-checkpoint";
    sha256 = "066rs0gbflz5jbfpvklc3vg5zs7l1fdfjrfy21y4c4j5vkm49gz5";
    buildInputs = [ go-cleanhttp ];
  };

  go-cleanhttp = buildFromGitHub {
    version = 2;
    date = "2017-02-10";
    rev = "3573b8b52aa7b37b9358d966a898feb387f62437";
    owner = "hashicorp";
    repo = "go-cleanhttp";
    sha256 = "1q6fzddda47f0n2n04iz7lpz77j1lfs14477qd6ajjj6q0a6sii4";
  };

  go-collectd = buildFromGitHub {
    version = 2;
    owner = "collectd";
    repo = "go-collectd";
    rev = "v0.3.0";
    sha256 = "0dzs6ia5y3dc6vcdqv7llgxj381jdpl17kbjgn0ncggshxly4zhf";
    goPackagePath = "collectd.org";
    buildInputs = [
      grpc
      net
      pkgs.collectd
      protobuf
    ];
    preBuild = ''
      # Regerate protos
      srcDir="$(pwd)"/go/src
      pushd go/src/$goPackagePath >/dev/null
      find . -name \*pb.go -delete
      for file in $(find . -name \*.proto | sort | uniq); do
        pushd "$(dirname "$file")" > /dev/null
        echo "Regenerating protobuf: $file" >&2
        protoc -I "$srcDir" -I "$srcDir/$goPackagePath" -I . --go_out=plugins=grpc:. "$(basename "$file")"
        popd >/dev/null
      done
      popd >/dev/null

      # Create a config.h and proper headers
      export COLLECTD_SRC="$(pwd)/collectd-src"
      mkdir -pv "$COLLECTD_SRC"
      pushd "$COLLECTD_SRC" >/dev/null
        unpackFile "${pkgs.collectd.src}"
      popd >/dev/null
      srcdir="$(echo "$COLLECTD_SRC"/collectd-*)"
      # Run configure to generate config.h
      pushd "$srcdir" >/dev/null
        ./configure
      popd >/dev/null
      export CGO_CPPFLAGS="-I$srcdir/src/daemon -I$srcdir/src"
    '';
  };

  go-colorable = buildFromGitHub {
    version = 2;
    rev = "v0.0.7";
    owner  = "mattn";
    repo   = "go-colorable";
    sha256 = "0r7qqrdpy19whvkifcpc6w53am83rq05vmax1ajaw2ywl0gwvvlq";
  };

  go-connections = buildFromGitHub {
    version = 2;
    rev = "a2afab9802043837035592f1c24827fb70766de9";
    owner  = "docker";
    repo   = "go-connections";
    sha256 = "0yzfn0kg041qms5qq4j0dim3943ibfp6w1y3ah4chg46vvib48m4";
    propagatedBuildInputs = [
      logrus
      net
      runc
    ];
    date = "2017-03-01";
  };

  go-couchbase = buildFromGitHub {
    version = 2;
    rev = "252aecae9cc013d7d65a127fe7590d13a9e30935";
    owner  = "couchbase";
    repo   = "go-couchbase";
    sha256 = "119x6y3v1bsfrpshz5pf2ap5r8710gcv1z1r961q8xf6sv38jp6v";
    date = "2017-03-14";
    goPackageAliases = [
      "github.com/couchbaselabs/go-couchbase"
    ];
    propagatedBuildInputs = [
      gomemcached
      goutils_logging
    ];
    excludedPackages = "\\(perf\\|example\\)";
  };

  go-crypto = buildFromGitHub {
    version = 2;
    rev = "469591c50f62b1aa0aa6e23971e24602a6c65b95";
    owner  = "keybase";
    repo   = "go-crypto";
    sha256 = "0c42qpf6nihfdmb6hbphkm3fqigi0bnk051y3rl65ay3ip61m367";
    date = "2017-03-15";
    propagatedBuildInputs = [
      ed25519
    ];
  };

  go-deadlock = buildFromGitHub {
    version = 2;
    rev = "v0.1.0";
    owner  = "sasha-s";
    repo   = "go-deadlock";
    sha256 = "0d7kl9fw4d5mpn1ivd2hicnxp3fxp8yhmd287nz39appgl0gwkf8";
  };

  go-difflib = buildFromGitHub {
    version = 1;
    rev = "v1.0.0";
    owner  = "pmezard";
    repo   = "go-difflib";
    sha256 = "0zb1bmnd9kn0qbyn2b62r9apbkpj3752isgbpia9i3n9ix451cdb";
  };

  go-digest = buildFromGitHub {
    version = 2;
    rev = "aa2ec055abd10d26d539eb630a92241b781ce4bc";
    owner  = "opencontainers";
    repo   = "go-digest";
    sha256 = "11zwn00kdhzpmms1585iczj4mqqjlvmxnm332bawmldk1w7qllin";
    date = "2017-01-30";
    goPackageAliases = [
      "github.com/docker/distribution/digest"
    ];
  };

  go-dockerclient = buildFromGitHub {
    version = 2;
    date = "2017-03-07";
    rev = "318513eb1ab27495afbc67f671ba1080513d8aa0";
    owner = "fsouza";
    repo = "go-dockerclient";
    sha256 = "0a5r16pl03zzlrc8v90hykfvv48pxvvrq3pk8y3sq3dakvzdykin";
    propagatedBuildInputs = [
      docker_for_go-dockerclient
      go-cleanhttp
      mux
    ];
  };

  go-etcd = buildFromGitHub {
    version = 2;
    date = "2015-10-26";
    rev = "003851be7bb0694fe3cc457a49529a19388ee7cf";
    owner  = "coreos";
    repo   = "go-etcd";
    sha256 = "1cijiw77cy4z6p4zhagm0q7ydyn8kk24v1611arx6wmvzgi7lyc3";
    propagatedBuildInputs = [
      ugorji_go
    ];
  };

  go-ethereum = buildFromGitHub {
    version = 2;
    date = "2017-03-14";
    rev = "dc4c59d42b793414833c10b91c2902e971de8477";
    owner  = "ethereum";
    repo   = "go-ethereum";
    sha256 = "09hlg6x7wd7jy6yq1h3694hj8yggslskj4vr53ck7ac8yc7kvbq7";
    subPackages = [
      "crypto/sha3"
    ];
  };

  go-events = buildFromGitHub {
    version = 2;
    owner = "docker";
    repo = "go-events";
    rev = "aa2e3b613fbbfdddbe055a7b9e3ce271cfd83eca";
    date = "2016-09-06";
    sha256 = "9a343e28d608971d2baec59bc62637a697f1b45c44e61b782b81c212b5ef507b";
    propagatedBuildInputs = [
      logrus
    ];
  };

  go-farm = buildFromGitHub {
    version = 2;
    rev = "83948bc0eb076b6b72c28abe5282fa8cf5240db6";
    owner  = "dgryski";
    repo   = "go-farm";
    sha256 = "1pmai6x37k7qfggzzg12qhm0qg974rbkw43vv1pcqmw8fcljqg00";
    date = "2016-12-02";
  };

  go-flags = buildFromGitHub {
    version = 2;
    rev = "v1.2.0";
    owner  = "jessevdk";
    repo   = "go-flags";
    sha256 = "0cv6vf1vwysblni8lzy0lmyi7fkgqh8jsz4rwn6rvds9n1481nf5";
  };

  go-floodsub = buildFromGitHub {
    version = 2;
    rev = "28e8562c4df36ca9e5140d0c469981ea6ddfefa0";
    owner  = "libp2p";
    repo   = "go-floodsub";
    sha256 = "0dqspyjbipk8k12xzx2sxq7hs6xp2pci0dc0zwdii4ny3km57psq";
    date = "2017-03-09";
    propagatedBuildInputs = [
      gogo_protobuf
      go-libp2p-host
      go-libp2p-net
      go-libp2p-peer
      go-log
      timecache
    ];
  };

  go-getter = buildFromGitHub {
    version = 2;
    rev = "c3d66e76678dce180a7b452653472f949aedfbcd";
    date = "2017-02-07";
    owner = "hashicorp";
    repo = "go-getter";
    sha256 = "1sxpn5adi9zvw394pk89a6rsyn9jjj23psggvfzjiwzk24b6p7r6";
    propagatedBuildInputs = [
      aws-sdk-go
      go-homedir
      go-netrc
      go-version
    ];
  };

  go-git-ignore = buildFromGitHub {
    version = 2;
    rev = "87c28ffedb6cb7ff29ae89e0440e9ddee0d95a9e";
    date = "2016-12-22";
    owner = "sabhiram";
    repo = "go-git-ignore";
    sha256 = "1c8nsr9c2lnfc7d57wdmszkmk29jd3f82mnc1334dnlz5qls8rbc";
  };

  go-github = buildFromGitHub {
    version = 2;
    date = "2017-02-17";
    rev = "82629e04595093a1cebd5e2aa8096ad87a3a81d1";
    owner = "google";
    repo = "go-github";
    sha256 = "cec1f08c3ee954eb9ba406bf38d1e2da4ad37134b0520e49197438f77587e633";
    buildInputs = [ oauth2 ];
    propagatedBuildInputs = [ go-querystring ];
    meta.autoUpdate = false;
  };

  go-grpc-prometheus = buildFromGitHub {
    version = 2;
    rev = "v1.1";
    owner = "grpc-ecosystem";
    repo = "go-grpc-prometheus";
    sha256 = "01swr5sdsjyjsllr3b0ngr5x3d6hnwnyp21jzwrvnxrksvhd40jz";
    propagatedBuildInputs = [
      grpc
      net
      prometheus_client_golang
    ];
  };

  go-homedir = buildFromGitHub {
    version = 2;
    date = "2016-12-03";
    rev = "b8bc1bf767474819792c23f32d8286a45736f1c6";
    owner  = "mitchellh";
    repo   = "go-homedir";
    sha256 = "18j4j5zpxlpqqbdcl7d7cl69gcj747wq3z2m58lb99376w4a5xm6";
  };

  go-homedir_minio = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "go-homedir";
    date = "2016-02-15";
    rev = "0b1069c753c94b3633cc06a1995252dbcc27c7a6";
    sha256 = "0e595179466b94fcf18515a1791319cbfdd60b3e12b06dfc2cc7778a79a201c7";
  };

  hailocab_go-hostpool = buildFromGitHub {
    version = 1;
    rev = "e80d13ce29ede4452c43dea11e79b9bc8a15b478";
    date = "2016-01-25";
    owner  = "hailocab";
    repo   = "go-hostpool";
    sha256 = "06ic8irabl0iwhmkyqq4wzq1d4pgp9vk1kmflgv1wd5d9q8qmkgf";
  };

  gohtml = buildFromGitHub {
    version = 2;
    owner = "yosssi";
    repo = "gohtml";
    rev = "1d8dc9c914ff4253a3af95c1891d809210245e69";
    date = "2017-02-06";
    sha256 = "12rnpnl6df52ahzcl8xfx5akhahnzj9y16zkgfipiasw8w248pl0";
    propagatedBuildInputs = [
      net
    ];
  };

  go-humanize = buildFromGitHub {
    version = 2;
    rev = "259d2a102b871d17f30e3cd9881a642961a1e486";
    owner = "dustin";
    repo = "go-humanize";
    sha256 = "17mic4dp33ki0hv7snj5y6q96lh357gswzikbj1pqnkgia0hxbqf";
    date = "2017-02-28";
  };

  go-i18n = buildFromGitHub {
    version = 2;
    rev = "v1.7.0";
    owner  = "nicksnyder";
    repo   = "go-i18n";
    sha256 = "1pgmg111sqjhih87jpqmks7pf99byi1r40q5rzpwqwvsww428gh6";
    buildInputs = [
      yaml_v2
    ];
  };

  go-immutable-radix = buildFromGitHub {
    version = 2;
    date = "2017-02-13";
    rev = "30664b879c9a771d8d50b137ab80ee0748cb2fcc";
    owner = "hashicorp";
    repo = "go-immutable-radix";
    sha256 = "1akj47vd7p8ysa4apiqhp7s110ms40y10sg0k84yy3n323yyx4mj";
    propagatedBuildInputs = [ golang-lru ];
  };

  go-ini = buildFromGitHub {
    version = 1;
    rev = "a98ad7ee00ec53921f08832bc06ecf7fd600e6a1";
    owner = "vaughan0";
    repo = "go-ini";
    sha256 = "07i40hj47z5m6wa5bzy7sc2na3hbwh84ridl40yfybgdlyrzdkf4";
    date = "2013-09-23";
  };

  go-ipfs-api = buildFromGitHub {
    version = 2;
    rev = "458b0e60a89e4fc666b9ea085bfa9d023afed15f";
    owner  = "ipfs";
    repo   = "go-ipfs-api";
    sha256 = "02bl3iz9akkkqwpa7hg0wr2scf8gln8z2wa7kryavzjl0qcyvi8n";
    excludedPackages = "tests";
    propagatedBuildInputs = [
      go-floodsub
      go-multiaddr
      go-multiaddr-net
      go-multipart-files
      tar-utils
    ];
    meta.useUnstable = true;
    date = "2017-03-06";
  };

  go-ipfs-util = buildFromGitHub {
    version = 2;
    rev = "78188a11e9b4e58e58d37b124fd43afcbef90ec8";
    owner  = "ipfs";
    repo   = "go-ipfs-util";
    sha256 = "02mnb52rs4y2wyas6yifnl76pgwvadfqfdkijz263f4g1lxl4qp9";
    date = "2017-02-01";
    buildInputs = [
      go-base58
      go-multihash
    ];
  };

  go-isatty = buildFromGitHub {
    version = 2;
    rev = "57fdcb988a5c543893cc61bce354a6e24ab70022";
    owner  = "mattn";
    repo   = "go-isatty";
    sha256 = "1ln0mmdibh3y129ar75x6q54wjp84b6qf4463dr3hlqwrilmkdpp";
    date = "2017-03-07";
  };

  go-jmespath = buildFromGitHub {
    version = 1;
    rev = "bd40a432e4c76585ef6b72d3fd96fb9b6dc7b68d";
    owner = "jmespath";
    repo = "go-jmespath";
    sha256 = "1jiz511xlndrai7xkpvr045x7fsda030240gcwjc4yg4y36ck8cg";
    date = "2016-08-03";
  };

  go-jose_v1 = buildFromGitHub {
    version = 2;
    rev = "v1.1.0";
    owner = "square";
    repo = "go-jose";
    sha256 = "b2dac3e4693bbf2ef11c8afd6aec838479acb789c1d156084776e68488bbd64e";
    goPackagePath = "gopkg.in/square/go-jose.v1";
    buildInputs = [
      urfave_cli
      kingpin_v2
    ];
    meta.autoUpdate = false;
  };

  go-jose_v2 = buildFromGitHub {
    version = 2;
    rev = "v2.1.0";
    owner = "square";
    repo = "go-jose";
    sha256 = "0pwclkx1297d9mv835pk82sgsr1a3xjxi1flx9m28kl50rambcwm";
    goPackagePath = "gopkg.in/square/go-jose.v2";
    buildInputs = [
      urfave_cli
      kingpin_v2
    ];
  };

  go-keyspace = buildFromGitHub {
    version = 2;
    rev = "5b898ac5add1da7178a4a98e69cb7b9205c085ee";
    owner = "whyrusleeping";
    repo = "go-keyspace";
    sha256 = "1kf9gyrhfjhqckziaag8qg5kyyy2zmkfz33wmf9c6p6xqypg0bx7";
    date = "2016-03-22";
  };

  go-libp2p-crypto = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-crypto";
    date = "2017-03-05";
    rev = "533994cfd21c22949b853c2d31670734040fa958";
    sha256 = "1w69d3684qf0jgasiirdykaziyb0xrx9z90314ap8bj67vi89scg";
    propagatedBuildInputs = [
      btcd
      ed25519
      go-base58
      go-ipfs-util
      go-multihash
      gogo_protobuf
    ];
  };

  go-libp2p-host = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-host";
    date = "2017-03-06";
    rev = "eabec5bfa955d03e5c5f767dadbc43e462cd7ef6";
    sha256 = "1jk1iasaykd1av579a5f9zxdpqdff3p58rydjc12yxrpcwyzyinm";
    propagatedBuildInputs = [
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-protocol
      go-multiaddr
      go-multistream
      go-semver
    ];
  };

  go-libp2p-interface-conn = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-interface-conn";
    date = "2017-03-06";
    rev = "d7e2536ffb5fd823fb3d40ec5cb90ae2e34f8d12";
    sha256 = "1ylz9iz3kr27i7a7wp80j0d77s7xwvvgk7rhv890nr95hzklzi2m";
    propagatedBuildInputs = [
      go-ipfs-util
      go-libp2p-crypto
      go-libp2p-peer
      go-libp2p-transport
      go-maddr-filter
      go-multiaddr
    ];
  };

  go-libp2p-net = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-net";
    date = "2017-03-06";
    rev = "a2453194e3899f56cdc35908292540955f7cd43a";
    sha256 = "0rj7hnpj2h05ryxaaq4m61n9xl0xkx28y80s8jzgs3hv58akr100";
    propagatedBuildInputs = [
      goprocess
      go-libp2p-interface-conn
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-protocol
      go-multiaddr
    ];
  };

  go-libp2p-peer = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-peer";
    date = "2017-03-06";
    rev = "66d82b1dd12cc3e9b0013c6ba8ff5630ac24d2b8";
    sha256 = "1ir2a5wzwsv09lpnh4x5b5aq0qvyz2mnnx5als78gxhpigx1hf6b";
    propagatedBuildInputs = [
      go-base58
      go-ipfs-util
      go-libp2p-crypto
      go-log
      go-multihash
    ];
  };

  go-libp2p-peerstore = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-peerstore";
    date = "2017-03-06";
    rev = "1ee2d0de819a12d2a5ac75f562406680ded933db";
    sha256 = "1kp5p312sfy3kw8cs52bb3d6a87621fwqhbwcb4xc9fcpqibsq57";
    propagatedBuildInputs = [
      go-libp2p-crypto
      go-libp2p-peer
      go-log
      go-keyspace
      go-multiaddr
      go-multiaddr-net
      mafmt
    ];
  };

  go-libp2p-protocol = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-protocol";
    date = "2016-10-11";
    rev = "40488c03777c16bfcd65da2f675b192863cbc2dc";
    sha256 = "0mxs1x3cs0srrb2cvqbd2h0361gjhzz9xb7n6pjq013vnq6dyf03";
  };

  go-libp2p-transport = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-libp2p-transport";
    date = "2017-02-03";
    rev = "63cfec9f189253ed1f1e624e11df5367909bdd4a";
    sha256 = "05x01pcdijr0fn1qailrvh3fa2z2ja86bic2irs4p9lvdjqffxc5";
    propagatedBuildInputs = [
      go-log
      go-multiaddr
      go-multiaddr-net
      mafmt
    ];
  };

  go-log = buildFromGitHub {
    version = 2;
    owner = "ipfs";
    repo = "go-log";
    date = "2016-09-03";
    rev = "7c24d3c8b0889a7091d7f3618b9ad32b575db2c6";
    sha256 = "0xvgrj61mi3g1i4kp10836wmvg1k8rgngh7c82w266x7lyg7w00s";
    propagatedBuildInputs = [
      whyrusleeping_go-logging
    ];
  };

  whyrusleeping_go-logging = buildFromGitHub {
    version = 2;
    owner = "whyrusleeping";
    repo = "go-logging";
    date = "2016-12-07";
    rev = "0a5b4a6decf577ce8293eca85ec733d7ab92d742";
    sha256 = "057iwrmlhjnr4w9f9nhndicldv8h4007rxblr7l16rpkbski00wb";
  };

  go-logging = buildFromGitHub {
    version = 2;
    owner = "op";
    repo = "go-logging";
    date = "2016-03-15";
    rev = "970db520ece77730c7e4724c61121037378659d9";
    sha256 = "8087016a076abb7ab630f22c6e2b0ae8ce310350aad9792123c7842b299f87a7";
  };

  go-lxc_v2 = buildFromGitHub {
    version = 2;
    rev = "8304875cc3423823032ec93556beee076c6ba687";
    owner  = "lxc";
    repo   = "go-lxc";
    sha256 = "12qh3qsaxfidmh0yjhqwq4rjagr6nlqi3m4cgilwhndglqy969sn";
    goPackagePath = "gopkg.in/lxc/go-lxc.v2";
    buildInputs = [
      pkgs.lxc
    ];
    date = "2017-03-11";
  };

  go-lz4 = buildFromGitHub {
    version = 2;
    rev = "7224d8d8f27ef618c0a95f1ae69dbb0488abc33a";
    owner  = "bkaradzic";
    repo   = "go-lz4";
    sha256 = "1hbbagvmq7kxrlwqkn0i4mz66i3n37ch7y6bm9yncnjgd97kldms";
    date = "2016-09-24";
  };

  go-maddr-filter = buildFromGitHub {
    version = 2;
    owner = "libp2p";
    repo = "go-maddr-filter";
    date = "2017-02-02";
    rev = "d5b83eac5f7d67a79bbe653443e07784f7cb6952";
    sha256 = "09nk4l40qlmd6swhcnm0rb081768y65cczvlm1f24wgnhm0sgyy6";
    propagatedBuildInputs = [
      go-multiaddr
      go-multiaddr-net
    ];
  };

  go-md2man = buildFromGitHub {
    version = 2;
    owner = "cpuguy83";
    repo = "go-md2man";
    rev = "v1.0.6";
    sha256 = "1i67z76plrd7ygk66691bgarcx5kfkf1ryvcwdaa099hbliwbai8";
    propagatedBuildInputs = [
      blackfriday
    ];
  };

  go-memdb = buildFromGitHub {
    version = 2;
    date = "2017-02-10";
    rev = "6b158e314030abfb0dbbbc24d0ac71b132259ebf";
    owner = "hashicorp";
    repo = "go-memdb";
    sha256 = "087a6a73x69pvy6bk9krw3v8a67xyg8brvz8jvsvj1g247xnqk4d";
    propagatedBuildInputs = [
      go-immutable-radix
    ];
  };

  rcrowley_go-metrics = buildFromGitHub {
    version = 2;
    rev = "1f30fe9094a513ce4c700b9a54458bbb0c96996c";
    date = "2016-11-28";
    owner = "rcrowley";
    repo = "go-metrics";
    sha256 = "1bz5x3i4xr1nnlknliqy5v2544qmr2jw7qb9ssdr9w68l330fpaa";
    propagatedBuildInputs = [ stathat ];
  };

  armon_go-metrics = buildFromGitHub {
    version = 2;
    date = "2017-01-14";
    rev = "93f237eba9b0602f3e73710416558854a81d9337";
    owner = "armon";
    repo = "go-metrics";
    sha256 = "0f1c24krssll6k90ldf3hzf362r05km8j88riqj5lp6m4yxc4dka";
    propagatedBuildInputs = [
      circonus-gometrics
      datadog-go
      prometheus_client_golang
    ];
  };

  go-metro = buildFromGitHub {
    version = 2;
    date = "2015-06-07";
    rev = "d5cb643948fbb1a699e6da1426f0dba75fe3bb8e";
    owner = "dgryski";
    repo = "go-metro";
    sha256 = "5d271cba19ad6aa9b0aaca7e7de6d5473eb4a9e4b682bbb1b7a4b37cca9bb706";
    meta.autoUpdate = false;
  };

  go-mssqldb = buildFromGitHub {
    version = 2;
    rev = "efb3002072bc69d12d92dfc70290ccfdaa5403cf";
    owner = "denisenkom";
    repo = "go-mssqldb";
    sha256 = "1n4wmwfzd54bfvb14wzkg5n8a05ivkgjjxg1a2inmzklbi5yi5mg";
    date = "2017-03-08";
    buildInputs = [
      crypto
      net
    ];
  };

  go-multiaddr = buildFromGitHub {
    version = 2;
    rev = "5ea81f9b8a5b2d6b68af026b5899bd06cd5e0396";
    date = "2017-02-01";
    owner  = "multiformats";
    repo   = "go-multiaddr";
    sha256 = "0pmr18kfw5wd4wi9ql5iiy0wixhqk1j3rkfakrbcj83g1jnhdh5h";
    goPackageAliases = [ "github.com/jbenet/go-multiaddr" ];
    propagatedBuildInputs = [
      go-multihash
    ];
  };

  go-multiaddr-net = buildFromGitHub {
    version = 2;
    rev = "1854460b3710255985878ebf409f4002df88bb0b";
    owner  = "multiformats";
    repo   = "go-multiaddr-net";
    sha256 = "0hmaw47546fp4x9h1x9970l7c287gn1czqsqn8vfwk94fvh0rjxh";
    date = "2017-02-01";
    goPackageAliases = [ "github.com/jbenet/go-multiaddr-net" ];
    propagatedBuildInputs = [
      go-multiaddr
      utp
    ];
  };

  go-multierror = buildFromGitHub {
    version = 2;
    date = "2016-12-16";
    rev = "ed905158d87462226a13fe39ddf685ea65f1c11f";
    owner  = "hashicorp";
    repo   = "go-multierror";
    sha256 = "1lvmjf3mb1qx295djzddzj8w1j86c0cklkg19kfmzr5cbk257rzc";
    propagatedBuildInputs = [ errwrap ];
  };

  go-multihash = buildFromGitHub {
    version = 2;
    rev = "8e611f2d03612360724bbd0a792a29d1e40022ca";
    owner  = "multiformats";
    repo   = "go-multihash";
    sha256 = "1zqmw2v4rbljyjaxpnmiwlhskmsbyzv3p7x7n2f617xfzjsqvhb9";
    goPackageAliases = [ "github.com/jbenet/go-multihash" ];
    propagatedBuildInputs = [
      crypto
      go-base58
      go-ethereum
      hashland
      murmur3
    ];
    date = "2017-03-09";
  };

  go-multipart-files = buildFromGitHub {
    version = 1;
    rev = "3be93d9f6b618f2b8564bfb1d22f1e744eabbae2";
    owner  = "whyrusleeping";
    repo   = "go-multipart-files";
    sha256 = "0fdzi6v6rshh172hzxf8v9qq3d36nw3gc7g7d79wj88pinnqf5by";
    date = "2015-09-03";
  };

  go-multistream = buildFromGitHub {
    version = 2;
    rev = "661a0b9a0e6d9e99e4552c431b0eb82f58fde5b3";
    date = "2017-01-10";
    owner  = "multiformats";
    repo   = "go-multistream";
    sha256 = "0yxhxllw4swpzdn0jrlgm9379q8vk6h11zc772cx4va0kimlpksj";
  };

  go-nat-pmp = buildFromGitHub {
    version = 1;
    rev = "452c97607362b2ab5a7839b8d1704f0396b640ca";
    owner  = "AudriusButkevicius";
    repo   = "go-nat-pmp";
    sha256 = "0jjwqvanxxs15nhnkdx0mybxnyqm37bbg6yy0jr80czv623rp2bk";
    date = "2016-05-22";
    buildInputs = [
      gateway
    ];
  };

  go-netrc = buildFromGitHub {
    version = 2;
    owner = "bgentry";
    repo = "go-netrc";
    date = "2014-05-22";
    rev = "9fd32a8b3d3d3f9d43c341bfe098430e07609480";
    sha256 = "68984543a73f4d7ad4b58708207a483bd74fc9388ac582eac532434b11361a9e";
  };

  go-oidc = buildFromGitHub {
    version = 2;
    date = "2017-03-07";
    rev = "be73733bb8cc830d0205609b95d125215f8e9c70";
    owner  = "coreos";
    repo   = "go-oidc";
    sha256 = "04650px6ljjikkaws5zsmvxwrdzxfb3bdivk9pja4sq0j23c45zw";
    propagatedBuildInputs = [
      cachecontrol
      clockwork
      go-jose_v2
      net
      oauth2
      pkg
    ];
  };

  go-okta = buildFromGitHub {
    version = 2;
    rev = "388b6aef4eed400621bd3e3a98d831ef1368582d";
    owner = "sstarcher";
    repo = "go-okta";
    sha256 = "0pqabxarh1hm4r2bwmhp8zlp6k7rf4dypp82pia97nspnisr94dc";
    date = "2016-10-03";
  };

  go-os-rename = buildFromGitHub {
    version = 1;
    rev = "3ac97f61ef67a6b87b95c1282f6c317ed0e693c2";
    owner  = "jbenet";
    repo   = "go-os-rename";
    sha256 = "0y8rq0y654lcyl7ysijni75j8fpq4hhqnh9qiy2z4hvmnzvb85id";
    date = "2015-04-28";
  };

  go-ovh = buildFromGitHub {
    version = 2;
    rev = "d2207178e10e4527e8f222fd8707982df8c3af17";
    owner = "ovh";
    repo = "go-ovh";
    sha256 = "1kx6n608vwr7njbc59wgbpvwflq1haw7vp6qaa2ymbvjkn1b9ypv";
    date = "2017-01-02";
    propagatedBuildInputs = [
      ini_v1
    ];
  };

  go-plugin = buildFromGitHub {
    version = 2;
    rev = "f72692aebca2008343a9deb06ddb4b17f7051c15";
    date = "2017-02-17";
    owner  = "hashicorp";
    repo   = "go-plugin";
    sha256 = "14xp3x6vhqqm4qvjfnszdd4vbw6b4q3kryjxpgzl3qqmb4rcxlpk";
    buildInputs = [ yamux ];
  };

  go-ps = buildFromGitHub {
    version = 2;
    rev = "4fdf99ab29366514c69ccccddab5dc58b8d84062";
    date = "2017-03-09";
    owner  = "mitchellh";
    repo   = "go-ps";
    sha256 = "1x70gc6y9licdi6qww1lkwx1wkwwkqylzhkfl0wpnizl8m7vpdmp";
  };

  go-python = buildFromGitHub {
    version = 2;
    owner = "sbinet";
    repo = "go-python";
    date = "2017-03-14";
    rev = "ba7e58341058bdefb92b359870caf2dc0a05cfcf";
    sha256 = "1jkkkg5nrdqz6iv6bzlbxg7gycmq4bjc5mrpw3r3lvzqn73sdga7";
    nativeBuildInputs = [
      pkgs.pkgconfig
    ];
    buildInputs = [
      pkgs.python2Packages.python
    ];
  };

  go-querystring = buildFromGitHub {
    version = 2;
    date = "2017-01-11";
    rev = "53e6ce116135b80d037921a7fdd5138cf32d7a8a";
    owner  = "google";
    repo   = "go-querystring";
    sha256 = "1ibpx1hpqjkvcmn4gsz54k9p62sl1iac2kgb97spcl630nn4p0yj";
  };

  go-radix = buildFromGitHub {
    version = 1;
    rev = "4239b77079c7b5d1243b7b4736304ce8ddb6f0f2";
    owner  = "armon";
    repo   = "go-radix";
    sha256 = "0b5vksrw462w1j5ipsw7fmswhpnwsnaqgp6klw714dc6ppz57aqv";
    date = "2016-01-15";
  };

  go-reap = buildFromGitHub {
    version = 2;
    rev = "04ce4d0638f3b39b8a8030e2a22c4c90771fa5d6";
    owner  = "hashicorp";
    repo   = "go-reap";
    sha256 = "023ca78dmnwzd0g0yvrbznznmdjix36cang5wp7x054ihws8igd6";
    date = "2016-09-01";
    propagatedBuildInputs = [ sys ];
  };

  go-retryablehttp = buildFromGitHub {
    version = 2;
    rev = "6e85be8fee1dcaa02c0eaaac2df5a8fbecf94145";
    owner = "hashicorp";
    repo = "go-retryablehttp";
    sha256 = "1fssinl8qxdmg3b6wvbyd44p473fbkb03wi792bhqaq15jmysqqy";
    date = "2016-09-29";
    propagatedBuildInputs = [
      go-cleanhttp
    ];
  };

  go-rootcerts = buildFromGitHub {
    version = 1;
    rev = "6bb64b370b90e7ef1fa532be9e591a81c3493e00";
    owner = "hashicorp";
    repo = "go-rootcerts";
    sha256 = "0wi9ar5av0s4a2xarxh360kml3nkicrcdzzmhq1d406p10c3qjp2";
    date = "2016-05-03";
  };

  go-runewidth = buildFromGitHub {
    version = 2;
    rev = "v0.0.2";
    owner = "mattn";
    repo = "go-runewidth";
    sha256 = "1j99da81h9s528g3lmhgy1pvmzhhcxl8g3p9dzg8byxdsvjadxia";
  };

  go-semver = buildFromGitHub {
    version = 2;
    rev = "5e3acbb5668c4c3deb4842615c4098eb61fb6b1e";
    owner  = "coreos";
    repo   = "go-semver";
    sha256 = "1msmlbkv0mp25p0x74d1k8l1zrkz1prs9mcxhck77inzckq4fg81";
    date = "2017-02-09";
  };

  go-shellwords = buildFromGitHub {
    version = 2;
    rev = "v1.0.2";
    owner  = "mattn";
    repo   = "go-shellwords";
    sha256 = "1ya97s8yxw9959kp18w7741q9kdzslqrpr7cbn32r3sjdwdwdnk1";
  };

  go-simplejson = buildFromGitHub {
    version = 2;
    rev = "da1a8928f709389522c8023062a3739f3b4af419";
    owner  = "bitly";
    repo   = "go-simplejson";
    sha256 = "0qrqmhi7wng3nb42ch4pp7xly2yia8grg3mkifqnra5d9pr7q91j";
    date = "2017-02-06";
  };

  go-snappy = buildFromGitHub {
    version = 1;
    rev = "d8f7bb82a96d89c1254e5a6c967134e1433c9ee2";
    owner  = "siddontang";
    repo   = "go-snappy";
    sha256 = "18ikmwl43nqdphvni8z15jzhvqksqfbk8rspwd11zy24lmklci7b";
    date = "2014-07-04";
  };

  go-sockaddr = buildFromGitHub {
    version = 2;
    rev = "f910dd83c2052566cad78352c33af714358d1372";
    owner  = "hashicorp";
    repo   = "go-sockaddr";
    sha256 = "1wiiy21kf078ny68pddypvmlbhn04kdqrw6w9r3pxm5c53f69y5b";
    date = "2017-02-07";
    propagatedBuildInputs = [
      mitchellh_cli
      columnize
      errwrap
      go-wordwrap
    ];
  };

  go-spew = buildFromGitHub {
    version = 2;
    rev = "v1.1.0";
    owner  = "davecgh";
    repo   = "go-spew";
    sha256 = "1a3hlwra1nbd6pl37dqj82i2q6vy36fdab31z4nj59gpgji35zy3";
  };

  go-sqlite3 = buildFromGitHub {
    version = 2;
    rev = "v1.2.0";
    owner  = "mattn";
    repo   = "go-sqlite3";
    sha256 = "0s6s46achp1dczxcp9fw3n71wkhw8y5x5kd8izyllygrbs56h28c";
    excludedPackages = "test";
    buildInputs = [
      goquery
    ];
    propagatedBuildInputs = [
      net
    ];
  };

  go-syslog = buildFromGitHub {
    version = 2;
    date = "2016-12-13";
    rev = "b609c7d9de4658cded34a7336b90886c56f9dbdb";
    owner  = "hashicorp";
    repo   = "go-syslog";
    sha256 = "0py0lgqxcwyjhjl68bi6psrgs0vqhd38nd06jihk235wdxq6149a";
  };

  go-systemd = buildFromGitHub {
    version = 2;
    rev = "abf023b1f0f04b4cd92e02b21c5406ab18a85f08";
    owner = "coreos";
    repo = "go-systemd";
    sha256 = "1vqvrdrm516kyhbg1cgj8f2a567gkzf1ljlvcsb2m5m070alb8h7";
    propagatedBuildInputs = [
      dbus
      pkg
      pkgs.systemd_lib
    ];
    date = "2017-03-14";
  };

  go-systemd_journal = buildFromGitHub {
    inherit (go-systemd) rev owner repo sha256 version date;
    subPackages = [
      "journal"
    ];
  };

  go-toml = buildFromGitHub {
    version = 2;
    owner = "pelletier";
    repo = "go-toml";
    rev = "fee7787d3f811af92276f5ff10107092e95b7a1d";
    sha256 = "1zahmnln75zxy6vgh39y0cyw8kakxn36bvpdjlwwnj4mn8il7974";
    propagatedBuildInputs = [
      go-buffruneio
    ];
    meta.useUnstable = true;
    date = "2017-03-14";
  };

  go-units = buildFromGitHub {
    version = 2;
    rev = "0dadbb0345b35ec7ef35e228dabb8de89a65bf52";
    owner = "docker";
    repo = "go-units";
    sha256 = "19xnz75m0qmydh2pgcgb6im6hmp4606jwagfxf892rs446vn2wqi";
    date = "2017-01-27";
  };

  go-unsnap-stream = buildFromGitHub {
    version = 2;
    rev = "87275cecd8e984c5875577d22da7ce8945df780e";
    owner = "glycerine";
    repo = "go-unsnap-stream";
    sha256 = "1bgwgfg34s3zb39g2ifp5sj65gibvsj9b82dy05vk6wv9zxqh5n2";
    date = "2016-12-13";
    propagatedBuildInputs = [
      snappy
    ];
  };

  hashicorp-go-uuid = buildFromGitHub {
    version = 1;
    rev = "64130c7a86d732268a38cb04cfbaf0cc987fda98";
    date = "2016-07-16";
    owner  = "hashicorp";
    repo   = "go-uuid";
    sha256 = "072c84wn90di09qxrg0ml8vjfb5k10zk2n4k0rgxk1n45wyghkjx";
  };

  go-version = buildFromGitHub {
    version = 2;
    rev = "03c5bf6be031b6dd45afec16b1cf94fc8938bc77";
    owner  = "hashicorp";
    repo   = "go-version";
    sha256 = "0py0cmlj4c1zfxnszr0jqgvqgrpa1iwk8r0iai5p0vvzf4zafbkj";
    date = "2017-02-02";
  };

  go-wordwrap = buildFromGitHub {
    version = 2;
    rev = "ad45545899c7b13c020ea92b2072220eefad42b8";
    owner  = "mitchellh";
    repo   = "go-wordwrap";
    sha256 = "0yj17x3c1mr9l3q4dwvy8y2xgndn833rbzsjf10y48yvr12zqjd0";
    date = "2015-03-14";
  };

  go-zookeeper = buildFromGitHub {
    version = 2;
    rev = "1d7be4effb13d2d908342d349d71a284a7542693";
    date = "2016-10-28";
    owner  = "samuel";
    repo   = "go-zookeeper";
    sha256 = "15jwlcscvqpj6yfsjmi7735q45zn5pv1h0by3dzggfry6y0h44fs";
  };

  goconfig = buildFromGitHub {
    version = 2;
    owner = "Unknwon";
    repo = "goconfig";
    rev = "87a46d97951ee1ea20ed3b24c25646a79e87ba5d";
    date = "2016-11-21";
    sha256 = "4b1e8153d3bcaa0e5f929b1cd09e4fb780a4753d4aaf8df12b4915c6a65eb70a";
  };

  gorequest = buildFromGitHub {
    version = 2;
    owner = "parnurzeal";
    repo = "gorequest";
    rev = "v0.2.15";
    sha256 = "0r3jidgjrnh43slhxhggwy11ka90gd05blsh102x48di7pxz3kn8";
    propagatedBuildInputs = [
      http2curl
      net
    ];
  };

  grafana = buildFromGitHub {
    version = 2;
    owner = "grafana";
    repo = "grafana";
    rev = "v4.1.2";
    sha256 = "1w6466w2xkh7yi8v1pshajkakj195ryfzpnh4988gg6vpcqcrz51";
    buildInputs = [
      amqp
      aws-sdk-go
      binding
      urfave_cli
      color
      goreq
      go-spew
      go-sqlite3
      go-version
      gzip
      inject
      ini_v1
      ldap
      log15
      macaron_v1
      net
      oauth2
      session
      slug
      toml
      websocket
      xorm
    ];
  };

  graphite-golang = buildFromGitHub {
    version = 2;
    owner = "marpaia";
    repo = "graphite-golang";
    date = "2016-11-29";
    rev = "c474c9b821b4d0a4574edc6412b0003fbce233c4";
    sha256 = "0gvm8x29y4y2cv358hr1cs6sr8p6snbcmnmag6pa0a2sjwahj7i0";
  };

  groupcache = buildFromGitHub {
    version = 2;
    date = "2017-01-09";
    rev = "72d04f9fcdec7d3821820cc4a6f150eae553639a";
    owner  = "golang";
    repo   = "groupcache";
    sha256 = "1f80bp3yimv6v688c0lq4wkyry36y5z170cbi2wp91gqvnskvah2";
    buildInputs = [ protobuf ];
  };

  grpc = buildFromGitHub {
    version = 2;
    date = "2017-03-14";
    rev = "cdee119ee21e61eef7093a41ba148fa83585e143";
    owner = "grpc";
    repo = "grpc-go";
    sha256 = "02ic2v1z6gsblcj68bany90pm0vwky065j2vr03h3raxwh8zhnq6";
    goPackagePath = "google.golang.org/grpc";
    goPackageAliases = [
      "github.com/grpc/grpc-go"
    ];
    excludedPackages = "\\(test\\|benchmark\\)";
    propagatedBuildInputs = [
      glog
      net
      oauth2
      protobuf
    ];
    meta.useUnstable = true;
  };

  grpc_for_gax-go = buildFromGitHub {
    inherit (grpc) version date rev owner repo sha256 goPackagePath goPackageAliases meta;
    propagatedBuildInputs = [
      net
      protobuf
    ];
    subPackages = [
      "."
      "codes"
    ];
  };

  grpc-gateway = buildFromGitHub {
    version = 2;
    rev = "0c0b378a74040eeb5ef415c5289258a193be0e94";
    owner = "grpc-ecosystem";
    repo = "grpc-gateway";
    sha256 = "1pm8wy77qd2lfff0c947xrz6k81sy1l84kikrah1n4l2sqggr3sl";
    propagatedBuildInputs = [
      glog
      grpc
      net
      protobuf
    ];
    date = "2017-03-14";
  };


  gucumber = buildFromGitHub {
    version = 1;
    date = "2016-07-14";
    rev = "71608e2f6e76fd4da5b09a376aeec7a5c0b5edbc";
    owner = "gucumber";
    repo = "gucumber";
    sha256 = "0ghz0x1zdm1ypp9ycw871r2rcklik84z7pqgs2i88sk2s4m4igar";
    buildInputs = [ testify ];
    propagatedBuildInputs = [ ansicolor ];
  };

  gx = buildFromGitHub {
    version = 2;
    rev = "v0.11.0";
    owner = "whyrusleeping";
    repo = "gx";
    sha256 = "0pmwyscmbbqxdkpzncffn70d01vb7gb0ikg1gnhzkd8nwbx2kqzz";
    propagatedBuildInputs = [
      go-git-ignore
      go-homedir
      go-multiaddr
      go-multihash
      go-multiaddr-net
      go-os-rename
      json-filter
      semver
      stump
      urfave_cli
      go-ipfs-api
    ];
    excludedPackages = [
      "tests"
    ];
  };

  gx-go = buildFromGitHub {
    version = 2;
    rev = "v1.4.0";
    owner = "whyrusleeping";
    repo = "gx-go";
    sha256 = "08yl5kvmxb2q21sxlnd8qn79bv3dp1v5jfpli7n32wqahix3rnzi";
    buildInputs = [
      urfave_cli
      fs
      gx
      stump
    ];
  };

  gzip = buildFromGitHub {
    version = 1;
    date = "2016-02-21";
    rev = "cad1c6580a07c56f5f6bc52d66002a05985c5854";
    owner = "go-macaron";
    repo = "gzip";
    sha256 = "1myrzvymwxxck5xw9jbm1fp9aazhvqdp2sc2snymvnnlxwc8f0an";
    propagatedBuildInputs = [
      compress
      macaron_v1
    ];
  };

  gziphandler = buildFromGitHub {
    version = 2;
    date = "2017-03-14";
    rev = "3b0c4852c5b9710340f1ed7b1a529c46a3bc0fc1";
    owner = "NYTimes";
    repo = "gziphandler";
    sha256 = "05hjhsq324vjyzkkin0pgbg0kjaif2w7qp9d89cm9mm7vdjlq2kj";
  };

  hashland = buildFromGitHub {
    version = 2;
    rev = "e13accbe55f7fa03c73c74ace4cca4c425e47260";
    owner  = "tildeleb";
    repo   = "hashland";
    sha256 = "0gws01aq8fy53kljpngs4y5l02aqjm5jd6pa3l7j1h56pk2n2zs8";
    goPackagePath = "leb.io/hashland";
    date = "2016-11-30";
    excludedPackages = "example";
    propagatedBuildInputs = [
      aeshash
      cuckoo
      go-farm
      go-metro
      hrff
    ];
  };

  hashland_for_aeshash = buildFromGitHub {
    version = 2;
    rev = "e13accbe55f7fa03c73c74ace4cca4c425e47260";
    owner  = "tildeleb";
    repo   = "hashland";
    sha256 = "0gws01aq8fy53kljpngs4y5l02aqjm5jd6pa3l7j1h56pk2n2zs8";
    goPackagePath = "leb.io/hashland";
    date = "2016-11-30";
    subPackages = [
      "nhash"
    ];
  };

  handlers = buildFromGitHub {
    version = 2;
    owner = "gorilla";
    repo = "handlers";
    rev = "v1.2";
    sha256 = "12n6brnjmzlrvki6c8cz12vfaqamdk6487viy6swpnaqr9iicf2c";
  };

  hashstructure = buildFromGitHub {
    version = 2;
    date = "2017-01-15";
    rev = "ab25296c0f51f1022f01cd99dfb45f1775de8799";
    owner  = "mitchellh";
    repo   = "hashstructure";
    sha256 = "1w7r9c5sj7g68y0j3v6kkdmh9qmci50bwxn2qk6bnnh1dln4acbr";
  };

  hcl = buildFromGitHub {
    version = 2;
    date = "2017-02-17";
    rev = "630949a3c5fa3c613328e1b8256052cbc2327c9b";
    owner  = "hashicorp";
    repo   = "hcl";
    sha256 = "0bzz8air9w3vjwxllkqszir3fx83w0lll2f2ybybg25p3nlr0kjc";
  };

  hdrhistogram = buildFromGitHub {
    version = 2;
    date = "2016-10-09";
    rev = "3a0bb77429bd3a61596f5e8a3172445844342120";
    owner  = "codahale";
    repo   = "hdrhistogram";
    sha256 = "0xnsf0yzh4z1iyl0vcbj97cyl19zq37hvjfz533zq91xglgpghmc";
    propagatedBuildInputs = [
      mgo_v2
    ];
  };

  hil = buildFromGitHub {
    version = 2;
    date = "2016-12-21";
    rev = "5b8d13c8c5c2753e109fab25392a1dbfa2db93d2";
    owner  = "hashicorp";
    repo   = "hil";
    sha256 = "1gc7kw6bp3kaixqbaiga92ywhqs1mrdablp9297kgvbgnhdz44gn";
    propagatedBuildInputs = [
      mapstructure
      reflectwalk
    ];
    meta.useUnstable = true;
  };

  hllpp = buildFromGitHub {
    version = 2;
    owner = "retailnext";
    repo = "hllpp";
    date = "2015-03-19";
    rev = "38a7bb71b483e855d35010808143beaf05b67f9d";
    sha256 = "3a98569b08ed14b834fb91c7da0827c74ddec9d1c057356c9d9999440bd45157";
  };

  hotp = buildFromGitHub {
    version = 2;
    rev = "c180d57d286b385101c999a60087a40d7f48fc77";
    owner  = "gokyle";
    repo   = "hotp";
    sha256 = "1sv6fq7nw7crnqn7ycg3f5j3x4g0rahxynjprwh8md3cfj1161xr";
    date = "2016-02-17";
    propagatedBuildInputs = [
      rsc
    ];
  };

  hrff = buildFromGitHub {
    version = 2;
    rev = "0b0f30b52b94f5ed2e21ffd14f537f1094ba8ec6";
    owner  = "tildeleb";
    repo   = "hrff";
    sha256 = "009zlvj9qaxxz1zprhgn5w80qyc5mqr2rifm2q6q6a2j3cvm3ccg";
    goPackagePath = "leb.io/hrff";
    date = "2015-09-06";
  };

  http2curl = buildFromGitHub {
    version = 2;
    owner = "moul";
    repo = "http2curl";
    date = "2016-10-31";
    rev = "4e24498b31dba4683efb9d35c1c8a91e2eda28c8";
    sha256 = "1zzdplidhh77s20l6c51fqvrzppmkf830j7mxdv9lf7z5ry169sp";
  };

  httprouter = buildFromGitHub {
    version = 2;
    rev = "8a45e95fc75cb77048068a62daed98cc22fdac7c";
    owner  = "julienschmidt";
    repo   = "httprouter";
    sha256 = "1gbzzzlrqafvxv6wglam518825blwywh071p98m91wnyx36b0k7a";
    date = "2017-01-05";
  };

  hugo = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "hugo";
    rev = "v0.19";
    sha256 = "1wnysdixh2va86wkf97wkzz647v3pi352dzffzwxjfgwybq0dfdh";
    buildInputs = [
      ace
      afero
      amber
      blackfriday
      cast
      cobra
      cssmin
      emoji
      go-i18n
      fsnotify
      fsync
      inflect
      jwalterweatherman
      mapstructure
      mmark
      nitro
      osext
      pflag
      purell
      text
      toml
      viper
      websocket
      yaml_v2
    ];
  };

  inf_v0 = buildFromGitHub {
    version = 1;
    rev = "v0.9.0";
    owner  = "go-inf";
    repo   = "inf";
    sha256 = "0wqf867vifpfa81a1vhazjgfjjhiykqpnkblaxxj6ppyxlzrs3cp";
    goPackagePath = "gopkg.in/inf.v0";
  };

  inflect = buildFromGitHub {
    version = 1;
    owner = "bep";
    repo = "inflect";
    rev = "b896c45f5af983b1f416bdf3bb89c4f1f0926f69";
    date = "2016-04-08";
    sha256 = "13mjcnh6g7ml0gw24rbkfdjmkznjk4hcwfbxcbj5ydyfl0acq8wn";
  };

  influxdb = buildFromGitHub {
    version = 2;
    owner = "influxdata";
    repo = "influxdb";
    rev = "v1.2.2";
    sha256 = "1kkx2in8vi95cs5jwrjpdi3fhvk2kh1kwmh27ra3mqgydlvysv5p";
    propagatedBuildInputs = [
      bolt
      gollectd
      crypto
      encoding
      go-bits
      go-bitstream
      go-collectd
      hllpp
      jwt-go
      liner
      pat
      pool_v2
      gogo_protobuf
      ratecounter
      snappy
      statik
      toml
      usage-client
    ];
    goPackageAliases = [
      "github.com/influxdb/influxdb"
    ];
    postPatch = /* Remove broken tests */ ''
      rm -rf services/collectd/test_client
    '';
  };

  influxdb_client = buildFromGitHub {
    inherit (influxdb) owner repo rev sha256 version;
    goPackageAliases = [
      "github.com/influxdb/influxdb"
    ];
    subPackages = [
      "client"
      "models"
      "pkg/escape"
    ];
  };

  ini = buildFromGitHub {
    version = 2;
    rev = "v1.25.5";
    owner  = "go-ini";
    repo   = "ini";
    sha256 = "14cd63b588gsil2iwn6dmkryh461f0p2c0in9gw4px6ygvkk9plx";
  };

  ini_v1 = buildFromGitHub {
    version = 2;
    rev = "v1.25.5";
    owner  = "go-ini";
    repo   = "ini";
    goPackagePath = "gopkg.in/ini.v1";
    sha256 = "14kxy3pvi5rhgp6hb1pcxr6amfv7llx95kah6gg9l86vhkhbr09g";
  };

  inject = buildFromGitHub {
    version = 1;
    date = "2016-06-28";
    rev = "d8a0b8677191f4380287cfebd08e462217bac7ad";
    owner = "go-macaron";
    repo = "inject";
    sha256 = "1zb5sw83grna85cgsz7nhwpbkkysnyfc6hzk7gksidf08s8s9dmg";
  };

  internal = buildFromGitHub {
    version = 1;
    rev = "fbe290d56cdd8bb25347df893b14e3454f07bf74";
    owner  = "cznic";
    repo   = "internal";
    sha256 = "0x80s83nq75xajyqspzcgj2mq5gxw9psxghvb676q8y96jn1n10k";
    date = "2016-07-19";
    buildInputs = [
      fileutil
      mathutil
      mmap-go
    ];
  };

  iter = buildFromGitHub {
    version = 1;
    rev = "454541ec3da2a73fc34fd049b19ee5777bf19345";
    owner  = "bradfitz";
    repo   = "iter";
    sha256 = "0sv6rwr05v219j5vbwamfvpp1dcavci0nwr3a2fgxx98pjw7hgry";
    date = "2014-01-23";
  };

  ipfs = buildFromGitHub {
    version = 2;
    rev = "v0.4.6";
    owner = "ipfs";
    repo = "go-ipfs";
    sha256 = "1yj0i2n8ww7fplkqpnk7106lc514wjiik4wagja2gp0miq40xh8v";
    gxSha256 = "1wrx86118llzdpy1ksgn5v86ra3ickcjkf35pg3xjd3jvqy0rjqb";
    subPackages = [
      "cmd/ipfs"
      "cmd/ipfswatch"
    ];
    nativeBuildInputs = [
      gx-go.bin
    ];
    # Prevent our Godeps remover from work here
    preConfigure = ''
      mv Godeps "$TMPDIR"
    '';
    postConfigure = ''
      mv "$TMPDIR/Godeps" "go/src/$goPackagePath"
    '';
  };

  jose = buildFromGitHub {
    version = 2;
    owner = "SermoDigital";
    repo = "jose";
    rev = "2bd9b81ac51d6d6134fcd4fd846bd2e7347a15f9";
    date = "2016-12-05";
    sha256 = "1v5df8nkn34m7md3y8qbm71q7224r1la9r6rp06ah9zsakc8pqkb";
  };

  json-filter = buildFromGitHub {
    version = 1;
    owner = "whyrusleeping";
    repo = "json-filter";
    rev = "ff25329a9528f01c5175414f16cc0a6a162a5b8b";
    date = "2016-06-15";
    sha256 = "0y1d6yi09ac0xlf63qrzxsi7dqf10wha3na633qzqjnpjcga97ck";
  };

  jsonx = buildFromGitHub {
    version = 2;
    owner = "jefferai";
    repo = "jsonx";
    rev = "9cc31c3135eef39b8e72585f37efa92b6ca314d0";
    date = "2016-07-21";
    sha256 = "0s5zani868a70hpacqxl1qzzwc8hdappb99qixmbfkf7wdyyzfic";
    propagatedBuildInputs = [
      gabs
    ];
  };

  jwalterweatherman = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "jWalterWeatherman";
    rev = "fa7ca7e836cf3a8bb4ebf799f472c12d7e903d66";
    date = "2017-01-09";
    sha256 = "0qsr7l86vcydaihk5p7051g161i45hrynfh7q8bnyg04rsh6kg71";
    goPackageAliases = [
      "github.com/spf13/jwalterweatherman"
    ];
  };

  jwt-go = buildFromGitHub {
    version = 2;
    owner = "dgrijalva";
    repo = "jwt-go";
    rev = "2268707a8f0843315e2004ee4f1d021dc08baedf";
    sha256 = "164ly3njl7qbd4ddh8slmphwrs7vm7k8p6l5az57qrg3w00aijfy";
    date = "2017-02-01";
  };

  gravitational_kingpin = buildFromGitHub {
    version = 2;
    rev = "785686550a08e8e2e77641c91714280a6dfb08ee";
    owner = "gravitational";
    repo = "kingpin";
    sha256 = "0klg0nixdy13r50xkfh7mlhdyfk0x7ymmb1m4l29zj00zmhy07if";
    propagatedBuildInputs = [
      template
      units
    ];
    meta.useUnstable = true;
    date = "2016-02-05";
  };

  kingpin_v2 = buildFromGitHub {
    version = 2;
    rev = "v2.2.3";
    owner = "alecthomas";
    repo = "kingpin";
    sha256 = "196087z4473psagd0n0wss12knqabcbh4iyikwcbiiw3hx4lx0ix";
    goPackagePath = "gopkg.in/alecthomas/kingpin.v2";
    propagatedBuildInputs = [
      template
      units
    ];
  };

  ldap = buildFromGitHub {
    version = 2;
    rev = "v2.5.0";
    owner  = "go-ldap";
    repo   = "ldap";
    sha256 = "15mc4hrlfvjpbjr89w4s0267x3s3zkmhjd0qj2ls0bk2q3l48vmg";
    goPackageAliases = [
      "github.com/nmcclain/ldap"
      "github.com/vanackere/ldap"
    ];
    propagatedBuildInputs = [ asn1-ber ];
  };

  ledisdb = buildFromGitHub {
    version = 2;
    rev = "6ad692d5e10f0abb045353f685a719d825f17bcc";
    owner  = "siddontang";
    repo   = "ledisdb";
    sha256 = "1hjg1x18y4g59m77q4qn8g6mnl5iwws5cnf9c5k0dkh4bx32245p";
    date = "2017-03-15";
    prePatch = ''
      dirs=($(find . -type d -name vendor | sort))
      echo "''${dirs[@]}" | xargs -n 1 rm -r
    '';
    propagatedBuildInputs = [
      siddontang_go
      ugorji_go
      goleveldb
      goredis
      liner
      mmap-go
      siddontang_rdb
      toml
    ];
  };

  lego = buildFromGitHub {
    version = 2;
    rev = "45beff7ed309e190408d7ac1c89a7b7751596a73";
    owner = "xenolf";
    repo = "lego";
    sha256 = "0qb9rs4wmv3ha98iz5772l1dylqxabl4y2a2lnns2vjcnamxc8d8";

    buildInputs = [
      auroradnsclient
      aws-sdk-go
      azure-sdk-for-go
      urfave_cli
      crypto
      dns
      dnspod-go
      weppos-dnsimple-go
      egoscale
      go-autorest
      go-ini
      go-jose_v1
      go-ovh
      goamz
      google-api-go-client
      linode
      memcache
      ns1-go_v2
      oauth2
      net
      vultr
    ];

    subPackages = [
      "."
    ];
    date = "2017-03-13";
  };

  lemma = buildFromGitHub {
    version = 2;
    rev = "cbfbc8381e93147bc50db64509634327d0f6d626";
    owner = "mailgun";
    repo = "lemma";
    sha256 = "1rqg0fw94vavi6a9c0cgc0xg9gy6p25ps2p9bs65flda60cm59ph";
    date = "2016-09-01";
    propagatedBuildInputs = [
      crypto
      metrics
      timetools
      mailgun_ttlmap
    ];
  };

  libtrust = buildFromGitHub {
    version = 2;
    rev = "aabc10ec26b754e797f9028f4589c5b7bd90dc20";
    owner = "docker";
    repo = "libtrust";
    sha256 = "40837c2420436be95f8098bf3a9c1b2820b72ec2b43fd0983a00c006d66ba1e8";
    date = "2016-07-08";
    postPatch = /* Demo uses same package namespace as actual library */ ''
      rm -rfv tlsdemo
    '';
  };

  liner = buildFromGitHub {
    version = 2;
    rev = "bf27d3ba8e1d9899d45a457ffac16c953eb2d647";
    owner = "peterh";
    repo = "liner";
    sha256 = "07dv24678gg3vp37xwjf446145ns9wyg2g9igfrhk2nlgkz7kxgc";
    date = "2017-02-11";
  };

  linode = buildFromGitHub {
    version = 2;
    rev = "37e84520dcf74488f67654f9c775b9752c232dc1";
    owner = "timewasted";
    repo = "linode";
    sha256 = "13ypkib9nmm8pc2z8yqa97gh3karvrhwas0i4ck88pqhxwi85liw";
    date = "2016-08-29";
  };

  lldb = buildFromGitHub {
    version = 2;
    rev = "bea8611dd5c407f3c5eab9f9c68e887a27dc6f0e";
    owner  = "cznic";
    repo   = "lldb";
    sha256 = "1a3zd71vkvz1c319ihpmrky4zy84lazhsy3gwmnac71f6r8schii";
    buildInputs = [
      fileutil
      mathutil
      sortutil
    ];
    propagatedBuildInputs = [
      mmap-go
    ];
    extraSrcs = [
      {
        inherit (internal)
          goPackagePath
          src;
      }
      {
        inherit (zappy)
          goPackagePath
          src;
      }
    ];
    meta.useUnstable = true;
    date = "2016-11-02";
  };

  log15 = buildFromGitHub {
    version = 2;
    rev = "39bacc234bf1afd0b68573e95b45871f67ba2cd4";
    owner  = "inconshreveable";
    repo   = "log15";
    sha256 = "0sqk1yjya1gbfdy2sr453q07rvhfg3whxm0kj60qv35l68c8sw68";
    propagatedBuildInputs = [
      go-colorable
      stack
    ];
    date = "2017-02-16";
  };

  log15_v2 = buildFromGitHub {
    version = 1;
    rev = "v2.11";
    owner  = "inconshreveable";
    repo   = "log15";
    sha256 = "1krlgq3m0q40y8bgaf9rk7zv0xxx5z92rq8babz1f3apbdrn00nq";
    goPackagePath = "gopkg.in/inconshreveable/log15.v2";
    propagatedBuildInputs = [
      go-colorable
      stack
    ];
  };

  lunny_log = buildFromGitHub {
    version = 2;
    rev = "7887c61bf0de75586961948b286be6f7d05d9f58";
    owner = "lunny";
    repo = "log";
    sha256 = "0jsk5yc7lqlh9zicadbhxh6as3vlhln08f2wxrbnpcw0b1jncnp1";
    date = "2016-09-21";
  };

  mailgun_log = buildFromGitHub {
    version = 2;
    rev = "2f35a4607f1abf71f97f77f99b0de8493ef6f4ef";
    owner = "mailgun";
    repo = "log";
    sha256 = "1akyw7r5as06b6inn16wh9gg16zx3729nxmrgg0c46sgy23xmh9m";
    date = "2015-09-25";
  };

  loghisto = buildFromGitHub {
    version = 2;
    rev = "9d1d8c1fd2a4ac852bf2e312f2379f553345fda7";
    owner = "spacejam";
    repo = "loghisto";
    sha256 = "0dpfgzlf4n0vvppffxk5qwdb72iq6x320srkd1rzys0fd7xyvyz1";
    date = "2016-03-02";
    propagatedBuildInputs = [
      glog
    ];
  };

  logrus = buildFromGitHub {
    version = 2;
    rev = "v0.11.5";
    owner = "Sirupsen";
    repo = "logrus";
    sha256 = "13r9xjrhjfs8kjcbvhy6a53qvqm2iqn48ik3bk1bsfjdbqh326rb";
  };

  logutils = buildFromGitHub {
    version = 1;
    date = "2015-06-09";
    rev = "0dc08b1671f34c4250ce212759ebd880f743d883";
    owner  = "hashicorp";
    repo   = "logutils";
    sha256 = "11p4p01x37xcqzfncd0w151nb5izmf3sy77vdwy0dpwa9j8ccgmw";
  };

  logxi = buildFromGitHub {
    version = 2;
    date = "2016-10-27";
    rev = "aebf8a7d67ab4625e0fd4a665766fef9a709161b";
    owner  = "mgutz";
    repo   = "logxi";
    sha256 = "10rvbxihgkwbdbb6pc7pn4jhgjxmq7gvxc8r5hckfi7qmc3z0ahk";
    excludedPackages = "Gododir";
    propagatedBuildInputs = [
      ansi
      go-colorable
      go-isatty
    ];
  };

  luhn = buildFromGitHub {
    version = 1;
    rev = "v1.0.0";
    owner  = "calmh";
    repo   = "luhn";
    sha256 = "13brkbbmj9bh0b9j3avcyrj542d78l9hg3bxj7jjvkp5n5cxwp41";
  };

  lxd = buildFromGitHub {
    version = 2;
    rev = "lxd-2.11";
    owner  = "lxc";
    repo   = "lxd";
    sha256 = "0clxq4agsckimcixbzadgniqvihb20vimm03dz5p3wigs00bamas";
    excludedPackages = "test"; # Don't build the binary called test which causes conflicts
    buildInputs = [
      crypto
      gettext
      gocapability
      golang-petname
      go-lxc_v2
      go-sqlite3
      go-systemd
      log15_v2
      pkgs.lxc
      mux
      pborman_uuid
      pongo2-v3
      protobuf
      tablewriter
      tomb_v2
      yaml_v2
      websocket
    ];
  };

  macaron_v1 = buildFromGitHub {
    version = 2;
    rev = "v1.2.1";
    owner  = "go-macaron";
    repo   = "macaron";
    sha256 = "182xihcysz553g48xl0skcvbimpqngch4ii371fy29mipanis8rj";
    goPackagePath = "gopkg.in/macaron.v1";
    goPackageAliases = [
      "github.com/go-macaron/macaron"
    ];
    propagatedBuildInputs = [
      com
      ini_v1
      inject
    ];
  };

  mafmt = buildFromGitHub {
    version = 2;
    date = "2017-02-01";
    rev = "f052f16d5bc5e910bfeb695a91914378be0eadce";
    owner = "whyrusleeping";
    repo = "mafmt";
    sha256 = "0kqyfbgzakap63pvch081661p0xbz2r2f5i5cxy2gqsh2d35ph5j";
    propagatedBuildInputs = [
      go-multiaddr
    ];
  };

  mapstructure = buildFromGitHub {
    version = 2;
    date = "2017-03-07";
    rev = "53818660ed4955e899c0bcafa97299a388bd7c8e";
    owner  = "mitchellh";
    repo   = "mapstructure";
    sha256 = "1r5kja1nxir0h9876y4536xsb7id5zbvy10nknw87v14xqxrrkfm";
  };

  match = buildFromGitHub {
    version = 2;
    owner = "tidwall";
    repo = "match";
    date = "2016-08-30";
    rev = "173748da739a410c5b0b813b956f89ff94730b4c";
    sha256 = "362da507bd9755044b3a1f9c0f048ec8758012ca55593b9a1dd63edd76e4e5f9";
  };

  mathutil = buildFromGitHub {
    version = 2;
    date = "2017-03-13";
    rev = "1447ad269d64ca91aa8d7079baa40b6fc8b965e7";
    owner = "cznic";
    repo = "mathutil";
    sha256 = "1v1ff44562dwmijs5pnmsa1ylxnskpm916rfcwqf1padgjxmp6bm";
    buildInputs = [ bigfft ];
  };

  maxminddb-golang = buildFromGitHub {
    version = 2;
    rev = "v1.1.0";
    owner  = "oschwald";
    repo   = "maxminddb-golang";
    sha256 = "0z1hbncy2ang3p6zc9pvijbx7y3vgwfi714a4cm5mx6j6125dl49";
    propagatedBuildInputs = [
      sys
    ];
  };

  mc = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "mc";
    rev = "43693592867420ad43f767ab26d8fb45dbb81051";
    sha256 = "1mxc97wm2hqiw9as5m4v1bnf8pmlz18bflrghfl1zzh9nwdwl6rz";
    propagatedBuildInputs = [
      cli_minio
      color
      go-colorable
      go-homedir_minio
      go-humanize
      go-version
      minio_pkg
      minio-go
      notify
      pb
      profile
      structs
    ];
    date = "2017-03-14";
  };

  mdns = buildFromGitHub {
    version = 2;
    date = "2017-02-21";
    rev = "4e527d9d808175f132f949523e640c699e4253bb";
    owner = "hashicorp";
    repo = "mdns";
    sha256 = "0d7hknw06jsk3w7cvy5hrwg3y4dhzc5d2176vr0g624ww5jdzh64";
    propagatedBuildInputs = [
      dns
      net
    ];
  };

  memberlist = buildFromGitHub {
    version = 2;
    date = "2017-02-08";
    rev = "23ad4b7d7b38496cd64c241dfd4c60b7794c254a";
    owner = "hashicorp";
    repo = "memberlist";
    sha256 = "0m367rklwsqdyfd09fq65hr8as6spy1w7lymzwvj7q28c2simqah";
    propagatedBuildInputs = [
      dns
      ugorji_go
      armon_go-metrics
      go-multierror
      go-sockaddr
      seed
    ];
  };

  memcache = buildFromGitHub {
    version = 2;
    date = "2015-06-22";
    rev = "1031fa0ce2f20c1c0e1e1b51951d8ea02c84fa05";
    owner = "rainycape";
    repo = "memcache";
    sha256 = "0585b0rblaxn4b2p5q80x3ynlcbhvf43p18yxxhlnm0yf0w3hjl9";
  };

  metrics = buildFromGitHub {
    version = 2;
    date = "2015-01-23";
    rev = "2b3c4565aafdcd40c8069e50de08ac5379787943";
    owner = "mailgun";
    repo = "metrics";
    sha256 = "01nnm2wl2m1p1bj86rj87r1yf5f9fmvxxamd2v88p04958xbj0jk";
    propagatedBuildInputs = [
      timetools
    ];
  };

  mgo_v2 = buildFromGitHub {
    version = 1;
    rev = "r2016.08.01";
    owner = "go-mgo";
    repo = "mgo";
    sha256 = "0hq8wfypghfcz83035wdb844b39pd1qly43zrv95i99p35fwmx22";
    goPackagePath = "gopkg.in/mgo.v2";
    goPackageAliases = [
      "github.com/10gen/llmgo"
    ];
    excludedPackages = "dbtest";
    buildInputs = [
      pkgs.cyrus-sasl
    ];
  };

  minheap = buildFromGitHub {
    version = 2;
    rev = "7c28d80e2ada649fc8ab1a37b86d30a2633bd47c";
    owner = "mailgun";
    repo = "minheap";
    sha256 = "06lyppnqhyfq1ksc8c50c2czjp3h1ra38jsm8r5mafxrn6rv7p7w";
    date = "2013-12-07";
  };

  minio = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "minio";
    rev = "RELEASE.2016-09-11T17-42-18Z";
    sha256 = "a1e43f383fe94c9e5056c4144d9fa0264d7a44b85bcc12dd7970f1acf9953445";
    buildInputs = [
      amqp
      blake2b-simd
      cli_minio
      color
      cors
      crypto
      dsync
      elastic_v3
      gjson
      go-bindata-assetfs
      go-homedir_minio
      go-humanize
      go-version
      handlers
      jwt-go
      logrus
      mc
      minio-go
      mux
      pb
      profile
      redigo
      reedsolomon
      rpc
      sha256-simd
      skyring-common
      structs
    ];
  };

  # The pkg package from minio, for bootstrapping minio
  minio_pkg = buildFromGitHub {
    inherit (minio) version owner repo rev sha256;
    propagatedBuildInputs = [
      # Propagate minio_pkg_probe from here for consistency
      minio_pkg_probe
      pb
      structs
    ];
    postUnpack = ''
      mv -v "$sourceRoot" "''${sourceRoot}.old"
      mkdir -pv "$sourceRoot"
      mv -v "''${sourceRoot}.old"/pkg "$sourceRoot"/pkg
      rm -rf "''${sourceRoot}.old"
    '';
  };

  # Probe pkg was remove in later releases, but still required by mc
  minio_pkg_probe = buildFromGitHub {
    version = 2;
    inherit (minio) owner repo;
    rev = "RELEASE.2016-04-17T22-09-24Z";
    sha256 = "41c8749f0a7c6a22ef35f7cb2577e31871bff95c4c5c035a936b220f198ed04e";
    propagatedBuildInputs = [
      go-humanize
    ];
    postUnpack = ''
      mv -v "$sourceRoot" "''${sourceRoot}.old"
      mkdir -pv "$sourceRoot"/pkg
      mv -v "''${sourceRoot}.old"/pkg/probe "$sourceRoot"/pkg/probe
      rm -rf "''${sourceRoot}.old"
    '';
    meta.autoUpdate = false;
  };

  minio-go = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "minio-go";
    rev = "5857456dabe780988e5a3b7284343031e73863dc";
    sha256 = "19nih9vv5kywlphsvhhncgxrbmqf8kg5k4q2klkqm8k234iclwl0";
    meta.useUnstable = true;
    date = "2017-03-15";
  };

  missinggo = buildFromGitHub {
    version = 1;
    rev = "f3a48f14358dc22876048390ba49b963a476a5db";
    owner  = "anacrolix";
    repo   = "missinggo";
    sha256 = "d5c34a92445e5ec95d897f68f9f1cce2a02fdc0d6adc372a98a8bbce6a441c84";
    date = "2016-06-18";
    propagatedBuildInputs = [
      b
      btree
      docopt-go
      envpprof
      goskiplist
      iter
      net
      roaring
      tagflag
    ];
    meta.autoUpdate = false;
  };

  missinggo_lib = buildFromGitHub {
    inherit (missinggo) rev owner repo sha256 version date;
    subPackages = [
      "."
    ];
    propagatedBuildInputs = [
      iter
    ];
    meta.autoUpdate = false;
  };

  mmap-go = buildFromGitHub {
    version = 1;
    owner = "edsrzf";
    repo = "mmap-go";
    rev = "935e0e8a636ca4ba70b713f3e38a19e1b77739e8";
    sha256 = "1a9s99gwziamlw2yn7i86wh675ag2bqbp5aa13vf8kl2rfc2p6ma";
    date = "2016-05-12";
  };

  mmark = buildFromGitHub {
    version = 2;
    owner = "miekg";
    repo = "mmark";
    rev = "2d4f1dd6f87cad351b9323bbaa6f6c586f0c4bee";
    sha256 = "0r0mrsj0pz60g7ljiij0kl9b5s4r0nyl56fjgwy5fn5rpliakinc";
    buildInputs = [
      toml
    ];
    date = "2016-11-03";
  };

  mock = buildFromGitHub {
    version = 2;
    owner = "golang";
    repo = "mock";
    rev = "bd3c8e81be01eef76d4b503f5e687d2d1354d2d9";
    date = "2016-01-21";
    sha256 = "5d964bd99a35234ae8a9a0a9ea030665f57ede3459dff10290788475744ba470";
  };

  mongo-tools = buildFromGitHub {
    version = 2;
    rev = "r3.5.2";
    owner  = "mongodb";
    repo   = "mongo-tools";
    sha256 = "0k48d820ds15vlb5l27xfzbnsd6l5wnl8vylrycn6ark6w7gvlf4";
    buildInputs = [
      crypto
      escaper
      go-cache
      go-flags
      gopacket
      gopass
      mgo_v2
      openssl
      termbox-go
      tomb_v2
    ];

    # Mongodb incorrectly names all of their binaries main
    # Let's work around this with our own installer
    preInstall = ''
      mkdir -p $bin/bin
      while read b; do
        rm -f go/bin/main
        go install $goPackagePath/$b/main
        cp go/bin/main $bin/bin/$b
      done < <(find go/src/$goPackagePath -name main | xargs dirname | xargs basename -a)
      rm -r go/bin
    '';
  };

  mow-cli = buildFromGitHub {
    version = 2;
    rev = "d3ffbc2f98b83e09dc8efd55ecec75eb5fd656ec";
    owner  = "jawher";
    repo   = "mow.cli";
    sha256 = "1mji6248gv5i61qg1dsbcf1ijy9ajf16x3lv0b8f3jvvb495m8ms";
    date = "2017-02-20";
  };

  ns1-go_v2 = buildFromGitHub {
    version = 2;
    rev = "49e3a8a0b594e847e01cdac77810ba49f9564ccf";
    owner  = "ns1";
    repo   = "ns1-go";
    sha256 = "003i41hid39gj70rm7naqy1wfs5kddc4hmia122hca34jhravwvr";
    goPackagePath = "gopkg.in/ns1/ns1-go.v2";
    date = "2017-03-02";
  };

  msgp = buildFromGitHub {
    version = 2;
    rev = "v1.0";
    owner  = "tinylib";
    repo   = "msgp";
    sha256 = "1m49ahnqqf40yjj9jij30iargq6jm0cm1alpr191nd3x692sc9ds";
    propagatedBuildInputs = [
      fwd
      chalk
      tools
    ];
  };

  multibuf = buildFromGitHub {
    version = 2;
    rev = "565402cd71fbd9c12aa7e295324ea357e970a61e";
    owner  = "mailgun";
    repo   = "multibuf";
    sha256 = "1csjfl3bcbya7dq3xm1nqb5rwrpw5migrqa4ajki242fa5i66mdr";
    date = "2015-07-14";
  };

  murmur3 = buildFromGitHub {
    version = 2;
    rev = "0d12bf811670bf6a1a63828dfbd003eded177fce";
    owner  = "spaolacci";
    repo   = "murmur3";
    sha256 = "1biq3rv8ycnyrma135273bi6pd62866gy84dnv17vqf3pnrcz3bd";
    date = "2015-08-29";
  };

  mux = buildFromGitHub {
    version = 2;
    rev = "v1.3.0";
    owner = "gorilla";
    repo = "mux";
    sha256 = "1h621g4yjccw36nfxawzh28jd1awdpvnrjhfhd3pp6m1dmhnc3gg";
    propagatedBuildInputs = [
      context
    ];
  };

  muxado = buildFromGitHub {
    version = 1;
    date = "2014-03-12";
    rev = "f693c7e88ba316d1a0ae3e205e22a01aa3ec2848";
    owner  = "inconshreveable";
    repo   = "muxado";
    sha256 = "db9a65b811003bcb48d1acefe049bb12c8de232537cf07e1a4a949a901d807a2";
    meta.autoUpdate = false;
  };

  mysql = buildFromGitHub {
    version = 2;
    rev = "v1.3";
    owner  = "go-sql-driver";
    repo   = "mysql";
    sha256 = "1jy5ak2ka6qi16i99c06b1k6nvf3fbngcj454dzxk1xwrd5y076h";
  };

  net-rpc-msgpackrpc = buildFromGitHub {
    version = 1;
    date = "2015-11-15";
    rev = "a14192a58a694c123d8fe5481d4a4727d6ae82f3";
    owner = "hashicorp";
    repo = "net-rpc-msgpackrpc";
    sha256 = "007pwdpap465b32cx1i2hmf2q67vik3wk04xisq2pxvqvx81irks";
    propagatedBuildInputs = [ ugorji_go go-multierror ];
  };

  netlink = buildFromGitHub {
    version = 2;
    rev = "fe3b5664d23a11b52ba59bece4ff29c52772a56b";
    owner  = "vishvananda";
    repo   = "netlink";
    sha256 = "14lj51afzq2fhklcyc0v9z9sy134bjw0s9vcy29n37m2sa6paxcx";
    date = "2017-02-20";
    propagatedBuildInputs = [
      netns
    ];
  };

  netns = buildFromGitHub {
    version = 2;
    rev = "54f0e4339ce73702a0607f49922aaa1e749b418d";
    owner  = "vishvananda";
    repo   = "netns";
    sha256 = "0rwb0bk1dcz477di5md4jd643d5cpc3yizwqlq6zfwx7yxi0nqp2";
    date = "2017-02-19";
  };

  nitro = buildFromGitHub {
    version = 1;
    owner = "spf13";
    repo = "nitro";
    rev = "24d7ef30a12da0bdc5e2eb370a79c659ddccf0e8";
    date = "2013-10-03";
    sha256 = "1dbnfac79lxc1pr1j1n3956i292ck4yjrhr8nsd2wp2jccab5zdz";
  };

  nodb = buildFromGitHub {
    version = 1;
    owner = "lunny";
    repo = "nodb";
    rev = "fc1ef06ad4af0da31cdb87e3fa5ec084c67e6597";
    date = "2016-06-21";
    sha256 = "1w46s9mgqjq0faybr743fs96jp0g1pcahrfamfiwi5hz28dqfcsp";
    propagatedBuildInputs = [
      goleveldb
      lunny_log
      go-snappy
      toml
    ];
  };

  nomad = buildFromGitHub {
    version = 2;
    rev = "v0.5.5";
    owner = "hashicorp";
    repo = "nomad";
    sha256 = "1isnpkyaskhvq2ddqdgikl6iykpc84bzj6ssmc60b9fyyc8qqzvw";

    nativeBuildInputs = [
      ugorji_go.bin
    ];

    buildInputs = [
      gziphandler
      circbuf
      armon_go-metrics
      go-spew
      go-humanize
      go-dockerclient
      cronexpr
      consul_api
      go-checkpoint
      go-cleanhttp
      go-getter
      go-memdb
      ugorji_go
      go-multierror
      go-syslog
      go-version
      hcl
      logutils
      memberlist
      net-rpc-msgpackrpc
      raft_v1
      raft-boltdb_v1
      scada-client
      serf
      yamux
      osext
      mitchellh_cli
      colorstring
      copystructure
      go-ps
      hashstructure
      mapstructure
      runc
      columnize
      gopsutil
      sys
      go-plugin
      tail
      srslog
      consul-template
      sync
      time
      tomb_v2
      snappy
      docker_for_nomad
    ];

    subPackages = [
      "."
    ];

    # Rename deprecated ParseNamed to ParseNormalizedNamed
    postPatch = ''
      find . -type f -exec sed -i {} \
        -e 's,.ParseNamed,.ParseNormalizedNamed,g' \
        -e 's,"github.com/docker/docker/reference","github.com/docker/distribution/reference",g' \
        \;
    '';

    preBuild = ''
      pushd go/src/$goPackagePath
      go list ./... | xargs go generate
      popd
    '';
  };

  notify = buildFromGitHub {
    version = 2;
    owner = "rjeczalik";
    repo = "notify";
    date = "2017-03-01";
    rev = "41a86457b5eea072a7e6f40bbfaf94c8df41d3aa";
    sha256 = "1bhfhbgk7s3x00jhppjrsmfjvcp1r91ji0r0l5ws742438ksrwj9";
  };

  objx = buildFromGitHub {
    version = 1;
    date = "2015-09-28";
    rev = "1a9d0bb9f541897e62256577b352fdbc1fb4fd94";
    owner  = "stretchr";
    repo   = "objx";
    sha256 = "0ycjvfbvsq6pmlbq2v7670w1k25nydnz4scx0qgiv0f4llxnr0y9";
  };

  open-golang = buildFromGitHub {
    version = 2;
    owner = "skratchdot";
    repo = "open-golang";
    rev = "75fb7ed4208cf72d323d7d02fd1a5964a7a9073c";
    date = "2016-03-02";
    sha256 = "da900f012522dd61cc0504a16bbb137e3ed2173d0715fbf709046a1e0d923ca3";
  };

  openssl = buildFromGitHub {
    version = 2;
    date = "2016-09-22";
    rev = "5be686e264d836e7a01ca7fc7c53acdb8edbe768";
    owner = "10gen";
    repo = "openssl";
    sha256 = "0jlr0y8812ayj5xfpn7m0m1pfm8pf1g43xbw7ngs4zxcs0ip7l9g";
    goPackageAliases = [ "github.com/spacemonkeygo/openssl" ];
    nativeBuildInputs = [ pkgs.pkgconfig ];
    buildInputs = [ pkgs.openssl ];
    propagatedBuildInputs = [ spacelog ];

    preBuild = ''
      find go/src/$goPackagePath -name \*.go | xargs sed -i 's,spacemonkeygo/openssl,10gen/openssl,g'
    '';
  };

  osext = buildFromGitHub {
    version = 2;
    date = "2017-03-09";
    rev = "9d302b58e975387d0b4d9be876622c86cefe64be";
    owner = "kardianos";
    repo = "osext";
    sha256 = "1p2n6k4bvz375ra1690w13cgv2l0hmazbm70saka11jv9b4m9h3v";
    goPackageAliases = [
      "github.com/bugsnag/osext"
      "bitbucket.org/kardianos/osext"
    ];
  };

  oxy = buildFromGitHub {
    version = 2;
    owner = "vulcand";
    repo = "oxy";
    date = "2016-07-23";
    rev = "db85f00cac5466def1f6f2667063e6e38c1fe606";
    sha256 = "3c32677900a6399eecd80fc47798e998f47f8df502727574052d6ddc654d4a61";
    goPackageAliases = [ "github.com/mailgun/oxy" ];
    propagatedBuildInputs = [
      hdrhistogram
      mailgun_log
      multibuf
      predicate
      timetools
      mailgun_ttlmap
    ];
    meta.autoUpdate = false;
  };

  pat = buildFromGitHub {
    version = 2;
    owner = "bmizerany";
    repo = "pat";
    date = "2016-02-17";
    rev = "c068ca2f0aacee5ac3681d68e4d0a003b7d1fd2c";
    sha256 = "aad2d84661ea918168e60ed7bab467d4e0fce28fe9372e786c2714c10f6490a7";
  };

  pb = buildFromGitHub {
    version = 2;
    owner = "cheggaaa";
    repo = "pb";
    date = "2017-03-06";
    rev = "bd1f886442f85613c68401483d34fc7ed9d70ca7";
    sha256 = "02xmr9wzzl9gq4z548cl3jvs7axj9da2mlf6ny90kcq2ladvqr8c";
    propagatedBuildInputs = [
      go-runewidth
    ];
    meta.useUnstable = true;
  };

  pb_v1 = buildFromGitHub {
    version = 2;
    owner = "cheggaaa";
    repo = "pb";
    rev = "v1.0.9";
    sha256 = "0czhpmzq19cgn4hjyi8ym3zsxw63kh3cdvgpwvbgj3bw0mpplv7c";
    goPackagePath = "gopkg.in/cheggaaa/pb.v1";
    propagatedBuildInputs = [
      go-runewidth
    ];
  };

  beorn7_perks = buildFromGitHub {
    version = 1;
    date = "2016-08-04";
    owner  = "beorn7";
    repo   = "perks";
    rev = "4c0e84591b9aa9e6dcfdf3e020114cd81f89d5f9";
    sha256 = "19dw6jcvcbnk0nq4wy9dhrb1d3k85xwnfvwn1ld03f2mzmshf9fr";
  };

  pester = buildFromGitHub {
    version = 2;
    owner = "sethgrid";
    repo = "pester";
    rev = "2c5fb962da6113d0968907fd81dba3ca35151d1c";
    date = "2016-12-29";
    sha256 = "0sjni0qz026xr4q04j0dzi0jnxnipm86qpic9l4wmxcf2q0bzx1y";
  };

  pflag = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "pflag";
    rev = "9ff6c6923cfffbcd502984b8e0c80539a94968b7";
    date = "2017-01-30";
    sha256 = "0h0iq8h2xwifaz3qfz89svy5by7zrfqmchvbkfyzs4k7w5fw6sh9";
  };

  pkcs7 = buildFromGitHub {
    version = 2;
    owner = "fullsailor";
    repo = "pkcs7";
    rev = "eb67e7e564b9eae64dc7d95fae0784d6086a5fc4";
    date = "2017-02-08";
    sha256 = "0814z5w0pcsnb64pg356xhxamkl4aa1hdal2w6xhnhcz9xmsaxan";
  };

  pkg = buildFromGitHub {
    version = 2;
    date = "2017-02-06";
    owner  = "coreos";
    repo   = "pkg";
    rev = "1c941d73110817a80b9fa6e14d5d2b00d977ce2a";
    sha256 = "012xiqc9369a1dy3yk4scb3nib95i5xdqxqz85ykkb8gk6r27dm6";
    buildInputs = [
      crypto
      yaml_v1
    ];
    propagatedBuildInputs = [
      go-systemd_journal
    ];
  };

  pongo2-v3 = buildFromGitHub {
    version = 1;
    rev = "v3.0";
    owner  = "flosch";
    repo   = "pongo2";
    sha256 = "1qjcj7hcjskjqp03fw4lvn1cwy78dck4jcd0rcrgdchis1b84isk";
    goPackagePath = "gopkg.in/flosch/pongo2.v3";
  };

  pool_v2 = buildFromGitHub {
    version = 2;
    owner = "fatih";
    repo = "pool";
    date = "2017-01-11";
    rev = "6e328e67893eb46323ad06f0e92cb9536babbabc";
    sha256 = "0zyv8ikhvj3jmqlv0s6ablgazyzc61d3k2jybqa1h95ibb9qrdhq";
    goPackagePath = "gopkg.in/fatih/pool.v2";
  };

  pq = buildFromGitHub {
    version = 2;
    rev = "472a0745531a17dbac346e828b4c60e73ddff30c";
    owner  = "lib";
    repo   = "pq";
    sha256 = "07m3qv4l8l8vb96ncmpffv19mxc5yv57zpq937083y3psgb8sy01";
    date = "2017-03-13";
  };

  probing = buildFromGitHub {
    version = 2;
    rev = "07dd2e8dfe18522e9c447ba95f2fe95262f63bb2";
    owner  = "xiang90";
    repo   = "probing";
    sha256 = "140b5bizry0cw2s98dscp5b8zy57h2l5ybkmr7abx9d1c2nrxqnj";
    date = "2016-08-13";
  };

  predicate = buildFromGitHub {
    version = 2;
    rev = "19b9dde14240d94c804ae5736ad0e1de10bf8fe6";
    owner  = "vulcand";
    repo   = "predicate";
    sha256 = "0i2smqnr8vldz7iiid835kgkvs55hb5vjdjj9h87xlwy7f8y9map";
    date = "2016-06-21";
  };

  profile = buildFromGitHub {
    version = 2;
    owner = "pkg";
    repo = "profile";
    rev = "v1.2.0";
    sha256 = "02mq7xinxxln3wz3pgqaklpj0ry3ipp8agvzci72l2b56v50aas2";
  };

  prometheus = buildFromGitHub {
    version = 2;
    rev = "v1.5.2";
    owner  = "prometheus";
    repo   = "prometheus";
    sha256 = "00sf9z4fsfksx5yrdfqgzh32f9sg6jsys0s92f3p74nw70rfhq7y";
    buildInputs = [
      aws-sdk-go
      azure-sdk-for-go
      consul_api
      dns
      fsnotify_v1
      go-autorest
      goleveldb
      govalidator
      go-zookeeper
      google-api-go-client
      grpc
      influxdb_client
      logrus
      net
      prometheus_common
      yaml_v2
    ];
  };

  prometheus_client_golang = buildFromGitHub {
    version = 2;
    rev = "a5060f1eaab721946b185b2de468ff83ea5b89cb";
    owner = "prometheus";
    repo = "client_golang";
    sha256 = "0arx5z3ahr4i24z31i5af08714wv7p1c2b56sk78rs6lzsdmzc1v";
    propagatedBuildInputs = [
      goautoneg
      net
      protobuf
      prometheus_client_model
      prometheus_common_for_client
      procfs
      beorn7_perks
    ];
    date = "2017-03-07";
  };

  prometheus_client_model = buildFromGitHub {
    version = 2;
    rev = "6f3806018612930941127f2a7c6c453ba2c527d2";
    date = "2017-02-16";
    owner  = "prometheus";
    repo   = "client_model";
    sha256 = "0a9i3ja3pp6sj2v2qshnp12mdgshngwf73p0jmmhn2yddipbngc0";
    buildInputs = [
      protobuf
    ];
  };

  prometheus_common = buildFromGitHub {
    version = 2;
    date = "2017-02-20";
    rev = "49fee292b27bfff7f354ee0f64e1bc4850462edf";
    owner = "prometheus";
    repo = "common";
    sha256 = "03b452lj2cig2ar2ml6giqlqvjg4qbizmxzrdqclil9308d5d2c5";
    buildInputs = [
      logrus
      net
      prometheus_client_model
      protobuf
    ];
    propagatedBuildInputs = [
      golang_protobuf_extensions
      httprouter
      prometheus_client_golang
    ];
  };

  prometheus_common_for_client = buildFromGitHub {
    inherit (prometheus_common) date rev owner repo sha256 version;
    subPackages = [
      "expfmt"
      "model"
      "internal/bitbucket.org/ww/goautoneg"
    ];
    propagatedBuildInputs = [
      golang_protobuf_extensions
      prometheus_client_model
      protobuf
    ];
  };

  procfs = buildFromGitHub {
    version = 2;
    rev = "a1dba9ce8baed984a2495b658c82687f8157b98f";
    date = "2017-02-16";
    owner  = "prometheus";
    repo   = "procfs";
    sha256 = "08dasdwixak8lfv663r626qv8lbp3zyr391s8rjky2ijcn3xyajx";
  };

  properties = buildFromGitHub {
    version = 2;
    owner = "magiconair";
    repo = "properties";
    rev = "b3b15ef068fd0b17ddf408a23669f20811d194d2";
    sha256 = "038hfxgg0c9ddz3bal9i4ijk83ixc9d2al7415z2is2j093m4n13";
    date = "2017-01-13";
  };

  gogo_protobuf = buildFromGitHub {
    version = 2;
    owner = "gogo";
    repo = "protobuf";
    rev = "v0.4";
    sha256 = "17bpsaqg5cqsdfp6da6w14lypjnv7vrdiwd033hbl35m6w6x87xi";
    excludedPackages = "test";
  };

  pty = buildFromGitHub {
    version = 2;
    owner = "kr";
    repo = "pty";
    rev = "v1.0.0";
    sha256 = "1v6xk33d575r598ir2k2zc0myl524ll2mcjkrxbcvg8l5wi7xn0a";
  };

  purell = buildFromGitHub {
    version = 2;
    owner = "PuerkitoBio";
    repo = "purell";
    rev = "v1.1.0";
    sha256 = "0fm0yr5iaxhkg5kkqry6pi0v2hq469x3fwfb1p90afzzav500xsf";
    propagatedBuildInputs = [
      net
      text
      urlesc
    ];
  };

  qart = buildFromGitHub {
    version = 1;
    rev = "0.1";
    owner  = "vitrun";
    repo   = "qart";
    sha256 = "02n7f1j42jp8f4nvg83nswfy6yy0mz2axaygr6kdqwj11n44rdim";
  };

  ql = buildFromGitHub {
    version = 2;
    rev = "v1.1.0";
    owner  = "cznic";
    repo   = "ql";
    sha256 = "0ap19p5zgjrqa31fw87rsi10n0jrh5jydyyqqpbjalkg5qxwd63l";
    propagatedBuildInputs = [
      go4
      b
      exp
      lldb
      strutil
    ];
  };

  rabbit-hole = buildFromGitHub {
    version = 2;
    rev = "v1.2.0";
    owner  = "michaelklishin";
    repo   = "rabbit-hole";
    sha256 = "0xx567gchg8wav04ml8693avdqhn9gp8bn40zi6fv3r6y3q83w7d";
  };

  radius = buildFromGitHub {
    version = 2;
    rev = "8ecfc6afafd1730084ea411c01b3618b093a1ccc";
    date = "2016-12-24";
    owner  = "layeh";
    repo   = "radius";
    sha256 = "1l2s1v5zj9fy1jybq3gv2s5ybjx3r70fhpsmilwrmpk45hjrs4lg";
    goPackagePath = "layeh.com/radius";
  };

  raft_v1 = buildFromGitHub {
    version = 2;
    date = "2016-08-23";
    rev = "5f09c4ffdbcd2a53768e78c47717415de12b6728";
    owner  = "hashicorp";
    repo   = "raft";
    sha256 = "87367c09962cfefc09cfc7c7092099086aa98412f7ad174c85c803790635fa83";
    propagatedBuildInputs = [ armon_go-metrics ugorji_go ];
  };

  raft_v2 = buildFromGitHub {
    version = 2;
    date = "2016-11-09";
    # Use the library-v2-stage-one branch until it is merged
    # into master.
    rev = "aaad9f10266e089bd401e7a6487651a69275641b";
    owner  = "hashicorp";
    repo   = "raft";
    sha256 = "b5a3392c27c22bbd44bc7978ca61f9ce90658caf51bebef7b4db11788d4d5e80";
    propagatedBuildInputs = [
      armon_go-metrics
      logxi
      ugorji_go
    ];
    meta.autoUpdate = false;
  };

  raft-boltdb_v2 = buildFromGitHub {
    version = 2;
    date = "2017-02-09";
    rev = "df631556b57507bd5d0ed4f87468fd93ab025bef";
    owner  = "hashicorp";
    repo   = "raft-boltdb";
    sha256 = "0hhc71684mdz09cm8r9hf9j9m97yzv495ln3kk4cms62pc9yf93b";
    propagatedBuildInputs = [
      bolt
      ugorji_go
      raft_v2
    ];
  };

  raft-boltdb_v1 = buildFromGitHub {
    inherit (raft-boltdb_v2) version rev date owner repo sha256;
    propagatedBuildInputs = [
      bolt
      ugorji_go
      raft_v1
    ];
  };

  ratecounter = buildFromGitHub {
    version = 2;
    owner = "paulbellamy";
    repo = "ratecounter";
    rev = "348ad3bf08f04afb2b4f645a6587c9372c06a684";
    sha256 = "032aj935b9x20czahyn9li2yrbd7imx8lq16c5ci450q26s7ji8n";
    date = "2017-02-06";
  };

  ratelimit = buildFromGitHub {
    version = 2;
    rev = "acf38b000a03e4ab89e40f20f1e548f4e6ac7f72";
    date = "2017-03-14";
    owner  = "juju";
    repo   = "ratelimit";
    sha256 = "04bir651ac5b0zgbl5hlhdxapsrz2l1xw1i4qncl5nnnbms3xysz";
  };

  raw = buildFromGitHub {
    version = 2;
    rev = "4ad22e6f1008c9f1100cb970699da776b45be83c";
    owner  = "feyeleanor";
    repo   = "raw";
    sha256 = "0zb5qwrm7x7p79wzi4lbr4px9q6qm5zz9xwjakf2wb1cnyxim93w";
    date = "2016-12-30";
  };

  rclone = buildFromGitHub {
    version = 2;
    owner = "ncw";
    repo = "rclone";
    rev = "986a2851bf31b770e3c432bb9136b7965a49da83";
    sha256 = "1rrivhbywm7vkr58kdxlaana7izn9yrbnajiglz9vcr2wal27w0c";
    propagatedBuildInputs = [
      aws-sdk-go
      cobra
      crypto
      dropbox
      eme
      errors
      ewma
      fs
      fuse
      go-acd
      goconfig
      google-api-go-client
      oauth2
      open-golang
      pflag
      sftp
      swift
      sys
      tb
      testify
    ];
    meta.useUnstable = true;
    date = "2017-03-15";
  };

  cupcake_rdb = buildFromGitHub {
    version = 2;
    date = "2016-08-25";
    rev = "43ba34106c765f2111c0dc7b74cdf8ee437411e0";
    owner = "cupcake";
    repo = "rdb";
    sha256 = "0sqs6l4i5f2pd4i719aijbyjhdss8zqvk3b9195d0ljx2di9y84i";
  };

  siddontang_rdb = buildFromGitHub {
    version = 1;
    date = "2015-03-07";
    rev = "fc89ed2e418d27e3ea76e708e54276d2b44ae9cf";
    owner = "siddontang";
    repo = "rdb";
    sha256 = "1rf7dcxymdqjxjld6mb0fpsprnf342y1mr6m93fr073m5k5ij6kq";
    propagatedBuildInputs = [
      cupcake_rdb
    ];
  };

  redigo = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "redigo";
    date = "2016-07-23";
    rev = "5e2117cd32d677a36dcd8c9c83776a065555653b";
    sha256 = "3991316f879ff46e423e73f4006b26b620a0a98397fd649e0d667ff7cd35093a";
    meta.useUnstable = true;
  };

  redis_v2 = buildFromGitHub {
    version = 1;
    rev = "v2.3.2";
    owner  = "go-redis";
    repo   = "redis";
    sha256 = "211e91fd3b5e120ca073aecb8088ba513012ab4513b13934890aaa6791b2923b";
    goPackagePath = "gopkg.in/redis.v2";
    propagatedBuildInputs = [
      bufio_v1
    ];
    meta.autoUpdate = false;
  };

  reedsolomon = buildFromGitHub {
    version = 2;
    owner = "klauspost";
    repo = "reedsolomon";
    date = "2017-02-19";
    rev = "5abf0ee302ccf4834e84f63ff74eca3e8b88e4e2";
    sha256 = "1r6yk16id1nk1qmpn21g6cw4ipy68j2711mc8ysd39js3pginff2";
    propagatedBuildInputs = [
      cpuid
    ];
    meta.useUnstable = true;
  };

  reflectwalk = buildFromGitHub {
    version = 2;
    date = "2017-01-10";
    rev = "417edcfd99a4d472c262e58f22b4bfe97580f03e";
    owner  = "mitchellh";
    repo   = "reflectwalk";
    sha256 = "0kcig5x8bv7hzzyy67g0wsm8akbl6kn8l6r0sdy1yc7jybsnbizq";
  };

  resumable = buildFromGitHub {
    version = 2;
    owner = "stevvooe";
    repo = "resumable";
    date = "2016-09-23";
    rev = "f714bdb9b57a7162bc99aaa0b68a338c0da1c392";
    sha256 = "18jm8ssihjl5flqhahqcvz2s5cifgcl6f7ms23xl70zkls6j0l3a";
  };

  roaring = buildFromGitHub {
    version = 2;
    rev = "v0.3.4";
    owner  = "RoaringBitmap";
    repo   = "roaring";
    sha256 = "1y42gz3r81d7w2n7xvyfvr74lx84ziw63dkviz48xvx0ivyw33hw";
    propagatedBuildInputs = [
      go-unsnap-stream
      msgp
    ];
  };

  rollinghash = buildFromGitHub {
    version = 2;
    rev = "v2.0.2";
    owner  = "chmduquesne";
    repo   = "rollinghash";
    sha256 = "1krn9jjsjl8c1w09p8qyn3hfrgdbc3a465jzv6a6399fylxhgipf";
  };

  roundtrip = buildFromGitHub {
    version = 2;
    owner = "gravitational";
    repo = "roundtrip";
    date = "2016-12-09";
    rev = "41588aab7963b48601122368b5c893f13c5c4608";
    sha256 = "1436mpzymknd353nzs0gv3mlw7x6vjj458vxzg0hrldkwvrz86g4";
    propagatedBuildInputs = [
      trace
    ];
  };

  rpc = buildFromGitHub {
    version = 2;
    owner = "gorilla";
    repo = "rpc";
    date = "2016-09-24";
    rev = "22c016f3df3febe0c1f6727598b6389507e03a18";
    sha256 = "0ny16dm38zkd7j6v11vayfx8j5q6bmfhsl3hj855f79c90i4bkaq";
  };

  rsc = buildFromGitHub {
    version = 2;
    owner = "mdp";
    repo = "rsc";
    date = "2016-01-31";
    rev = "90f07065088deccf50b28eb37c93dad3078c0f3c";
    sha256 = "0nibwihq09m5chhryi20dcjg9bbk4yy0x2asz0c8ln73hrcijdm1";
    buildInputs = [
      pkgs.qrencode
    ];
  };

  runc = buildFromGitHub {
    version = 1;
    rev = "v1.0.0-rc1";
    owner = "opencontainers";
    repo = "runc";
    sha256 = "75b869ab4d184c870de0c203d5466d846c279652ba412f35af7ddeca6835ff5c";
    propagatedBuildInputs = [
      go-units
      logrus
      docker_for_runc
      go-systemd
      protobuf
      gocapability
      netlink
      urfave_cli
      runtime-spec
    ];
    meta.autoUpdate = false;
  };

  runtime-spec = buildFromGitHub {
    version = 1;
    rev = "v1.0.0-rc1";
    owner = "opencontainers";
    repo = "runtime-spec";
    sha256 = "1c112fe3b731835f244a6d7030de25e371ba4f783cdff0ae53e471908a117162";
    buildInputs = [
      gojsonschema
    ];
    meta.autoUpdate = false;
  };

  sanitized-anchor-name = buildFromGitHub {
    version = 2;
    owner = "shurcooL";
    repo = "sanitized_anchor_name";
    rev = "1dba4b3954bc059efc3991ec364f9f9a35f597d2";
    date = "2016-09-17";
    sha256 = "10gr6fqd9v4q1jfqms4v797a9769x3p9gvrzv3a65ngdqyfnikk5";
  };

  scada-client = buildFromGitHub {
    version = 1;
    date = "2016-06-01";
    rev = "6e896784f66f82cdc6f17e00052db91699dc277d";
    owner  = "hashicorp";
    repo   = "scada-client";
    sha256 = "1by4kyd2hrrrghwj7snh9p8fdlqka24q9yr6nyja2acs2zpjgh7a";
    buildInputs = [ armon_go-metrics net-rpc-msgpackrpc yamux ];
  };

  seed = buildFromGitHub {
    version = 2;
    rev = "e2103e2c35297fb7e17febb81e49b312087a2372";
    owner = "sean-";
    repo = "seed";
    sha256 = "0hnkw8zjiqkyffxfbgh1020dgy0vxzad1kby0kkm8ld3i5g0aq7a";
    date = "2017-03-13";
  };

  semver = buildFromGitHub {
    version = 2;
    rev = "v3.5.0";
    owner = "blang";
    repo = "semver";
    sha256 = "1maxa24la1y37dgngaw7ar7fykcxzix54xy60jhnfap8p0yrzs74";
  };

  serf = buildFromGitHub {
    version = 2;
    rev = "v0.8.1";
    owner  = "hashicorp";
    repo   = "serf";
    sha256 = "1afffipv2msa5062jlb52glmfsz9qh2zp58n847190j7b9mm93j9";

    buildInputs = [
      net circbuf armon_go-metrics ugorji_go go-syslog logutils mdns memberlist
      dns mitchellh_cli mapstructure columnize
    ];
  };

  session = buildFromGitHub {
    version = 2;
    rev = "b8a2b5ef7fb4c91c1c8ca23e2a52e29a4bcbb22f";
    owner  = "go-macaron";
    repo   = "session";
    sha256 = "10xckq8mkw4d6764g020aa8qzp03i6ywd13pmj921y7ik467q3za";
    date = "2016-11-21";
    propagatedBuildInputs = [
      gomemcache
      go-couchbase
      com
      ledisdb
      macaron_v1
      mysql
      nodb
      pq
      redis_v2
    ];
  };

  sets = buildFromGitHub {
    version = 1;
    rev = "6c54cb57ea406ff6354256a4847e37298194478f";
    owner  = "feyeleanor";
    repo   = "sets";
    sha256 = "11gg27znzsay5pn9wp7rl427v8bl1rsncyk8nilpsbpwfbz7q7vm";
    date = "2013-02-27";
    propagatedBuildInputs = [
      slices
    ];
  };

  sftp = buildFromGitHub {
    version = 2;
    owner = "pkg";
    repo = "sftp";
    rev = "62d5779aab08c3e7a61d44192871e500ac0f3319";
    date = "2017-03-15";
    sha256 = "1k1bypdl5pka8libwpjrrq78wggciswhnbc2vbhy2wbs1rlfyag7";
    propagatedBuildInputs = [
      crypto
      errors
      fs
    ];
  };

  sha256-simd = buildFromGitHub {
    version = 2;
    owner = "minio";
    repo = "sha256-simd";
    date = "2017-03-04";
    rev = "187c585ea0bb8b4eefbc39f13427ef728668101e";
    sha256 = "0gsb85zn09q0dwmg47h67ivpz6h8vf6y73vb5v1486n3v5zn7ils";
  };

  skyring-common = buildFromGitHub {
    version = 2;
    owner = "skyrings";
    repo = "skyring-common";
    date = "2016-09-29";
    rev = "d1c0bb1cbd5ed8438be1385c85c4f494608cde1e";
    sha256 = "0wr3bw55daf8ryz46hviwvs1wz1l2c6x3rrccr70gllg74lg1wd5";
    buildInputs = [
      go-logging
      go-python
      gorequest
      graphite-golang
      influxdb
      mgo_v2
    ];
    postPatch = /* go-python now uses float64 */ ''
      sed -i tools/gopy/gopy.go \
        -e 's/python.PyFloat_FromDouble(f32)/python.PyFloat_FromDouble(f64)/'
    '';
  };

  slices = buildFromGitHub {
    version = 2;
    rev = "145c47818f5f4e3ab04935822b3bd440e54ffc45";
    owner  = "feyeleanor";
    repo   = "slices";
    sha256 = "1bgzczwymd0498gk9ikrdfw32s5cir9n1skrnz0jh5qwkxdljm9n";
    date = "2016-12-30";
    propagatedBuildInputs = [
      raw
    ];
  };

  slug = buildFromGitHub {
    version = 2;
    rev = "v1.0.3";
    owner  = "gosimple";
    repo   = "slug";
    sha256 = "1vb7bwls06fqpxnkwlsb0lbq0nic2hsd5dpf9g94h59avgnxilrz";
    propagatedBuildInputs = [
      com
      macaron_v1
      #unidecode
    ];
  };

  sortutil = buildFromGitHub {
    version = 1;
    date = "2015-06-17";
    rev = "4c7342852e65c2088c981288f2c5610d10b9f7f4";
    owner = "cznic";
    repo = "sortutil";
    sha256 = "11iykyi1d7vjmi7778chwbl86j6s1742vnd4k7n1rvrg7kq558xq";
  };

  spacelog = buildFromGitHub {
    version = 2;
    date = "2017-01-06";
    rev = "16604ed16156d8634877b208e8acc9279f399777";
    owner = "spacemonkeygo";
    repo = "spacelog";
    sha256 = "0rcqgs6n9hklscl0ay9wk36yknd4sim3hxkpii3zcf3sis2s1bh2";
    buildInputs = [ flagfile ];
  };

  speakeasy = buildFromGitHub {
    version = 2;
    date = "2016-10-13";
    rev = "675b82c74c0ed12283ee81ba8a534c8982c07b85";
    owner = "bgentry";
    repo = "speakeasy";
    sha256 = "0k0mydv8dn6dwia05v5wz4h20baynrd0xgsrmwp496yhwq8yagkz";
  };

  srslog = buildFromGitHub {
    version = 2;
    rev = "a974ba6f7fb527d2ddc73ee9c05d3e2ccc0af0dc";
    date = "2017-01-06";
    owner  = "RackSec";
    repo   = "srslog";
    sha256 = "14714h9wkmb2i2flbljpmsa3mjvi27jkqwxc3rz1q67zbkv7vd1w";
  };

  stack = buildFromGitHub {
    version = 1;
    rev = "v1.5.2";
    owner = "go-stack";
    repo = "stack";
    sha256 = "0c75y18wb45n61ppgzb52k59p52g7221zcm435pz3ca0yhjz02q6";
  };

  stathat = buildFromGitHub {
    version = 1;
    date = "2016-07-15";
    rev = "74669b9f388d9d788c97399a0824adbfee78400e";
    owner = "stathat";
    repo = "go";
    sha256 = "19aki04z76qzgdr8l3zlz904mkalspfa46cja2fdjy70sfvfjdp1";
  };

  statik = buildFromGitHub {
    version = 2;
    owner = "rakyll";
    repo = "statik";
    date = "2017-01-06";
    rev = "a2b9c3533409cccb4bb188346bcfc789629a424d";
    sha256 = "1bz6sylgynac7wvh3f9m4d7mzbrm5msgdjra4359v5y1mqx23777";
    postPatch = /* Remove recursive import of itself */ ''
      sed -i example/main.go \
        -e '/"github.com\/rakyll\/statik\/example\/statik"/d'
    '';
  };

  structs = buildFromGitHub {
    version = 2;
    date = "2017-01-03";
    rev = "a720dfa8df582c51dee1b36feabb906bde1588bd";
    owner  = "fatih";
    repo   = "structs";
    sha256 = "11wryq1rk3b0ks5zy7fjsyml4clkipzwbzsywpjqlw39zfbcad0j";
  };

  stump = buildFromGitHub {
    version = 1;
    date = "2016-06-11";
    rev = "206f8f13aae1697a6fc1f4a55799faf955971fc5";
    owner = "whyrusleeping";
    repo = "stump";
    sha256 = "0qmchkr29rzscc148aw2vb2qf5dma2dka0ys96cx5fxa4p516d3i";
  };

  strutil = buildFromGitHub {
    version = 2;
    date = "2017-01-31";
    rev = "43a89592ed56c227c7fdb1fcaf7d1d08be02ec54";
    owner = "cznic";
    repo = "strutil";
    sha256 = "16lv9wc7b8371b08n5hr6mlnllnj60is7mhcpbnk247g25160wp0";
  };

  suture = buildFromGitHub {
    version = 2;
    rev = "v2.0.1";
    owner  = "thejerf";
    repo   = "suture";
    sha256 = "0jhzl8ihadxyw76h58ijwy73nh390knhkxlgnvfnsfwgf7irghd0";
  };

  swift = buildFromGitHub {
    version = 2;
    rev = "8e9b10220613abdbc2896808ee6b43e411a4fa6c";
    owner  = "ncw";
    repo   = "swift";
    sha256 = "0rp54ghj07dvb6501kvhijq8cnl72k6m99baxqk7jjda8fd2kk0r";
    date = "2017-03-15";
  };

  anacrolix_sync = buildFromGitHub {
    version = 2;
    rev = "d29d95568d362a0008c1ffbaea39a3449ea67509";
    owner  = "anacrolix";
    repo   = "sync";
    sha256 = "1bfwg17qh4s91rzd4wgczmvi4c67kfdh71dr8qnbwr76qavybl10";
    date = "2016-12-14";
    buildInputs = [
      missinggo
    ];
  };

  syncthing = buildFromGitHub rec {
    version = 2;
    rev = "v0.14.24";
    owner = "syncthing";
    repo = "syncthing";
    sha256 = "0a6z3c28znl4h4xi2wjlrj5ncy5al10fg5xpfv15a2jc4np6zy2b";
    buildFlags = [ "-tags noupgrade" ];
    buildInputs = [
      go-lz4 du luhn xdr snappy ratelimit osext
      goleveldb suture qart crypto net text rcrowley_go-metrics
      go-nat-pmp glob gateway ql groupcache pq gogo_protobuf
      geoip2-golang sha256-simd go-deadlock AudriusButkevicius_cli
      time rollinghash
    ];
    postPatch = ''
      # Mostly a cosmetic change
      sed -i 's,unknown-dev,${rev},g' cmd/syncthing/main.go
    '';
    preBuild = ''
      pushd go/src/$goPackagePath
      go run script/genassets.go gui > lib/auto/gui.files.go
      popd
    '';
  };

  syncthing-lib = buildFromGitHub {
    inherit (syncthing) rev owner repo sha256 version;
    subPackages = [
      "lib/sync"
      "lib/logger"
      "lib/protocol"
      "lib/osutil"
      "lib/tlsutil"
      "lib/dialer"
      "lib/relay/client"
      "lib/relay/protocol"
    ];
    propagatedBuildInputs = [ go-lz4 luhn xdr text suture du net ];
  };

  syslogparser = buildFromGitHub {
    version = 1;
    rev = "ff71fe7a7d5279df4b964b31f7ee4adf117277f6";
    date = "2015-07-17";
    owner  = "jeromer";
    repo   = "syslogparser";
    sha256 = "1x1nq7kyvmfl019d3rlwx9nqlqwvc87376mq3xcfb7f5vxlmz9y5";
  };

  tablewriter = buildFromGitHub {
    version = 2;
    rev = "febf2d34b54a69ce7530036c7503b1c9fbfdf0bb";
    date = "2017-01-28";
    owner  = "olekukonko";
    repo   = "tablewriter";
    sha256 = "0wava2c1by6cdrm0kxf1ldkayip6sivlwankgrhiw6sj645w5km9";
    propagatedBuildInputs = [
      go-runewidth
    ];
  };

  tagflag = buildFromGitHub {
    version = 1;
    rev = "e7497e81ffa475caf0fc24e999eb29edc0335040";
    date = "2016-06-15";
    owner  = "anacrolix";
    repo   = "tagflag";
    sha256 = "3515c691c6ecc867e3e539048b9ca331ccb654c1890cde460748b9b3043eba5a";
    propagatedBuildInputs = [
      go-humanize
      missinggo_lib
      xstrings
    ];
    meta.autoUpdate = false;
  };

  tail = buildFromGitHub {
    version = 2;
    rev = "faf842bde7ed83bbc3c65a2c454fae39bc29a95f";
    owner  = "hpcloud";
    repo   = "tail";
    sha256 = "1mxqwvslhjkpn1qfbzmca5p3r75jz2myi95cq76cdd1w9prigihb";
    propagatedBuildInputs = [
      fsnotify_v1
      tomb_v1
    ];
    date = "2017-02-06";
  };

  tar-split = buildFromGitHub {
    version = 2;
    owner = "vbatts";
    repo = "tar-split";
    rev = "bd4c5d64c3e9297f410025a3b1bd0c58f659e721";
    date = "2016-09-26";
    sha256 = "e317e4bb73fab3e03ff34b96a861fec72e716f61fc01343876131e50dfacc402";
    propagatedBuildInputs = [
      urfave_cli
      logrus
    ];
  };

  tar-utils = buildFromGitHub {
    version = 1;
    rev = "beab27159606f5a7c978268dd1c3b12a0f1de8a7";
    date = "2016-03-22";
    owner  = "whyrusleeping";
    repo   = "tar-utils";
    sha256 = "0p0cmk30b22bgfv4m29nnk2359frzzgin2djhysrqznw3wjpn3nz";
  };

  tb = buildFromGitHub {
    version = 2;
    owner = "tsenart";
    repo = "tb";
    rev = "19f4c3d79d2bd67d0911b2e310b999eeea4454c1";
    date = "2015-12-08";
    sha256 = "fb8fb335f10f48e641b3a6abcfe3eb20737cfb5a71aa6b6dbd3399aaedcb8fad";
  };

  teleport = buildFromGitHub {
    version = 2;
    rev = "v1.3.2";
    owner = "gravitational";
    repo = "teleport";
    sha256 = "04zqah87vwpmw3x7g5k0d4890ddmfkkvsx43xfncxlsdsf73f0fx";
    buildInputs = [
      bolt
      configure
      docker_for_teleport
      etcd_client
      go-oidc
      goterm
      hotp
      httprouter
      gravitational_kingpin
      lemma
      osext
      oxy
      pty
      roundtrip
      trace
      gravitational_ttlmap
      u2f
      pborman_uuid
      yaml_v2
    ];
    excludedPackages = "\\(test\\|suite\\)";
  };

  template = buildFromGitHub {
    version = 1;
    rev = "a0175ee3bccc567396460bf5acd36800cb10c49c";
    owner = "alecthomas";
    repo = "template";
    sha256 = "10albmv2bdrrgzzqh1rlr88zr2vvrabvzv59m15wazwx39mqzd7p";
    date = "2016-04-05";
  };

  termbox-go = buildFromGitHub {
    version = 2;
    rev = "91bae1bb5fa9ee504905ecbe7043fa30e92feaa3";
    date = "2017-03-01";
    owner = "nsf";
    repo = "termbox-go";
    sha256 = "171gkx2dcvk6zlwbfi7v3rk69fx01y389ls0gykn8vi8mmwr05wx";
    propagatedBuildInputs = [
      go-runewidth
    ];
  };

  testify = buildFromGitHub {
    version = 2;
    rev = "v1.1.4";
    owner = "stretchr";
    repo = "testify";
    sha256 = "0n3z8225px7rylkwz6rvf48ykrh591a7p8gc27a2dh2zskny5qsz";
    propagatedBuildInputs = [
      go-difflib
      go-spew
      objx
    ];
  };

  timecache = buildFromGitHub {
    version = 2;
    rev = "cfcb2f1abfee846c430233aef0b630a946e0a5a6";
    date = "2016-09-10";
    owner  = "whyrusleeping";
    repo   = "timecache";
    sha256 = "0w65wbpf0fzxdj2f1d8km9hg91yp9519agdgb6v6jnxnjvi7d43j";
  };

  timetools = buildFromGitHub {
    version = 2;
    rev = "fd192d755b00c968d312d23f521eb0cdc6f66bd0";
    date = "2015-05-05";
    owner = "mailgun";
    repo = "timetools";
    sha256 = "0ja8k6b1gp99jifm9ljkwfrqsn00c87pz7alafmy34sc0xlxdcy9";
    propagatedBuildInputs = [
      mgo_v2
    ];
  };

  tokenbucket = buildFromGitHub {
    version = 1;
    rev = "c5a927568de7aad8a58127d80bcd36ca4e71e454";
    date = "2013-12-01";
    owner = "ChimeraCoder";
    repo = "tokenbucket";
    sha256 = "11zasaakzh4fzzmmiyfq5mjqm5md5bmznbhynvpggmhkqfbc28gz";
  };

  tomb_v2 = buildFromGitHub {
    version = 2;
    date = "2016-12-08";
    rev = "d5d1b5820637886def9eef33e03a27a9f166942c";
    owner = "go-tomb";
    repo = "tomb";
    sha256 = "0azb4hkv41wl750wapl4jbnpvn1jg54z1clcnqvvs84rh75ywqj1";
    goPackagePath = "gopkg.in/tomb.v2";
  };

  tomb_v1 = buildFromGitHub {
    version = 1;
    date = "2014-10-24";
    rev = "dd632973f1e7218eb1089048e0798ec9ae7dceb8";
    owner = "go-tomb";
    repo = "tomb";
    sha256 = "1gn3f185fihpd5ccr04bp2iprj75jyx803a6i9b3avbcmn24w7xa";
    goPackagePath = "gopkg.in/tomb.v1";
  };

  toml = buildFromGitHub {
    version = 2;
    owner = "BurntSushi";
    repo = "toml";
    rev = "e643e9ef00b049d75de26e61109c5ea01885cd21";
    sha256 = "0crb06204aaxcfpd57a4wyi4s6mdxsx9jmd92npc16bhxvlnzh4r";
    goPackageAliases = [ "github.com/burntsushi/toml" ];
    date = "2017-03-07";
  };

  trace = buildFromGitHub {
    version = 2;
    owner = "gravitational";
    repo = "trace";
    rev = "adf21be7e383c8626273cded2b3dc12d4fd7f449";
    sha256 = "10rjnz008hd69jdsvkqj3n9bap6vxh5lj266z90lgw1mxp8mdh3c";
    date = "2017-02-24";
    propagatedBuildInputs = [
      clockwork
      grpc
      logrus
      net
    ];
  };

  gravitational_ttlmap = buildFromGitHub {
    version = 2;
    owner = "gravitational";
    repo = "ttlmap";
    rev = "348cf76cace4d93fdacc38dfdaa2306f4f0e9c16";
    sha256 = "00z54zc4g5h8qdwdqhkycyjl705sg7bb1iilkmrdh04n602wdwr0";
    date = "2016-04-07";
    propagatedBuildInputs = [
      clockwork
      minheap
    ];
  };

  mailgun_ttlmap = buildFromGitHub {
    version = 2;
    owner = "mailgun";
    repo = "ttlmap";
    rev = "8210f93bcb6393a9f36a22ac02fb3c4f53289850";
    sha256 = "1ir31h07xmjwkn0mnx3hkp6mj0x1qa58ling09czxqjqwm263ab3";
    date = "2016-08-25";
    propagatedBuildInputs = [
      minheap
      timetools
    ];
  };

  u2f = buildFromGitHub {
    version = 2;
    rev = "eb799ce68da4150b16ff5d0c89a24e2a2ad993d8";
    owner = "tstranex";
    repo = "u2f";
    sha256 = "8b2e6912aeced8aa055feedbbe3de2ef065666b81181eb1c9e2826cc6d37f81f";
    date = "2016-05-08";
    meta.autoUpdate = false;
  };

  units = buildFromGitHub {
    version = 1;
    rev = "2efee857e7cfd4f3d0138cc3cbb1b4966962b93a";
    owner = "alecthomas";
    repo = "units";
    sha256 = "1jj055kgx6mfx5zw263ci70axk3z5006db74dqhcilxwk1a2ga23";
    date = "2015-10-22";
  };

  urlesc = buildFromGitHub {
    version = 2;
    owner = "PuerkitoBio";
    repo = "urlesc";
    rev = "5bd2802263f21d8788851d5305584c82a5c75d7e";
    sate = "2015-02-08";
    sha256 = "09qypmzsr71ikqinffr5ryg4b38kclssrfnnh8n3rv0plcx8i5rr";
    date = "2016-07-26";
  };

  usage-client = buildFromGitHub {
    version = 2;
    owner = "influxdata";
    repo = "usage-client";
    date = "2016-08-29";
    rev = "6d3895376368aa52a3a81d2a16e90f0f52371967";
    sha256 = "37a9a3330c2a7fac370ccb7117c681dd6fafeef57d327b3071ec13a279fa7996";
  };

  utp = buildFromGitHub {
    version = 2;
    rev = "a45fe7814045a407e5878527cd8cea508171dd3c";
    owner  = "anacrolix";
    repo   = "utp";
    sha256 = "0qaymcsa8pg753b88zz8gw1414w8kw36xkdf3nnssk5wckq33zz2";
    date = "2017-03-01";
    propagatedBuildInputs = [
      envpprof
      missinggo
      anacrolix_sync
    ];
  };

  pborman_uuid = buildFromGitHub {
    version = 2;
    rev = "1b00554d822231195d1babd97ff4a781231955c9";
    owner = "pborman";
    repo = "uuid";
    sha256 = "0frx4d0459axn4s30ipdagfr28xxz491fxl01igg3g03z7flkf5p";
    date = "2017-01-12";
  };

  satori_uuid = buildFromGitHub {
    version = 1;
    rev = "v1.1.0";
    owner = "satori";
    repo = "uuid";
    sha256 = "19xzrdm1x07s7siavy8ssilhzyn89kqqpprmql1vsbplzljl4zgl";
  };

  vault = buildFromGitHub {
    version = 2;
    rev = "v0.6.5";
    owner = "hashicorp";
    repo = "vault";
    sha256 = "1bccm5fm1hi5bf0a21617hsnglrix4x370l7pf0sx9ga3f4f6j89";

    nativeBuildInputs = [
      pkgs.protobuf-cpp
      protobuf.bin
    ];

    buildInputs = [
      azure-sdk-for-go
      armon_go-metrics
      go-radix
      govalidator
      aws-sdk-go
      speakeasy
      etcd_client
      go-mssqldb
      duo_api_golang
      structs
      pkcs7
      yaml
      ini_v1
      ldap
      mysql
      gocql
      protobuf
      snappy
      go-github
      go-querystring
      hailocab_go-hostpool
      consul_api
      errwrap
      go-cleanhttp
      ugorji_go
      go-multierror
      go-rootcerts
      go-syslog
      hashicorp-go-uuid
      golang-lru
      hcl
      logutils
      net-rpc-msgpackrpc
      scada-client
      serf
      yamux
      go-jmespath
      pq
      go-isatty
      rabbit-hole
      mitchellh_cli
      copystructure
      go-homedir
      mapstructure
      reflectwalk
      swift
      columnize
      go-zookeeper
      crypto
      net
      oauth2
      sys
      appengine
      asn1-ber
      mgo_v2
      grpc
      pester
      logxi
      go-colorable
      go-crypto
      jsonx
      google-cloud-go
      radius
      go-okta
      go-grpc-prometheus
      go-semver
      etcd_for_vault
      jose
    ];

    # Regerate protos
    preBuild = ''
      srcDir="$(pwd)"/go/src
      pushd go/src/$goPackagePath >/dev/null
      find . -name \*pb.go -delete
      for file in $(find . -name \*.proto | sort | uniq); do
        pushd "$(dirname "$file")" > /dev/null
        echo "Regenerating protobuf: $file" >&2
        protoc -I "$srcDir" -I "$srcDir/$goPackagePath" -I . --go_out=plugins=grpc:. "$(basename "$file")"
        popd >/dev/null
      done
      popd >/dev/null
    '';
  };

  vault_api = buildFromGitHub {
    inherit (vault) rev owner repo sha256 version;
    subPackages = [
      "api"
      "helper/compressutil"
      "helper/jsonutil"
    ];
    propagatedBuildInputs = [
      hcl
      structs
      go-cleanhttp
      go-multierror
      go-rootcerts
      mapstructure
      pester
    ];
  };

  viper = buildFromGitHub {
    version = 2;
    owner = "spf13";
    repo = "viper";
    rev = "84f94806c67f59dd7ae87bc5351f7a9c94a4558d";
    date = "2017-03-15";
    sha256 = "0zw9vwf7hk4xy0lymd7yqkgycbm3p3mdmd8bvxmdjfjkvkhfmb6m";
    buildInputs = [
      crypt
      pflag
    ];
    propagatedBuildInputs = [
      afero
      cast
      fsnotify
      go-toml
      hcl
      jwalterweatherman
      mapstructure
      properties
      #toml
      yaml_v2
    ];
  };

  vultr = buildFromGitHub {
    version = 2;
    rev = "1.12.0";
    owner  = "JamesClonk";
    repo   = "vultr";
    sha256 = "1wnmdsik9cd1g47aa0w2k2c3cdi2b99paaj3wg4i3b63yrn76gm1";
    propagatedBuildInputs = [
      mow-cli
      tokenbucket
      ratelimit
    ];
  };

  websocket = buildFromGitHub {
    version = 2;
    rev = "v1.1.0";
    owner  = "gorilla";
    repo   = "websocket";
    sha256 = "0qrvpvjnsi9bash1x8fhnj1fnpgydxjvys2adbkih2vys20a3hch";
  };

  wmi = buildFromGitHub {
    version = 1;
    rev = "f3e2bae1e0cb5aef83e319133eabfee30013a4a5";
    owner = "StackExchange";
    repo = "wmi";
    sha256 = "1paiis0l4adsq68v5p4mw7g7vv39j06fawbaph1d3cglzhkvsk7q";
    date = "2015-05-20";
  };

  yaml = buildFromGitHub {
    version = 2;
    rev = "04f313413ffd65ce25f2541bfd2b2ceec5c0908c";
    date = "2016-12-06";
    owner = "ghodss";
    repo = "yaml";
    sha256 = "107j4pq74xmmmvah32d7nxlmj7wkcg6w5pkk4wm279mpkarb7q60";
    propagatedBuildInputs = [
      yaml_v2
    ];
  };

  yaml_v2 = buildFromGitHub {
    version = 2;
    rev = "a3f3340b5840cee44f372bddb5880fcbc419b46a";
    date = "2017-02-08";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "1dsj1hwhnkqagafh32mcnjf5pgv91gvxbqgm1p63drm0igqzzl9c";
    goPackagePath = "gopkg.in/yaml.v2";
  };

  yaml_v1 = buildFromGitHub {
    version = 1;
    rev = "9f9df34309c04878acc86042b16630b0f696e1de";
    date = "2014-09-24";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "128xs9pdz042hxl28fi2gdrz5ny0h34xzkxk5rxi9mb5mq46w8ys";
    goPackagePath = "gopkg.in/yaml.v1";
  };

  yamux = buildFromGitHub {
    version = 1;
    date = "2016-07-20";
    rev = "d1caa6c97c9fc1cc9e83bbe34d0603f9ff0ce8bd";
    owner  = "hashicorp";
    repo   = "yamux";
    sha256 = "19frd5lldxrjybdj8a3al3bq2wn0bghrnldxvrydr5ysf782qalw";
  };

  xdr = buildFromGitHub {
    version = 2;
    rev = "08e072f9cb164f943a92eb59f90f3abc64ac6e8f";
    owner  = "calmh";
    repo   = "xdr";
    sha256 = "01dmdnxvrj40s65w729pjdjh6bf18lm3k57b1mx0z3xql00xsc4k";
    date = "2017-01-04";
  };

  xhandler = buildFromGitHub {
    version = 2;
    owner = "rs";
    repo = "xhandler";
    date = "2016-06-18";
    rev = "ed27b6fd65218132ee50cd95f38474a3d8a2cd12";
    sha256 = "14e5d9f09a28bff8a9687e2f1d2250e034852b2dd784eb8c1ee04fac676f9357";
    propagatedBuildInputs = [
      net
    ];
  };

  xorm = buildFromGitHub {
    version = 2;
    rev = "v0.5.8";
    owner  = "go-xorm";
    repo   = "xorm";
    sha256 = "17rv8g52rq2cc8d1mfm2xj28wq78frs1jwj90fk6ygyzm4zavrhl";
    propagatedBuildInputs = [
      core
    ];
  };

  xstrings = buildFromGitHub {
    version = 1;
    rev = "3959339b333561bf62a38b424fd41517c2c90f40";
    date = "2015-11-30";
    owner  = "huandu";
    repo   = "xstrings";
    sha256 = "16l1cqpqsgipa4c6q55n8vlnpg9kbylkx1ix8hsszdikj25mcig1";
  };

  zappy = buildFromGitHub {
    version = 1;
    date = "2016-07-23";
    rev = "2533cb5b45cc6c07421468ce262899ddc9d53fb7";
    owner = "cznic";
    repo = "zappy";
    sha256 = "1fn4kqiggz6b5srkqhn37nwsi381x6hx3n83cbg0fxcb7zb3b6xl";
    buildInputs = [
      mathutil
    ];
    extraSrcs = [
      {
        inherit (internal)
          goPackagePath
          src;
      }
    ];
  };
}; in self
