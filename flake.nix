{
  description = "A Nix-flake-based Elixir development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

  outputs = inputs:
    let
      supportedSystems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          });
    in {
      overlays.default = final: prev: rec {
        # documentation
        # https://nixos.org/manual/nixpkgs/stable/#sec-beam

        # ==== ERLANG ====

        # use whatever version is currently defined in nixpkgs
        # erlang = pkgs.beam.interpreters.erlang;

        # use latest version of Erlang 28
        erlang = final.beam.interpreters.erlang_27;

        # specify exact version of Erlang OTP
        # erlang = pkgs.beam.interpreters.erlang.override {
        #   version = "26.2.2";
        #   sha256 = "sha256-7S+mC4pDcbXyhW2r5y8+VcX9JQXq5iEUJZiFmgVMPZ0=";
        # }

        # ==== BEAM packages ====

        # all BEAM packages will be compile with your preferred erlang version
        pkgs-beam = final.beam.packagesWith erlang;

        # ==== Elixir ====

        # use whatever version is currently defined in nixpkgs
        # elixir = pkgs-beam.elixir;

        # use latest version of Elixir 1.17
        elixir = pkgs-beam.elixir_1_18;

        # specify exact version of Elixir
        # elixir = pkgs-beam.elixir.override {
        #   version = "1.17.1";
        #   sha256 = "sha256-a7A+426uuo3bUjggkglY1lqHmSbZNpjPaFpQUXYtW9k=";
        # };
      };

      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs;
            [
              # use the Elixr/OTP versions defined above; will also install OTP, mix, hex, rebar3
              elixir

              # mix needs it for downloading dependencies
              git

              # probably needed for your Phoenix assets
              nodejs_24
              # biome

              postgresql

              # Database tools
              pgcli # Better PostgreSQL CLI
            ] ++
            # Linux only
            pkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [
              # gigalixir
              inotify-tools
              libnotify
            ]) ++
            # macOS only
            pkgs.lib.optionals pkgs.stdenv.isDarwin (with pkgs; [
              terminal-notifier
              darwin.apple_sdk.frameworks.CoreFoundation
              darwin.apple_sdk.frameworks.CoreServices
            ]);

          # Set up PostgreSQL data directory and environment
          shellHook = ''
            export PGDATA="$PWD/.nix-postgres"
            export PGHOST="$PWD/.nix-postgres"
            export PGPORT=5432
            export PGUSER=postgres
            export PGDATABASE=postgres

            # Initialize PostgreSQL if not already done
            if [ ! -d "$PGDATA" ]; then
              echo "Initializing PostgreSQL database in $PGDATA..."
              initdb --auth-host=trust --auth-local=trust --encoding=UTF8 --locale=en_US.UTF-8 --username=postgres
            fi

            # Start PostgreSQL if not running
            if ! pg_ctl status > /dev/null 2>&1; then
              echo "Starting PostgreSQL..."
              pg_ctl start -l "$PGDATA/postgres.log" -o "-k $PGHOST -p $PGPORT"
              
              # Wait for PostgreSQL to start
              while ! pg_isready -h "$PGHOST" -p "$PGPORT" > /dev/null 2>&1; do
                echo "Waiting for PostgreSQL to start..."
                sleep 1
              done
              
              # Create the development and test databases if they don't exist
              createdb wik_dev 2>/dev/null || echo "Database wik_dev already exists"
              createdb wik_test 2>/dev/null || echo "Database wik_test already exists"
              
              echo "PostgreSQL is ready!"
              echo "  - Data directory: $PGDATA"
              echo "  - Socket: $PGHOST"
              echo "  - Port: $PGPORT"
              echo "  - Databases: wik_dev, wik_test"
            fi

            # Cleanup function
            cleanup() {
              echo "Stopping PostgreSQL..."
              pg_ctl stop -m fast > /dev/null 2>&1 || true
            }
            trap cleanup EXIT

            echo "Development environment ready!"
            echo "Run 'mix setup' to install dependencies and set up the Phoenix application."
          '';
        };
      });
    };
}
