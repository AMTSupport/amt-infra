{
  config,
  pkgs,
  lib,
  ...
}:
{
  sops.secrets = {
    "POSTGRES/HUDU_PASSWORD" = {
      owner = config.users.users.postgres.name;
      group = config.users.groups.postgres.name;
      restartUnits = [ "postgresql.service" ];
    };

    "POSTGRES/S3_KEY" = {
      owner = config.users.users.postgres.name;
      group = config.users.groups.postgres.name;
    };
  };

  services = {
    postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      enableTCPIP = true;
      authentication = ''
        host hudu_production hudu 10.88.0.0/16 md5
      '';
      ensureDatabases = [ "hudu_production" ];
      ensureUsers = [
        {
          name = "hudu";
          ensureClauses.superuser = true;
        }
      ];
    };
    postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 17:00:00"; # 3 AM Sydney time
      databases = [ "hudu_production" ];
      location = "/var/lib/postgresql/backup/postgres";
      compression = "zstd";
      compressionLevel = 12;
    };

    redis = {
      servers."" = {
        enable = true;
        port = 6379;
        bind = null;

        # TODO - is there any way to make hudu use a password?
        settings.protected-mode = "no";
      };
    };
  };

  systemd.services.postgresql.postStart = ''
    $PSQL -tA <<'EOF'
      DO $$
      DECLARE password TEXT;
      BEGIN
        password := trim(both from replace(pg_read_file('${
          config.sops.secrets."POSTGRES/HUDU_PASSWORD".path
        }'), E'\n', '''));
        EXECUTE format('ALTER USER hudu WITH PASSWORD '''%s''';', password);
      END $$;
    EOF

    $PSQL -tAc 'ALTER DATABASE "hudu_production" OWNER TO "hudu";'
  '';

  # Allow access to databases from podman containers
  networking.firewall.interfaces.podman0.allowedTCPPorts = [
    5432 # PostgreSQL
    6379 # Redis
  ];

  # Setup the S3 as a mount so we can drop files into it
  environment.systemPackages = [ pkgs.s3fs ];
  fileSystems."backup" = {
    device = "${lib.getExe' pkgs.s3fs "s3fs"}#backup";
    mountPoint = "/var/lib/postgresql/backup";
    fsType = "fuse";
    noCheck = true;
    options = [
      "_netdev"
      "allow_other"
      "use_path_request_style"
      "url=http://localhost:8081/"
      "passwd_file=${config.sops.secrets."POSTGRES/S3_KEY".path}"
      "umask=0007"
      "mp_umask=0007"
      "nonempty"
      "uid=${toString config.users.users.postgres.uid}"
      "gid=${toString config.users.groups.postgres.gid}"
    ];
  };
}
