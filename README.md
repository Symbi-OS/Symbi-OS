# Symbiote Project

## What's with the title:
A play on "symbiosis". The word "symbiosis" comes from smashing together two greek words that mean "live" and "together".
When organisms live together, they have an opportunity to mutually benefit. We believe there is an analogous opportunity to unite the historically separated application and kernel codepaths.

## Project Contributions
This project makes three main contributions: enabling the mingling of application and kernel code; identifying and encoding procedures for optimizing applications; exploiting these optimizations in the context of linux applications.

1. We add one system call, **kelevate**, to Linux which breaks down the hardware enforced wall between application and the Linux Kernel. This is done by enabling application threads to run in the same mode as the kernel (supervisor execution mode). We support this for x86_64 and have early support for Arm64 processors. It may be surprising that this was implemented in just a few hundred lines of code. This can be found in [our fork of Linux](https://github.com/Symbi-OS/linux).

2. We provide a library of tools, the **Symbiote Library**, which has two man uses. It encodes our approach and provides hooks that will be used in: 1) mitigating the issues that arise when application threads run in supervisor mode; 2) performance and energy optimization for applications. It provides a good starting point for others. [It can be found here](https://github.com/Symbi-OS/Symlib)

3. We use the Symbiote library to modify core kernel data-structures in order to mitigate common runtime issues with running applications in the elevated mode. Then we use it to redefine the interface between applications an kernel in order to performance and energy optimize applications. We quantify the impact of optimize micro benchmarks like LEBench and toy exemplars. Then we do the same for "real" programs like Redis and Memcached, demonstrating latency, throughput, and energy wins.


# Manifesto:

## Intro
Today's operating systems erect a nearly impenetrable barrier between applications and the operating system code bases. This barrier prevents co-optimization between the application and system domains; each environment is developed quite independently. This results in sub-optimal application performance. As a result, applications go out of there way to bypass the kernel

This project optimizes application performance by breaking the wall between application and kernel, allowing co-optimizing between the two domains. We demonstrate improvements to application throughput, latency, and energy use. The approach opens a larger space that makes contact with most systems concerns: security, debugging, kernel prototyping.

All the major operating systems running on our our phones, laptops, and data-center servers use hardware (namely the memory management unit) to enforce a domain separation between application and kernel. Many academic and industrial systems explore architectural changes to OSes to enable "application" and "system" mingling, see the MicroKernel, ExoKernel, and UniKernel literature. It's hard for these exotic system structures to catch on in a world that is familiar with building code for the mainstream Monolithic kernel architecture.

We offer a novel approach that, instead of offering an architectural solution, simply allows one or more application threads to enter the kernel's mode of execution. Once there, these threads can read, write, and execute kernel data and memory. With this ability, applications can *shortcut* kernel code paths eliminating costs like system call overheads. Further, they can open up the kernel API to redefine their interaction with the system, for example, by more directly accessing hardware and changing core kernel policies. This can speed up meaningful paths in the data-center such as networking and storage. Threads can enter and leave the kernel's mode of execution on demand, perhaps for nanoseconds or years.

We offer the following terminology to structure our conversation:
- elevated (lowered) thread: an application thread that has entered (exited) supervisor execution mode. Also used in verb form: to elevate/lower a thread.
- symbiote: a process that makes use of the kElevate mechanism to elevate its threads
- ChronoKernel: an OS that allows application threads fast access to elevated execution. This name emphasizes the temporal dynamics at play, as opposed to architecture forward approaches (like unikernels) which tend to lock applications into one mode or the other for their lifetime
- kElevate: the mechanism we use in our implementation that allows an application thread to elevate/lower

## Contributions
A core contribution of this work is drawing out the possible orthogonalization of software codebases (application/kernel) from hardware modes of execution (user/supervisor). Our mechanism provides an on-demand way for threads to navigate this space. Executing applications in user mode and kernels in supervisor mode is obviously well studied in the academic and industrial conversation. Library OSes and their decedents, unikernels, have explored making architectural changes that prescriptively locate the application and kernel together sometimes in user mode, and sometime in kernel mode. Although there are many ways research has approached this, our contribution is novel in that allows the controlled navigation of these four permutations. 

When an application thread becomes elevated, it can truly do anything, so, simply enabling this in an OS may be interesting, but it is not immediately useful. As a second core contribution, we provide a library, the Symbiote library, which contains our set of approaches to structuring a developer's use of elevated threads. Here we offer a set of principles that have helped structure our development process by intentionalyy constraining the design space:
- Build symbiotes to the standard application model
- leave no trace: Interpose instead of overwrite: don't touch the kernel if you don't have to
- others ...


ChronoKernels are defined by an ability they provide to threads, as opposed to a particular arrangement of software. We therefore can imagine retrofitting modern monoliths, microkernels etc. With the mechanism they need to become chronokernels. We can also imagine what a from-scratch system might look like, one that supported thread elevation from the start.


One major goal of this work is to keep  One common concern about this approach is summarized in the following question: "Aren't you just making application programming as hard as kernel programming"? 

 tested virtual and barememtal on laptops and servers

## Future work
While this paper is scoped to mainly study what is possible when elevating application threads, there is a symmetric study of what can be done when it is possible to lower kernel threads. Apart from the occasional supervisor register access, most monolithic kernel code does not *have* to run in supervisor mode. This is the observation of microkernels. Reasons to run kernel code in user space include fault tolerance, migration, performance, and debugging. Rump kernels, for example packaged device drivers (as unikernels?) in user-space to ease debugging in a location where a null pointer dereference means a segfault, not a kernel panic. Our approach turns the question around, "What if supervisor access was divided not spatially, but temporally."

## Security
On its face, removing isolation between application and kernel sounds like it unleashes anarchy on the system: application threads can corrupt, panic, and spy on each other and the system. While admittedly our primary focus is on improving performance and energy use, not security, we are not willing to put e.g. co-running mutually distrusting applications out of scope. Two arguments may help here, the first restricts the deployment context to ease entry, but the second retains the full context of general purpose computing:

1) Much datacenter computation runs single applications (and their helper processes) in dedicated virtual machines (VMs). With the hypervisor providing isolation, there is nothing to be gained from e.g. observing co-running apps, or panicking the (guest) kernel. 

2) We require the superuser capability in order for an application to access supervisor mode. Any superuser can exploit the existing kernel modules system to install code with the same abilities into the kernel. We have processes including verified languages, testing, and human code review that are robust enough to ensure module code is as safe as core kernel code. These same processes can be leveraged e.g. to verify the safety of a system call shortcutting server process started by a system administrator, but used by standard client processes. 

## Ramp from modules
Although our approach has the same power as kernel modules, it differs significantly. First, 

This notably excludes a subset of embedded devices and other hardware with a single execution mode.



allows users to access the same ... the use of the tool is different in kind ...

goals: low programmer effort incremental optimization approach compatibility 

ABI compatible 

context, hardware baremetal

We demonstrate, however, 

unlike kernel modules, however,

kernel modules

implementation 

chrono




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
