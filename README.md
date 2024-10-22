Pyramid Bootloader

# About
This IsThe Leagcy Bootloader For OS Pyramid

# Setup
Install The Nessecry Requirments For this to work:
```
sudo apt update
sudo apt install make nasm
sudo apt install qemu-system
sudo apt-get install genisoimage
```

## Building
### To Make an .Img File
```
Make
```

### To make an .Iso File 
```
make build/main.iso
```

## Runing On Vitrual Machine

### Linux
- Boots as floppy disk
```
qemu-system-i386 -fda build/floppy.img
```

### Windows
Use The Oracle VirtualBox, VmWare or any simller program.