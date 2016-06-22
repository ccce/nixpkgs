/* This file defines the composition for Go packages. */

{ stdenv
, buildGoPackage
, fetchbzr
, fetchFromBitbucket
, fetchFromGitHub
, fetchgit
, fetchhg
, fetchTritonPatch
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

      unpackDir="$TMPDIR/src"
      mkdir "$unpackDir"
      cd "$unpackDir"
      unpackFile "${src}"
      cd *

      mtime=$(find . -type f -print0 | xargs -0 -r stat -c '%Y' | sort -n | tail -n 1)
      if [ "$(( $(date -u '+%s') - 600 ))" -lt "$mtime" ]; then
        str="The newest file is too close to the current date (10 minutes):\n"
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
      tar --sort=name --owner=0 --group=0 --numeric-owner \
        --no-acls --no-selinux --no-xattrs \
        --mode=go=rX,u+rw,a-s \
        --clamp-mtime --mtime=@$mtime \
        -c . | brotli --quality 6 --output "$out"
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
            inherit rev owner repo sha256;
          };
        in if gxSha256 == null then
          src'
        else
          fetchGxPackage { src = src'; sha256 = gxSha256; };
      })
  );

  buildFromGoogle = { rev, date ? null, repo, sha256, name ? repo, goPackagePath ? "google.golang.org/${repo}", ... }@args: buildGoPackage (args // (let
      name' = "${name}-${if date != null then date else if builtins.stringLength rev != 40 then rev else stdenv.lib.strings.substring 0 7 rev}";
    in {
      inherit rev goPackagePath;
      name = name';
      src  = fetchzip {
        name = name';
        url = "https://code.googlesource.com/go${repo}/+archive/${rev}.tar.gz";
        inherit sha256;
        stripRoot = false;
        purgeTimestamps = true;
      };
    })
  );

  ## OFFICIAL GO PACKAGES

  appengine = buildFromGitHub {
    rev = "267c27e7492265b84fc6719503b14a1e17975d79";
    date = "2016-06-20";
    owner = "golang";
    repo = "appengine";
    sha256 = "0i121rgyw3sbybg6qbhrr7nrvlka221a990zf64n4ghmdzgm5kw4";
    goPackagePath = "google.golang.org/appengine";
    propagatedBuildInputs = [
      protobuf
      net
    ];
  };

  crypto = buildFromGitHub {
    rev = "f3241ce8505855877cc8a9717bd61a0f7c4ea83c";
    date = "2016-06-10";
    owner    = "golang";
    repo     = "crypto";
    sha256 = "1wxlgj8qxc6cfpplwj9x4xs6bd9wsy8mbplwm8yz7q3cdn5d3c74";
    goPackagePath = "golang.org/x/crypto";
    goPackageAliases = [
      "code.google.com/p/go.crypto"
      "github.com/golang/crypto"
    ];
    buildInputs = [
      net_crypto_lib
    ];
  };

  glog = buildFromGitHub {
    rev = "23def4e6c14b4da8ac2ed8007337bc5eb5007998";
    date = "2016-01-25";
    owner  = "golang";
    repo   = "glog";
    sha256 = "0wj30z2r6w1zdbsi8d14cx103x13jszlqkvdhhanpglqr22mxpy0";
  };

  net = buildFromGitHub {
    rev = "bc3663df0ac92f928d419e31e0d2af22e683a5a2";
    date = "2016-06-21";
    owner  = "golang";
    repo   = "net";
    sha256 = "1zqrjj3d599y2izsn7imh7zjm3sik5xfnpbpwm3pg6f2fi7vgr6c";
    goPackagePath = "golang.org/x/net";
    goPackageAliases = [
      "code.google.com/p/go.net"
      "github.com/hashicorp/go.net"
      "github.com/golang/net"
    ];
    propagatedBuildInputs = [ text crypto ];
  };

  net_crypto_lib = buildFromGitHub {
    inherit (net) rev date owner repo sha256 goPackagePath;
    subPackages = [
      "context"
    ];
  };

  oauth2 = buildFromGitHub {
    rev = "65a8d08c6292395d47053be10b3c5e91960def76";
    date = "2016-06-07";
    owner = "golang";
    repo = "oauth2";
    sha256 = "1xph0wj1b0n1dqc7myjqrbnjzk9qcllx4mf95k3qhi62bdhcgj1m";
    goPackagePath = "golang.org/x/oauth2";
    goPackageAliases = [ "github.com/golang/oauth2" ];
    propagatedBuildInputs = [ net gcloud-golang-compute-metadata ];
  };


  protobuf = buildFromGitHub {
    rev = "0c1f6d65b5a189c2250d10e71a5506f06f9fa0a0";
    date = "2016-06-14";
    owner = "golang";
    repo = "protobuf";
    sha256 = "1cm649d6nz760n5z354kxmcd7bf0f0qa1jy2495yadmyn53wx929";
    goPackagePath = "github.com/golang/protobuf";
    goPackageAliases = [ "code.google.com/p/goprotobuf" ];
  };

  snappy = buildFromGitHub {
    rev = "d9eb7a3d35ec988b8585d4a0068e462c27d28380";
    date = "2016-05-29";
    owner  = "golang";
    repo   = "snappy";
    sha256 = "1z7xwm1w0nh2p6gdp0cg6hvzizs4zjn43c7vrm1fmf3sdvp6pxnw";
    goPackageAliases = [ "code.google.com/p/snappy-go/snappy" ];
  };

  sys = buildFromGitHub {
    rev = "62bee037599929a6e9146f29d10dd5208c43507d";
    date = "2016-06-15";
    owner  = "golang";
    repo   = "sys";
    sha256 = "1qkhj4c91c576lqn27pw7q83q7l045ghc71mxd0j5a3mlc0w5737";
    goPackagePath = "golang.org/x/sys";
    goPackageAliases = [
      "github.com/golang/sys"
    ];
  };

  text = buildFromGitHub {
    rev = "e3c902a8b2c4c420ce61514795e05b8e28a6364e";
    date = "2016-06-07";
    owner = "golang";
    repo = "text";
    sha256 = "19kyh4l8nf1i0fr80rwhkrb7wdv4w92sxd7am132ym839w0lif9z";
    goPackagePath = "golang.org/x/text";
    goPackageAliases = [ "github.com/golang/text" ];
  };

  tools = buildFromGitHub {
    rev = "a2a552218a0e22e6fb22469f49ef371b492f6178";
    date = "2016-06-14";
    owner = "golang";
    repo = "tools";
    sha256 = "06nngr7qic52fkf4g45jxgb68h7p34xgscblkra56i34kri62qwy";
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
    owner = "yosssi";
    repo = "ace";
    rev = "71afeb714739f9d5f7e1849bcd4a0a5938e1a70d";
    date = "2016-01-02";
    sha256 = "1alfpk0wa73bxpl5g2my7xbimxqii7l24znm5b2cn0307qj0pclz";
    buildInputs = [
      gohtml
    ];
  };

  afero = buildFromGitHub {
    owner = "spf13";
    repo = "afero";
    rev = "1a8ecf8b9da1fb5306e149e83128fc447957d2a8";
    date = "2016-06-06";
    sha256 = "0987ijvvzba5xwkkiwp89czsp1s0sfaiv4nnsd0yvlf2zswp2zbk";
    propagatedBuildInputs = [
      sftp
      text
    ];
  };

  amber = buildFromGitHub {
    owner = "eknkc";
    repo = "amber";
    rev = "91774f050c1453128146169b626489e60108ec03";
    date = "2016-04-21";
    sha256 = "0mimywnfvvjkvpyda48qr1xqijkz5k5qinf9qcwzydahjmif7j7q";
  };

  ansicolor = buildFromGitHub {
    date = "2015-11-20";
    rev = "a422bbe96644373c5753384a59d678f7d261ff10";
    owner  = "shiena";
    repo   = "ansicolor";
    sha256 = "1qfq4ax68d7a3ixl60fb8kgyk0qx0mf7rrk562cnkpgzrhkdcm0w";
  };

  asn1-ber = buildFromGitHub {
    rev = "v1.1";
    owner  = "go-asn1-ber";
    repo   = "asn1-ber";
    sha256 = "1mi96bl0jn3nrp4v5aqxgqf5zdndif1qdhdjgjayigjkl67770s3";
    goPackageAliases = [
      "github.com/nmcclain/asn1-ber"
      "github.com/vanackere/asn1-ber"
      "gopkg.in/asn1-ber.v1"
    ];
  };

  assertions = buildGoPackage rec {
    version = "1.5.0";
    name = "assertions-${version}";
    goPackagePath = "github.com/smartystreets/assertions";
    src = fetchurl {
      name = "${name}.tar.gz";
      url = "https://github.com/smartystreets/assertions/archive/${version}.tar.gz";
      sha256 = "1s4b0v49yv7jmy4izn7grfqykjrg7zg79dg5hsqr3x40d5n7mk02";
    };
    buildInputs = [ oglematchers ];
    propagatedBuildInputs = [ goconvey ];
    doCheck = false;
  };

  aws-sdk-go = buildFromGitHub {
    rev = "v1.1.36";
    owner  = "aws";
    repo   = "aws-sdk-go";
    sha256 = "15k90pckmyk3f7h51jwfx7535h18cr2phgy7gxn8fp9601dpclcb";
    buildInputs = [ testify gucumber tools ];
    propagatedBuildInputs = [ ini go-jmespath ];

    preBuild = ''
      pushd go/src/$goPackagePath
      make generate
      popd
    '';
  };

  azure-sdk-for-go = buildFromGitHub {
    date = "2016-06-22";
    rev = "be1b1680ad0a95f6e95110bdad5025147027de12";
    owner  = "Azure";
    repo   = "azure-sdk-for-go";
    sha256 = "07j9i9mybx96g5j0cjrp044997zh2d5d4zdhgi11qzk68ncrzxcv";
    buildInputs = [
      go-autorest
    ];
  };

  b = buildFromGitHub {
    date = "2016-02-10";
    rev = "47184dd8c1d2c7e7f87dae8448ee2007cdf0c6c4";
    owner  = "cznic";
    repo   = "b";
    sha256 = "1sw8yyb906v3kv8km8wnyrgkvyjbv74iinrdvjh1qb87p2vr4b17";
  };

  bigfft = buildFromGitHub {
    date = "2013-09-13";
    rev = "a8e77ddfb93284b9d58881f597c820a2875af336";
    owner = "remyoudompheng";
    repo = "bigfft";
    sha256 = "1cj9zyv3shk8n687fb67clwgzlhv47y327180mvga7z741m48hap";
  };

  blackfriday = buildFromGitHub {
    owner = "russross";
    repo = "blackfriday";
    rev = "1d6b8e9301e720b08a8938b8c25c018285885438";
    sha256 = "1cc7mqmgj55k3sz79iff3b4s7vjgf5afjqrdlm218wyjsszihq8k";
    propagatedBuildInputs = [
      sanitized-anchor-name
    ];
    date = "2016-05-31";
  };

  bolt = buildFromGitHub {
    rev = "v1.2.1";
    owner  = "boltdb";
    repo   = "bolt";
    sha256 = "1fm23v09n43f61pzkd0znl9nwlss8kj076pqycsj7vq1bjf1lw0v";
  };

  btree = buildFromGitHub {
    rev = "7d79101e329e5a3adf994758c578dab82b90c017";
    owner  = "google";
    repo   = "btree";
    sha256 = "0ky9a9r1i3awnjisk8bkw4d9v5jkcm9w6sphd889vxdhvizvkskl";
    date = "2016-05-24";
  };

  bufs = buildFromGitHub {
    date = "2014-08-18";
    rev = "3dcccbd7064a1689f9c093a988ea11ac00e21f51";
    owner  = "cznic";
    repo   = "bufs";
    sha256 = "0551h2slsb7lg3r6yif65xvf6k8f0izqwyiigpipm3jhlln37c6p";
  };

  candiedyaml = buildFromGitHub {
    date = "2016-04-29";
    rev = "99c3df83b51532e3615f851d8c2dbb638f5313bf";
    owner  = "cloudfoundry-incubator";
    repo   = "candiedyaml";
    sha256 = "104giv2wjiispfsm82q3lk5qjvfjgrqhhnxm2yma9i21klmvir0y";
  };

  cast = buildFromGitHub {
    owner = "spf13";
    repo = "cast";
    rev = "27b586b42e29bec072fe7379259cc719e1289da6";
    date = "2016-03-03";
    sha256 = "1b2wmjq68h6g2g8b9yjnip26xkyqfnqppnmaixlpk43hakhxxggf";
    buildInputs = [
      jwalterweatherman
    ];
  };

  check-v1 = buildFromGitHub {
    rev = "4f90aeace3a26ad7021961c297b22c42160c7b25";
    owner = "go-check";
    repo = "check";
    goPackagePath = "gopkg.in/check.v1";
    sha256 = "1vmf8shg0kqakmh60k5m985vxj9h2lb18lw69qx9scl5i66n746h";
    date = "2016-01-05";
  };

  circbuf = buildFromGitHub {
    date = "2015-08-26";
    rev = "bbbad097214e2918d8543d5201d12bfd7bca254d";
    owner  = "armon";
    repo   = "circbuf";
    sha256 = "0wgpmzh0ga2kh51r214jjhaqhpqr9l2k6p0xhy5a006qypk5fh2m";
  };

  mitchellh_cli = buildFromGitHub {
    date = "2016-03-23";
    rev = "168daae10d6ff81b8b1201b0a4c9607d7e9b82e3";
    owner = "mitchellh";
    repo = "cli";
    sha256 = "1ihlx94djy3npy88kv1ahsgk4vh4jchsgmyj2pkrawf8chf1i4v3";
    propagatedBuildInputs = [ crypto go-radix speakeasy go-isatty ];
  };

  urfave_cli = buildFromGitHub {
    rev = "v1.17.0";
    owner = "urfave";
    repo = "cli";
    sha256 = "0171xw72kvsk4zcygvrmslcir9qp7q4v1lh6rpllayf9ws1253dl";
    goPackagePath = "github.com/codegangsta/cli";
    goPackageAliases = [
      "github.com/urfave/cli"
    ];
    buildInputs = [
      yaml-v2
    ];
  };

  cobra = buildFromGitHub {
    owner = "spf13";
    repo = "cobra";
    rev = "6a8bd97bdb1fc0d08a83459940498ea49d3e8c93";
    date = "2016-06-21";
    sha256 = "13kgjxjm19lv6fxkvbqny4dgzqyqhsx444an9xzr7hm6lzb1g8hc";
    buildInputs = [
      pflag
      viper
    ];
    propagatedBuildInputs = [
      go-md2man
    ];
  };

  columnize = buildFromGitHub {
    rev = "v2.1.0";
    owner  = "ryanuber";
    repo   = "columnize";
    sha256 = "0r9r4p4x1vnrq31dj5bvw3phhmqpsb5vwh72cs2wwxmhalzq92hx";
  };

  copystructure = buildFromGitHub {
    date = "2016-06-09";
    rev = "ae8f8315ad044b86ced2e0be9e3598e9dd94f38e";
    owner = "mitchellh";
    repo = "copystructure";
    sha256 = "185c10ab80cn4jxdp915h428lm0r9zf1cqrfsjs71im3w3ankvsn";
    propagatedBuildInputs = [ reflectwalk ];
  };

  consul = buildFromGitHub {
    rev = "v0.6.4";
    owner = "hashicorp";
    repo = "consul";
    sha256 = "0jvhhzbkdxcqj1jwc2h25qd996g3rv3csjaix14v6hds9nniqyww";

    buildInputs = [
      datadog-go circbuf armon_go-metrics go-radix speakeasy bolt
      go-bindata-assetfs go-dockerclient errwrap go-checkpoint
      go-immutable-radix go-memdb ugorji_go go-multierror go-reap go-syslog
      golang-lru hcl logutils memberlist net-rpc-msgpackrpc raft raft-boltdb
      scada-client yamux muxado dns mitchellh_cli mapstructure columnize
      copystructure hil hashicorp-go-uuid crypto sys
    ];

    propagatedBuildInputs = [
      go-cleanhttp
      serf
    ];

    # Keep consul.ui for backward compatability
    passthru.ui = pkgs.consul-ui;
  };

  consul-api = buildFromGitHub {
    inherit (consul) owner repo;
    rev = "09cfda47ed103910a8e1af76fa378a7e6acd5310";
    date = "2016-06-21";
    sha256 = "34c43e04134bd3a4badabca52672c7a6cb6329dd602507114fd387be3c99fa1a";
    buildInputs = [
      go-cleanhttp
      serf
    ];
    subPackages = [
      "api"
      "lib"
      "tlsutil"
    ];
  };

  consul-template = buildFromGitHub {
    rev = "v0.15.0";
    owner = "hashicorp";
    repo = "consul-template";
    sha256 = "04fppwf7hr11s15rgzfpnhgqrwzn6akp9phjrn9gymlp7ak3i4jc";

    buildInputs = [
      consul-api
      go-cleanhttp
      go-multierror
      go-reap
      go-syslog
      logutils
      mapstructure
      serf
      yaml-v2
      vault-api
    ];
  };

  context = buildGoPackage rec {
    rev = "v1.1";
    name = "config-${stdenv.lib.strings.substring 0 7 rev}";
    goPackagePath = "github.com/gorilla/context";

    src = fetchFromGitHub {
      inherit rev;
      owner = "gorilla";
      repo = "context";
    sha256 = "0fsm31ayvgpcddx3bd8fwwz7npyd7z8d5ja0w38lv02yb634daj6";
    };
  };

  cronexpr = buildFromGitHub {
    rev = "f0984319b44273e83de132089ae42b1810f4933b";
    owner  = "gorhill";
    repo   = "cronexpr";
    sha256 = "0d2c67spcyhr4bxzmnqsxnzbn6a8sw893wvc4cx7a3js4ydy7raz";
    date = "2016-03-18";
  };

  crypt = buildFromGitHub {
    owner = "xordataexchange";
    repo = "crypt";
    rev = "749e360c8f236773f28fc6d3ddfce4a470795227";
    date = "2015-05-23";
    sha256 = "0zc00mpvqv7n1pz6fn6570wf9j8dc5d2m49yrqqygs52r2iarpx5";
    propagatedBuildInputs = [
      consul
      crypto
    ];
    patches = [
      (fetchTritonPatch {
       rev = "77ff70bae635d2ac5bae8c647120d336070a579e";
       file = "crypt/crypt-2015-05-remove-etcd-support.patch";
       sha256 = "e942558fc230884e4ddbbafd97f7a3ea56bacdfea90a24f8790d37c399265904";
      })
    ];
    postPatch = ''
      sed -i backend/consul/consul.go \
        -e 's,"github.com/armon/consul-api",consulapi "github.com/hashicorp/consul/api",'
    '';
  };

  cssmin = buildFromGitHub {
    owner = "dchest";
    repo = "cssmin";
    rev = "fb8d9b44afdc258bfff6052d3667521babcb2239";
    date = "2015-12-10";
    sha256 = "1m9zqdaw2qycvymknv6vx2i4jlpdj6lcjysxd18czbf5kp6pcri4";
  };

  datadog-go = buildFromGitHub {
    date = "2016-03-29";
    rev = "cc2f4770f4d61871e19bfee967bc767fe730b0d9";
    owner = "DataDog";
    repo = "datadog-go";
    sha256 = "10c1jkghl7a7a4z80lsjg11gx3vf6nn7y5x078b98mxisf0x0cdv";
  };

  dbus = buildFromGitHub {
    rev = "v4.0.0";
    owner = "godbus";
    repo = "dbus";
    sha256 = "0q2qabf656sq0pd3candndd8nnkwwp4by4hlkxjn4fs85ld44i8s";
  };

  dns = buildFromGitHub {
    rev = "5d001d020961ae1c184f9f8152fdc73810481677";
    date = "2016-06-14";
    owner  = "miekg";
    repo   = "dns";
    sha256 = "0vb4cjlb05znl81byk46v7jc4hwln1qxsbbzq8siwxhxr3d7p5ck";
  };

  weppos-dnsimple-go = buildFromGitHub {
    rev = "65c1ca73cb19baf0f8b2b33219b7f57595a3ccb0";
    date = "2016-02-04";
    owner  = "weppos";
    repo   = "dnsimple-go";
    sha256 = "0v3vnp128ybzmh4fpdwhl6xmvd815f66dgdjzxarjjw8ywzdghk9";
  };

  docker = buildFromGitHub {
    rev = "v1.11.2";
    owner = "docker";
    repo = "docker";
    sha256 = "1ycf0gj3whpjbalskshb2k4qblhdj8pqb8fji1h1wsqhabsnrz6x";
  };

  docker_for_runc = buildFromGitHub {
    inherit (docker) rev owner repo sha256;
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
    inherit (docker) rev owner repo sha256;
    subPackages = [
      "opts"
      "pkg/archive"
      "pkg/fileutils"
      "pkg/homedir"
      "pkg/idtools"
      "pkg/ioutils"
      "pkg/pools"
      "pkg/promise"
      "pkg/stdcopy"
    ];
    propagatedBuildInputs = [
      go-units
      logrus
      net
      runc
    ];
  };

  docopt-go = buildFromGitHub {
    rev = "0.6.2";
    owner  = "docopt";
    repo   = "docopt-go";
    sha256 = "11cxmpapg7l8f4ar233f3ybvsir3ivmmbg1d4dbnqsr1hzv48xrf";
  };

  duo_api_golang = buildFromGitHub {
    date = "2016-03-22";
    rev = "6f814b626e6aad2bb14b95969b42fdb09c4a0f16";
    owner = "duosecurity";
    repo = "duo_api_golang";
    sha256 = "01lxky92b71ayzc2fw1y7phdzn9m62sr7p1y1pm6adbzjaqlpg8n";
  };

  emoji = buildFromGitHub {
    owner = "kyokomi";
    repo = "emoji";
    rev = "v1.4";
    sha256 = "1k87kd0h4qk2klbxx3r86g07wk9mgrb0jhdj8kgd2hlgh45j4pd2";
  };

  envpprof = buildFromGitHub {
    rev = "0383bfe017e02efb418ffd595fc54777a35e48b0";
    owner = "anacrolix";
    repo = "envpprof";
    sha256 = "0i9d021hmcfkv9wv55r701p6j6r8mj55fpl1kmhdhvar8s92rjgl";
    date = "2016-05-28";
  };

  du = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "calmh";
    repo   = "du";
    sha256 = "02gri7xy9wp8szxpabcnjr18qic6078k213dr5k5712s1pg87qmj";
  };

  errors = buildFromGitHub {
    owner = "pkg";
    repo = "errors";
    rev = "v0.7.0";
    sha256 = "0nshc2ziy81cmnj8gv0v28875bk2q49kv5cqa04zk87kmh6bvkfj";
  };

  errwrap = buildFromGitHub {
    date = "2014-10-27";
    rev = "7554cd9344cec97297fa6649b055a8c98c2a1e55";
    owner  = "hashicorp";
    repo   = "errwrap";
    sha256 = "02hsk2zbwg68w62i6shxc0lhjxz20p3svlmiyi5zjz988qm3s530";
  };

  etcd = buildFromGitHub {
    owner = "coreos";
    repo = "etcd";
    rev = "v2.3.7";
    sha256 = "10igsyr92gzp3d6g42nk4y5dx15xzvcnxfdls7ryhdrzqh4is8cc";
    buildInputs = [
      pkgs.libpcap
      tablewriter
    ];
  };

  etcd-client = buildFromGitHub {
    inherit (etcd) rev owner repo sha256;
    subPackages = [
      "client"
      "pkg/pathutil"
      "pkg/transport"
      "pkg/types"
      "Godeps/_workspace/src/golang.org/x/net"
      "Godeps/_workspace/src/github.com/ugorji/go/codec"
    ];
  };

  exp = buildFromGitHub {
    date = "2015-12-07";
    rev = "c21cce1fce3e6e5bc84854aa3d02a808de44229b";
    owner  = "cznic";
    repo   = "exp";
    sha256 = "00dx5nnjxwpd8dmig210hsgag0brk8391kar97kp3dlikn6dbqb5";
    propagatedBuildInputs = [ bufs fileutil mathutil sortutil zappy ];
  };

  fileutil = buildFromGitHub {
    date = "2015-07-08";
    rev = "1c9c88fbf552b3737c7b97e1f243860359687976";
    owner  = "cznic";
    repo   = "fileutil";
    sha256 = "0naps0miq8lk4k7k6c0l9583nv6wcdbs9zllvsjjv60h4fsz856a";
    buildInputs = [ mathutil ];
  };

  fs = buildFromGitHub {
    date = "2013-11-07";
    rev = "2788f0dbd16903de03cb8186e5c7d97b69ad387b";
    owner  = "kr";
    repo   = "fs";
    sha256 = "16ygj65wk30cspvmrd38s6m8qjmlsviiq8zsnnvkhfy5l0gk4c86";
  };

  fsnotify = buildFromGitHub {
    owner = "fsnotify";
    repo = "fsnotify";
    rev = "v1.3.0";
    sha256 = "1gazf2b3srhr8i9dxisjq9pf71ln5qcbcfknics31rc1d1sii2hy";
    propagatedBuildInputs = [
      sys
    ];
  };

  fsync = buildFromGitHub {
    owner = "spf13";
    repo = "fsync";
    rev = "eefee59ad7de621617d4ff085cf768aab4b919b1";
    date = "2016-03-01";
    sha256 = "1qakm902mpdikkz7fngxvy6xczq7mvcmj0dkz6gr20h9l7h95lnh";
    buildInputs = [
      afero
    ];
  };

  gateway = buildFromGitHub {
    date = "2016-05-22";
    rev = "edad739645120eeb82866bc1901d3317b57909b1";
    owner  = "calmh";
    repo   = "gateway";
    sha256 = "0gzwns51jl2jm62ii99c7caa9p7x2c8p586q1cjz8bpv2mcd8njg";
    goPackageAliases = [
      "github.com/jackpal/gateway"
    ];
  };

  gcloud-golang = buildFromGoogle {
    rev = "0a83eba2cadb60eb22123673c8fb6fca02b03c94";
    repo = "cloud";
    sha256 = "1bma7wypm32dldrlkavac4sg23glqvhq6igc870mzj9xc2y2b1pf";
    propagatedBuildInputs = [
      net
      oauth2
      protobuf
      google-api-go-client
      grpc
    ];
    excludedPackages = "oauth2";
    meta.hydraPlatforms = [ ];
    date = "2016-06-21";
  };

  gcloud-golang-for-go4 = buildFromGoogle {
    inherit (gcloud-golang) rev repo sha256 date;
    subPackages = [
      "storage"
    ];
    propagatedBuildInputs = [
      google-api-go-client
      grpc
      net
      oauth2
    ];
  };

  gcloud-golang-compute-metadata = buildFromGoogle {
    inherit (gcloud-golang) rev repo sha256 date;
    subPackages = [ "compute/metadata" "internal" ];
    buildInputs = [ net ];
  };

  gettext = buildFromGitHub {
    rev = "305f360aee30243660f32600b87c3c1eaa947187";
    owner = "gosexy";
    repo = "gettext";
    sha256 = "0s1f99llg462mbcdmg2yp8l6ifq56v6qp8bw33ng5yrws91xflj7";
    date = "2016-06-02";
    buildInputs = [
      go-flags
      go-runewidth
    ];
  };

  ginkgo = buildFromGitHub {
    rev = "059cec02d342bab423425a99b191186a03255e9e";
    owner = "onsi";
    repo = "ginkgo";
    sha256 = "1agvlz59mydkw3qw9hnnk1q3bllc2vv91blds5vy0i6h21qjrn0z";
    date = "2016-06-13";
  };

  glob = buildFromGitHub {
    rev = "0.2.0";
    owner = "gobwas";
    repo = "glob";
    sha256 = "1lbijdwchj6v7qpy9mr0xzs3v2y868vrmsxk1y24dm6wpacz50jd";
  };

  ugorji_go = buildFromGitHub {
    date = "2016-05-31";
    rev = "b94837a2404ab90efe9289e77a70694c355739cb";
    owner = "ugorji";
    repo = "go";
    sha256 = "0419rraxl5hwpwmwf6ac5201as1456r128llwa49qnl3jg4s98rz";
    goPackageAliases = [ "github.com/hashicorp/go-msgpack" ];
  };

  go4 = buildFromGitHub {
    date = "2016-06-01";
    rev = "15c19124e43b90eba9aa27b4341e38365254a84a";
    owner = "camlistore";
    repo = "go4";
    sha256 = "bdc95657e810fc023362d563a85226ff62ba79e1ecc91e3a4683008cee5c564a";
    goPackagePath = "go4.org";
    goPackageAliases = [ "github.com/camlistore/go4" ];
    buildInputs = [
      gcloud-golang-for-go4
      oauth2
      net
      sys
    ];
    autoUpdatePath = "github.com/camlistore/go4";
  };

  goamz = buildFromGitHub {
    rev = "6787558cdc4dff39ac8029e0c90c15a45b317585";
    owner  = "goamz";
    repo   = "goamz";
    sha256 = "0admmj5s22rvc4hbfwrckd8vxrqik58bra4a6s02ldpkjp7d7ckp";
    date = "2016-06-21";
    goPackageAliases = [
      "github.com/mitchellh/goamz"
    ];
    buildInputs = [
      check-v1
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
      inherit rev;
      owner  = "ww";
      repo   = "goautoneg";
      sha256 = "9acef1c250637060a0b0ac3db033c1f679b894ef82395c15f779ec751ec7700a";
    };

    meta.autoUpdate = false;
  };

  gocapability = buildFromGitHub {
    rev = "2c00daeb6c3b45114c80ac44119e7b8801fdd852";
    owner = "syndtr";
    repo = "gocapability";
    sha256 = "0kwcqvj2fq6wl453hcc3q4fmyrv3yk9m3igxwksx9rmpnzaclz8r";
    date = "2015-07-16";
  };

  gocql = buildFromGitHub {
    rev = "b7b8a0e04b0cb0ca0b379421c58ec6fab9939b85";
    owner  = "gocql";
    repo   = "gocql";
    sha256 = "0ypkjl63xjw4r618dr94p8c1sccnw09bb1x7h124s916q9j9p3vp";
    propagatedBuildInputs = [ inf snappy hailocab_go-hostpool net ];
    date = "2016-05-25";
  };

  goconvey = buildGoPackage rec {
    version = "1.5.0";
    name = "goconvey-${version}";
    goPackagePath = "github.com/smartystreets/goconvey";
    src = fetchurl {
      name = "${name}.tar.gz";
      url = "https://github.com/smartystreets/goconvey/archive/${version}.tar.gz";
      sha256 = "0g3965cb8kg4kf9b0klx4pj9ycd7qwbw1jqjspy6i5d4ccd6mby4";
    };
    buildInputs = [ oglematchers ];
    doCheck = false; # please check again
  };

  gojsonpointer = buildFromGitHub {
    rev = "e0fe6f68307607d540ed8eac07a342c33fa1b54a";
    owner  = "xeipuuv";
    repo   = "gojsonpointer";
    sha256 = "1gm1m5vf1nkg87qhskpqfyg9r8n0fy74nxvp6ajcqb04v3k8sd7v";
    date = "2015-10-27";
  };

  gojsonreference = buildFromGitHub {
    rev = "e02fc20de94c78484cd5ffb007f8af96be030a45";
    owner  = "xeipuuv";
    repo   = "gojsonreference";
    sha256 = "1c2yhjjxjvwcniqag9i5p159xsw4452vmnc2nqxnfsh1whd8wpi5";
    date = "2015-08-08";
    propagatedBuildInputs = [ gojsonpointer ];
  };

  gojsonschema = buildFromGitHub {
    rev = "c395321cdc9f3777b70ca9c439e20b5789de6304";
    owner  = "xeipuuv";
    repo   = "gojsonschema";
    sha256 = "0dzxq4fnbf860ljhl2rzb23kihw88rr2ldwcz7cjyhh9h33k1bir";
    date = "2016-06-21";
    propagatedBuildInputs = [ gojsonreference ];
  };

  govers = buildFromGitHub {
    rev = "3b5f175f65d601d06f48d78fcbdb0add633565b9";
    date = "2015-01-09";
    owner = "rogpeppe";
    repo = "govers";
    sha256 = "1ir47942q9z6h5cajn84hvibhxicq93yrrgd36bagkibi4b2s5qf";
    dontRenameImports = true;
  };

  golang-lru = buildFromGitHub {
    date = "2016-02-07";
    rev = "a0d98a5f288019575c6d1f4bb1573fef2d1fcdc4";
    owner  = "hashicorp";
    repo   = "golang-lru";
    sha256 = "1q4cvlrk1pzki8lkf8b5mc3ciini8b6dlljrijycdh7izfc17vsz";
  };

  golang-petname = buildFromGitHub {
    rev = "2182cecef7f257230fc998bc351a08a5505f5e6c";
    owner  = "dustinkirkland";
    repo   = "golang-petname";
    sha256 = "15pwg0fx2mvqlg9xshpjrhn0s8vd4zyp88rw7pz3wm74jshvjpk2";
    date = "2016-02-01";
  };

  golang_protobuf_extensions = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "matttproud";
    repo   = "golang_protobuf_extensions";
    sha256 = "0r1sv4jw60rsxy5wlnr524daixzmj4n1m1nysv4vxmwiw9mbr6fm";
    buildInputs = [ protobuf ];
  };

  goleveldb = buildFromGitHub {
    rev = "fa5b5c78794bc5c18f330361059f871ae8c2b9d6";
    date = "2016-06-08";
    owner = "syndtr";
    repo = "goleveldb";
    sha256 = "19y1k0xmkpg31nfisf9nhx1dl21y4ivfgs33pipvqza0b71sa8zn";
    propagatedBuildInputs = [ ginkgo gomega snappy ];
  };

  gomega = buildFromGitHub {
    rev = "3e93f011213c200aadafcb19ed56eb718381cfbd";
    owner  = "onsi";
    repo   = "gomega";
    sha256 = "0vy9qkxjjq946a3rf1j0wi32rnv5b5d0359f7dn5cp6f87fw5wlk";
    propagatedBuildInputs = [
      protobuf
      yaml-v2
    ];
    date = "2016-06-13";
  };

  google-api-go-client = buildFromGitHub {
    rev = "63ade871fd3aec1225809d496e81ec91ab76ea29";
    date = "2016-05-31";
    owner = "google";
    repo = "google-api-go-client";
    sha256 = "02wb0k5hvybdpklbm4pwjll6f47z0vpkm8chks6cbj2bdnsmplrl";
    goPackagePath = "google.golang.org/api";
    goPackageAliases = [
      "github.com/google/google-api-client"
    ];
    buildInputs = [
      net
    ];
  };

  gopass = buildFromGitHub {
    date = "2016-03-03";
    rev = "66487b23f2880ba32e185121d2cd51a338ea069a";
    owner = "howeyc";
    repo = "gopass";
    sha256 = "0r4kx80hq48fkipz4x7hkiqb74hygpja1h5xbzydaw4cdgc5vwjs";
    propagatedBuildInputs = [ crypto ];
  };

  gopsutil = buildFromGitHub {
    rev = "v2.1";
    owner  = "shirou";
    repo   = "gopsutil";
    sha256 = "1bq3fpw0jpjnkla2krf9i612v8k4kyfm0g1z7maikrnxhfiza4lc";
  };

  goskiplist = buildFromGitHub {
    rev = "2dfbae5fcf46374f166f8969cb07e167f1be6273";
    owner  = "ryszard";
    repo   = "goskiplist";
    sha256 = "1dr6n2w5ikdddq9c1fwqnc0m383p73h2hd04302cfgxqbnymabzq";
    date = "2015-03-12";
  };

  govalidator = buildFromGitHub {
    rev = "df81827fdd59d8b4fb93d8910b286ab7a3919520";
    owner = "asaskevich";
    repo = "govalidator";
    sha256 = "0bhnv6fd6msyi7y258jkrqr28gmnc34aj5fxii85494di8g2ww5z";
    date = "2016-05-19";
  };

  go-autorest = buildFromGitHub {
    rev = "1141e60d2b042bac407794a2f3e6028ccf748fe5";
    date = "2016-06-22";
    owner  = "Azure";
    repo   = "go-autorest";
    sha256 = "986342ccd2bef14d9df936a5c7feec922f2be98f3a8824bafaff54b13991b1fb";
    propagatedBuildInputs = [
      crypto
      jwt-go
    ];
  };

  go-base58 = buildFromGitHub {
    rev = "1.0.0";
    owner  = "jbenet";
    repo   = "go-base58";
    sha256 = "0sbss2611iri3mclcz3k9b7kw2sqgwswg4yxzs02vjk3673dcbh2";
  };

  go-bencode = buildGoPackage rec {
    version = "1.1.1";
    name = "go-bencode-${version}";
    goPackagePath = "github.com/ehmry/go-bencode";

    src = fetchurl {
      url = "https://${goPackagePath}/archive/v${version}.tar.gz";
      sha256 = "0y2kz2sg1f7mh6vn70kga5d0qhp04n01pf1w7k6s8j2nm62h24j6";
    };
  };

  go-bindata-assetfs = buildFromGitHub {
    rev = "57eb5e1fc594ad4b0b1dbea7b286d299e0cb43c2";
    owner   = "elazarl";
    repo    = "go-bindata-assetfs";
    sha256 = "0kr3jz9lfivm0q9lsl6zpa4i02qa79304kn059skr0dnsnizj2q7";
    date = "2015-12-24";
  };

  go-checkpoint = buildFromGitHub {
    date = "2015-10-22";
    rev = "e4b2dc34c0f698ee04750bf2035d8b9384233e1b";
    owner  = "hashicorp";
    repo   = "go-checkpoint";
    sha256 = "1lnwx8c6ny3d2smj6ap4ar0d3i7fzjbi0mhmrnpmyln0anrp4yd4";
    buildInputs = [ go-cleanhttp ];
  };

  go-cleanhttp = buildFromGitHub {
    date = "2016-04-07";
    rev = "ad28ea4487f05916463e2423a55166280e8254b5";
    owner = "hashicorp";
    repo = "go-cleanhttp";
    sha256 = "1knpnv6wg2fnnsk2h2bj4m003f7xsvwm58vnn9gc753mbr78vx00";
  };

  go-colorable = buildFromGitHub {
    rev = "v0.0.5";
    owner  = "mattn";
    repo   = "go-colorable";
    sha256 = "1cj5wp5b0c5xg6hd5v9207b47aysji2zyg7zcs3z4rimzhnlbbnc";
  };

  go-difflib = buildFromGitHub {
    date = "2016-01-10";
    rev = "792786c7400a136282c1664665ae0a8db921c6c2";
    owner  = "pmezard";
    repo   = "go-difflib";
    sha256 = "0xhjjfvx97zkms5004v1k3prc5g1kljiayhf05v0n0yf89s5r28r";
  };

  go-dockerclient = buildFromGitHub {
    date = "2016-06-21";
    rev = "3c3341e082f778f28a186b9d4b97e825f41f0d5d";
    owner = "fsouza";
    repo = "go-dockerclient";
    sha256 = "0kkn3llizm7r16jndgdr5kxxfc2pzm9rcirwkcfn3dnxinjilwdw";
    propagatedBuildInputs = [
      docker_for_go-dockerclient
      go-cleanhttp
      mux
    ];
  };

  go-flags = buildFromGitHub {
    date = "2016-05-28";
    rev = "b9b882a3990882b05e02765f5df2cd3ad02874ee";
    owner  = "jessevdk";
    repo   = "go-flags";
    sha256 = "02wzy17cl9v91ssmidqgvsk82dgg0iskd12h8dkp1ya1f9cvn7rj";
  };

  go-getter = buildFromGitHub {
    rev = "3d6040e1c4b972f6634c5aafb08901f916c5ee3c";
    date = "2016-06-03";
    owner = "hashicorp";
    repo = "go-getter";
    sha256 = "0msy19c1gnrqbfrg2yc298ysdy8fiw6q2j6db35cm9698bcfc078";
    buildInputs = [ aws-sdk-go ];
  };

  go-git-ignore = buildFromGitHub {
    rev = "228fcfa2a06e870a3ef238d54c45ea847f492a37";
    date = "2016-01-15";
    owner = "sabhiram";
    repo = "go-git-ignore";
    sha256 = "1a78b1as3xd2v3lawrb0y43bm3rmb452mysvzqk1309gw51lk4gx";
  };

  go-github = buildFromGitHub {
    date = "2016-06-15";
    rev = "07995e49c22dcb1e372c88ff12793b0194433e1c";
    owner = "google";
    repo = "go-github";
    sha256 = "1rvk6bi5fls3r0q2x9mgv9jx9sgm191yabm0cfkxz3fw4v7vnkbg";
    buildInputs = [ oauth2 ];
    propagatedBuildInputs = [ go-querystring ];
  };

  go-homedir = buildFromGitHub {
    date = "2016-06-21";
    rev = "756f7b183b7ab78acdbbee5c7f392838ed459dda";
    owner  = "mitchellh";
    repo   = "go-homedir";
    sha256 = "0lacs15dkbs9ag6mdq5xg4w72g7m8p4042f7z4lrnk3r36c53zjq";
  };

  hailocab_go-hostpool = buildFromGitHub {
    rev = "e80d13ce29ede4452c43dea11e79b9bc8a15b478";
    date = "2016-01-25";
    owner  = "hailocab";
    repo   = "go-hostpool";
    sha256 = "06ic8irabl0iwhmkyqq4wzq1d4pgp9vk1kmflgv1wd5d9q8qmkgf";
  };

  go-humanize = buildFromGitHub {
    rev = "499693e27ee0d14ffab67c31ad065fdb3d34ea75";
    owner = "dustin";
    repo = "go-humanize";
    sha256 = "1f04fk2lavjlhfyz683djskhcvv43lsv4rgapraz8jf5g9jx9fbn";
    date = "2016-06-02";
  };

  go-immutable-radix = buildFromGitHub {
    date = "2016-06-08";
    rev = "afc5a0dbb18abdf82c277a7bc01533e81fa1d6b8";
    owner = "hashicorp";
    repo = "go-immutable-radix";
    sha256 = "1yyhag8vnr7vi4ak2rkd651k9h8221dpdsqpva95zvf9nycgzlsd";
    propagatedBuildInputs = [ golang-lru ];
  };

  go-ini = buildFromGitHub {
    rev = "a98ad7ee00ec53921f08832bc06ecf7fd600e6a1";
    owner = "vaughan0";
    repo = "go-ini";
    sha256 = "07i40hj47z5m6wa5bzy7sc2na3hbwh84ridl40yfybgdlyrzdkf4";
    date = "2013-09-23";
  };

  go-ipfs-api = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "ipfs";
    repo   = "go-ipfs-api";
    sha256 = "0c54r9g10rcnrm9rzj815gjkcgmr5z3pjgh3b4b19vbsgm2rx7hf";
    excludedPackages = "tests";
    propagatedBuildInputs = [ go-multiaddr-net go-multipart-files tar-utils ];
  };

  go-isatty = buildFromGitHub {
    rev = "v0.0.1";
    owner  = "mattn";
    repo   = "go-isatty";
    sha256 = "0ynlb7bh0c6jfcx1d5hsv3zga56x049akdv8cf7hpfsrzkzcqwx8";
  };

  go-jmespath = buildFromGitHub {
    rev = "0.2.2";
    owner = "jmespath";
    repo = "go-jmespath";
    sha256 = "141a1i19fbmcf8qsz88kfb34vvmqpz5ya6hqz9r4v92by840xczi";
  };

  go-jose = buildFromGitHub {
    rev = "v1.0.2";
    owner = "square";
    repo = "go-jose";
    sha256 = "0pp117a464kj8br9pqk9xha87plndfg8mhfc9k1bq0v4qs7awyiq";
    goPackagePath = "gopkg.in/square/go-jose.v1";
    goPackageAliases = [
      "github.com/square/go-jose"
    ];
    buildInputs = [
      urfave_cli
      kingpin-v2
    ];
  };

  go-lxc-v2 = buildFromGitHub {
    rev = "8f9e220b36393c03854c2d224c5a55644b13e205";
    owner  = "lxc";
    repo   = "go-lxc";
    sha256 = "16ka135074r3i89fiwjhhrmidzfv8kv5hqk2rnhbq9mcrsv138ms";
    goPackagePath = "gopkg.in/lxc/go-lxc.v2";
    buildInputs = [ pkgs.lxc ];
    date = "2016-05-31";
  };

  go-lz4 = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "bkaradzic";
    repo   = "go-lz4";
    sha256 = "1bdh2wqp2hh81x00wmsb4px9fzj13jcrdl6w52pabqkr2wyyqwkf";
  };

  go-md2man = buildFromGitHub {
    owner = "cpuguy83";
    repo = "go-md2man";
    rev = "v1.0.5";
    sha256 = "06kr1j092afkz609mrzbdcgl9lzw4z0ry32jfv8q2c8f4lmjk8lx";
    propagatedBuildInputs = [
      blackfriday
    ];
  };

  go-memdb = buildFromGitHub {
    date = "2016-03-01";
    rev = "98f52f52d7a476958fa9da671354d270c50661a7";
    owner = "hashicorp";
    repo = "go-memdb";
    sha256 = "07938b1ln4x7caflhgsvaw8kikh5xcddwrc6zj0hcmzmbpfpyxai";
    buildInputs = [ go-immutable-radix ];
  };

  rcrowley_go-metrics = buildFromGitHub {
    rev = "cfa5a85e9f0abbdf1701b59082c36fc7bff10759";
    date = "2016-06-13";
    owner = "rcrowley";
    repo = "go-metrics";
    sha256 = "0bk7r6f960w4pyc366w63v4fa2zwmzlakrqsc957wq93l32l0r0h";
    propagatedBuildInputs = [ stathat ];
  };

  armon_go-metrics = buildFromGitHub {
    date = "2016-05-20";
    rev = "fbf75676ee9c0a3a23eb0a4d9220a3612cfbd1ed";
    owner = "armon";
    repo = "go-metrics";
    sha256 = "0wrkka9y0w8arfy08aghawwxxj36cgm6i0dw9ri6vhbb821nfar0";
    propagatedBuildInputs = [ prometheus_client_golang datadog-go ];
  };

  go-mssqldb = buildFromGitHub {
    rev = "e291d7fd2204827b9964304c46ec21c330573faf";
    owner = "denisenkom";
    repo = "go-mssqldb";
    sha256 = "0yl67knpcvhzavqn5hbpf0nwv3j4m6jh3dyp4k8nfc4gcv8bwafn";
    date = "2016-06-07";
    buildInputs = [ crypto ];
  };

  go-multiaddr = buildFromGitHub {
    rev = "f3dff105e44513821be8fbe91c89ef15eff1b4d4";
    date = "2016-05-09";
    owner  = "jbenet";
    repo   = "go-multiaddr";
    sha256 = "0qdma38d4bmib063hh899h2491kgzgg16kgqdvypncchawq8nqlj";
    propagatedBuildInputs = [
      go-multihash
    ];
  };

  go-multiaddr-net = buildFromGitHub {
    rev = "d4cfd691db9f50e430528f682ca603237b0eaae0";
    owner  = "jbenet";
    repo   = "go-multiaddr-net";
    sha256 = "0nwqaqfn30qxhwa0v2sbxankkj41krbwd30bp92y0xrkz5ivvi16";
    date = "2016-05-16";
    propagatedBuildInputs = [
      go-multiaddr
      utp
    ];
  };

  go-multierror = buildFromGitHub {
    date = "2015-09-16";
    rev = "d30f09973e19c1dfcd120b2d9c4f168e68d6b5d5";
    owner  = "hashicorp";
    repo   = "go-multierror";
    sha256 = "0l1410m98pklnqkr6fqi2bpcqfag5z1l3snykn46ps38lb1sc3f3";
    propagatedBuildInputs = [ errwrap ];
  };

  go-multihash = buildFromGitHub {
    rev = "dfd3350f10a27ba2cfcd0e5e2d12c43a69f6e408";
    owner  = "jbenet";
    repo   = "go-multihash";
    sha256 = "0bc8k9l4920c48dr6ivpvdrlh3zkdy60714lmpsyrgiadqyhi3cx";
    propagatedBuildInputs = [ go-base58 crypto ];
    date = "2016-06-21";
  };

  go-multipart-files = buildFromGitHub {
    rev = "3be93d9f6b618f2b8564bfb1d22f1e744eabbae2";
    owner  = "whyrusleeping";
    repo   = "go-multipart-files";
    sha256 = "0fdzi6v6rshh172hzxf8v9qq3d36nw3gc7g7d79wj88pinnqf5by";
    date = "2015-09-03";
  };

  go-nat-pmp = buildFromGitHub {
    rev = "452c97607362b2ab5a7839b8d1704f0396b640ca";
    owner  = "AudriusButkevicius";
    repo   = "go-nat-pmp";
    sha256 = "0jjwqvanxxs15nhnkdx0mybxnyqm37bbg6yy0jr80czv623rp2bk";
    date = "2016-05-22";
    buildInputs = [
      gateway
    ];
  };

  go-ole = buildFromGitHub {
    rev = "v1.2.0";
    owner  = "go-ole";
    repo   = "go-ole";
    sha256 = "1bkvi5l2sshjrg1g9x1a4i337adrv1vhk8p1xrkx5z05nfwazvx0";
  };

  go-plugin = buildFromGitHub {
    rev = "8cf118f7a2f0c7ef1c82f66d4f6ac77c7e27dc12";
    date = "2016-06-07";
    owner  = "hashicorp";
    repo   = "go-plugin";
    sha256 = "1mgj52aml4l2zh101ksjxllaibd5r8h1gcgcilmb8p0c3xwf7lvq";
    buildInputs = [ yamux ];
  };

  go-querystring = buildFromGitHub {
    date = "2016-03-10";
    rev = "9235644dd9e52eeae6fa48efd539fdc351a0af53";
    owner  = "google";
    repo   = "go-querystring";
    sha256 = "0c0rmm98vz7sk7z6a1r07dp6jyb513cyr2y753sjpnyrc28xhdwg";
  };

  go-radix = buildFromGitHub {
    rev = "4239b77079c7b5d1243b7b4736304ce8ddb6f0f2";
    owner  = "armon";
    repo   = "go-radix";
    sha256 = "0b5vksrw462w1j5ipsw7fmswhpnwsnaqgp6klw714dc6ppz57aqv";
    date = "2016-01-15";
  };

  go-reap = buildFromGitHub {
    rev = "2d85522212dcf5a84c6b357094f5c44710441912";
    owner  = "hashicorp";
    repo   = "go-reap";
    sha256 = "0q90nf4mgvxb26vd7avs1mw1m9cb6x9mx6jnz4xsia71ghi3lj50";
    date = "2016-01-13";
    propagatedBuildInputs = [ sys ];
  };

  go-rootcerts = buildFromGitHub {
    rev = "6bb64b370b90e7ef1fa532be9e591a81c3493e00";
    owner = "hashicorp";
    repo = "go-rootcerts";
    sha256 = "0wi9ar5av0s4a2xarxh360kml3nkicrcdzzmhq1d406p10c3qjp2";
    date = "2016-05-03";
  };

  go-runewidth = buildFromGitHub {
    rev = "v0.0.1";
    owner = "mattn";
    repo = "go-runewidth";
    sha256 = "1sf0a2fbp2fp0lgizh2bjd3cgni35czvshx5clb2m6b604k7by9a";
  };

  go-simplejson = buildFromGitHub {
    rev = "v0.5.0";
    owner  = "bitly";
    repo   = "go-simplejson";
    sha256 = "09svnkziaffkbax5jjnjfd0qqk9cpai2gphx4ja78vhxdn4jpiw0";
  };

  go-spew = buildFromGitHub {
    rev = "5215b55f46b2b919f50a1df0eaa5886afe4e3b3d";
    date = "2015-11-05";
    owner  = "davecgh";
    repo   = "go-spew";
    sha256 = "1l4dg2xs0vj49gk0f5d4ij3hrwi72ay4w9a7xjkz1syg4qi9jy40";
  };

  go-sqlite3 = buildFromGitHub {
    rev = "38ee283dabf11c9cbdb968eebd79b1fa7acbabe6";
    date = "2016-05-14";
    owner  = "mattn";
    repo   = "go-sqlite3";
    sha256 = "1kahwmicakvkwi2k8mg97b7sfll2v506a50nksv2054x3gxdfw9q";
  };

  go-syslog = buildFromGitHub {
    date = "2015-02-18";
    rev = "42a2b573b664dbf281bd48c3cc12c086b17a39ba";
    owner  = "hashicorp";
    repo   = "go-syslog";
    sha256 = "0zbnlz1l1f50k8wjn8pgrkzdhr6hq4rcbap0asynvzw89crh7h4g";
  };

  go-systemd = buildFromGitHub {
    rev = "b32b8467dbea18858bfebf65c1a6a761090f2c31";
    owner = "coreos";
    repo = "go-systemd";
    sha256 = "1f8g3agzlfkr10l87q1aj3kflac658k71y6gzj6mh6f6hpdiirc1";
    propagatedBuildInputs = [
      dbus
      pkg
      pkgs.systemd_lib
    ];
    date = "2016-06-21";
  };

  go-systemd_journal = buildFromGitHub {
    inherit (go-systemd) rev owner repo sha256 date;
    subPackages = [
      "journal"
    ];
  };

  go-units = buildFromGitHub {
    rev = "v0.3.0";
    owner = "docker";
    repo = "go-units";
    sha256 = "15gnwpncr6ibxrvnj76r6j4fyskdixhjf6nc8vaib8lhx360avqc";
  };

  hashicorp-go-uuid = buildFromGitHub {
    rev = "73d19cdc2bf00788cc25f7d5fd74347d48ada9ac";
    date = "2016-03-29";
    owner  = "hashicorp";
    repo   = "go-uuid";
    sha256 = "1c8z6g9fyhbn35ps6agyf25mhqpsdpgr6kp3rq4kw2rsal6n8lqa";
  };

  go-version = buildFromGitHub {
    rev = "0181db47023708a38c2d20d2fe25a5fa034d5743";
    owner  = "hashicorp";
    repo   = "go-version";
    sha256 = "04kryh7dmz8zwd2kdma119fg6ydw2gm9zr041i8hr6dnjvrrp177";
    date = "2016-05-19";
  };

  go-zookeeper = buildFromGitHub {
    rev = "e64db453f3512cade908163702045e0f31137843";
    date = "2016-06-15";
    owner  = "samuel";
    repo   = "go-zookeeper";
    sha256 = "13rqz6v8q5gncdn5ca25n262slvs46h9grzym43z1wpwdpal4wwv";
  };

  gohtml = buildFromGitHub {
    owner = "yosssi";
    repo = "gohtml";
    rev = "ccf383eafddde21dfe37c6191343813822b30e6b";
    date = "2015-09-23";
    sha256 = "1ccniz4r354r2y4m2dz7ic9nywzi6jffnh44dy6icyqi64v9ydw7";
    propagatedBuildInputs = [
      net
    ];
  };

  groupcache = buildFromGitHub {
    date = "2016-05-15";
    rev = "02826c3e79038b59d737d3b1c0a1d937f71a4433";
    owner  = "golang";
    repo   = "groupcache";
    sha256 = "093p9jiid2c03d02g8fada7bl05244caddd7qjmjs0ggsrardc46";
    buildInputs = [ protobuf ];
  };

  grpc = buildFromGitHub {
    rev = "e78224b060cf3215247b7be455f80ea22e469b66";
    date = "2016-06-14";
    owner = "grpc";
    repo = "grpc-go";
    sha256 = "0adw7dviys0pbc2xk0z4w82pzrkpqjbv0r39lim7zz7qphp60zgy";
    goPackagePath = "google.golang.org/grpc";
    goPackageAliases = [ "github.com/grpc/grpc-go" ];
    propagatedBuildInputs = [ http2 net protobuf oauth2 glog ];
    excludedPackages = "\\(test\\|benchmark\\)";
  };

  gucumber = buildFromGitHub {
    date = "2016-05-11";
    rev = "5692705bb5ff96c5d7b33819b4739715008cc635";
    owner = "lsegal";
    repo = "gucumber";
    sha256 = "19hvwz21rmfkhxjdhj6jwjk0fmjwwa1yyfgvz9xyp7gi3fcnvnhy";
    buildInputs = [ testify ];
    propagatedBuildInputs = [ ansicolor ];
  };

  gx = buildFromGitHub {
    rev = "v0.7.0";
    owner = "whyrusleeping";
    repo = "gx";
    sha256 = "0c5nwmza4c07rh3j02bxgy7cqa8hc3gr5a1zhn150v15fix75l9l";
    propagatedBuildInputs = [
      go-homedir
      go-multiaddr
      go-multihash
      go-multiaddr-net
      semver
      go-git-ignore
      stump
      urfave_cli
      go-ipfs-api
    ];
    excludedPackages = [
      "tests"
    ];
  };

  gx-go = buildFromGitHub {
    rev = "v1.2.0";
    owner = "whyrusleeping";
    repo = "gx-go";
    sha256 = "008yfrax1kd9r63rqdi9fcqhy721bjq63d4ypm5d4nn0fbychg4s";
    buildInputs = [
      urfave_cli
      fs
      gx
      stump
    ];
  };

  hashstructure = buildFromGitHub {
    date = "2016-06-09";
    rev = "b098c52ef6beab8cd82bc4a32422cf54b890e8fa";
    owner  = "mitchellh";
    repo   = "hashstructure";
    sha256 = "0zg0q20hzg92xxsfsf2vn1kq044j8l7dh82fm7w7iyv03nwq0cxc";
  };

  hcl = buildFromGitHub {
    date = "2016-06-21";
    rev = "5b7dbf7eefffea49afb3c9655d6582c72fae5fd1";
    owner  = "hashicorp";
    repo   = "hcl";
    sha256 = "0fxg3alm0rbcz5s1a0ns0064avlsl217l5dgjx8yl4nd459337cz";
  };

  hil = buildFromGitHub {
    date = "2016-06-12";
    rev = "7130f7330953adacbfb4ca0ad4b14b806bce3762";
    owner  = "hashicorp";
    repo   = "hil";
    sha256 = "0rwyjn15vq0fk02vj1ykr68ar36kvhpm6lyq6d7s4bck5b8gxiyj";
    propagatedBuildInputs = [
      mapstructure
      reflectwalk
    ];
  };

  http2 = buildFromGitHub rec {
    rev = "aa7658c0e9902e929a9ed0996ef949e59fc0f3ab";
    owner = "bradfitz";
    repo = "http2";
    sha256 = "10x76xl5b6z2w0mbq7lnx7sl3cbdsp6gc1n3bis9lc0ilclzml65";
    buildInputs = [ crypto ];
    date = "2016-01-16";
  };

  httprouter = buildFromGitHub {
    rev = "77366a47451a56bb3ba682481eed85b64fea14e8";
    owner  = "julienschmidt";
    repo   = "httprouter";
    sha256 = "12hj2pc07nzha56rcpq6js0j7gs207blasxrixbwcwcgy9pamc80";
    date = "2016-02-19";
  };

  hugo = buildFromGitHub {
    owner = "spf13";
    repo = "hugo";
    rev = "v0.16";
    sha256 = "1jf8mwpzggridb3dip0dd1hzbzn0kkajfi5jy9vh3naakxzk11w7";
    buildInputs = [
      ace
      afero
      amber
      blackfriday
      cast
      cobra
      cssmin
      emoji
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
      yaml-v2
    ];
  };

  inf = buildFromGitHub {
    rev = "v0.9.0";
    owner  = "go-inf";
    repo   = "inf";
    sha256 = "0wqf867vifpfa81a1vhazjgfjjhiykqpnkblaxxj6ppyxlzrs3cp";
    goPackagePath = "gopkg.in/inf.v0";
    goPackageAliases = [ "github.com/go-inf/inf" ];
  };

  inflect = buildFromGitHub {
    owner = "bep";
    repo = "inflect";
    rev = "b896c45f5af983b1f416bdf3bb89c4f1f0926f69";
    date = "2016-04-08";
    sha256 = "13mjcnh6g7ml0gw24rbkfdjmkznjk4hcwfbxcbj5ydyfl0acq8wn";
  };

  ini = buildFromGitHub {
    rev = "v1.12.0";
    owner  = "go-ini";
    repo   = "ini";
    sha256 = "0kh539ajs00ciiizf9dbf0244hfgwcflz1plk8prj4iw9070air7";
  };

  iter = buildFromGitHub {
    rev = "454541ec3da2a73fc34fd049b19ee5777bf19345";
    owner  = "bradfitz";
    repo   = "iter";
    sha256 = "0sv6rwr05v219j5vbwamfvpp1dcavci0nwr3a2fgxx98pjw7hgry";
    date = "2014-01-23";
  };

  flagfile = buildFromGitHub {
    date = "2015-02-13";
    rev = "871ce569c29360f95d7596f90aa54d5ecef75738";
    owner  = "spacemonkeygo";
    repo   = "flagfile";
    sha256 = "0s7g6xsv5y75gzky43065r7mfvdbgmmr6jv0w2b3nyir3z00frxn";
  };

  ipfs = buildFromGitHub {
    rev = "v0.4.2";
    owner = "ipfs";
    repo = "go-ipfs";
    sha256 = "098jcmc94i5p0amm8g3fkizpchd8p4kqzdy2yy7m6q8sfjlsdg2m";
    gxSha256 = "0dxr1jrgsldv4154h2sj18q0mpmgnrq1dzqfrnynhzfs2q3rq50k";

    subPackages = [
      "cmd/ipfs"
    ];
  };

  jwalterweatherman = buildFromGitHub {
    owner = "spf13";
    repo = "jWalterWeatherman";
    rev = "33c24e77fb80341fe7130ee7c594256ff08ccc46";
    date = "2016-03-01";
    sha256 = "0w6risn5iwx9b0sn0f6z2yfs3p1gqa22asy3hkix1p81a1xmsidc";
    goPackageAliases = [
      "github.com/spf13/jwalterweatherman"
    ];
  };

  jwt-go = buildFromGitHub {
    owner = "dgrijalva";
    repo = "jwt-go";
    rev = "v2.7.0";
    sha256 = "2af35dbb8eace9e84faf6d6f7c6aab6776492b002e5c9587513c5d1d5f8e8ab3";
  };

  kingpin-v2 = buildFromGitHub {
    rev = "v2.1.11";
    owner = "alecthomas";
    repo = "kingpin";
    goPackagePath = "gopkg.in/alecthomas/kingpin.v2";
    sha256 = "0s3xz1pwqdfk466nk2qj1r5p1n9qh6y7ndik44yq56i5k3lxb9qg";
    propagatedBuildInputs = [
      template
      units
    ];
  };

  ldap = buildFromGitHub {
    rev = "v2.3.0";
    owner  = "go-ldap";
    repo   = "ldap";
    sha256 = "1iwapk3z1cz6q1a4hfyp857ny2skdjjx7hjhbcn6q5fd64ldpv8y";
    goPackageAliases = [
      "github.com/nmcclain/ldap"
      "github.com/vanackere/ldap"
    ];
    propagatedBuildInputs = [ asn1-ber ];
  };

  lego = buildFromGitHub {
    rev = "v0.3.1";
    owner = "xenolf";
    repo = "lego";
    sha256 = "12bry70rgdi0i9dybhaq1vfa83ac5cdka86652xry1j7a8gq0z76";

    buildInputs = [
      aws-sdk-go
      urfave_cli
      crypto
      dns
      weppos-dnsimple-go
      go-ini
      go-jose
      goamz
      google-api-go-client
      oauth2
      net
      vultr
    ];

    subPackages = [
      "."
    ];
  };

  log15-v2 = buildFromGitHub {
    rev = "v2.11";
    owner  = "inconshreveable";
    repo   = "log15";
    sha256 = "1krlgq3m0q40y8bgaf9rk7zv0xxx5z92rq8babz1f3apbdrn00nq";
    goPackagePath = "gopkg.in/inconshreveable/log15.v2";
    propagatedBuildInputs = [
      go-colorable
    ];
  };

  logrus = buildFromGitHub rec {
    rev = "v0.10.0";
    owner = "Sirupsen";
    repo = "logrus";
    sha256 = "1rf70m0r0x3rws8334rmhj8wik05qzxqch97c31qpfgcl96ibnfb";
  };

  logutils = buildFromGitHub {
    date = "2015-06-09";
    rev = "0dc08b1671f34c4250ce212759ebd880f743d883";
    owner  = "hashicorp";
    repo   = "logutils";
    sha256 = "11p4p01x37xcqzfncd0w151nb5izmf3sy77vdwy0dpwa9j8ccgmw";
  };

  luhn = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "calmh";
    repo   = "luhn";
    sha256 = "13brkbbmj9bh0b9j3avcyrj542d78l9hg3bxj7jjvkp5n5cxwp41";
  };

  lxd = buildFromGitHub {
    rev = "lxd-2.0.2";
    owner  = "lxc";
    repo   = "lxd";
    sha256 = "1d935hv0h48l9i5a023mkmy9jy0fg5i0nwq9gp3xfkqb8r3rjvq8";
    excludedPackages = "test"; # Don't build the binary called test which causes conflicts
    buildInputs = [
      crypto
      gettext
      gocapability
      golang-petname
      go-lxc-v2
      go-sqlite3
      go-systemd
      log15-v2
      pkgs.lxc
      mux
      pborman_uuid
      pongo2-v3
      protobuf
      tablewriter
      tomb-v2
      yaml-v2
      websocket
    ];
  };

  mathutil = buildFromGitHub {
    date = "2016-06-13";
    rev = "78ad7f262603437f0ecfebc835d80094f89c8f54";
    owner = "cznic";
    repo = "mathutil";
    sha256 = "1m3nfvymw912bii4cim0vwcgs1k0fmbmcms6h38aqxh0gkxgd8mq";
    buildInputs = [ bigfft ];
  };

  mapstructure = buildFromGitHub {
    date = "2016-02-11";
    rev = "d2dd0262208475919e1a362f675cfc0e7c10e905";
    owner  = "mitchellh";
    repo   = "mapstructure";
    sha256 = "1pmjkrlz0mvs90ysag12pp4sldhfm1m91472w50wjaqhda028ijh";
  };

  mdns = buildFromGitHub {
    date = "2015-12-05";
    rev = "9d85cf22f9f8d53cb5c81c1b2749f438b2ee333f";
    owner = "hashicorp";
    repo = "mdns";
    sha256 = "0hsbhh0v0jpm4cg3hg2ffi2phis4vq95vyja81rk7kzvml17pvag";
    propagatedBuildInputs = [ net dns ];
  };

  memberlist = buildFromGitHub {
    date = "2016-06-21";
    rev = "b2053e314b4a87e5f0d2d47aeafd3e03be13da90";
    owner = "hashicorp";
    repo = "memberlist";
    sha256 = "1hkjda75h8zbmq9zy49fdjxgkibs8jwkwif60dlpigcjvwq2307c";
    propagatedBuildInputs = [
      dns
      ugorji_go
      armon_go-metrics
      go-multierror
    ];
  };

  mgo = buildFromGitHub {
    rev = "r2016.02.04";
    owner = "go-mgo";
    repo = "mgo";
    sha256 = "0q968aml9p5x49x70ay7myfg6ibggckir3gam5n6qydj6rviqpy7";
    goPackagePath = "gopkg.in/mgo.v2";
    goPackageAliases = [ "github.com/go-mgo/mgo" ];
    buildInputs = [ pkgs.cyrus-sasl tomb-v2 ];
  };

  missinggo = buildFromGitHub {
    rev = "e40875155efce3d98562ca9e265e152c364ada3e";
    owner  = "anacrolix";
    repo   = "missinggo";
    sha256 = "3054fbcab4329c3daf10b080adad3f67209433b0bed1440a0056d469a3feb04b";
    date = "2016-05-30";
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
  };

  missinggo_lib = buildFromGitHub {
    inherit (missinggo) rev owner repo sha256 date;
    subPackages = [
      "."
    ];
    propagatedBuildInputs = [
      iter
    ];
  };

  mmark = buildFromGitHub {
    owner = "miekg";
    repo = "mmark";
    rev = "v1.3.4";
    sha256 = "0mpnn6894j6cwvxq29vh3k06jg46swy58ff60i9vjqn942cklkvv";
    buildInputs = [
      toml
    ];
  };

  mongo-tools = buildFromGitHub {
    rev = "r3.3.4";
    owner  = "mongodb";
    repo   = "mongo-tools";
    sha256 = "1rb9ifrl411r097wvbbgi21lb46ssfmgj67fb27lj6izbz69sdx8";
    buildInputs = [ crypto mgo go-flags gopass openssl tomb-v2 ];

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
    rev = "772320464101e904cd51198160eb4d489be9cc49";
    owner  = "jawher";
    repo   = "mow.cli";
    sha256 = "1dwy7pwh3mig3xj1x8bcd8cm6ilv2581vah9rwi992agx3b8318s";
    date = "2016-02-21";
  };

  mux = buildFromGitHub {
    rev = "v1.1";
    owner = "gorilla";
    repo = "mux";
    sha256 = "1iicj9v3ippji2i1jf2g0jmrvql1k2yydybim3hsb0jashnq7794";
    propagatedBuildInputs = [ context ];
  };

  muxado = buildFromGitHub {
    date = "2016-06-21";
    rev = "ae9295605c1ab40eda134187357025d368f68c84";
    owner  = "inconshreveable";
    repo   = "muxado";
    sha256 = "0j0imiwzcp6fykd6l3z0jknnq14kzyab9j3qym8r6rf03v1nd1r8";
  };

  mysql = buildFromGitHub {
    rev = "3654d25ec346ee8ce71a68431025458d52a38ac0";
    owner  = "go-sql-driver";
    repo   = "mysql";
    sha256 = "17kw9n01zks3l76ybrdzib2x9bc1r6rsnnmyl8blw1w216bwd7bz";
    date = "2016-06-02";
  };

  net-rpc-msgpackrpc = buildFromGitHub {
    date = "2015-11-15";
    rev = "a14192a58a694c123d8fe5481d4a4727d6ae82f3";
    owner = "hashicorp";
    repo = "net-rpc-msgpackrpc";
    sha256 = "007pwdpap465b32cx1i2hmf2q67vik3wk04xisq2pxvqvx81irks";
    propagatedBuildInputs = [ ugorji_go go-multierror ];
  };

  netlink = buildFromGitHub {
    rev = "734d02c3e202f682c74b71314b2c61eec0170fd4";
    owner  = "vishvananda";
    repo   = "netlink";
    sha256 = "0dv9l8w5h3l4jsw7d7qllgh7pyjaqgm701rk3xnpqgr9mjpfqv93";
    date = "2016-06-20";
    propagatedBuildInputs = [
      netns
    ];
  };

  netns = buildFromGitHub {
    rev = "8ba1072b58e0c2a240eb5f6120165c7776c3e7b8";
    owner  = "vishvananda";
    repo   = "netns";
    sha256 = "05r4qri45ngm40kp9qdbyqrs15gx7swjj27bmc7i04wg9yd65j95";
    date = "2016-04-30";
  };

  nitro = buildFromGitHub {
    owner = "spf13";
    repo = "nitro";
    rev = "24d7ef30a12da0bdc5e2eb370a79c659ddccf0e8";
    date = "2013-10-03";
    sha256 = "1dbnfac79lxc1pr1j1n3956i292ck4yjrhr8nsd2wp2jccab5zdz";
  };

  nomad = buildFromGitHub {
    rev = "v0.3.2";
    owner = "hashicorp";
    repo = "nomad";
    sha256 = "53d6347f4e5f64590cc6c6ffec9e0ec42bfefd91e6c331fb2cbc6f32423394df";

    buildInputs = [
      datadog-go wmi armon_go-metrics go-radix aws-sdk-go perks speakeasy
      bolt go-systemd go-units go-humanize go-dockerclient ini go-ole
      dbus protobuf cronexpr consul-api errwrap go-checkpoint go-cleanhttp
      go-getter go-immutable-radix go-memdb go-multierror go-syslog
      go-version golang-lru hcl logutils memberlist net-rpc-msgpackrpc raft
      raft-boltdb scada-client serf yamux syslogparser go-jmespath osext
      go-isatty golang_protobuf_extensions mitchellh_cli copystructure
      hashstructure mapstructure reflectwalk runc prometheus_client_golang
      prometheus_common prometheus_procfs columnize gopsutil ugorji_go sys
      go-plugin circbuf go-spew
    ];

    subPackages = [
      "."
    ];
  };

  objx = buildFromGitHub {
    date = "2015-09-28";
    rev = "1a9d0bb9f541897e62256577b352fdbc1fb4fd94";
    owner  = "stretchr";
    repo   = "objx";
    sha256 = "0ycjvfbvsq6pmlbq2v7670w1k25nydnz4scx0qgiv0f4llxnr0y9";
  };

  openssl = buildFromGitHub {
    date = "2015-03-30";
    rev = "4c6dbafa5ec35b3ffc6a1b1e1fe29c3eba2053ec";
    owner = "10gen";
    repo = "openssl";
    sha256 = "1yyq8acz9pb19mnr9j5hd0axpw6xlm8fbqnkp4m16mmfjd6l5kii";
    goPackageAliases = [ "github.com/spacemonkeygo/openssl" ];
    nativeBuildInputs = [ pkgs.pkgconfig ];
    buildInputs = [ pkgs.openssl ];
    propagatedBuildInputs = [ spacelog ];

    preBuild = ''
      find go/src/$goPackagePath -name \*.go | xargs sed -i 's,spacemonkeygo/openssl,10gen/openssl,g'
    '';
  };

  osext = buildFromGitHub {
    date = "2015-12-22";
    rev = "29ae4ffbc9a6fe9fb2bc5029050ce6996ea1d3bc";
    owner = "kardianos";
    repo = "osext";
    sha256 = "05803q7snh1pcwjs5f8g35wfhv21j0mp6yk9agmcx50rjcn3x6qr";
    goPackageAliases = [
      "github.com/bugsnag/osext"
      "bitbucket.org/kardianos/osext"
    ];
  };

  perks = buildFromGitHub rec {
    date = "2014-07-16";
    owner  = "bmizerany";
    repo   = "perks";
    rev = "d9a9656a3a4b1c2864fdb44db2ef8619772d92aa";
    sha256 = "1p5aay4x3q255vrdqv2jcl45acg61j3bz6xgljvqdhw798cyf6a3";
  };

  beorn7_perks = buildFromGitHub rec {
    date = "2016-02-29";
    owner  = "beorn7";
    repo   = "perks";
    rev = "3ac7bf7a47d159a033b107610db8a1b6575507a4";
    sha256 = "1swhv3v8vxgigldpgzzbqxmzdwpvjdii11a3xql677mfbvgv7mpq";
  };

  pflag = buildFromGitHub {
    owner = "spf13";
    repo = "pflag";
    rev = "367864438f1b1a3c7db4da06a2f55b144e6784e0";
    date = "2016-06-10";
    sha256 = "18g0sv7wzl6j1p1j055hlaacz54lp57063d4gy8pbi70phys1qfy";
  };

  pkcs7 = buildFromGitHub {
    owner = "fullsailor";
    repo = "pkcs7";
    rev = "9ab43480afa35dcb6df2c5b80e5e158f421c03c7";
    date = "2016-06-05";
    sha256 = "1l58fj2f4cc2gn38r16n2yl38p3r0l5na2sjx8a9w17kvv91jqr3";
  };

  pkg = buildFromGitHub rec {
    date = "2016-06-20";
    owner  = "coreos";
    repo   = "pkg";
    rev = "fa29b1d70f0beaddd4c7021607cc3c3be8ce94b8";
    sha256 = "1dr9ajrlcqhzklawwklandax93xaj2igvynbwpp6plw13v1g24k5";
    buildInputs = [
      crypto
      go-systemd_journal
      yaml-v1
    ];
  };

  pongo2-v3 = buildFromGitHub {
    rev = "v3.0";
    owner  = "flosch";
    repo   = "pongo2";
    sha256 = "1qjcj7hcjskjqp03fw4lvn1cwy78dck4jcd0rcrgdchis1b84isk";
    goPackagePath = "gopkg.in/flosch/pongo2.v3";
  };

  pq = buildFromGitHub {
    rev = "e2402a7cd1e57e08a576b94cdfed36ae30366545";
    owner  = "lib";
    repo   = "pq";
    sha256 = "16x0k7m7q62z7xrrp3x31ia2707ysxfqr5k9z9sa90hgsndrxcnr";
    date = "2016-02-11";
  };

  prometheus_client_golang = buildFromGitHub {
    rev = "488edd04dc224ba64c401747cd0a4b5f05dfb234";
    owner = "prometheus";
    repo = "client_golang";
    sha256 = "0fvsa9qg10cswzdal96w90gk96h96wdm8cji1rrdf83zccbr7src";
    propagatedBuildInputs = [
      goautoneg
      net
      protobuf
      prometheus_client_model
      prometheus_common_for_client
      prometheus_procfs
      beorn7_perks
    ];
    date = "2016-05-31";
  };

  prometheus_client_model = buildFromGitHub {
    rev = "fa8ad6fec33561be4280a8f0514318c79d7f6cb6";
    date = "2015-02-12";
    owner  = "prometheus";
    repo   = "client_model";
    sha256 = "150fqwv7lnnx2wr8v9zmgaf4hyx1lzd4i1677ypf6x5g2fy5hh6r";
    buildInputs = [
      protobuf
    ];
  };

  prometheus_common = buildFromGitHub {
    date = "2016-06-07";
    rev = "3a184ff7dfd46b9091030bf2e56c71112b0ddb0e";
    owner = "prometheus";
    repo = "common";
    sha256 = "1nvchgb0zirf22ywpsl63068nhrj19pr57xzrdsqg4nvz2sgdcb0";
    buildInputs = [ net prometheus_client_model httprouter logrus protobuf ];
    propagatedBuildInputs = [
      golang_protobuf_extensions
      prometheus_client_golang
    ];
  };

  prometheus_common_for_client = buildFromGitHub {
    inherit (prometheus_common) date rev owner repo sha256;
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

  prometheus_procfs = buildFromGitHub {
    rev = "abf152e5f3e97f2fafac028d2cc06c1feb87ffa5";
    date = "2016-04-11";
    owner  = "prometheus";
    repo   = "procfs";
    sha256 = "08536i8yaip8lv4zas4xa59igs4ybvnb2wrmil8rzk3a2hl9zck8";
  };

  properties = buildFromGitHub {
    owner = "magiconair";
    repo = "properties";
    rev = "v1.7.0";
    sha256 = "00s9b7fmzhg3j55hs48s3pvzslfj54k1h9vicj782gg79pgid785";
  };

  purell = buildFromGitHub {
    owner = "PuerkitoBio";
    repo = "purell";
    rev = "1d5d1cfad45d42ec5f81fa8ef23de09cebc6dcc3";
    date = "2016-06-07";
    sha256 = "0f6x59470ck9rzjf0lfcnbzadk8awv8dpdindryplm2my7z6d74w";
    propagatedBuildInputs = [
      urlesc
    ];
  };

  qart = buildFromGitHub {
    rev = "0.1";
    owner  = "vitrun";
    repo   = "qart";
    sha256 = "02n7f1j42jp8f4nvg83nswfy6yy0mz2axaygr6kdqwj11n44rdim";
  };

  ql = buildFromGitHub {
    rev = "v1.0.3";
    owner  = "cznic";
    repo   = "ql";
    sha256 = "1r1370h0zpkhi9fs57vx621vsj8g9j0ijki0y4mpw18nz2mq620n";
    propagatedBuildInputs = [
      go4
      b
      exp
      strutil
    ];
  };

  rabbit-hole = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "michaelklishin";
    repo   = "rabbit-hole";
    sha256 = "1gff1h7kzgmkc4f9l1kx6lx21is421xs0l7v8szf7pzdpczrf15r";
  };

  raft = buildFromGitHub {
    date = "2016-06-21";
    rev = "7877922807c08bb7ae6e7ff46ffeada14041034e";
    owner  = "hashicorp";
    repo   = "raft";
    sha256 = "1zf2ac0ib21x8amx4xgmbwqyk22jv4i2mk1m9mwpaz8afzniji6h";
    propagatedBuildInputs = [ armon_go-metrics ugorji_go ];
  };

  raft-boltdb = buildFromGitHub {
    date = "2015-02-01";
    rev = "d1e82c1ec3f15ee991f7cc7ffd5b67ff6f5bbaee";
    owner  = "hashicorp";
    repo   = "raft-boltdb";
    sha256 = "07g818sprpnl0z15wl16wj9dvyl9igqaqa0w4y7mbfblnpydvgis";
    propagatedBuildInputs = [ bolt ugorji_go raft ];
  };

  ratelimit = buildFromGitHub {
    rev = "77ed1c8a01217656d2080ad51981f6e99adaa177";
    date = "2015-11-25";
    owner  = "juju";
    repo   = "ratelimit";
    sha256 = "0m7bvg8kg9ffl624lbcq47207n6r54z9by1wy0axslishgp1lh98";
  };

  raw = buildFromGitHub {
    rev = "724aedf6e1a5d8971aafec384b6bde3d5608fba4";
    owner  = "feyeleanor";
    repo   = "raw";
    sha256 = "0pkvvvln5cyyy0y2i82jv39gjnfgzpb5ih94iav404lfsachh8m1";
    date = "2013-03-27";
  };

  reflectwalk = buildFromGitHub {
    date = "2015-05-27";
    rev = "eecf4c70c626c7cfbb95c90195bc34d386c74ac6";
    owner  = "mitchellh";
    repo   = "reflectwalk";
    sha256 = "0zpapfp4vx9zr3zlw2405clgix7jzhhdphmsyhar4yhhs04fb3qz";
  };

  roaring = buildFromGitHub {
    rev = "v0.2.5";
    owner  = "RoaringBitmap";
    repo   = "roaring";
    sha256 = "1kc85xpk5p0fviywck9ci3i8nzsng34gx29i2j3322ax1nyj93ap";
  };

  runc = buildFromGitHub {
    rev = "v0.1.1";
    owner  = "opencontainers";
    repo   = "runc";
    sha256 = "1d508sfy6853b3j6ki02fs681ws23d8vgicxi0hwp8gna8ih9x2c";
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
  };

  runtime-spec = buildFromGitHub {
    rev = "8399dc9f956d298bdb5a0b65a7774f1e8542709c";
    date = "2016-06-21";
    owner  = "opencontainers";
    repo   = "runtime-spec";
    sha256 = "5deb586cabedb0c09e8cedd187e3589a3567ed36e175034ed87adc344a5fba2c";
    buildInputs = [
      gojsonschema
    ];
  };

  sanitized-anchor-name = buildFromGitHub {
    owner = "shurcooL";
    repo = "sanitized_anchor_name";
    rev = "10ef21a441db47d8b13ebcc5fd2310f636973c77";
    date = "2015-10-27";
    sha256 = "0pmkdx914ir0a1inrjaa68r1c27cga1dr8gwx333c8vffiy08kkw";
  };

  scada-client = buildFromGitHub {
    date = "2016-06-01";
    rev = "6e896784f66f82cdc6f17e00052db91699dc277d";
    owner  = "hashicorp";
    repo   = "scada-client";
    sha256 = "1by4kyd2hrrrghwj7snh9p8fdlqka24q9yr6nyja2acs2zpjgh7a";
    buildInputs = [ armon_go-metrics net-rpc-msgpackrpc yamux ];
  };

  semver = buildFromGitHub {
    rev = "v3.2.0";
    owner = "blang";
    repo = "semver";
    sha256 = "1m56r23bilzm3fdx003zm0iajb655fmyz9k9piqbhf1ygzgc7109";
  };

  serf = buildFromGitHub {
    rev = "v0.7.0";
    owner  = "hashicorp";
    repo   = "serf";
    sha256 = "1qzphmv2kci14v5xis08by1bhl09a3yhjy0glyh1wk0s96mx2d1b";

    buildInputs = [
      net circbuf armon_go-metrics ugorji_go go-syslog logutils mdns memberlist
      dns mitchellh_cli mapstructure columnize
    ];
  };

  sets = buildFromGitHub {
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
    owner = "pkg";
    repo = "sftp";
    rev = "57fcf4a640a942eb05181f929601f8f4409eda3e";
    date = "2016-06-22";
    sha256 = "19xf7xk5y2r21g5rddrvwlrlrn5bdsm6hd5cnwpqnlwk9faklh2a";
    propagatedBuildInputs = [
      crypto
      errors
      fs
    ];
  };

  slices = buildFromGitHub {
    rev = "bb44bb2e4817fe71ba7082d351fd582e7d40e3ea";
    owner  = "feyeleanor";
    repo   = "slices";
    sha256 = "05i934pmfwjiany6r9jgp27nc7bvm6nmhflpsspf10d4q0y9x8zc";
    date = "2013-02-25";
    propagatedBuildInputs = [
      raw
    ];
  };

  sortutil = buildFromGitHub {
    date = "2015-06-17";
    rev = "4c7342852e65c2088c981288f2c5610d10b9f7f4";
    owner = "cznic";
    repo = "sortutil";
    sha256 = "11iykyi1d7vjmi7778chwbl86j6s1742vnd4k7n1rvrg7kq558xq";
  };

  spacelog = buildFromGitHub {
    date = "2016-06-06";
    rev = "f936fb050dc6b5fe4a96b485a6f069e8bdc59aeb";
    owner = "spacemonkeygo";
    repo = "spacelog";
    sha256 = "008npp1bdza55wqyv157xd1512xbpar6hmqhhs3bi5xh7xlwpswj";
    buildInputs = [ flagfile ];
  };

  speakeasy = buildFromGitHub {
    date = "2016-05-20";
    rev = "e1439544d8ecd0f3e9373a636d447668096a8f81";
    owner = "bgentry";
    repo = "speakeasy";
    sha256 = "1aks9mz0xrgxb9fvpf9pac104zwamzv2j53bdirgxsjn12904cqm";
  };

  stathat = buildFromGitHub {
    date = "2016-06-13";
    rev = "c828dca0ee6eadc566bfcbcc00e4a992f12821a3";
    owner = "stathat";
    repo = "go";
    sha256 = "1cqm1ghwn0z6jc16snxxds8n9i05jjg2305fkm4ki4mqnv0r3shq";
  };

  structs = buildFromGitHub {
    date = "2016-06-15";
    rev = "c7685df069270748b8101edee16c4e1e6589712c";
    owner  = "fatih";
    repo   = "structs";
    sha256 = "04cd4mdd5vqkkbh33cb24zn01jrldmlyxyygah2gvprb6ld8y1fn";
  };

  stump = buildFromGitHub {
    date = "2016-06-11";
    rev = "206f8f13aae1697a6fc1f4a55799faf955971fc5";
    owner = "whyrusleeping";
    repo = "stump";
    sha256 = "0qmchkr29rzscc148aw2vb2qf5dma2dka0ys96cx5fxa4p516d3i";
  };

  strutil = buildFromGitHub {
    date = "2015-04-30";
    rev = "1eb03e3cc9d345307a45ec82bd3016cde4bd4464";
    owner = "cznic";
    repo = "strutil";
    sha256 = "0ipn9zaihxpzs965v3s8c9gm4rc4ckkihhjppchr3hqn2vxwgfj1";
  };

  suture = buildFromGitHub {
    rev = "v1.1.1";
    owner  = "thejerf";
    repo   = "suture";
    sha256 = "0hpi9swsln9nrj4c18hac8905g8nbgfd8arpi8v118pasx5pw2l0";
  };

  swift = buildFromGitHub {
    rev = "b964f2ca856aac39885e258ad25aec08d5f64ee6";
    owner  = "ncw";
    repo   = "swift";
    sha256 = "1dxhb26pa8j0rzn3w5jdfs56dzf2qv6k28jf5kn4d403y2rvfv99";
    date = "2016-06-17";
  };

  sync = buildFromGitHub {
    rev = "812602587b72df6a2a4f6e30536adc75394a374b";
    owner  = "anacrolix";
    repo   = "sync";
    sha256 = "10rk5fkchbmfzihyyxxcl7bsg6z0kybbjnn1f2jk40w18vgqk50r";
    date = "2015-10-30";
    buildInputs = [
      missinggo
    ];
  };

  syncthing = buildFromGitHub rec {
    rev = "v0.13.7";
    owner = "syncthing";
    repo = "syncthing";
    sha256 = "0vd7i8fy4wqljx8rg0adqpyl785g6wh649fyfl0vc56vi74adxmj";
    buildFlags = [ "-tags noupgrade" ];
    buildInputs = [
      go-lz4 du luhn xdr snappy ratelimit osext
      goleveldb suture qart crypto net text rcrowley_go-metrics
      go-nat-pmp glob gateway ql groupcache pq
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
    inherit (syncthing) rev owner repo sha256;
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
    rev = "ff71fe7a7d5279df4b964b31f7ee4adf117277f6";
    date = "2015-07-17";
    owner  = "jeromer";
    repo   = "syslogparser";
    sha256 = "1x1nq7kyvmfl019d3rlwx9nqlqwvc87376mq3xcfb7f5vxlmz9y5";
  };

  tablewriter = buildFromGitHub {
    rev = "daf2955e742cf123959884fdff4685aa79b63135";
    date = "2016-06-21";
    owner  = "olekukonko";
    repo   = "tablewriter";
    sha256 = "096014asbb9d27wyyrg81n922icf7p0r0wr2cipg6ymqrfa2d32f";
    propagatedBuildInputs = [
      go-runewidth
    ];
  };

  tagflag = buildFromGitHub {
    rev = "e7497e81ffa475caf0fc24e999eb29edc0335040";
    date = "2016-06-16";
    owner  = "anacrolix";
    repo   = "tagflag";
    sha256 = "0w14w9xv7j1y8a19mb3jsqb5fm50nr50fdjh59h3bavx2vvn9caw";
    propagatedBuildInputs = [
      go-humanize
      missinggo_lib
      xstrings
    ];
  };

  tar-utils = buildFromGitHub {
    rev = "beab27159606f5a7c978268dd1c3b12a0f1de8a7";
    date = "2016-03-22";
    owner  = "whyrusleeping";
    repo   = "tar-utils";
    sha256 = "0p0cmk30b22bgfv4m29nnk2359frzzgin2djhysrqznw3wjpn3nz";
  };

  template = buildFromGitHub {
    rev = "a0175ee3bccc567396460bf5acd36800cb10c49c";
    owner = "alecthomas";
    repo = "template";
    sha256 = "10albmv2bdrrgzzqh1rlr88zr2vvrabvzv59m15wazwx39mqzd7p";
    date = "2016-04-05";
  };

  testify = buildFromGitHub {
    rev = "v1.1.3";
    owner = "stretchr";
    repo = "testify";
    sha256 = "12r2v07zq22bk322hn8dn6nv1fg04wb5pz7j7bhgpq8ji2sassdp";
    propagatedBuildInputs = [ objx go-difflib go-spew ];
  };

  tokenbucket = buildFromGitHub {
    rev = "c5a927568de7aad8a58127d80bcd36ca4e71e454";
    date = "2013-12-01";
    owner = "ChimeraCoder";
    repo = "tokenbucket";
    sha256 = "11zasaakzh4fzzmmiyfq5mjqm5md5bmznbhynvpggmhkqfbc28gz";
  };

  tomb-v2 = buildFromGitHub {
    date = "2014-06-26";
    rev = "14b3d72120e8d10ea6e6b7f87f7175734b1faab8";
    owner = "go-tomb";
    repo = "tomb";
    sha256 = "1ixpcahm1j5s9rv52al1k8047hsv7axxqvxcpdpa0lr70b33n45f";
    goPackagePath = "gopkg.in/tomb.v2";
    goPackageAliases = [ "github.com/go-tomb/tomb" ];
  };

  toml = buildFromGitHub {
    owner = "BurntSushi";
    repo = "toml";
    rev = "v0.2.0";
    sha256 = "1sqhi5rx27scpcygdzipbhx4l6x4mjjxkbh5hg00wzqhfwhy4mxw";
  };

  units = buildFromGitHub {
    rev = "2efee857e7cfd4f3d0138cc3cbb1b4966962b93a";
    owner = "alecthomas";
    repo = "units";
    sha256 = "1jj055kgx6mfx5zw263ci70axk3z5006db74dqhcilxwk1a2ga23";
    date = "2015-10-22";
  };

  urlesc = buildFromGitHub {
    owner = "PuerkitoBio";
    repo = "urlesc";
    rev = "5fa9ff0392746aeae1c4b37fcc42c65afa7a9587";
    sate = "2015-02-08";
    sha256 = "00cil3qsy9agswkaagihvmmg67zklgk899h09p49wp7bxgj45rnk";
    date = "2015-02-08";
  };

  utp = buildFromGitHub {
    rev = "d7ad5aff2b8a5fa415d1c1ed00b71cfd8b4c69e0";
    owner  = "anacrolix";
    repo   = "utp";
    sha256 = "148gsqvb47bpvnf232g1k1095bqpvhr3l22bscn8chbf6xyp5fjz";
    date = "2016-06-01";
    propagatedBuildInputs = [
      envpprof
      missinggo
      sync
    ];
  };

  pborman_uuid = buildFromGitHub {
    rev = "v1.0";
    owner = "pborman";
    repo = "uuid";
    sha256 = "1yk7vxrhsyk5izazdqywzfwb7iq6b5lwwdp0yc4rl4spqx30s0f9";
  };

  vault = buildFromGitHub rec {
    rev = "v0.6.0";
    owner = "hashicorp";
    repo = "vault";
    sha256 = "0fpiwbzfirw0s9zvvyc40nzjm8hh5mjxfs0wf7m0lclr8ij8dk26";

    buildInputs = [
      azure-sdk-for-go
      armon_go-metrics
      go-radix
      govalidator
      aws-sdk-go
      speakeasy
      candiedyaml
      etcd-client
      go-mssqldb
      duo_api_golang
      structs
      pkcs7
      yaml
      ini
      ldap
      mysql
      gocql
      protobuf
      snappy
      go-github
      go-querystring
      hailocab_go-hostpool
      consul-api
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
      #ugorji_go
      crypto
      net
      oauth2
      sys
      appengine
      asn1-ber
      inf
    ];
  };

  vault-api = buildFromGitHub {
    inherit (vault) rev owner repo sha256;
    subPackages = [ "api" ];
    propagatedBuildInputs = [
      hcl
      structs
      go-cleanhttp
      go-multierror
      go-rootcerts
      mapstructure
    ];
  };

  viper = buildFromGitHub {
    owner = "spf13";
    repo = "viper";
    rev = "c1ccc378a054ea8d4e38d8c67f6938d4760b53dd";
    date = "2016-06-06";
    sha256 = "1zhvyh8zq7c9j65l2jc2gaxmyvygfvxfjqn0hi5a938x7csydx90";
    buildInputs = [
      crypt
      pflag
    ];
    propagatedBuildInputs = [
      cast
      fsnotify
      hcl
      jwalterweatherman
      mapstructure
      properties
      toml
      yaml-v2
    ];
    patches = [
      (fetchTritonPatch {
        file = "viper/viper-2016-06-remove-etcd-support.patch";
        rev = "89c1dace6882bef6b3f05e5e6da3e9166665ef57";
        sha256 = "3cd7132e57b325168adf3f547f5123f744864ba8630ca653b8ee1e928e0e1ac9";
      })
    ];
  };

  vultr = buildFromGitHub {
    rev = "v1.8";
    owner  = "JamesClonk";
    repo   = "vultr";
    sha256 = "1m8y850kkz0y4wlq4amkqx5ayfw5j5d5x9i37a3xnzjxlcsini78";
    propagatedBuildInputs = [
      mow-cli
      tokenbucket
      ratelimit
    ];
  };

  websocket = buildFromGitHub {
    rev = "v1.0.0";
    owner  = "gorilla";
    repo   = "websocket";
    sha256 = "11sggyd6plhcd4bdi8as0bx70bipda8li1rdf0y2n5iwnar3qflq";
  };

  wmi = buildFromGitHub {
    rev = "f3e2bae1e0cb5aef83e319133eabfee30013a4a5";
    owner = "StackExchange";
    repo = "wmi";
    sha256 = "1paiis0l4adsq68v5p4mw7g7vv39j06fawbaph1d3cglzhkvsk7q";
    date = "2015-05-20";
  };

  yaml = buildFromGitHub {
    rev = "aa0c862057666179de291b67d9f093d12b5a8473";
    date = "2016-06-03";
    owner = "ghodss";
    repo = "yaml";
    sha256 = "0vayx9m09flqlkwx8jy4cih01d8637cvnm1x3yxfvzamlb5kdm9p";
    propagatedBuildInputs = [ candiedyaml ];
  };

  yaml-v2 = buildFromGitHub {
    rev = "a83829b6f1293c91addabc89d0571c246397bbf4";
    date = "2016-03-01";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "0jf2man0a6jz02zcgqaadqa3844jz5kihrb343jq52xp2180zwzz";
    goPackagePath = "gopkg.in/yaml.v2";
  };

  yaml-v1 = buildFromGitHub {
    rev = "9f9df34309c04878acc86042b16630b0f696e1de";
    date = "2014-09-24";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "128xs9pdz042hxl28fi2gdrz5ny0h34xzkxk5rxi9mb5mq46w8ys";
    goPackagePath = "gopkg.in/yaml.v1";
  };

  yamux = buildFromGitHub {
    date = "2016-06-09";
    rev = "badf81fca035b8ebac61b5ab83330b72541056f4";
    owner  = "hashicorp";
    repo   = "yamux";
    sha256 = "063capa74w4q6sj2bm9gs75vri3cxa06pzgzly17rl5grzilsw3y";
  };

  xdr = buildFromGitHub {
    rev = "v2.0.0";
    owner  = "calmh";
    repo   = "xdr";
    sha256 = "017k3y66fy2azbv9iymxsixpyda9czz8v3mhpn17750vlg842dsp";
  };

  xstrings = buildFromGitHub {
    rev = "3959339b333561bf62a38b424fd41517c2c90f40";
    date = "2015-11-30";
    owner  = "huandu";
    repo   = "xstrings";
    sha256 = "16l1cqpqsgipa4c6q55n8vlnpg9kbylkx1ix8hsszdikj25mcig1";
  };

  zappy = buildFromGitHub {
    date = "2016-03-05";
    rev = "4f5e6ef19fd692f1ef9b01206de4f1161a314e9a";
    owner = "cznic";
    repo = "zappy";
    sha256 = "1kinbjs95hv16kn4cgm3vb1yzv09ina7br5m3ygh803qzxp7i5jz";
  };
}; in self
