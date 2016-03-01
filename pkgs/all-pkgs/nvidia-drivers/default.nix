{ stdenv
, fetchTritonPatch
, fetchurl

, buildConfig ? "all"
, channel ? null

# Kernelspace dependencies
, kernel ? null
, nukeReferences

# Userspace dependencies
, xlibs
, zlib

# Just needed for the passthru driver path
, mesa_noglu

, libsOnly ? false

, nvidiasettingsSupport ? true
  , atk
  , gdk-pixbuf
  , glib
  , pango
  , gtk2 # <346
  , gtk3 # >346
  , cairo
}:

/* NOTICE: ONLY versions 304+ are supported on Triton
 *
 * BETA:        361.xx,   xorg <=1.18.x, linux <=4.4
 * SHORTLIVED:  358.xx,   xorg <=1.18.x, linux <=4.4
 * LONGLIVED:   352.xx,   xorg <=1.18.x, linux <=4.4 (stable) <- default
 * LEGACY:      340.xx,   xorg <=1.18.x, linux <=4.4
 * LEGACY:      304.xx,   xorg <=1.18.x, linux <=4.4
 * UNSUPPORTED: 173.14.x, xorg <=1.15.x, linux <=3.13
 * UNSUPPORTED: 96.43.x,  xorg <=1.12.x, linux <=3.7
 * UNSUPPORTED: 71.86.x,  xorg <=?,      linux <=?
 *
 * If your gpu requires a version that is unsupported it is
 * recommended to use the nouveau driver.
 */

with {
  inherit (stdenv)
    system
    isx86_64;
  inherit (stdenv.lib)
    any
    makeLibraryPath
    optionals
    optionalString
    versionAtLeast
    versionOlder;
  inherit (builtins.getAttr channel (import ./sources.nix))
    versionMajor
    versionMinor
    sha256i686
    sha256x86_64;
};

let
  version = "${versionMajor}.${versionMinor}";
  buildKernelspace = any (n: n == buildConfig) [ "kernelspace" "all" ];
  buildUserspace = any (n: n == buildConfig) [ "userspace" "all" ];
in

assert any (n: n == buildConfig) [
  "kernelspace"
  "userspace"
  "all"
];
assert any (n: n == channel) [
  "legacy304"
  "legacy340"
  "long-lived"
  "short-lived"
  "testing"
];
assert buildKernelspace -> kernel != null;
assert nvidiasettingsSupport -> (
  atk != null &&
  gdk-pixbuf != null &&
  glib != null &&
  pango != null
  # TODO: add gtk2/3 requirement
);
assert libsOnly -> !buildKernelspace;

stdenv.mkDerivation {
  name = "nvidia-drivers-${buildConfig}-${version}"
       + "${optionalString buildKernelspace "-${kernel.version}"}";

  src = fetchurl {
    url =
      if system == "i686-linux" then
        "http://us.download.nvidia.com/XFree86/Linux-x86/${version}/" +
        "NVIDIA-Linux-x86-${version}.run"
      else if system == "x86_64-linux" then
        "http://us.download.nvidia.com/XFree86/Linux-x86_64/${version}/" +
        "NVIDIA-Linux-x86_64-${version}-no-compat32.run"
      else
        throw "The NVIDIA drivers do not support the `${system}' platform";
    sha256 =
      if system == "i686-linux" then
        sha256i686
      else if system == "x86_64-linux" then
        sha256x86_64
      else
        throw "The NVIDIA drivers do not support the `${system}' platform";
  };

  kernel =
    if buildKernelspace then
      kernel.dev
    else
      null;

  disallowedReferences =
    if buildKernelspace then
      [ kernel.dev ]
    else
      [ ];

  patches =
    optionals (versionAtLeast versionMajor "346" &&
               versionOlder versionMajor "355") [
      (fetchTritonPatch {
        rev = "d3fc5e59bd2b4b465c2652aae5e7428b24eb5669";
        file = "nvidia-drivers/linux-4.2.patch";
        sha256 = "01fe34a2eeb88057d51849098966e202f1ab94e548afe85ef25f533c8375e3c3";
      })
    ];

  # Make sure anything that isn't declared within the derivation
  # is inherited so that it is passed to the builder.
  inherit
    buildKernelspace
    buildUserspace
    libsOnly
    nvidiasettingsSupport
    version
    versionMajor;

  nativeBuildInputs = [ nukeReferences ];

  builder = ./builder.sh;

  glPath = makeLibraryPath [
    xlibs.libXext
    xlibs.libX11
    xlibs.libXrandr
  ];
  programPath = makeLibraryPath [
    xlibs.libXv
  ];
  allLibPath = makeLibraryPath [
    stdenv.cc.cc
    xlibs.libX11
    xlibs.libXext
    xlibs.libXrandr
    zlib
  ];
  gtkPath = optionalString (!libsOnly) (
    makeLibraryPath (
      [
        atk
        pango
        glib
        gdk-pixbuf
      ] ++ (
        if versionAtLeast versionMajor "346" then [
          cairo
          gtk3
        ] else [
          gtk2
        ]
      )
    )
  );

  dontStrip = true;
  enableParallelBuilding = true;

  passthru = {
    inherit
      version
      versionMajor;
    inherit (mesa_noglu)
      driverSearchPath;
    nvenc =
      if versionAtLeast versionMajor "340" then
        true
      else
        false;
    cudaUVM =
      if ((versionAtLeast versionMajor "340" &&
           versionOlder versionMajor "346") ||
          (versionAtLeast versionMajor "346" &&
           isx86_64)) then
        true
      else
        false;
  };

  meta = with stdenv.lib; {
    description = "Drivers and Linux kernel modules for NVIDIA graphics cards";
    homepage = http://www.nvidia.com/object/unix.html;
    license = licenses.unfreeRedistributable;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      i686-linux
      ++ x86_64-linux;
    # Resolves collision w/ xorg-server "lib/xorg/modules/extensions/libglx.so"
    priority = 4;
  };
}
