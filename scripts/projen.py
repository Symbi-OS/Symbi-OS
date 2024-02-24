#!/bin/python3

import os
import readline
import stat

MAKEFILE_SRC_KERNEL_LINK = '-L ./ -lkernel'
MAKEFILE_SRC_MOD_OBJ_M_APPEND = 'obj-m += skmod.o'
MAKEFILE_SRC_SKMOD_DEPENDENCY = 'skmod.o'
MAKEFILE_SRC_LINUX_PATH = 'LINUX_PATH=~/Symbi-OS/linux'
MAKEFILE_SRC_SKMOD_TARGET = '''# skmod - Symbiote Kernel Module
skmod.o: skmod.c
	make -C $(LINUX_PATH) M=$(PWD) modules_check
	rm .*.cmd skmod.mod modules.order'''

MAKEFILE_SRC_KERNEL_LINK_VAR = '$(KERNEL_LINK)'
MAKEFILE_SRC_LIBKERNEL_TARGET='''libkernel.a: mklibkernel.sh
	./mklibkernel.sh'''
MAKEFILE_SRC_LIBKERNEL_DEPENDENCY = 'libkernel.a'

MAKEFILE_SRC_TARGET_NAME = 'program'

MAKEFILE_FORMAT_DICTIONARY = {
    '_kernlink': MAKEFILE_SRC_KERNEL_LINK,
    '_linux_path': MAKEFILE_SRC_LINUX_PATH,
    '_kern_mod_obj_m_append': MAKEFILE_SRC_MOD_OBJ_M_APPEND,
    '_libkernel_target': MAKEFILE_SRC_LIBKERNEL_TARGET,
    '_libkernel_dependency': MAKEFILE_SRC_LIBKERNEL_DEPENDENCY,
    '_skmod_target': MAKEFILE_SRC_SKMOD_TARGET,
    '_skmod_dependency': MAKEFILE_SRC_SKMOD_DEPENDENCY,
    '_kernel_link_var': MAKEFILE_SRC_KERNEL_LINK_VAR,
    'target_name': MAKEFILE_SRC_TARGET_NAME
}

MAKEFILE_TEMPLATE = '''CC=gcc
CFLAGS=-O0 -g -Wall -Wextra -mno-red-zone -m64

SYMLIB_DIR=$$HOME/Symbi-OS/Symlib
SYMLIB_DYNAM_BUILD_DIR=$(SYMLIB_DIR)/dynam_build
SYMLIB_INCLUDE_DIR=$(SYMLIB_DIR)/include
SYMLIB_LINK=-L $(SYMLIB_DYNAM_BUILD_DIR) -lSym

KERNEL_LINK={_kernlink}

{_linux_path}
{_kern_mod_obj_m_append}

all: {_libkernel_dependency} {target_name}

{_libkernel_target}

{_skmod_target}

{target_name}: {_libkernel_dependency} {_skmod_dependency} {target_name}.c
\t$(CC) $(CFLAGS) -I$(SYMLIB_INCLUDE_DIR) $^ -o $@ {_kernel_link_var} $(SYMLIB_LINK)

clean:
\trm -rf *.o *.so *.s .*.d *.a {target_name}
'''

SKMOD_HEADER_CONTENT = '''#ifndef SKMOD_H
#define SKMOD_H

int skmod_getpid();

#endif
'''

SKMOD_SRC_CONTENT = '''#include <linux/module.h>	/* Needed by all modules */
#include <linux/sched.h>
#include <linux/mm.h>
#include <linux/pid.h>

int skmod_getpid(void) {
    return current->pid;
}
'''

MAIN_SRC_CONTENT = '''#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <LINF/sym_all.h>

int main() {
    uint64_t cr3;

    sym_elevate();
    asm volatile("mov %%cr3, %0" : "=r"(cr3));
    sym_lower();

    printf("cr3: 0x%lx\\n", cr3);
    return 0;
}
'''

MAIN_SRC_CONTENT_SKMOD = '''#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <LINF/sym_all.h>
#include "skmod.h"

int main() {{
    sym_elevate();
    int pid = skmod_getpid();
    sym_lower();

    printf("current->pid: %i\\n", pid);
    return 0;
}}
'''

MAKE_LIBKERNEL_SCRIPT = '''#!/bin/bash

VMLINUX=~/Symbi-OS/linux/vmlinux
KERNELASM=kernel.s
OBJ=libkernel.o
LIB=libkernel.a

tmpfile=/tmp/$$_null.s
cat > $tmpfile <<EOF
.section .note.GNU-stack

EOF


syms=""
nm $VMLINUX | while read val info sym; do
    if [[ $sym = abort ]]; then
        continue
    fi
  
    echo ".global $sym"
    echo ".set $sym,0x$val"
done > $KERNELASM

echo ".section .note.GNU-stack" >> $KERNELASM

gcc -static -c $KERNELASM -o $OBJ
ar rcs $LIB $OBJ

rm $KERNELASM
'''

def complete(text, state):
    """ Tab completion for file system paths. """
    # Check if the last character is a space to avoid appending slash on empty completions
    if not text.endswith(' ') and os.path.isdir(text) and not text.endswith('/'):
        text += '/'

    # Add a wildcard for directory listing and filter based on the state
    matches = glob.glob(text + '*') + [None]
    return matches[state]

def setup_autocomplete():
    """ Setup tab completion for the file system paths. """
    readline.set_completer_delims(' \t\n;')
    readline.set_completer(complete)
    readline.parse_and_bind("tab: complete")

def get_user_input(prompt, initial=""):
    """ Prompt the user for input, with tab completion and initial input. """
    # Prepend slash to initial path if it doesn't end with one and is not empty
    if not initial.endswith('/') and os.path.isdir(initial):
        initial += '/'
    
    # Setup autocomplete
    setup_autocomplete()
    
    # Set initial input for readline
    readline.set_startup_hook(lambda: readline.insert_text(initial))

    try:
        return input(prompt)
    finally:
        # Ensure the hook is removed so it doesn't affect subsequent inputs
        readline.set_startup_hook(None)

def generate_project_files(project_name, target_dir, use_kernel_build):
    """ Generate Makefile and other project files. """
    project_path = os.path.join(target_dir, project_name)
    if os.path.exists(project_path):
        print(f"Error: The directory '{project_path}' already exists.")
        return
    else:
        os.makedirs(project_path, exist_ok=True)
        makefile_path = os.path.join(project_path, 'Makefile')
        makefile_content = MAKEFILE_TEMPLATE.format(**MAKEFILE_FORMAT_DICTIONARY)

        with open(makefile_path, 'w') as makefile:
            makefile.write(makefile_content)

        if use_kernel_build:
            # Generating mklibkernel.sh
            mklibkern_sh_path = os.path.join(project_path, 'mklibkernel.sh')
            mklibkern_sh_content = MAKE_LIBKERNEL_SCRIPT
            with open(mklibkern_sh_path, 'w') as mklibkern_sh:
                mklibkern_sh.write(mklibkern_sh_content)

                # chmod +x
                st = os.stat(mklibkern_sh_path)
                os.chmod(mklibkern_sh_path, st.st_mode | stat.S_IEXEC)

            # Generating skmod.h
            skmod_h_path = os.path.join(project_path, 'skmod.h')
            skmod_h_content = SKMOD_HEADER_CONTENT
            with open(skmod_h_path, 'w') as skmod_h:
                skmod_h.write(skmod_h_content)
            
            # Generating skmod.c
            skmod_c_path = os.path.join(project_path, 'skmod.c')
            skmod_c_content = SKMOD_SRC_CONTENT
            with open(skmod_c_path, 'w') as skmod_c:
                skmod_c.write(skmod_c_content)
        
        # Generating program.c
        main_c_path = os.path.join(project_path, f'{MAKEFILE_SRC_TARGET_NAME}.c')
        main_c_content = MAIN_SRC_CONTENT_SKMOD if use_kernel_build else MAIN_SRC_CONTENT 
        with open(main_c_path, 'w') as program_c:
            program_c.write(main_c_content)
        
        print(f"Project files for '{project_name}' have been generated in '{target_dir}'.")

# Main script body
if __name__ == "__main__":
    project_name = input("Enter the project name: ")
    home_directory = os.path.expanduser('~')
    
    if not home_directory.endswith('/'):
        home_directory += '/'

    if os.path.isdir(f'{home_directory}Symbi-OS'):
        home_directory += 'Symbi-OS/'
    
    target_dir = get_user_input("Enter the target directory: ", initial=home_directory)
    use_kernel_build = ''

    while use_kernel_build.lower() not in ['y', 'n']:
        use_kernel_build = input("Use kernel module build system? [y/n]: ")
    
    use_kernel_build = use_kernel_build.lower() == 'y'
    
    if not use_kernel_build:
        for key in list(MAKEFILE_FORMAT_DICTIONARY.keys()):
            if key.startswith('_'):
                MAKEFILE_FORMAT_DICTIONARY[key] = ''

    generate_project_files(project_name, target_dir, use_kernel_build)
    
