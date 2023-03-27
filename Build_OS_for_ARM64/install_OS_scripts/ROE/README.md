We provide an dockerfile to build the dyninit with the FDO C-based client. It is not complete for can be easily improved to initialise and run the FDO client a device startup.

There is also a bootstrap script to create partitions on the device HDD and download ROE (kernel, initrd and grub). 
Hence, the device can reboot with the ROE and initiates FDO steps towards TO2.
