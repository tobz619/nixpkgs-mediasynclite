{ buildGoModule
, copyDesktopItems
, fetchFromGitLab
, lib
, libGL
, libX11
, libXcursor
, libXext
, libXi
, libXinerama
, libXrandr
, makeDesktopItem
, mesa
, pkg-config
, stdenv
}:

buildGoModule rec {
  pname = "clipqr";
  version = "1.1.0";

  src = fetchFromGitLab {
    owner = "imatt-foss";
    repo = "clipqr";
    rev = "v${version}";
    hash = "sha256-OQ45GV+bViIejGC03lAuvw/y8v1itA+6pFC4H/qL744=";
  };

  vendorHash = null;

  ldflags = [ "-s" "-w" ];

  buildInputs = [
    libGL
    libX11
    libXcursor
    libXext
    libXi
    libXinerama
    libXrandr
    mesa
  ];

  nativeBuildInputs = [
    copyDesktopItems
    pkg-config
  ];

  postInstall = ''
    install -Dm644 icon.svg $out/share/icons/hicolor/scalable/apps/clipqr.svg
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "ClipQR";
      desktopName = "ClipQR";
      exec = "clipqr";
      categories = [ "Utility" ];
      icon = "clipqr";
      comment = "Scan QR codes on screen and from camera";
      genericName = "ClipQR";
    })
  ];

  meta = with lib; {
    description = "Scan QR codes on screen and from camera, the result is in your clipboard";
    license = licenses.mit;
    maintainers = with maintainers; [ MatthieuBarthel ];
    homepage = "https://gitlab.com/imatt-foss/clipqr";
    broken = stdenv.isDarwin;
  };
}
