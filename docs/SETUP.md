# PyramidOS Development Environment Setup

This guide details how to set up a complete development environment for PyramidOS on Windows 10/11 using the Windows Subsystem for Linux (WSL).

## 📋 Prerequisites

- **OS:** Windows 10 (Build 19041+) or Windows 11.
- **Permissions:** Administrator access to install WSL.
- **Editor:** [Visual Studio Code](https://code.visualstudio.com/) (Recommended) with the "WSL" extension.

---

## Step 1: Install Windows Subsystem for Linux (WSL)

WSL allows you to run a genuine Linux environment directly on Windows.

1. Open **PowerShell** as **Administrator**.
2. Run the command:

    ```powershell
    wsl --install
    ```

3. **Restart your computer** when prompted.
4. After reboot, open the "Ubuntu" app from the Start Menu to finish installation (create a username/password).

---

## Step 2: Install Dependencies

We support two build modes: **Quick Start** (Native GCC) and **Production** (Cross-Compiler). The build system automatically detects which one you have.

### Option A: Quick Start (Recommended for Beginners)

This uses your Linux distribution's standard compiler. It is sufficient for the current Phase 1 & 2 development.

1. Open your **Ubuntu** terminal.
2. Update sources and install tools:

    ```bash
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y build-essential nasm qemu-system-x86 make
    ```

### Option B: Production Setup (Cross-Compiler)

*Recommended for advanced development to prevent host system library contamination.*

1. Install build dependencies:

    ```bash
    sudo apt install -y bison flex libgmp-dev libmpc-dev libmpfr-dev texinfo
    ```

2. Build the `i686-elf` toolchain (This takes 10-30 minutes):

    ```bash
    # Setup vars
    export PREFIX="$HOME/opt/cross"
    export TARGET=i686-elf
    export PATH="$PREFIX/bin:$PATH"
    
    mkdir -p $HOME/src && cd $HOME/src

    # Binutils
    wget https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.xz
    tar -xf binutils-2.38.tar.xz
    mkdir build-binutils && cd build-binutils
    ../binutils-2.38/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror
    make && sudo make install
    cd ../..

    # GCC
    wget https://ftp.gnu.org/gnu/gcc/gcc-11.3.0/gcc-11.3.0.tar.xz
    tar -xf gcc-11.3.0.tar.xz
    mkdir build-gcc && cd build-gcc
    ../gcc-11.3.0/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c --without-headers
    make all-gcc
    make all-target-libgcc
    sudo make install-gcc
    sudo make install-target-libgcc
    ```

3. Add to PATH permanently:

    ```bash
    echo 'export PATH="$HOME/opt/cross/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    ```

---

## Step 3: Build and Run

1. **Navigate to Project:**
    In the Ubuntu terminal, navigate to where you cloned the repo. Windows drives are mounted at `/mnt`.

    ```bash
    # Example
    cd /mnt/d/PyramidOS
    ```

2. **Compile:**

    ```bash
    make clean && make
    ```

    *Success Output:* You should see `Build Complete: build/pyramidos.img`.

3. **Run Emulation:**

    ```bash
    make run
    ```

### 🖥️ A Note on QEMU Graphics (WSL)

* **Windows 11:** GUI apps (QEMU) work out of the box via WSLg.
- **Windows 10:** You may need an X Server (like [VcXsrv](https://sourceforge.net/projects/vcxsrv/)) running on Windows to see the QEMU window.
  - *VcXsrv config:* Select "Disable access control" during launch.
  - *WSL config:* `export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0`

---

## Troubleshooting

- **"Command not found: make"**: Run `sudo apt install build-essential`.
- **"fatal: unable to open output file"**: Ensure you run `make clean && make` (or just `make`) before `make run`.
- **QEMU Error "Could not initialize SDL"**: This means WSL cannot find a display. Ensure you are on Windows 11 or have an X Server running on Windows 10.
