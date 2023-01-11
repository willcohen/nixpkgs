{ lib
, stdenv
, mkDerivation
, fetchFromGitHub
, cmake
, ninja
, flex
, bison
, proj
, geos
, sqlite
, gsl
, qwt
, fcgi
, python3
, libspatialindex
, libspatialite
, postgresql
, txt2tags
, openssl
, libzip
, libtasn1
, utmp
, hdf5
, netcdf
, exiv2
, protobuf
, qtbase
, qtsensors
, qca-qt5
, qtkeychain
, qt3d
, qscintilla
, qtlocation
, qtserialport
, qtxmlpatterns
, withGrass ? true
, grass
, withWebKit ? false
, qtwebkit
, pdal
, zstd
, makeWrapper
, wrapGAppsHook
, substituteAll
}:

let

  py = python3.override {
    packageOverrides = self: super: {
      pyqt5 = super.pyqt5.override {
        withLocation = true;
      };
    };
  };

  pythonBuildInputs = with py.pkgs; [
    qscintilla-qt5
    gdal
    jinja2
    numpy
    psycopg2
    chardet
    python-dateutil
    pyyaml
    pytz
    requests
    urllib3
    pygments
    pyqt5
    pyqt-builder
    sip
    setuptools
    owslib
    six
  ];
in mkDerivation rec {
  version = "3.22.14";
  pname = "qgis-ltr-unwrapped";

  src = fetchFromGitHub {
    owner = "qgis";
    repo = "QGIS";
    rev = "final-${lib.replaceStrings [ "." ] [ "_" ] version}";
    hash = "sha256-VT85cVeKuHQCGQokID9yrbents7ewHK1j7I17oFTvlo=";
  };

  passthru = {
    inherit pythonBuildInputs;
    inherit py;
  };

  buildInputs = [
    openssl
    proj
    geos
    sqlite
    gsl
    qwt
    exiv2
    protobuf
    fcgi
    libspatialindex
    libspatialite
    postgresql
    txt2tags
    libzip
    libtasn1
    hdf5
    netcdf
    qtbase
    qtsensors
    qca-qt5
    qtkeychain
    qscintilla
    qtlocation
    qtserialport
    qtxmlpatterns
    qt3d
    zstd
  ] ++ lib.optional withGrass grass
    ++ lib.optional withWebKit qtwebkit
    ++ lib.optional stdenv.isLinux pdal
    ++ lib.optional stdenv.isDarwin utmp
    ++ pythonBuildInputs;

  nativeBuildInputs = [ makeWrapper wrapGAppsHook cmake flex bison ninja ];

  patches = [
    (substituteAll {
      src = ./set-pyqt-package-dirs.patch;
      pyQt5PackageDir = "${py.pkgs.pyqt5}/${py.pkgs.python.sitePackages}";
      qsciPackageDir = "${py.pkgs.qscintilla-qt5}/${py.pkgs.python.sitePackages}";
    })
  ];

  cmakeFlags = [
    "-DWITH_3D=True"
  ] ++ lib.optional (!withWebKit) "-DWITH_QTWEBKIT=OFF"
    ++ lib.optional stdenv.isLinux "-DWITH_PDAL=TRUE"
    ++ lib.optional withGrass (let
        gmajor = lib.versions.major grass.version;
        gminor = lib.versions.minor grass.version;
      in "-DGRASS_PREFIX${gmajor}=${grass}/grass${gmajor}${gminor}"
    );

  dontWrapGApps = true; # wrapper params passed below
  dontWrapQtApps = stdenv.isDarwin;

  postFixup = lib.optionalString (withGrass && stdenv.isLinux) ''
    # grass has to be availble on the command line even though we baked in
    # the path at build time using GRASS_PREFIX.
    # using wrapGAppsHook also prevents file dialogs from crashing the program
    # on non-NixOS
    wrapProgram $out/bin/qgis \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ grass ]}
  '' + lib.optionalString stdenv.isDarwin ''
    mkdir -p $out/Applications
    mkdir -p $out/bin
    mv $out/QGIS.app $out/Applications/
    ln -s $out/Applications/QGIS.app/Contents/MacOS/QGIS $out/bin/qgis
    export SHORT_VERSION=$(echo "${version}" | awk 'BEGIN{FS=OFS="."} NF--')
    echo "Short version: $SHORT_VERSION"
    for f in $out/Applications/QGIS.app/Contents/MacOS/lib/libqgis_app.${version}.dylib \
             $out/Applications/QGIS.app/Contents/MacOS/lib/libqgispython.${version}.dylib \
             $out/Applications/QGIS.app/Contents/MacOS/QGIS \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_3d.framework/Versions/$SHORT_VERSION/qgis_3d \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_analysis.framework/Versions/$SHORT_VERSION/qgis_analysis \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_core.framework/Versions/$SHORT_VERSION/qgis_core \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_gui.framework/Versions/$SHORT_VERSION/qgis_gui \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_native.framework/Versions/$SHORT_VERSION/qgis_native \
             $out/Applications/QGIS.app/Contents/Frameworks/qgisgrass8.framework/Versions/$SHORT_VERSION/qgisgrass8 \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_3d.framework/qgis_3d \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_analysis.framework/qgis_analysis \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_core.framework/qgis_core \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_gui.framework/qgis_gui \
             $out/Applications/QGIS.app/Contents/Frameworks/qgis_native.framework/qgis_native \
             $out/Applications/QGIS.app/Contents/Frameworks/qgisgrass8.framework/qgisgrass8
      do
        echo "Manually running install_name_tool on $f"
        install_name_tool -change "@loader_path/../lib/libqscintilla2_qt5.dylib" "${qscintilla}/lib/libqscintilla2_qt5.dylib" $f
        install_name_tool -change "@loader_path/../lib/libqt5keychain.dylib" "${qtkeychain}/lib/libqt5keychain.dylib" $f
        install_name_tool -change "@loader_path/../lib/libqwt.dylib" "${qwt}/lib/libqwt.dylib" $f
        install_name_tool -change "@loader_path/../../Frameworks/qca-qt5.framework/qca-qt5" "${qca-qt5}/lib/qca-qt5.framework/qca-qt5" $f
        install_name_tool -change "@loader_path/../../../qca-qt5.framework/qca-qt5" "${qca-qt5}/lib/qca-qt5.framework/qca-qt5" $f
        install_name_tool -change "@loader_path/../../../../MacOS/lib/libqscintilla2_qt5.dylib" "${qscintilla}/lib/libqscintilla2_qt5.dylib" $f
        install_name_tool -change "@loader_path/../../../../MacOS/lib/libqt5keychain.dylib" "${qtkeychain}/lib/libqt5keychain.dylib" $f
        install_name_tool -change "@loader_path/../../../../MacOS/lib/libqwt.dylib" "${qwt}/lib/libqwt.dylib" $f
        install_name_tool -change "@loader_path/../../../qgis_3d.framework/qgis_core" "$out/Applications/QGIS.app/Contents/Frameworks/qgis_core.framework/Versions/$SHORT_VERSION/qgis_core" $f
        install_name_tool -change "@loader_path/../../../qgis_analysis.framework/qgis_analysis" "$out/Applications/QGIS.app/Contents/Frameworks/qgis_analysis.framework/Versions/$SHORT_VERSION/qgis_analysis" $f
        install_name_tool -change "@loader_path/../../../qgis_core.framework/qgis_core" "$out/Applications/QGIS.app/Contents/Frameworks/qgis_core.framework/Versions/$SHORT_VERSION/qgis_core" $f
        install_name_tool -change "@loader_path/../../../qgis_gui.framework/qgis_gui" "$out/Applications/QGIS.app/Contents/Frameworks/qgis_gui.framework/Versions/$SHORT_VERSION/qgis_gui" $f
        install_name_tool -change "@loader_path/../../../qgis_native.framework/qgis_native" "$out/Applications/QGIS.app/Contents/Frameworks/qgis_native.framework/Versions/$SHORT_VERSION/qgis_native" $f
        install_name_tool -change "@loader_path/../../../qgisgrass8.framework/qgisgrass8" "$out/Applications/QGIS.app/Contents/Frameworks/qgisgrass8.framework/Versions/$SHORT_VERSION/qgisgrass8" $f
        install_name_tool -change "@executable_path/lib/libqwt.dylib" "${qwt}/lib/libqwt.dylib" $f
        install_name_tool -change "@executable_path/lib/libqscintilla2_qt5.dylib" "${qscintilla}/lib/libqscintilla2_qt5.dylib" $f
        install_name_tool -change "@executable_path/lib/libqt5keychain.dylib" "${qtkeychain}/lib/libqt5keychain.dylib" $f
        install_name_tool -change "@executable_path/../Frameworks/qca-qt5.framework/qca-qt5" "${qca-qt5}/lib/qca-qt5.framework/qca-qt5" $f
    done
  '';

  meta = {
    description = "A Free and Open Source Geographic Information System";
    homepage = "https://www.qgis.org";
    license = lib.licenses.gpl2Plus;
    platforms = with lib.platforms; unix;
    maintainers = with lib.maintainers; [ lsix sikmir erictapen willcohen ];
  };
}
