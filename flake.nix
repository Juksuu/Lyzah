{
  description = "Lyzah game engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zig,
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forEachSupportedSystem =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f { pkgs = import nixpkgs { inherit system; }; });

      zig_stable = system: zig.packages.${system}."0.17.1";
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }: {
          default = pkgs.mkShell {
            packages = with pkgs; [
              (zig_stable pkgs.stdenv.hostPlatform.system)
              zls

              glfw
              wayland

              shaderc
              lldb

              vulkan-loader
              vulkan-headers
              vulkan-tools-lunarg
              vulkan-validation-layers
            ];

            LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib:${pkgs.wayland}/lib";
          };
        }
      );
    };
}
