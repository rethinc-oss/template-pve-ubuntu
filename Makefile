EXECUTABLES = curl git dab sed
K := $(foreach exec,$(EXECUTABLES),\
        $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))

BASEDIR:=$(shell dab basedir)
TEMPLATE_DIR=./templates

global: info/init_ok sysinst installzsh createsysuser createclonescript hardenssh removepkg


info/init_ok: dab.conf
	dab init
	touch $@


sysinst:
        # ============================
	# Sys Install
        # ============================
	#
	# Create a minimal debootstrap
	@dab bootstrap --minimal

	# Generate and set the default locale
	@dab install locales
	@sed -e 's/^# en_US.UTF-8/en_US.UTF-8/' -i $(BASEDIR)/etc/locale.gen
	@dab exec dpkg-reconfigure locales
	@echo "LANG=en_US.UTF-8" > $(BASEDIR)/etc/default/locale

	# Set the default keyboard layout
	@sed -e 's/^XKBLAYOUT="us"/XKBLAYOUT="de"/' -i $(BASEDIR)/etc/default/keyboard

	# Set timezone to Europe/Berlin
	@echo "Europe/Berlin" > $(BASEDIR)/etc/timezone
	@dab exec rm -f /etc/localtime
	@dab exec ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime


installzsh:
	#
	#
        # ============================
	# Install ZSH
        # ============================
	#
        # Install zsh & oh-my-zsh
	@dab install git
	@dab install zsh
	@curl -o /tmp/oh-my-zhs-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
	@chmod +x /tmp/oh-my-zhs-install.sh
	ZSH='$(BASEDIR)/usr/share/oh-my-zsh' /tmp/oh-my-zhs-install.sh --unattended

	# Install 'dracula' theme
	@dab exec mkdir -p /usr/share/oh-my-zsh/themes/lib
	@curl -o $(BASEDIR)/usr/share/oh-my-zsh/themes/dracula.zsh-theme https://raw.githubusercontent.com/dracula/zsh/master/dracula.zsh-theme
	@curl -o $(BASEDIR)/usr/share/oh-my-zsh/themes/lib/async.zsh https://raw.githubusercontent.com/dracula/zsh/master/lib/async.zsh

	# Customize .zshrc template in /etc/skel
	@dab exec cp /usr/share/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
	@dab exec sed -i 's|export ZSH=.*|export ZSH=/usr/share/oh-my-zsh|' /etc/skel/.zshrc
	@dab exec sed -i 's|ZSH_THEME=.*|ZSH_THEME="dracula"|' /etc/skel/.zshrc
	@dab exec sed -i '/source.*/i ZSH_CACHE_DIR=$$HOME\/.cache\/oh-my-zsh\nif [[ ! -d $$ZSH_CACHE_DIR ]]; then\n  mkdir -p $$ZSH_CACHE_DIR\nfi\n' /etc/skel/.zshrc
	@dab exec sed -i '/source.*/i ZSH_COMPDUMP=$${ZSH_CACHE_DIR}\/.zcomdump-$${ZSH_VERSION}\n' /etc/skel/.zshrc
	@dab exec sed -i '/# User configuration/a \\nif [ -d "\$${HOME}/.local/bin" ] ; then\n    PATH="\$${HOME}/.local/bin:\$${PATH}\nfi' /etc/skel/.zshrc
	@dab exec sed -i '/# User configuration/a \\nif [ -d "\$${HOME}/bin" ] ; then\n    PATH="\$${HOME}/bin:\$${PATH}\nfi' /etc/skel/.zshrc

	# Remove bash templates from /etc/skel
	@dab exec rm -f /etc/skel/.bash_logout
	@dab exec rm -f /etc/skel/.bashrc
	@dab exec rm -f /etc/skel/.profile

	# Make zsh the default shell for new users
	@dab exec sed -i "s|#DSHELL=.*|DSHELL=/bin/zsh|" /etc/adduser.conf

	# Convert the root user
	@dab exec chsh -s /bin/zsh root
	@dab exec rm -f /root/.bash_logout
	@dab exec rm -f /root/.bashrc
	@dab exec rm -f /root/.profile
	@dab exec cp /etc/skel/.zshrc /root


createsysuser:
        #
        #
        # ============================
        # Creating the management user
        # ============================
        #
        # Install zsh & oh-my-zsh
	@dab exec adduser --quiet --disabled-password --comment "System Operator" sysop
	@dab exec sudo adduser sysop sudo
	@dab exec sh -c "echo sysop:sysop | sudo chpasswd"


createclonescript:
	#
	#
	# ============================
	# Create the cloning service
	# ============================
	@cp $(TEMPLATE_DIR)/clone-credentials.sh $(BASEDIR)/usr/local/bin
	@chmod 0744 $(BASEDIR)/usr/local/bin/clone-credentials.sh
	@cp $(TEMPLATE_DIR)/clone-credentials.service $(BASEDIR)/etc/systemd/system
	@dab exec ln -s /usr/lib/systemd/system/clone-credentials.service /etc/systemd/system/sysinit.target.wants/clone-credentials.service


hardenssh:
	#
	#
	# ============================
	# Harden the ssh service
	# ============================
	@cp $(TEMPLATE_DIR)/sshd_config $(BASEDIR)/etc/ssh/
	awk '$$5 >= 3071' $(BASEDIR)/etc/ssh/moduli > $(BASEDIR)/etc/ssh/moduli.tmp
	mv $(BASEDIR)/etc/ssh/moduli.tmp $(BASEDIR)/etc/ssh/moduli


removepkg:
	#
	#
	# ============================
	# Remove system packages
	# ============================
	@dab exec apt --purge -q -y remove postfix


package:
	#
	#
	# ============================
	# Create dist archive
	# ============================
	dab finalize --compressor zstd-max


.PHONY: clean
clean:
	dab clean


.PHONY: dist-clean
dist-clean:
	dab dist-clean


all: global
        #
        #
	# ============================
        # If no errors reported
        # you can run "make package"
        # to create dist archive
	# ============================
