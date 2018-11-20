#!/bin/bash

#
# Debian specific functions
#
# (c) 2008-2016, Hetzner Online GmbH
#

# setup_network_config "$device" "$HWADDR" "$IPADDR" "$BROADCAST" "$SUBNETMASK" "$GATEWAY" "$NETWORK" "$IP6ADDR" "$IP6PREFLEN" "$IP6GATEWAY"
setup_network_config() {
  if [ -n "$1" ] && [ -n "$2" ]; then

    #
    # good we have a device and a MAC
    #
    CONFIGFILE="$FOLD/hdd/etc/network/interfaces"
    if [ -f "$FOLD/hdd/etc/udev/rules.d/70-persistent-net.rules" ]; then
      UDEVFILE="$FOLD/hdd/etc/udev/rules.d/70-persistent-net.rules"
    else
      UDEVFILE="/dev/null"
    fi
    {
      echo "### $COMPANY - installimage"
      echo "# device: $1"
      printf 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="%s", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="%s"\n' "$2" "$1"
    } > "$UDEVFILE"

    {
      echo "### $COMPANY - installimage"
      echo "# Loopback device:"
      echo "auto lo"
      echo "iface lo inet loopback"
      echo "iface lo inet6 loopback"
      echo ""
    } > "$CONFIGFILE"

    if [ -n "$3" ] && [ -n "$4" ] && [ -n "$5" ] && [ -n "$6" ] && [ -n "$7" ]; then
      echo "# device: $1" >> "$CONFIGFILE"
      if is_private_ip "$3" && isVServer; then
        {
          echo "auto  $1"
          echo "iface $1 inet dhcp"
        } >> "$CONFIGFILE"
      else
        {
          echo "auto  $1"
          echo "iface $1 inet static"
          echo "  address   $3"
          echo "  netmask   $5"
          echo "  gateway   $6"
          if ! is_private_ip "$3"; then
            echo "  # default route to access subnet"
            echo "  up route add -net $7 netmask $5 gw $6 $1"
          fi
        } >> "$CONFIGFILE"
      fi
    fi

    if [ -n "$8" ] && [ -n "$9" ] && [ -n "${10}" ]; then
      debug "setting up ipv6 networking $8/$9 via ${10}"
      {
        echo ""
        echo "iface $1 inet6 static"
        echo "  address $8"
        echo "  netmask $9"
        echo "  gateway ${10}"
      } >> "$CONFIGFILE"
    fi

    return 0
  fi
}

# generate_config_mdadm "NIL"
generate_config_mdadm() {
  local mdadmconf="/etc/mdadm/mdadm.conf"
  execute_chroot_command "/usr/share/mdadm/mkconf > $mdadmconf"; declare -i EXITCODE=$?

  #
  # Enable mdadm
  #
  local mdadmdefconf="$FOLD/hdd/etc/default/mdadm"
  sed -i "s/AUTOCHECK=false/AUTOCHECK=true # modified by installimage/" \
    "$mdadmdefconf"
  sed -i "s/AUTOSTART=false/AUTOSTART=true # modified by installimage/" \
    "$mdadmdefconf"
  sed -i "s/START_DAEMON=false/START_DAEMON=true # modified by installimage/" \
    "$mdadmdefconf"
  sed -i -e "s/^INITRDSTART=.*/INITRDSTART='all' # modified by installimage/" \
    "$mdadmdefconf"

  return "$EXITCODE"
}

# generate_new_ramdisk "NIL"
generate_new_ramdisk() {
  if [ -n "$1" ]; then
    local outfile; outfile=$(find "$FOLD"/hdd/boot -name "initrd.img-*" -not -regex '.*\(gz\|bak\)' -printf '%f\n' | sort -nr | head -n1)
    local kvers; kvers=$(echo "$outfile" |cut -d "-" -f2-)
    debug "# Kernel Version found: $kvers"

    if [ "$IMG_VERSION" -ge 60 ]; then
      local blacklist_conf="$FOLD/hdd/etc/modprobe.d/blacklist-$C_SHORT.conf"
      # blacklist various driver due to bugs and stability issues
      {
        echo "### $COMPANY - installimage"
        echo "### silence any onboard speaker"
        echo "blacklist pcspkr"
        echo "blacklist snd_pcsp"
        echo "### i915 driver blacklisted due to various bugs"
        echo "### especially in combination with nomodeset"
        echo "blacklist i915"
        echo "### mei driver blacklisted due to serious bugs"
        echo "blacklist mei"
        echo "blacklist mei_me"
        echo 'blacklist sm750fb'
      } > "$blacklist_conf"
    fi

    # apparently sometimes the mdadm assembly bugfix introduced with the recent mdadm release does not work
    # however, the problem is limited to H8SGL boards
    # see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=784070
    if [ "$IMG_VERSION" -ge 80 ] && [ "$MBTYPE" = 'H8SGL' ]; then
      local script="$FOLD/hdd/usr/share/initramfs-tools/scripts/local-block/mdadmpatch"
      cp "$SCRIPTPATH/h8sgl-deb8-md.sh" "$script"
      chmod a+x "$script"
    fi

    # just make sure that we do not accidentally try to install a bootloader
    # when we haven't configured grub yet
    # Debian won't install a boot loader anyway, but display an error message,
    # that needs to be confirmed
    [[ -e "$FOLD/hdd/etc/kernel-img.conf" ]] && \
      sed -i "s/do_bootloader = yes/do_bootloader = no/" "$FOLD/hdd/etc/kernel-img.conf"

    # well, we might just as well update all initramfs and stop findling around
    # to find out which kernel version is the latest
    execute_chroot_command "update-initramfs -u -k $kvers"; EXITCODE=$?

    return "$EXITCODE"
  fi
}

setup_cpufreq() {
  if [ -n "$1" ]; then
    local loadcpufreqconf="$FOLD/hdd/etc/default/loadcpufreq"
    local cpufreqconf="$FOLD/hdd/etc/default/cpufrequtils"
    {
      echo "### $COMPANY - installimage"
      echo "# cpu frequency scaling"
    } > "$cpufreqconf"
    if isVServer; then
      echo 'ENABLE="false"' > "$loadcpufreqconf"
      echo 'ENABLE="false"' >> "$cpufreqconf"
    else
      {
        echo 'ENABLE="true"'
        printf 'GOVERNOR="%s"' "$1"
        echo 'MAX_SPEED="0"'
        echo 'MIN_SPEED="0"'
      } >> "$cpufreqconf"
    fi

    return 0
  fi
}

#
# Generate the GRUB bootloader configuration.
#
generate_config_grub() {
  declare -i EXITCODE=0

  local grubdefconf="$FOLD/hdd/etc/default/grub"

  # set linux_default in grub
  local grub_linux_default="nomodeset"
  if isVServer; then
     grub_linux_default="${grub_linux_default} elevator=noop"
  fi

  sed -i "$grubdefconf" -e "s/^GRUB_HIDDEN_TIMEOUT=.*/GRUB_HIDDEN_TIMEOUT=5/" -e "s/^GRUB_HIDDEN_TIMEOUT_QUIET=.*/GRUB_HIDDEN_TIMEOUT_QUIET=false/"
  sed -i "$grubdefconf" -e "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${grub_linux_default}\"/"
  # need to sort escapes of this cmd to use without execute_chroot
  execute_chroot_command 'sed -i /etc/default/grub -e "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"'"${grub_linux_default}"'\"/"'

  # only install grub2 in mbr of all other drives if we use swraid
  local debconf_drives;
  for ((i=1; i<=COUNT_DRIVES; i++)); do
    if [ "$SWRAID" -eq 1 ] || [ "$i" -eq 1 ] ;  then
      local disk; disk="$(eval echo "\$DRIVE"$i)"
      execute_chroot_command "grub-install --no-floppy --recheck $disk 2>&1"
      if [ "$i" -eq 1 ]; then
        debconf_drives="$disk"
      else
        debconf_drives="$debconf_drives, $disk"
      fi
    fi
  done
  [ -e "$FOLD/hdd/boot/grub/grub.cfg" ] && rm "$FOLD/hdd/boot/grub/grub.cfg"

  execute_chroot_command "grub-mkconfig -o /boot/grub/grub.cfg 2>&1"
  execute_chroot_command "echo 'set grub-pc/install_devices $debconf_drives' | debconf-communicate"

  uuid_bugfix

  PARTNUM=$(echo "$SYSTEMBOOTDEVICE" | rev | cut -c1)

  if [ "$SWRAID" = "0" ]; then
    PARTNUM="$((PARTNUM - 1))"
  fi

  delete_grub_device_map

  return "$EXITCODE"
}

delete_grub_device_map() {
  [ -f "$FOLD/hdd/boot/grub/device.map" ] && rm "$FOLD/hdd/boot/grub/device.map"
}

#
# os specific functions
# for purpose of e.g. debian-sys-maint mysql user password in debian/ubuntu LAMP
#
run_os_specific_functions() {
  randomize_mdadm_checkarray_cronjob_time

  #
  # randomize mysql password for debian-sys-maint in LAMP image
  #
  debug "# Testing if mysql is installed and if this is a LAMP image and setting new debian-sys-maint password"
  if [ -f "$FOLD/hdd/etc/mysql/debian.cnf" ] ; then
    if [[ "${IMAGE_FILE,,}" =~ lamp ]]; then
      randomize_maint_mysql_pass || return 1
    fi
  fi

  (( "${IMG_VERSION}" >= 80 )) && (( "${IMG_VERSION}" <= 711 )) && debian_udev_finish_service_fix

  return 0
}

randomize_mdadm_checkarray_cronjob_time() {
  local mdcron="$FOLD/hdd/etc/cron.d/mdadm"
  if [ -f "$mdcron" ] && grep -q checkarray "$mdcron"; then
    declare -i hour minute day
    minute=$(((RANDOM % 59) + 1))
    hour=$(((RANDOM % 4) + 1))
    day=$(((RANDOM % 28) + 1))
    debug "# Randomizing cronjob run time for mdadm checkarray: day $day @ $hour:$minute"

    sed -i -e "s/^[* 0-9]*root/$minute $hour $day * * root/" -e "s/ &&.*]//" "$mdcron"
  else
    debug "# No /etc/cron.d/mdadm found to randomize cronjob run time"
  fi
}

debian_udev_finish_service_fix() {
  local unit_file="${FOLD}/hdd/lib/systemd/system/udev-finish.service"
  local override_dir="${FOLD}/hdd/etc/systemd/system/udev-finish.service.d"
  local override_file="${override_dir}/override.conf"
  if ! [[ -f "${unit_file}" ]]; then
    debug '# udev-finish.service not found. not installing override'
    return
  fi
  debug '# install udev-finish.service override'
  mkdir "${override_dir}"
  {
    echo "### ${COMPANY} - installimage"
    echo '[Unit]'
    echo 'After=basic.target'
  } > "${override_file}"
}

#
# randomize mysql password for debian-sys-maint in LAMP image
#
randomize_maint_mysql_pass() {
  local sqlconfig; sqlconfig="$FOLD/hdd/etc/mysql/debian.cnf"
  local mycnf; mycnf="$FOLD/hdd/root/.my.cnf"
  local pma_dbc_cnf; pma_dbc_cnf="$FOLD/hdd/etc/dbconfig-common/phpmyadmin.conf"
  local pma_sec_cnf; pma_sec_cnf="$FOLD/hdd/var/lib/phpmyadmin/blowfish_secret.inc.php"
  # generate PW for user debian-sys-maint, root and phpmyadmin
  local debianpass; debianpass=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c16)
  local rootpass; rootpass=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c16)
  local pma_pass; pma_pass=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c16)
  local pma_sec; pma_sec=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c24)
  if [ -f "$pma_sec_cnf" ]; then
    echo -e "<?php\\n\$cfg['blowfish_secret'] = '$pma_sec';" > "$pma_sec_cnf"
  fi
  MYSQLCOMMAND="USE mysql; \
  UPDATE user SET password=PASSWORD('$debianpass') WHERE user='debian-sys-maint'; \
  UPDATE user SET password=PASSWORD('$rootpass') WHERE user='root'; \
  UPDATE user SET password=PASSWORD('$pma_pass') WHERE user='phpmyadmin'; \
  FLUSH PRIVILEGES;"
  echo -e "$MYSQLCOMMAND" > "$FOLD/hdd/etc/mysql/pwchange.sql"
  execute_chroot_command "/etc/init.d/mysql start >>/dev/null 2>&1"
  execute_chroot_command "mysql --defaults-file=/etc/mysql/debian.cnf < /etc/mysql/pwchange.sql >>/dev/null 2>&1"; EXITCODE=$?
  execute_chroot_command "/etc/init.d/mysql stop >>/dev/null 2>&1"
  sed -i s/password.*/"password = $debianpass"/g "$sqlconfig"
  sed -i s/dbc_dbpass=.*/"dbc_dbpass='$pma_pass'"/g "$pma_dbc_cnf"
  if [ "$IMG_VERSION" -ge 80 ]; then
    mkdir "$FOLD/hdd/run/lock"
  fi
  execute_chroot_command "DEBIAN_FRONTEND=noninteractive dpkg-reconfigure phpmyadmin"
  rm "$FOLD/hdd/etc/mysql/pwchange.sql"

  #
  # generate correct ~/.my.cnf
  #
  {
    echo "[client]"
    echo "user=root"
    echo "password=$rootpass"
  } > "$mycnf"

  # write password file and erase script
  cp "$SCRIPTPATH/password.txt" "$FOLD/hdd/"
  sed -i -e "s#<password>#$rootpass#" "$FOLD/hdd/password.txt"
  local motdfile;
  if [ "$IMG_VERSION" -ge 80 ]; then
     mkdir "$FOLD/hdd/etc/update-motd.d"
     motdfile="$FOLD/hdd/etc/update-motd.d/99-hetzner-lamp"
     {
       echo "#!/bin/sh"
       echo ""
       echo 'echo ""'
       echo "echo 'Note: Your MySQL password is in /password.txt (delete this with \"erase_password_note\")'"
       echo 'echo ""'
     } > "$motdfile"
     chmod 755 "$motdfile"
     # currently broken in jessie #743286
     sed -i -e 's/motd.dynamic/motd/' "$FOLD/hdd/etc/pam.d/sshd"
  else
     motdfile="$FOLD/hdd/etc/motd.tail"
    {
      echo ''
      echo 'Note: Your MySQL password is in /password.txt (delete this with "erase_password_note")'
      echo ''
    } >>  "$motdfile"
  fi
  chmod 600 "$FOLD/hdd/password.txt"
  cp "$SCRIPTPATH/erase_password_note" "$FOLD/hdd/usr/local/bin/"
  chmod +x "$FOLD/hdd/usr/local/bin/erase_password_note"

  return "$EXITCODE"
}

# vim: ai:ts=2:sw=2:et
