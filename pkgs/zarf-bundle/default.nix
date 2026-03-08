{ pkgs, clusterName ? "unknown", helmCharts ? [], lib, ... }:
let
  # collect charts, images
  chartPackages = builtins.map (chartModule: chartModule.config.chartPackage) helmCharts;
  imagePackages = builtins.concatMap (chartModule: chartModule.config.imagePackages) helmCharts;

  # Generate the zarf.yaml
  # We use the oci:// prefix to tell Zarf to look at local folders, not the internet
  zarfConfig = {
    kind = "ZarfPackageConfig";
    metadata = { name = "loa-${clusterName}-bootstrap-bundle"; };
    components = [
      {
        # fixes helm crd upgrade problem
        name = "system-crds";
        required = true;
        manifests = [
          {
            name = "extracted-crds";
            namespace = "kube-system";
            files = [ "extracted-crds/**/*.yaml" ];
          }
        ];
      }
      {
        name = "${clusterName}-charts";
        # TODO this this right?
        charts = builtins.map (chartModule: {
          name = chartModule.config.name;
          localPath = chartModule.config.chartPackage;
          valuesFiles = [ chartModule.config.valuesPackage ];
        }) helmCharts;
        # images = lib.mapAttrsToList (img: _: "oci://./oci-store/${img}") imageHashes;
        images = builtins.map (imgDrv: "oci://./oci-store/${imgDrv}") imagePackages;
      }
    ];
  };

  zarfYaml = pkgs.writeText "zarf.yaml" (builtins.toJSON zarfConfig);
in
pkgs.stdenv.mkDerivation {
  name = "loa-${clusterName}-zarf-bundle";
  
  nativeBuildInputs = [ pkgs.zarf pkgs.skopeo ] ++ chartPackages ++ imagePackages;

  # No network access required here!
  buildPhase = ''
    mkdir -p oci-store charts extracted-crds
    
    cp ${zarfYaml} ./zarf.yaml

    # Copy charts and extract CRDs
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: drvPath: ''
      cp ${drvPath} ./charts/${name}.tgz
      
      # Unpack to a temporary directory
      mkdir -p /tmp/${name}-unpack
      tar -xzf ./charts/${name}.tgz -C /tmp/${name}-unpack
      
      # If the chart has a crds directory, copy its contents
      if [ -d /tmp/${name}-unpack/*/crds ]; then
        echo "Extracting CRDs for ${name}..."
        cp -r /tmp/${name}-unpack/*/crds/* ./extracted-crds/
      fi
      rm -rf /tmp/${name}-unpack
    '') chartPackages)}

    # Convert the dockerTools tarballs into an OCI layout that Zarf can read
    # We map the pulledImages array into the oci-store directory
    ${lib.concatStringsSep "\n" (lib.imap0 (i: imgDrv: ''
      skopeo copy docker-archive:${imgDrv} oci:./oci-store/image-${toString i}
    '') imagePackages)}

    # Build the Zarf bundle entirely offline
    zarf package create --confirm --output .
  '';

  installPhase = ''
    mkdir -p $out
    cp zarf.yaml $out/
    cp zarf-package-*.tar.zst $out/
  '';
}