{
  pkgs,
  lib,
  inputs,
  ...
}: {
  claude.code.enable = true;

  # Android + Flutter
  android.enable = true;
  android.platformTools.version = "latest";
  android.platforms.version = ["34"];
  android.buildTools.version = ["33.0.2" "35.0.0"];
  android.flutter.enable = true;

  languages.dart.enable = true;

  # Additional packages from shell.nix
  packages = [
    pkgs.gh
    pkgs.git
    pkgs.invidious
    pkgs.jdk21
    pkgs.webkitgtk_4_1 # required for Flutter Linux desktop build (webkit2gtk-4.1)
  ];

  # PostgreSQL service — replaces the manual postgres setup in nix/clipious.nix
  services.postgres = {
    enable = true;
    port = 5433;
    # Allow TCP connections (matching the original listen_addresses='*')
    listen_addresses = "*";
    # Trust auth for all hosts — dev only, mirrors the original pg_hba.conf edits
    hbaConf = ''
      local all all              trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
      host  all all 0.0.0.0/0   trust
      host  all all ::/0        trust
    '';
  };

  # Disable process-compose auto-restart for postgres.
  # Without this, a crash on first start leaves postmaster.pid behind and the
  # auto-restarted second attempt immediately fails with "lock file already exists".
  processes.postgres.process-compose.availability.restart = "no";

  # Clean up stale postgres state before the first start of each `devenv up`.
  # The native process manager doesn't support `process.manager.before`, so this
  # runs as a task that postgres depends on. Uses $DEVENV_ROOT (always set by
  # devenv) rather than $DEVENV_STATE so it works even before full shell activation.
  tasks."postgres:cleanup" = {
    before = ["devenv:processes:postgres"];
    exec = ''
      PGDATA="$DEVENV_ROOT/.devenv/state/postgres"
      if [ -f "$PGDATA/postmaster.pid" ]; then
        OLD_PID=$(head -1 "$PGDATA/postmaster.pid")
        # Try graceful stop first; this may fail if the socket path changed between sessions.
        pg_ctl stop -D "$PGDATA" -m fast -w 2>/dev/null || true
        # If the process is still alive, kill it directly by PID.
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
          kill "$OLD_PID" 2>/dev/null || true
          sleep 2
          kill -0 "$OLD_PID" 2>/dev/null && kill -9 "$OLD_PID" 2>/dev/null || true
          sleep 1
        fi
        rm -f "$PGDATA/postmaster.pid"
      fi
      # Remove shared memory segments with no attached processes (stale IPC)
      ipcs -m | awk 'NR>3 && $6==0 {print $2}' | xargs -r ipcrm -m 2>/dev/null || true
    '';
  };

  # Invidious process — replaces invidious setup in nix/clipious.nix
  # Run with: devenv up
  processes.invidious.exec = ''
    cd ${./nix/helpers/invidious}
    until pg_isready -h 127.0.0.1 -p 5433 -U "$(whoami)" -q; do
      echo "Waiting for PostgreSQL..."
      sleep 1
    done
    # Connect as the current unix user (the initdb superuser) to bootstrap the
    # kemal role and invidious database. Matches the original init_db.sh comment:
    # "PGUSER needs to be computer logged in user to for it to work".
    PGUSER="$(whoami)" createuser -h 127.0.0.1 -p 5433 -s kemal 2>/dev/null || true
    PGUSER="$(whoami)" createdb   -h 127.0.0.1 -p 5433 -O kemal invidious 2>/dev/null || true
    invidious --migrate
    psql -h 127.0.0.1 -p 5433 -U kemal -d invidious -f ./users.sql 2>/dev/null || true
    invidious
  '';

  # Environment variables
  env =
    {
      ANDROID_KEY_FILE = "/home/fmgordillo/code/clipious/android/key.properties";
      PGUSER = "kemal";
      PGPASSWORD = "kemal";
      # PGHOST and PGPORT are set automatically by services.postgres
      PGDATABASE = "invidious";
    }
    // (
      if pkgs.stdenv.isLinux
      then {
        # Prevent locale issues in nix-shell --pure (Linux only)
        LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
        LANG = "en_US.UTF-8";
      }
      else {}
    );

  # Scripts — replaces shell aliases
  scripts.build-runner = {
    exec = "dart run build_runner build --delete-conflicting-outputs";
    description = "Run code generation once";
  };
  scripts.build-runner-watch = {
    exec = "dart run build_runner watch --delete-conflicting-outputs";
    description = "Watch for changes and run code generation";
  };
  scripts.check-services = {
    exec = ''${./nix/helpers/check-services.sh}'';
    description = "Ensure devenv services (PostgreSQL, Invidious) are running";
  };

  # Git Hooks — format, analyze, and test Dart code
  # Hooks are wrapped with check-services to automatically start PostgreSQL and Invidious
  # on-demand if they're not already running.
  git-hooks = {
    enable = true;
    hooks = {
      dart-format = {
        enable = true;
        name = "Dart Format";
        entry = "bash -c 'check-services dart format --set-exit-if-changed \"$@\"' --";
        language = "system";
        files = "\\.dart$";
        stages = ["commit"];
      };
      dart-analyze = {
        enable = true;
        name = "Dart Analyze";
        entry = "bash -c 'check-services dart analyze'";
        language = "system";
        files = "\\.dart$";
        pass_filenames = false;
        stages = ["commit"];
      };
      flutter-test = {
        enable = true;
        name = "Flutter Test";
        entry = "bash -c 'check-services flutter test'";
        language = "system";
        files = "\\.dart$";
        pass_filenames = false;
        stages = ["commit"];
      };
    };
  };

  # One-time setup: configure flutter JDK, install git hooks.
  # Separated from enterShell so blocking network/IO operations don't interfere
  # with the interactive terminal.
  scripts.setup = {
    exec = ''
      echo "Configuring Flutter JDK"
      flutter config --jdk-dir ${pkgs.jdk21}/lib/openjdk

      echo "Fetching Dart/Flutter dependencies"
      flutter pub get

      echo "Done — run 'devenv up' to start PostgreSQL and Invidious."
    '';
    description = "One-time project setup (flutter JDK, git hooks)";
  };

  # Shell hook — only fast, non-blocking, non-interactive operations
  enterShell = ''
    # Set up writable Android SDK and Gradle directories for Nix compatibility
    export ANDROID_SDK_ROOT="$DEVENV_ROOT/.devenv/android-sdk"
    export ANDROID_NDK_HOME="$DEVENV_ROOT/.devenv/android-sdk/ndk-bundle"
    export GRADLE_USER_HOME="$DEVENV_ROOT/.devenv/gradle"
    mkdir -p "$ANDROID_SDK_ROOT" "$GRADLE_USER_HOME"

    echo "Available scripts: setup, build-runner, build-runner-watch, check-services"
    echo "Pre-commit hooks will automatically start services as needed."
    echo "Run 'devenv up' manually to start PostgreSQL and Invidious for development."
  '';
}
