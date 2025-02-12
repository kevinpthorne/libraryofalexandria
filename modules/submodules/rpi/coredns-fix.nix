{ pkgs, lib, ... }:
{
    config = {
        services.kubernetes.addons.dns = {
            coredns = {
                finalImageTag = "1.10.1";
                imageDigest = "sha256:a0ead06651cf580044aeb0a0feba63591858fb2e43ade8c9dea45a6a89ae7e5e";
                imageName = "coredns/coredns";
                sha256 = "0c4vdbklgjrzi6qc5020dvi8x3mayq4li09rrq2w0hcjdljj0yf9";
            };
        };
    };
}