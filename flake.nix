{
  description = "Lyzah game engine";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forEachSupportedSystem = f:
        nixpkgs.lib.genAttrs supportedSystems
        (system: f { pkgs = import nixpkgs { inherit system; }; });
    in {
      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            zig
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
      });
    };
}
