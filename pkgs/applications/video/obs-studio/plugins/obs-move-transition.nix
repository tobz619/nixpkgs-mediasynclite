{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
}:

stdenv.mkDerivation rec {
  pname = "obs-move-transition";
  version = "2.9.6";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-move-transition";
    rev = version;
    sha256 = "sha256-A3R78JvjOdYE9/ZZ+KbZ5Ula9HC5E/u7BrqE2i6VwYs=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = with lib; {
    description = "Plugin for OBS Studio to move source to a new position during scene transition";
    homepage = "https://github.com/exeldro/obs-move-transition";
    maintainers = with maintainers; [ starcraft66 ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
