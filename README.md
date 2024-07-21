# VFIO dynamic loader
Quick and dirty script for loading VFIO drivers without the need to reboot or re-login

## INFO
- IOMMU must be enabled and working ([see](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Setting_up_IOMMU) for more info)
- Currently only works for some NVIDIA GPU setups
- Tested on: Fedora Linux 40 (KDE Plasma)

## USAGE

    ./vfio.sh                List GPU pci ids
    ./vfio.sh bind           Load vfio drivers
    ./vfio.sh unbind         Unload vfio drivers
