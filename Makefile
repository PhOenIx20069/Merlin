obj-m += modules/merlin/merlin_.o

KDIR := $(PWD)/linux-6.10.10.compiled

PWD := $(shell pwd)
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
	
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean