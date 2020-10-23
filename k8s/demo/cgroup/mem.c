// source: https://medium.com/@kkwriting/kubernetes-resource-limits-and-kernel-cgroups-337625bab87d
//
// ./mem 20 (pass)
// Get the process ID
// ./mem 21 (Killed)
//
//  cd /sys/fs/cgroup/memory
//  mkdir cgroup-mem-demo
//  cd cgroup-mem-demo
//  echo $processID > cgroup.procs
//
// bpftrace -e 'kretprobe:try_charge /pid == 21738/ { @ret[retval] = count(); @[kstack]=count(); }'
// The c program used to demo on mem limit enforced by cgroup

#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#define PAGE (4*1024)
int get_key() {
    printf("\nPress any key to continue…\n");
    return getc(stdin);
}
int main(int argc, char **argv) {
    char c __attribute__((unused));
    unsigned char *p;
    int count=0;
    if (argc < 2) {
       printf("Usage: mem <pages to allocate>\n");
       return -1;
    }
    int alloc_mem = atoi(argv[1])*PAGE;
    printf("Pid: %d. \n", getpid());
    printf("Page allocation requested: %d.\n", alloc_mem);
    printf("Yet to call malloc.\n");
    c = get_key();
    p = malloc(alloc_mem);
    printf("Malloc called. No writes yet.");
    c = get_key();
    for (int i=0; i<alloc_mem ; i++) {
        p[i] = 1;
    }
    for (int i=0; i<alloc_mem ; i++) {
        if (p[i] == 1) count++;
    }
    printf("Alloc in bytes: %d\n", alloc_mem);
    printf("Page count: %d\n", count/PAGE);
    c = get_key();
}
