{
  runCommand,
  symlinkJoin,
  writeShellScriptBin,
  qt6,
}:
let
  qtLibPatched = runCommand "qt6-lib-with-prl" { } ''
    mkdir -p $out
    for f in \
      ${qt6.qtbase}/lib/* \
      ${qt6.qtmultimedia}/lib/*
    do
      ln -sfn "$f" "$out/$(basename "$f")"
    done

    for mod in Qt6Qml Qt6Quick Qt6QuickControls2 Qt6QuickShapes; do
      if [ ! -e "$out/lib''${mod}.prl" ]; then
        cat > "$out/lib''${mod}.prl" <<EOF
    QMAKE_PRL_TARGET = $mod
    QMAKE_PRL_CONFIG = qt warn_on release
    QMAKE_PRL_VERSION = 6.11.0
    QMAKE_PRL_LIBS =
    EOF
      fi
    done
  '';
  qtToolsMerged = symlinkJoin {
    name = "qt6-tools-merged";
    paths = with qt6; [
      qtbase
      qtdeclarative
      qttools
      qtwayland
    ];
  };
  qtIncludeMerged = symlinkJoin {
    name = "qt6-include-merged";
    paths = with qt6; [
      qtbase
      qtdeclarative
      qttools
      qtwayland
    ];
  };
  qmakeWrapper = writeShellScriptBin "qmake-wrapper" ''
    if [ "$1" = "-query" ]; then
      case "$2" in
        QT_HOST_LIBEXECS|QT_INSTALL_LIBEXECS)
          echo "${qtToolsMerged}/libexec"
          exit 0
          ;;

        QT_HOST_BINS|QT_INSTALL_BINS)
          echo "${qtToolsMerged}/bin"
          exit 0
          ;;

        QT_HOST_LIBS|QT_INSTALL_LIBS)
          echo "${qtLibPatched}"
          exit 0
          ;;

        QT_HOST_HEADERS|QT_INSTALL_HEADERS)
          echo "${qtIncludeMerged}/include"
          exit 0
          ;;
      esac
    fi
    exec ${qt6.qtbase}/bin/qmake6 "$@"
  '';
in
{
  inherit
    qtLibPatched
    qtToolsMerged
    qtIncludeMerged
    qmakeWrapper
    ;
}
