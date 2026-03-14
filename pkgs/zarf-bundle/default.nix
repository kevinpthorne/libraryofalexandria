{ pkgs, clusterName ? "unknown", helmCharts ? [], lib, ... }:
let
  # collect charts, images
  chartPackages = builtins.map (chartModule: chartModule.config.chartPackage) helmCharts;
  images = builtins.concatMap (chartModule: chartModule.config.images) helmCharts;

  nullable = val: default: if val == null then default else val;

  # Generate the zarf.yaml
  # We use the oci:// prefix to tell Zarf to look at local folders, not the internet
  zarfConfig = {
    kind = "ZarfPackageConfig";
    metadata = { name = "loa-${clusterName}-bootstrap-bundle"; };
    components = [
      # {
      #   # fixes helm crd upgrade problem
      #   name = "system-crds";
      #   required = true;
      #   manifests = [
      #     {
      #       name = "extracted-crds";
      #       namespace = "kube-system";
      #       files = [ "extracted-crds/**/*.yaml" ];
      #     }
      #   ];
      # }
      {
        name = "${clusterName}-charts";
        required = true;
        charts = builtins.map (chartModule: {
          name = chartModule.config.name;
          namespace = nullable chartModule.config.namespace "default";
          version = nullable chartModule.config.version "0.1.0";
          localPath = "./charts/${baseNameOf chartModule.config.chartPackage}";
          valuesFiles = [ "./charts/${baseNameOf chartModule.config.valuesPackage}" ];
        }) helmCharts;
        # images = lib.mapAttrsToList (img: _: "oci://./oci-store/${img}") imageHashes;
        images = builtins.map (image: "oci:oci-store:${image.config.name}") images;
      }
    ];
  };

  zarfYaml = pkgs.writeText "zarf.yaml" (builtins.toJSON zarfConfig);
in
pkgs.stdenv.mkDerivation {
  name = "loa-${clusterName}-zarf-bundle";
  src = ./.;
  
  nativeBuildInputs = [ pkgs.zarf pkgs.skopeo ];

  # No network access required here!
  buildPhase = ''
    set -x

    # --- SKOPEO/CONTAINER POLICY FIX ---
    # Create a fake home directory structure inside the Nix sandbox
    export HOME=$(pwd)
    mkdir -p $HOME/.config/containers
    
    # Write a permissive policy to allow skopeo to read the local tarballs
    cat <<EOF > $HOME/.config/containers/policy.json
    {
      "default": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    }
    EOF
    # -----------------------------------

    mkdir -p oci-store charts extracted-crds
    chmod -R +w .

    cp ${zarfYaml} ./zarf.yaml

    # copy charts and values
    ${lib.concatStringsSep "\n" (builtins.map (chartModule: ''
      cp -r ${chartModule.config.chartPackage} ./charts/${baseNameOf chartModule.config.chartPackage} || true
      cp -r ${chartModule.config.valuesPackage} ./charts/${baseNameOf chartModule.config.valuesPackage} || true
    '') helmCharts)}

    # Convert the dockerTools tarballs into an OCI layout that Zarf can read
    # We map the pulledImages array into the oci-store directory
    ${lib.concatStringsSep "\n" (builtins.map (imgDrv: ''
      skopeo copy docker-archive:${images.config.package} oci:oci-store:${images.config.name}
    '') images)}

    chmod -R +w charts oci-store

    # Build the Zarf bundle entirely offline
    zarf package create --confirm --output .

    set +x
  '';

  installPhase = ''
    set -x
    mkdir -p $out
    cp zarf.yaml $out/
    cp zarf-package-*.tar.zst $out/
    set +x
  '';
}