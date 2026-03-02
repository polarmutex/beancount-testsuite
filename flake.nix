{
  description = "Beancount Test Suite - Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Zig toolchain (pinned to 0.13 for API compatibility)
            zig_0_13
            zls  # Zig Language Server for IDE support

            # Python for bridge/testing
            python3
            python3Packages.pip
            python3Packages.virtualenv

            # Development tools
            git
            gnumake

            # Code formatting and linting
            nixpkgs-fmt  # For formatting this flake

            # Build essentials
            pkg-config

            # Optional: useful utilities
            jq           # JSON processing
            ripgrep      # Fast search
            fd           # Fast find
          ];

          shellHook = ''
            echo "🚀 Beancount Test Suite Development Environment"
            echo ""
            echo "Available tools:"
            echo "  • Zig $(zig version)"
            echo "  • Python $(python3 --version | cut -d' ' -f2)"
            echo "  • ZLS (Zig Language Server)"
            echo ""
            echo "Common commands:"
            echo "  zig build          - Build the project"
            echo "  zig build run      - Build and run"
            echo "  zig build test     - Run tests"
            echo ""

            # Set up Python virtual environment if it doesn't exist
            if [ ! -d .venv ]; then
              echo "Creating Python virtual environment..."
              python3 -m venv .venv
            fi

            # Activate virtual environment
            source .venv/bin/activate

            # Ensure pip is up to date
            pip install --upgrade pip > /dev/null 2>&1

            echo "Python virtual environment activated (.venv)"
            echo ""
          '';

          # Environment variables
          ZIGFLAGS = "";

          # Ensure locale is set properly
          LANG = "C.UTF-8";
          LC_ALL = "C.UTF-8";
        };

        # Optional: Define packages that can be built
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "beancount-testsuite";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.zig ];

          buildPhase = ''
            zig build -Doptimize=ReleaseSafe
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/beancount-testsuite $out/bin/
          '';
        };
      }
    );
}
