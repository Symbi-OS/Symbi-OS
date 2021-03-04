# Symbi-OS

This is a top level directory to organize the repos necessary to build this project. This should always point to a set of subrepos that can run the collection of apps successfully. It should be able to build all the subcomponents of the project and launch a demo app.

# Prereqs:

Linux:
flex bison libssl-dev qemu

# Building
top level directory

make build_all

cd Apps/examples/

make steal_syscalls

cd ../../Run/

make run_vm
