{
  description = "Lyzah game engine";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-overlay.follows = "zig";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      overlays = [
        # Other overlays
        (final: prev: { zigpkgs = inputs.zig.packages.${prev.system}; })
        (final: prev: { zlspkgs = inputs.zls.packages.${prev.system}; })
      ];

      # Our supported systems are the same supported systems as the Zig binaries
      systems = builtins.attrNames inputs.zig.packages;
    in flake-utils.lib.eachSystem systems (system:
      let pkgs = import nixpkgs { inherit overlays system; };
      in rec {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            zigpkgs.master
            zlspkgs.zls

            glfw
            wayland

            shaderc

            vulkan-loader
            vulkan-headers
            vulkan-tools-lunarg
            vulkan-validation-layers
          ];

          LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib:${pkgs.wayland}/lib";
        };
      });
}
