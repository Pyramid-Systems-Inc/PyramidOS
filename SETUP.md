# PyramidOS Development Environment Setup

This guide details how to set up a complete development environment for PyramidOS on a Windows 10 or 11 machine using the Windows Subsystem for Linux (WSL). This is the recommended and official way to build the project.

## Prerequisites

- A computer running Windows 10 or 11.
- An internet connection.

---

## Step 1: Install Windows Subsystem for Linux (WSL)

WSL allows you to run a genuine Linux environment directly on Windows, without the overhead of a virtual machine.

1. Open **PowerShell** or **Command Prompt** as an **Administrator**.
2. Run the following command to install WSL and the default Ubuntu distribution:

    ```powershell
    wsl --install
    ```

3. When the process is complete, **restart your computer** as prompted. This is a mandatory step.

4. After rebooting, find and open the "Ubuntu" application from your Start Menu. On its first launch, it will finalize the installation and ask you to create a username and a password for your new Linux environment.

---

## Step 2: Install Build Tools and Cross-Compiler

Once your Ubuntu terminal is running, you need to install the necessary tools. This includes standard build utilities, the NASM assembler, the QEMU emulator, and a special `i686-elf` cross-compiler for building our 32-bit kernel.

1. **Update Ubuntu's Package Lists:**
    In your Ubuntu terminal, run:

    ```bash
    sudo apt update
    sudo apt upgrade -y
    ```

2. **Install Prerequisites and Tools:**
    Install `build-essential` (which includes `make` and a native `gcc`), `nasm`, `qemu`, and other libraries needed to build our cross-compiler.

    ```bash
    sudo apt install -y build-essential nasm qemu-system-x86 bison flex libgmp-dev libmpc-dev libmpfr-dev texinfo
    ```

3. **Build the `i686-elf` Cross-Compiler:**
    This is a one-time process that compiles `binutils` (the linker) and `gcc` (the compiler) specifically for our target operating system. Copy and paste the entire block of commands into your Ubuntu terminal.

    ```bash
    # Set up environment variables
    export PREFIX="$HOME/opt/cross"
    export TARGET=i686-elf
    export PATH="$PREFIX/bin:$PATH"

    # Create a source directory
    mkdir -p $HOME/src

    # Build and install binutils
    cd $HOME/src
    wget https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.xz
    tar -xf binutils-2.38.tar.xz
    mkdir build-binutils
    cd build-binutils
    ../binutils-2.38/configure --target=$TARGET --prefix="$PREFIX" --with-sysroot --disable-nls --disable-werror
    make
    sudo make install
    cd ..

    # Build and install GCC
    wget https://ftp.gnu.org/gnu/gcc/gcc-11.3.0/gcc-11.3.0.tar.xz
    tar -xf gcc-11.3.0.tar.xz
    mkdir build-gcc
    cd build-gcc
    ../gcc-11.3.0/configure --target=$TARGET --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers
    make all-gcc
    make all-target-libgcc
    sudo make install-gcc
    sudo make install-target-libgcc
    cd ..

    # Clean up downloaded files
    rm -rf binutils-2.38.tar.xz gcc-11.3.0.tar.xz build-binutils build-gcc binutils-2.38 gcc-11.3.0
    ```

4. **Add the Cross-Compiler to your PATH Permanently:**
    This command adds the location of your new compiler to your shell's configuration file, so it's available every time you open a new terminal.

    ```bash
    echo 'export PATH="$HOME/opt/cross/bin:$PATH"' >> ~/.bashrc
    ```

5. **Apply the changes by closing and reopening your Ubuntu terminal.**

---

## Step 3: Building and Running PyramidOS

Once the setup is complete, you can build and run the OS.

1. **Navigate to Your Project Directory:**
    Your Windows drives are mounted under `/mnt/`. For example, if your project is at `D:\PyramidOS`, you would use:

    ```bash
    cd /mnt/d/PyramidOS
    ```

    *Note: If your path contains spaces, you must enclose it in quotes.*

2. **Build the OS:**
    Use the top-level Makefile. `make clean` is optional but good practice for a full rebuild.

    ```bash
    make clean && make
    ```

3. **Run the OS in QEMU:**
    This command runs the built disk image.

    ```bash
    qemu-system-i386 -fda build/pyramidos_legacy.img
    ```

---

## Daily Workflow Summary

After the one-time setup, your daily development cycle will be:

1. Open the **Ubuntu** app.
2. Navigate to your project directory (e.g., `cd /mnt/d/PyramidOS`).
3. Make code changes in your preferred Windows editor (like VS Code).
4. Run `make` in the Ubuntu terminal to build your changes.
5. Run `qemu-system-i386 -fda build/pyramidos_legacy.img` to test.
