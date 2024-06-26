{ lib, go, buildGoModule, fetchFromGitHub, installShellFiles }:

buildGoModule rec {
  pname = "vcluster";
  version = "0.17.0";

  src = fetchFromGitHub {
    owner = "loft-sh";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-xmSp3cNqNv48gBWpt0Pnvl3l5gIyV1oPNGrB58X+OVU=";
  };

  vendorHash = null;

  subPackages = [ "cmd/vclusterctl" ];

  nativeBuildInputs = [ installShellFiles ];

  ldflags = [
    "-s" "-w"
    "-X main.version=${version}"
    "-X main.goVersion=${lib.getVersion go}"
  ];

  # Test is disabled because e2e tests expect k8s.
  doCheck = false;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 "$GOPATH/bin/vclusterctl" -T $out/bin/vcluster
    runHook postInstall
  '';

  postInstall = ''
    installShellCompletion --cmd vcluster \
      --bash <($out/bin/vcluster completion bash) \
      --zsh <($out/bin/vcluster completion zsh)
  '';

  meta = with lib; {
    description = "Create fully functional virtual Kubernetes clusters";
    downloadPage = "https://github.com/loft-sh/vcluster";
    homepage = "https://www.vcluster.com/";
    license = licenses.asl20;
    maintainers = with maintainers; [ peterromfeldhk berryp qjoly ];
  };
}
