{ fetchFromGitHub
, lib
, protobuf
, rocksdb
, rust-jemalloc-sys-unprefixed
, rustPlatform
, rustc-wasm32
, stdenv
, Security
, SystemConfiguration
}:
rustPlatform.buildRustPackage rec {
  pname = "polkadot";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "paritytech";
    repo = "polkadot-sdk";
    rev = "v${version}";
    hash = "sha256-Tblknr9nU6X4lKMW8ZPOo7jZ/MoE8e8G58NnLITzhxY=";

    # the build process of polkadot requires a .git folder in order to determine
    # the git commit hash that is being built and add it to the version string.
    # since having a .git folder introduces reproducibility issues to the nix
    # build, we check the git commit hash after fetching the source and save it
    # into a .git_commit file, and then delete the .git folder. we can then use
    # this file to populate an environment variable with the commit hash, which
    # is picked up by polkadot's build process.
    leaveDotGit = true;
    postFetch = ''
      ( cd $out; git rev-parse --short HEAD > .git_commit )
      rm -rf $out/.git
    '';
  };

  preBuild = ''
    export SUBSTRATE_CLI_GIT_COMMIT_HASH=$(< .git_commit)
    rm .git_commit
  '';

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "ark-secret-scalar-0.0.2" = "sha256-rnU9+rf0POv4GuxKUp9Wv4/eNXi5gfGq+XhJLxpmSzU=";
      "common-0.1.0" = "sha256-ru++KG2ZZqa/wDGnKF/VfWnazHRSpOAD0WYb7rHlpCU=";
      "fflonk-0.1.0" = "sha256-MNvlePHQdY8DiOq6w7Hc1pgn7G58GDTeghCKHJdUy7E=";
      "simple-mermaid-0.1.0" = "sha256-IekTldxYq+uoXwGvbpkVTXv2xrcZ0TQfyyE2i2zH+6w=";
      "sp-ark-bls12-381-0.4.2" = "sha256-nNr0amKhSvvI9BlsoP+8v6Xppx/s7zkf0l9Lm3DW8w8=";
      "sp-crypto-ec-utils-0.4.1" = "sha256-cv2mr5K6mAKiACVzS7mPOIpoyt8iUfGZXsqVuiGXbL0=";
    };
  };

  buildType = "production";

  cargoBuildFlags = [ "-p" "polkadot" ];

  # NOTE: tests currently fail to compile due to an issue with cargo-auditable
  # and resolution of features flags, potentially related to this:
  # https://github.com/rust-secure-code/cargo-auditable/issues/66
  doCheck = false;

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    rustc-wasm32
    rustc-wasm32.llvmPackages.lld
  ];

  # NOTE: jemalloc is used by default on Linux with unprefixed enabled
  buildInputs = lib.optionals stdenv.isLinux [ rust-jemalloc-sys-unprefixed ] ++
    lib.optionals stdenv.isDarwin [ Security SystemConfiguration ];

  # NOTE: we need to force lld otherwise rust-lld is not found for wasm32 target
  CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER = "lld";
  PROTOC = "${protobuf}/bin/protoc";
  ROCKSDB_LIB_DIR = "${rocksdb}/lib";

  meta = with lib; {
    description = "Polkadot Node Implementation";
    homepage = "https://polkadot.network";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ akru andresilva FlorianFranzen RaghavSood ];
    platforms = platforms.unix;
  };
}
