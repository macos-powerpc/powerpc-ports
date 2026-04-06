# PowerPC Ports
Overlay repo with fixes and new ports to use with [PPCPorts](https://github.com/macos-powerpc/ppcports-base) (or MacPorts).
Primary target system is macOS 10.6 PowerPC. Most of ports are expected to work on modern macOS on x86_64 and arm64 as well.

Recommended set-up:

1. Install 10.6.8 (Snow Leopard) PowerPC. On a G5 you may install 10.5.8 instead and build for ppc64 (support for Leopard is limited though).
2. Install PPCPorts from [MacOS PowerPC](https://macos-powerpc.org). It is configured to use this repo on top of mainstream MacPorts ports tree.

Bug reports are accepted via Issues and will be addressed. This project is not associated with MacPorts, so please do not open tickets related to these ports on Trac.
Using this repository with mainstream MacPorts is possible, but you are on your own there.

Commit history is preserved here and PRs are accepted.

R ports have been moved to a separate repository: https://github.com/macos-powerpc/R-ports (PowerPC support is maintained there too).

This repository is accessible at [CodeBerg](https://codeberg.org/macos-powerpc/powerpc-ports) and [GitHub](https://github.com/macos-powerpc/powerpc-ports).
