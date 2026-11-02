{ ... }:

{
  # Enable the AMD IOMMU driver. Firmware must also expose AMD-Vi/IOMMU.
  # VFIO binding is intentionally deferred until a dedicated PCI device and
  # its entire IOMMU group have been inspected.
  boot.kernelParams = [ "amd_iommu=on" ];
}
