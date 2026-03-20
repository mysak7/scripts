#!/usr/bin/env python3
import os
import sys
import subprocess
import re

def run_cmd(cmd):
    """Executes a shell command silently, raising an error if it fails."""
    subprocess.run(cmd, shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def main():
    print("==============================================================")
    print("             Raspberry Pi Clone Boot Fixer")
    print("==============================================================")
    print("INFO: Recent versions of Raspberry Pi OS (Bookworm) moved the")
    print("boot directory and rely strictly on PARTUUIDs. Cloning tools ")
    print("often fail to update these IDs, causing the new cloned card ")
    print("to hang on boot because it searches for the old card's ID.")
    print("This script fixes the issue by replacing the hardcoded PARTUUIDs")
    print("with standard physical hardware paths (/dev/mmcblk0p*).")
    print("==============================================================\n")

    # Enforce root privileges for mounting and editing system files
    if os.geteuid() != 0:
        print("Error: This script must be run as root. Please run with: sudo python3 fix_clone.py")
        sys.exit(1)

    dev = input("Enter the USB drive letter of your cloned card (e.g., sda): ").strip()
    
    boot_part = f"/dev/{dev}1"
    root_part = f"/dev/{dev}2"

    if not os.path.exists(boot_part) or not os.path.exists(root_part):
        print(f"Error: Cannot find partitions {boot_part} or {root_part}. Check your drive letter.")
        sys.exit(1)

    boot_mount = "/mnt/clone_boot_fix"
    root_mount = "/mnt/clone_root_fix"

    os.makedirs(boot_mount, exist_ok=True)
    os.makedirs(root_mount, exist_ok=True)

    try:
        print(f"\n[*] Mounting {boot_part} and {root_part}...")
        run_cmd(f"mount {boot_part} {boot_mount}")
        run_cmd(f"mount {root_part} {root_mount}")

        # 1. Fix cmdline.txt on the boot partition
        cmdline_path = os.path.join(boot_mount, "cmdline.txt")
        if os.path.exists(cmdline_path):
            print(f"[*] Updating {cmdline_path}...")
            with open(cmdline_path, "r") as f:
                cmdline = f.read()
            
            # Find root=PARTUUID=... and replace with the physical SD card path
            new_cmdline = re.sub(r'root=(PARTUUID|UUID)=[\w\-]+', 'root=/dev/mmcblk0p2', cmdline)
            
            with open(cmdline_path, "w") as f:
                f.write(new_cmdline)
            print("    -> cmdline.txt updated successfully.")
        else:
            print("    -> Warning: cmdline.txt not found!")

        # 2. Fix fstab on the root partition
        fstab_path = os.path.join(root_mount, "etc", "fstab")
        if os.path.exists(fstab_path):
            print(f"[*] Updating {fstab_path}...")
            with open(fstab_path, "r") as f:
                fstab_lines = f.readlines()

            new_fstab = []
            for line in fstab_lines:
                # Skip comments
                if line.strip().startswith("#"):
                    new_fstab.append(line)
                    continue
                
                # Fix the /boot or /boot/firmware mount entry
                if " /boot" in line:
                    line = re.sub(r'^(PARTUUID|UUID)=[\w\-]+', '/dev/mmcblk0p1', line)
                # Fix the / (root) mount entry
                elif " / " in line:
                    line = re.sub(r'^(PARTUUID|UUID)=[\w\-]+', '/dev/mmcblk0p2', line)
                
                new_fstab.append(line)

            with open(fstab_path, "w") as f:
                f.writelines(new_fstab)
            print("    -> fstab updated successfully.")
        else:
            print("    -> Warning: fstab not found!")

    finally:
        # Guarantee cleanup even if the script crashes halfway through
        print("[*] Unmounting drives and cleaning up...")
        subprocess.run(f"umount {boot_mount}", shell=True, stderr=subprocess.DEVNULL)
        subprocess.run(f"umount {root_mount}", shell=True, stderr=subprocess.DEVNULL)
        try:
            os.rmdir(boot_mount)
            os.rmdir(root_mount)
        except OSError:
            pass
        
    print("\nSuccess! You can now shut down, swap the 64GB card into the Pi, and boot it up.")

if __name__ == "__main__":
    main()
