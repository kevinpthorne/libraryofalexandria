{
  pkgs,
  clusterName ? "unknown",
  helmCharts ? [ ],
  lib,
  ...
}:
let
  # collect charts, images
  chartPackages = builtins.map (chartModule: chartModule.chartPackage) helmCharts;
  images = builtins.concatMap (chartModule: chartModule.images) helmCharts;

  nullable = val: default: if val == null then default else val;
  localOciRepo = "oci-store";
  ociRefOf = image: "oci:${localOciRepo}:${baseNameOf image.imageName}_${image.finalImageTag}";

  # Generate the zarf.yaml
  # We use the oci:// prefix to tell Zarf to look at local folders, not the internet
  zarfConfig = {
    kind = "ZarfPackageConfig";
    metadata = {
      name = "loa-${clusterName}-bootstrap-bundle";
    };
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
          name = chartModule.name;
          namespace = nullable chartModule.namespace "default";
          version = nullable chartModule.version "0.1.0";
          localPath = "./charts/${baseNameOf (nullable chartModule.chartPackage "unlocked-chart-please-lock-charts")}";
          valuesFiles = [ "./charts/${baseNameOf chartModule.valuesPackage}" ];
        }) helmCharts;
        # images = lib.mapAttrsToList (img: _: "oci://./oci-store/${img}") imageHashes;
        images = builtins.map (image: ociRefOf image) images;
      }
    ];
  };

  zarfYaml = pkgs.writeText "zarf.yaml" (builtins.toJSON zarfConfig);
in
pkgs.stdenv.mkDerivation {
  name = "loa-${clusterName}-zarf-bundle";
  src = ./.;

  nativeBuildInputs = [
    pkgs.zarf
    pkgs.skopeo
  ];

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

    mkdir -p ${localOciRepo} charts extracted-crds
    chmod -R +w .

    cp ${zarfYaml} ./zarf.yaml

    # copy charts and values
    ${lib.concatStringsSep "\n" (
      builtins.map (chartModule: ''
        cp -r ${chartModule.chartPackage} ./charts/${baseNameOf chartModule.chartPackage} || true
        cp -r ${chartModule.valuesPackage} ./charts/${baseNameOf chartModule.valuesPackage} || true
      '') helmCharts
    )}

    # Convert the dockerTools tarballs into an OCI layout that Zarf can read
    # We map the pulledImages array into the oci-store directory
    ${lib.concatStringsSep "\n" (
      builtins.map (image: ''
        skopeo copy docker-archive:${image.package} ${ociRefOf image}
      '') images
    )}

    chmod -R +w charts ${localOciRepo}

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
