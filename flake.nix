{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby, ... }: let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      ruby = nixpkgs-ruby.lib.packageFromRubyVersionFile {
        file = ./.ruby-version; system = "x86_64-linux";
      };
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          postgresql
          pgcli
          redis
          memcached

          libyaml

          (pkgs.writeShellScriptBin "pg-stop" ''
            pg_ctl -D $PGDATA -U postgres stop
          '')

          (pkgs.writeShellScriptBin "pg-setup" ''
            if ! test -d $PGDATA; then
              pg_ctl initdb -D $PGDATA
              echo "unix_socket_directories = '$PGDATA'" >> $PGDATA/postgresql.conf
              echo "CREATE USER postgres WITH PASSWORD 'postgres' CREATEDB SUPERUSER;" | postgres --single -E postgres
            fi
          '')

          (pkgs.writeShellScriptBin "pg-start" ''
            pg_ctl -D $PGDATA -l $PGDATA/postgres.log \
              -o "-c unix_socket_directories='$PGDATA'" \
              -o "-c listen_addresses='*'" \
              -o "-c log_destination='stderr'" \
              -o "-c logging_collector=on" \
              -o "-c log_directory='log'" \
              -o "-c log_filename='postgresql-%Y-%m-%d_%H%M%S.log'" \
              -o "-c log_min_messages=info" \
              -o "-c log_min_error_statement=info" \
              -o "-c log_connections=on" \
              start
          '')

          (pkgs.writeShellScriptBin "dev" ''
            export PGDATA=$(pwd)/pgdata
            export PATH="$(pwd)/bin:$PATH"
            pg-start

            tmux -L monzieur

            pg-stop
          '')

        ] ++ [
          ruby
        ];
      };
    };
}
