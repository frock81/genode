#!/bin/bash

# Autor: Fabio Rocha <frock81@yahoo.com.br>
# 
# Descrição: 
#   Script para gerar ISOs para servidores físicos 
#   e máquinas virtuais.
# 
# TODO:
#   - cache para imagens ISO
#   - personalizar nome e senha de usuário

NET_TYPE=
NET_TYPE_DESC=
NET_TYPE_1="s"
NET_TYPE_2="d"
NET_TYPE_1_DESC="static"
NET_TYPE_2_DESC="dynamic"
PART_TYPE=
PART_TYPE_DESC=
PART_TYPE_1="l"
PART_TYPE_2="r"
PART_TYPE_1_DESC="lvm"
PART_TYPE_2_DESC="raid+lvm"
HOST_NAME=
HOST_NAME_TAG="{{ hostname }}"
BASE_ISO_PATH=
MOUNTPOINT="/mnt/iso"
CUSTOM_ISO_PATH=
CUSTOM_ISO_PRESEED_PATH=
PRESEED_DISTRO_1_TYPE_1=
PRESEED_DISTRO_1_TYPE_2="preseed_-_debian_-_raid+lvm.cfg.template"
PRESEED_DISTRO_2_TYPE_1="preseed_-_ubuntu_-_lvm.cfg.template"
PRESEED_DISTRO_2_TYPE_2="preseed_-_ubuntu_-_raid+lvm.cfg.template"
PRESEED_DISTRO_PATH=
PRESEED_TEMPLATE_DIR=preseed
PRESEED_TEMPLATE_PATH=
OUTPUT_ISO=
OUTPUT_DIR=
LINUX_DISTRO=
LINUX_DISTRO_NAME=
LINUX_DISTRO_1_SHORT="d"
LINUX_DISTRO_1_LONG="debian"
LINUX_DISTRO_2_SHORT="u"
LINUX_DISTRO_2_LONG="ubuntu"
LINUX_DISTRO_CODENAME=
NET_IP_ADDRESS=
NET_IP_ADDRESS_TAG="{{ net_ip_address }}"
ACCT_ROOT_PASSWORD=
ACCT_ROOT_PASSWORD_REPEAT=
ACCT_ROOT_PASSWORD_HASH=
ACCT_USERNAME=
ACCT_USER_FULLNAME=
ACCT_USER_PASSWORD=
ACCT_USER_PASSWORD_REPEAT=
ACCT_USER_PASSWORD_HASH=
DEBUG=0
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_RESET="\033[0m"
CONFIG_FILE=
IS_VM=
IS_NOT_A_VM=0
IS_A_VM=1

handle_ctrl_c()
{
  clean
  echo "Saindo..."
  exit
}

echo_color()
{
  local color="$1"
  local msg="$2"
  echo -e "\n${color}${msg}${COLOR_RESET}" 
}

echo_err()
{
  echo_color "${COLOR_RED}" "ERROR: ${1}"
}

echo_warn()
{
  echo_color "${COLOR_YELLOW}" "WARN: ${1}"
}

echo_info()
{
  echo_color "${COLOR_GREEN}" "INFO: ${1}"
}

echo_debug()
{
  echo_warn "DEBUG -- $1"
}

rm_custom_iso_dir()
{
  if [ -n "$CUSTOM_ISO_PATH" ]; then
    if [ "$DEBUG" -eq 1 ]; then
      echo_debug "Não removerá diretório ISO personalizada '$CUSTOM_ISO_PATH'"
      return
    fi
    sudo rm -rf "$CUSTOM_ISO_PATH"
  fi
}

umount_base_iso()
{
  if [ -d $MOUNTPOINT ]; then
    mountpoint $MOUNTPOINT > /dev/null
  fi
  if [ $? -eq 0 ]; then
    if [ "$DEBUG" -eq 1 ]; then
      echo_debug "Não desmontará ponto de montagem '${MOUNTPOINT}'"
      return
    fi
    sudo umount $MOUNTPOINT
  fi
}

rm_mountpoint()
{
  if [ -d $MOUNTPOINT ]; then
    if [ "$DEBUG" -eq 1 ]; then
      echo_debug "Não removerá diretório do ponto de montagem '${CUSTOM_ISO_PATH}'"
      return
    fi
    sudo rm -rf $MOUNTPOINT
  fi
}

clean()
{
  rm_custom_iso_dir
  umount_base_iso
  rm_mountpoint
}

create_traps()
{
  trap handle_ctrl_c 2
}

choose_linux_distro()
{
   while true; do
    cat <<EOF

Qual distro deseja usar?

  $LINUX_DISTRO_1_SHORT: $LINUX_DISTRO_1_LONG
  $LINUX_DISTRO_2_SHORT: $LINUX_DISTRO_2_LONG

Escolha uma das opções: 
EOF
    read LINUX_DISTRO
    if [ "$LINUX_DISTRO" = "$LINUX_DISTRO_1_SHORT" ]; then
      echo "Será criada uma ISO do tipo '$LINUX_DISTRO_1_LONG'"
      LINUX_DISTRO_NAME=$LINUX_DISTRO_1_LONG
      LINUX_DISTRO_CODENAME=jessie
      break
    fi
    if [ "$LINUX_DISTRO" = "$LINUX_DISTRO_2_SHORT" ]; then
      echo "Será criada uma ISO do tipo '$LINUX_DISTRO_2_LONG'"
      LINUX_DISTRO_NAME=$LINUX_DISTRO_2_LONG
      LINUX_DISTRO_CODENAME=xenial
      break
    fi
    echo "Opção inválida"
  done
}

validate_ip_address()
{
  echo $NET_IP_ADDRESS | grep "^10\.93\.4[89]\..\{1,3\}$" > /dev/null
  if [ $? -ne 0 ]; then
    echo "Endereço IP inválido: $NET_IP_ADDRESS"
    echo "O endereço IP deve fazer parte da rede 10.93.48.0/23"
    return 1
  fi

  if [ "$NET_IP_ADDRESS" = "10.93.48.11" ]; then
    echo "O endereço IP não pode ser o mesmo que o do gateway ($NET_IP_ADDRESS)"
    return 1
  fi

  if [ "$NET_IP_ADDRESS" = "10.93.49.255" ]; then
    echo "O endereço IP não pode ser o mesmo que o de broadcast ($NET_IP_ADDRESS)"
    return 1
  fi  

  return $return_code
}

get_net_info()
{
  while true; do
    read -p "Informe o endereço IP: " NET_IP_ADDRESS
    if validate_ip_address "$NET_IP_ADDRESS"; then
      break
    fi
  done
}

choose_net_type()
{
  while true; do
    cat <<EOF

Qual tipo de endereçamento de rede?

  $NET_TYPE_1: $NET_TYPE_1_DESC
  $NET_TYPE_2: $NET_TYPE_2_DESC

Escolha uma das opções: 
EOF
    read NET_TYPE
    if [ "$NET_TYPE" = "$NET_TYPE_1" ]; then
      echo "Será usado um endereçamento do tipo '$NET_TYPE_1_DESC'"
      NET_TYPE_DESC=$NET_TYPE_1_DESC
      get_net_info
      break
    fi
    if [ "$NET_TYPE" = "$NET_TYPE_2" ]; then
      echo "Será usado um endereçamento do tipo '$NET_TYPE_2_DESC'"
      NET_TYPE_DESC=$NET_TYPE_2_DESC
      break
    fi
    echo "Opção inválida"
  done
}

choose_partition_type()
{
  while true; do
    cat <<EOF

Qual tipo de particionamento?

  $PART_TYPE_1: $PART_TYPE_1_DESC
  $PART_TYPE_2: $PART_TYPE_2_DESC

Escolha uma das opções: 
EOF
    read PART_TYPE
    if [ "$PART_TYPE" = "$PART_TYPE_1" ]; then
      echo "Será criada uma ISO do tipo '$PART_TYPE_1_DESC'"
      PART_TYPE_DESC=$PART_TYPE_1_DESC
      break
    fi
    if [ "$PART_TYPE" = "$PART_TYPE_2" ]; then
      echo "Será criada uma ISO do tipo '$PART_TYPE_2_DESC'"
      PART_TYPE_DESC=$PART_TYPE_2_DESC
      break
    fi
    echo "Opção inválida"
  done
}

choose_is_vm()
{
  while true; do
    cat <<EOF

Trata-se de uma máquina virtual (virtio)?

  $IS_NOT_A_VM: não
  $IS_A_VM: sim

Escolha uma das opções: 
EOF
    read IS_VM
    if [ "$IS_VM" = "$IS_NOT_A_VM" ]; then
      echo "Não será criada uma ISO para vm."
      break
    fi
    if [ "$IS_VM" = "$IS_A_VM" ]; then
      echo "Será criada uma ISO para uma máquina virtual."
      break
    fi
    echo "Opção inválida"
  done
}

validate_hostname()
{
  echo $HOST_NAME | grep '^[a-z0-9-]\+$' > /dev/null
  return $?
}

choose_hostname()
{
  local confirma=
  echo 
  while true; do
    read -p "Digite o nome do host: " HOST_NAME
    while true; do
      read -p "O nome de host selecionado foi '$HOST_NAME'. Confirma? (s|n) " confirma
      if [ "$confirma" = "s" -o "$confirma" = "n" ]; then
        break
      fi
      echo "Opção inválida."
    done
    if [ "$confirma" = "s" ]; then
      if validate_hostname; then
        echo "Será usado '$HOST_NAME' para o host."
        break
      fi
      echo "Nome de host não validado."
      echo "Somente caracteres minúsculos e o dash são válidos."
      continue
    fi
    echo "Nome de host não confirmado."
  done
}

set_output_dir()
{
  OUTPUT_DIR=$HOME
}

set_output_iso_name()
{
  OUTPUT_ISO=custom-$(echo "$LINUX_DISTRO_NAME" | tr '[:upper:]' '[:lower:]')-$PART_TYPE_DESC-${HOST_NAME}.iso
}

get_base_iso_path()
{
  while true; do
    read -e -p "Forneça o caminho da ISO base: " BASE_ISO_PATH
    if [ -r "$BASE_ISO_PATH" ]; then
      break
    fi
    echo "Não foi possível ler a ISO '$BASE_ISO_PATH'."
  done
}

check_mountpoint_existance()
{
  [ -d "$ MOUNTPOINT" ] || sudo mkdir -p "$MOUNTPOINT"
}

check_mountpoint_mounted()
{
  mountpoint "$MOUNTPOINT" > /dev/null && sudo umount "$MOUNTPOINT"
}

real_mount_base_iso()
{
  sudo mount -o loop "$BASE_ISO_PATH" "$MOUNTPOINT" &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Erro ao montar a ISO base. Saindo."
    exit
  fi
  echo "ISO base montada com sucesso."
}

mount_base_iso()
{
  check_mountpoint_existance
  check_mountpoint_mounted
  real_mount_base_iso
}

check_custom_iso_path()
{
  CUSTOM_ISO_PATH=$( mktemp -d )
}

real_copy_base_iso_files()
{
  cp -rT "$MOUNTPOINT"/ "$CUSTOM_ISO_PATH"/
}

copy_base_iso_files()
{
  check_custom_iso_path
  real_copy_base_iso_files
}

copy_preseed_file()
{
  PRESEED_DISTRO_PATH=$BASEDIR/$PRESEED_TEMPLATE_DIR
  if [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_1_LONG" ]; then
    PRESEED_DISTRO_PATH=$PRESEED_DISTRO_PATH/$LINUX_DISTRO_1_LONG
    if [ "$PART_TYPE_DESC" = "$PART_TYPE_1_DESC" ]; then
      cp "$PRESEED_DISTRO_PATH/$PRESEED_DISTRO_1_TYPE_1" "$CUSTOM_ISO_PATH/preseed.cfg"
    fi
    if [ "$PART_TYPE_DESC" = "$PART_TYPE_2_DESC" ]; then
      cp "$PRESEED_DISTRO_PATH/$PRESEED_DISTRO_1_TYPE_2" "$CUSTOM_ISO_PATH/preseed.cfg"
    fi
  elif [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_2_LONG" ]; then
    PRESEED_DISTRO_PATH=$PRESEED_DISTRO_PATH/$LINUX_DISTRO_2_LONG
    if [ "$PART_TYPE_DESC" = "$PART_TYPE_1_DESC" ]; then
      cp "$PRESEED_DISTRO_PATH/$PRESEED_DISTRO_2_TYPE_1" "$CUSTOM_ISO_PATH/preseed.cfg"
    fi
    if [ "$PART_TYPE_DESC" = "$PART_TYPE_2_DESC" ]; then
      cp "$PRESEED_DISTRO_PATH/$PRESEED_DISTRO_2_TYPE_2" "$CUSTOM_ISO_PATH/preseed.cfg"
    fi
  fi
}

replace_vars()
{
  sed -i "s/{{ hostname }}/$HOST_NAME/" "$CUSTOM_ISO_PATH/preseed.cfg"
}

set_preseed_distro_path()
{
  PRESEED_DISTRO_PATH=$BASEDIR/$PRESEED_TEMPLATE_DIR
  if [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_1_LONG" ]; then
    PRESEED_DISTRO_PATH=$PRESEED_DISTRO_PATH/$LINUX_DISTRO_1_LONG
  elif [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_2_LONG" ]; then
    PRESEED_DISTRO_PATH=$PRESEED_DISTRO_PATH/$LINUX_DISTRO_2_LONG
  fi
}

set_preseed_template_path()
{
  PRESEED_TEMPLATE_PATH="$PRESEED_DISTRO_PATH/${LINUX_DISTRO_NAME}_${LINUX_DISTRO_CODENAME}"
}

append_template_to_presseed()
{
  local suffix="$1"
  cat "${PRESEED_TEMPLATE_PATH}_${suffix}.cfg" >> "$CUSTOM_ISO_PRESEED_PATH"
}

process_localization()
{
  append_template_to_presseed "localization"
}

process_static_network()
{
  sed -e "s/$NET_IP_ADDRESS_TAG/$NET_IP_ADDRESS/" -e "s/$HOST_NAME_TAG/$HOST_NAME/" \
    "${PRESEED_TEMPLATE_PATH}_network_static.cfg" >> "$CUSTOM_ISO_PRESEED_PATH"
}

process_dynamic_network()
{
  sed "s/$HOST_NAME_TAG/$HOST_NAME/" "${PRESEED_TEMPLATE_PATH}_network_dynamic.cfg" \
    >> "$CUSTOM_ISO_PRESEED_PATH"
}

process_network()
{
  # TODO Obter o hostname via dhcp ou forçar um nome
  # TODO Selecionar interface no auto ou forçar uma particular
  if [ "$NET_TYPE_DESC" = "$NET_TYPE_1_DESC" ]; then
    process_static_network
  else
    process_dynamic_network
  fi
}

process_mirror()
{
  append_template_to_presseed "mirror"
}

prompt_for_user()
{
  echo 
  while true; do
    read -p "Entre com o nome completo do novo usuário: " ACCT_USER_FULLNAME
    echo
    read -p "Entre com o nome de usuário: " ACCT_USERNAME
    echo
    break
  done
}

prompt_for_user_password()
{
  echo 
  while true; do
    read -s -p "Entre com uma senha para o novo usuário: " ACCT_USER_PASSWORD
    echo 
    read -s -p "Entre novamente com a senha para o novo usuário: " ACCT_USER_PASSWORD_REPEAT
    echo
    if [ "$ACCT_USER_PASSWORD" = "$ACCT_USER_PASSWORD_REPEAT" ]; then
      break
    fi
    echo "Senhas não conferem"
  done
}

prompt_for_root_password()
{
  echo 
  while true; do
    read -s -p "Entre com a senha de root: " ACCT_ROOT_PASSWORD
    echo 
    read -s -p "Entre novamente com a senha de root: " ACCT_ROOT_PASSWORD_REPEAT
    echo
    if [ "$ACCT_ROOT_PASSWORD" = "$ACCT_ROOT_PASSWORD_REPEAT" ]; then
      break
    fi
    echo "Senhas não conferem"
  done
}

calculate_password_hash()
{
 ACCT_ROOT_PASSWORD_HASH=$( mkpasswd -m sha-512 $ACCT_ROOT_PASSWORD )
}

calculate_user_password_hash()
{
 ACCT_USER_PASSWORD_HASH=$( mkpasswd -m sha-512 $ACCT_USER_PASSWORD )
}

replace_user()
{
 sed -e "s#{{ acct_user_fullname }}#$ACCT_USER_FULLNAME#" -e "s#{{ acct_username }}#$ACCT_USERNAME#" \
     -e "s#{{ acct_user_password }}#$ACCT_USER_PASSWORD_HASH#" -e "s#{{ acct_user_password_repeat }}#$ACCT_USER_PASSWORD_HASH#" \
     -e "s#{{ acct_user_password_hash }}#$ACCT_USER_PASSWORD_HASH#" \
     "${PRESEED_TEMPLATE_PATH}_account.cfg" >> "$CUSTOM_ISO_PRESEED_PATH"
}

replace_root_password_hash()
{
 sed -e "s#{{ root_password_hash }}#$ACCT_ROOT_PASSWORD_HASH#" \
  "${PRESEED_TEMPLATE_PATH}_root.cfg" >> "$CUSTOM_ISO_PRESEED_PATH"
}

process_account()
{
  if [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_1_LONG" ]; then
    if [ -z $ACCT_ROOT_PASSWORD_HASH ]; then
      prompt_for_root_password
      calculate_password_hash
      prompt_for_user
      prompt_for_user_password
      calculate_user_password_hash
    fi
    replace_root_password_hash
    replace_user
  elif [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_2_LONG" ]; then
    if [ -z $ACCT_USER_PASSWORD ]; then
      prompt_for_user
      prompt_for_user_password
      calculate_user_password_hash
    fi
    replace_user
  fi
}

process_tz()
{
  append_template_to_presseed "tz"
}

process_partitioning()
{
  #XXX O arquivo precisa ter o nome de acordo com o que está nesse código.
  cat "${PRESEED_TEMPLATE_PATH}_partitioning_${PART_TYPE_DESC}.cfg" \
    >> "$CUSTOM_ISO_PRESEED_PATH"
}
process_base()
{
  append_template_to_presseed "base"
}
process_apt()
{
  append_template_to_presseed "apt"
}
process_packages()
{
  append_template_to_presseed "packages"
}
process_bootloader()
{
  append_template_to_presseed "bootloader"
}
process_finishing()
{
  append_template_to_presseed "finishing"
}

process_vm()
{
  sed -i 's#/dev/sda#/dev/vda#' "$CUSTOM_ISO_PRESEED_PATH"
  # sed -i 's#mirror/http/proxy string#mirror/http/proxy string http://serv31.ic.pcdf.gov.br:8888/#' "$CUSTOM_ISO_PRESEED_PATH"
}

generate_preseed_file()
{
  set_preseed_template_path
  # TODO Trocar as funções simples 'process_...()' por 'append_template_to_preseed()'
  process_localization
  process_network
  process_mirror
  process_account
  process_tz
  process_partitioning
  process_base
  process_apt
  process_packages
  process_bootloader
  process_finishing
  if [ "$IS_VM" -eq "$IS_A_VM" ]; then
    process_vm
  fi
}

set_custom_iso_preseed_path()
{
  CUSTOM_ISO_PRESEED_PATH="$CUSTOM_ISO_PATH/preseed.cfg"
  touch "$CUSTOM_ISO_PRESEED_PATH"
}

process_preseed()
{
  set_custom_iso_preseed_path
  set_preseed_distro_path
  generate_preseed_file
  #copy_preseed_file
  #if [ $? -ne 0 ]; then
  #  echo "Erro ao copiar arquivo preseed. Saindo..."
  #  exit 1
  #fi
  #replace_vars
}

set_timeout()
{
  if [ "$DEBUG" -eq 0 ]; then
    sudo sed -i 's/timeout .\+/timeout 1/' "$CUSTOM_ISO_PATH/isolinux/isolinux.cfg"
  fi
}

append_default_install()
{
  local default=
  local parameters=""
  if [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_1_LONG" ]; then
    default="\tappend vga=788 initrd=/install.amd/initrd.gz --- quiet"
    parameters="$auto "
    parameters="$parameters file=/cdrom/preseed.cfg "
    parameters="$parameters DEBCONF_DEBUG=5 "
    parameters="$parameters debian-installer/locale=pt_BR "
    parameters="$parameters localechooser/translation/warn-severe=true "
    parameters="$parameters keyboard-configuration/xkb-keymap=pt_BR"
    sudo sed -i "6c\ $default $parameters" "$CUSTOM_ISO_PATH/isolinux/txt.cfg"
  elif [ "$LINUX_DISTRO_NAME" = "$LINUX_DISTRO_2_LONG" ]; then
    sudo sed -i "\#default install# a\label autoinstall\n  menu label ^Automatically install Ubuntu\n  kernel /install/vmlinuz\n  append auto file=/cdrom/preseed.cfg vga=788 initrd=/install/initrd.gz quiet debian-installer/locale=pt_BR localechooser/translation/warn-light=true console-setup/ask_detect=false keyboard-configuration/layout=pt_BR keyboard-configuration/variant=\"Portuguese (Brazil)\" DEBCONF_DEBUG=5 --" "$CUSTOM_ISO_PATH/isolinux/txt.cfg"
  fi
}

real_create_iso()
{
  sudo mkisofs -D -r -V “UBUNTU_UNATTENDED” -cache-inodes -J -l \
    -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table -o "$OUTPUT_DIR/$OUTPUT_ISO" \
    -input-charset "utf-8" "$CUSTOM_ISO_PATH/"
  if [ $? -eq 0 ]; then
    echo "Imagem '$OUTPUT_ISO' criada com sucesso!"
    echo "A ISO foi salva no diretório $OUTPUT_DIR"
  fi
}

create_iso()
{
  if [ ! -r "$BASE_ISO_PATH" ]; then
    if [ -r "$CONFIG_FILE" ]; then
      echo_warn "Não foi possível ler $BASE_ISO_PATH"
    fi
    get_base_iso_path
  fi
  mount_base_iso
  copy_base_iso_files
  process_preseed
  set_timeout
  append_default_install
  real_create_iso
}

main_logic()
{
  [ -z "$LINUX_DISTRO_NAME" ] && choose_linux_distro
  [ -z "$NET_TYPE_DESC" ] && choose_net_type
  [ -z "$HOST_NAME" ] && choose_hostname
  [ -z "$PART_TYPE_DESC" ] && choose_partition_type
  [ -z "$IS_VM" ] && choose_is_vm
  set_output_dir
  set_output_iso_name
  create_iso
  clean
}

set_base_dir()
{
  BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
}

read_config_file()
{
  if [ -f "$CONFIG_FILE" -a -r "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  fi
}

init()
{
  set_base_dir
  read_config_file
}

print_usage()
{
  cat <<EOF
Uso: $(basename $0) [opções]
Opções:
  -h | --help)                Ajuda
  -d | --debug)               Debug
  -c | --config <config_file> Arquivo de configuração
  
EOF
}

activate_debug()
{
  DEBUG=1
  echo_debug "Debug ativado."
}

clean_command()
{
  sudo rm -rf /tmp/tmp.*
}

parse_options()
{
  while [ "$#" -gt 0 ]; do
    local option="$1"
    case $option in 
      -h|--help) 
        print_usage
        exit 
      ;;
      -d|--debug) 
        activate_debug
        shift
      ;;
      -c|--config)
        CONFIG_FILE="$2"
        shift 2
      ;;
      -x|--clean)
        clean_command
        exit
      ;;
      *) 
        echo "Opção desconhecida"
        exit
      ;;
    esac
  done
}

main()
{
  parse_options "$@"
  init
  create_traps
  main_logic
}

main "$@"
