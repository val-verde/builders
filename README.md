# The Val Verde Builder - Version 1.0

## Summary
The purpose of this community project is to serve as a cross-platform standardization point for open source software. Val Verde currently hosts over 300 projects along with a cross platform software build and deployment pipeline and is about a year old now. We strive to provide polished software packages for end-users so that larger software projects can be successfully managed and deployed.

## Focus areas
1. Processor Support: AArch64 (Apple M1, Cortex-aXX) X86-64 (all flavors)
2. Operating System Targets: All Glibc/Musl deb/rpm based Linux Distros, Android, iOS, macOS, Windows
3. Programming Language Support: C, C++, CUDA, Fortran, Go, Java, Lua, Node, Objective-C, Perl, Python, Ruby, Rust, Swift
4. Build System Support: Autoconf, Bazel, Cargo, CMake, GNUMakefile, Maven, Meson, NPM, Python/SetupTools, WineBuild
5. Containerization Support: chroot (macOS), systemd-nspawn, Docker
6. Virtualization Support: Qemu VM
7. Machine Learning Tools: CoreML, Tensorflow
8. Graphics Porting Tools: clang/libclc, Mesa/lavapipe/zink, MoltenVK
9. Blockchain Support: Solidity
10. Optimization Support: LTO, PGO, Architecture tuning

## Achievements
1. Self hosted cross compiling environment suitable for CI.
2. Entirely built using LLVM-14 with custom per-package patches.
3.
    1. Unified toolchains for macOS, Android, Windows, Linux:
        1. C-family
        2. Go
        3. Java
        4. Node
        5. Python
        6. Rust
        7. Swift
    2. Custom ports for:
        1. Musl
        2. Windows-AArch64.
4. CI pipeline used to build and deploy 300 packages across 8 mainline targets and optimized to a 48 hour turn around time for a complete build.

## Benefits
1. Battle-tested Software library of OSS components kept up to date across all architectures. Made freely available along with all patches and build machinery needed to reconstitute published artifacts.
2. Free build and deployment CI pipeline to save many months of build engineering. It is designed to be simple to augment packages and diagnose build issues.
3. Simple build/deployment procedure in production set ups.
5. Expanding software TAM by leveraging cross-platform targeting solutions.
6. LLVM and Swift bleeding edge support which is also central to Val Verde build and devops infrastructure.

## License and Contact
Val Verde is an open community and each deliverable is available under the same license as its original project.

Please send general inquiries to openvalverdeinquiries@gmail.com or at the central portal at https://github.com/val-verde/builders/issues to report issues or for feature requests.
