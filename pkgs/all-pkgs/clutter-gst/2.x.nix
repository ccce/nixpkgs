{ stdenv
, fetchurl

, atk
, clutter
, cogl
, glib
, gobject-introspection
, gst-plugins-base
, gstreamer
, gtk3
, json-glib
, pango
}:

let
  inherit (stdenv.lib)
    enFlag;

  versionMajor = "2.0";
  versionMinor = "16";
  version = "${versionMajor}.${versionMinor}";
in

stdenv.mkDerivation rec {
  name = "clutter-gst-${version}";

  src = fetchurl {
    url = "mirror://gnome/sources/clutter-gst/${versionMajor}/${name}.tar.xz";
    sha256 = "0f90fkywwn9ww6a8kfjiy4xx65b09yaj771jlsmj2w4khr0zhi59";
  };

  buildInputs = [
    atk
    clutter
    cogl
    glib
    gobject-introspection
    gstreamer
    gst-plugins-base
    gtk3
    json-glib
    pango
  ];

  configureFlags = [
    "--disable-maintainer-flags"
    "--disable-debug"
    "--disable-gtk-doc"
    "--disable-gtk-doc-html"
    "--disable-gtk-doc-pdf"
    (enFlag "introspection" (gobject-introspection != null) null)
  ];

  postBuild = "rm -rf $out/share/gtk-doc";

  meta = with stdenv.lib; {
    description = "GStreamer bindings for clutter";
    homepage = http://www.clutter-project.org/;
    license = licenses.lgpl2Plus;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms =  with platforms;
      x86_64-linux;
  };
}
