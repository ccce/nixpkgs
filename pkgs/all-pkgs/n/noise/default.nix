{ stdenv
, cmake
, fetchurl
, gettext
, makeWrapper

, adwaita-icon-theme
, gdk-pixbuf
, glib
, gobject-introspection
, granite
, gst-plugins-bad
, gst-plugins-base
, gst-plugins-good
, gst-plugins-ugly
, gstreamer
, gtk3
, json-glib
#, libdbusmenu
, libgee
, libgpod
#, libindicate
, libnotify
, libpeas
, librsvg
, libsoup
, libxml2
, sqlheavy
, taglib
, vala
, zeitgeist

, atk
, cairo
, pango
}:

let
  inherit (stdenv.lib)
    makeSearchPath;

  channel = "0.4";
  version = "${channel}";
in
stdenv.mkDerivation rec {
  name = "noise-${version}";

  src = fetchurl {
    url = "https://launchpad.net/noise/${channel}.x/${version}/" +
          "+download/${name}.tar.xz";
    sha256 = "ae7b1f07df1f1e773c602cad224188ebc26799f1b759525b114edc698d044ab1";
  };

  nativeBuildInputs = [
    cmake
    gettext
    makeWrapper
  ];

  buildInputs = [
    adwaita-icon-theme
    gdk-pixbuf
    glib
    gobject-introspection
    granite
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gstreamer
    gtk3
    json-glib
    #libdbusmenu
    libgee
    libgpod
    #libindicate
    libnotify
    libpeas
    libsoup
    libxml2
    sqlheavy
    taglib
    vala
    zeitgeist
  ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
    "-DICON_UPDATE=OFF"
    "-DGSETTINGS_COMPILE=ON"
    "-DVALA_EXECUTABLE=${vala}/bin/valac"
  ];

  preFixup = ''
    wrapProgram $out/bin/noise \
      --set 'GDK_PIXBUF_MODULE_FILE' "$GDK_PIXBUF_MODULE_FILE" \
      --set 'GI_TYPELIB_PATH' "$GI_TYPELIB_PATH" \
      --prefix 'GST_PLUGIN_PATH' : "$GST_PLUGIN_PATH" \
      --prefix 'XDG_DATA_DIRS' : "$out/share" \
      --prefix 'XDG_DATA_DIRS' : "$GSETTINGS_SCHEMAS_PATH" \
      --prefix 'XDG_DATA_DIRS' : "$XDG_ICON_DIRS"
  '';

  meta = with stdenv.lib; {
    description = "Music player for Elementary OS";
    homepage = https://launchpad.net/noise;
    license = licenses.gpl3;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
