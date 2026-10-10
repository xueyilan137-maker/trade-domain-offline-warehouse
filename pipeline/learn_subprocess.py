import subprocess


def run_command(command):
    print(f"Running command: {' '.join(command)}")

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
    )

    print(f"returncode: {result.returncode}")

    if result.stdout:
        print("stdout:")
        print(result.stdout.strip())

    if result.stderr:
        print("stderr:")
        print(result.stderr.strip())

    if result.returncode != 0:
        raise SystemExit(f"Command failed with returncode={result.returncode}")


def main():
    run_command(["python", "--version"])


if __name__ == "__main__":
    main()
