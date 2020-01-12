#!/bin/bash

# -----------------------------------------------------------------------------
# define constants
# -----------------------------------------------------------------------------

export ANSIBLE_FORKS="9"
export ANSIBLE_FORCE_COLOR=true

STEP_NAMES=( bootstrap ssh-key-scan requirements-check packages-upgrade base prepare install post )
INCLUDE_CSV='0,1,2,3,4,5,6,7'
VERBOSITY=''
RETRY=false

# -----------------------------------------------------------------------------
# define helper
# -----------------------------------------------------------------------------

function gen_password() {
  local length=$1
  local count=$2

  if [ "${length}" == "" ]; then
    length=30
  fi

  if [ "${count}" == "" ]; then
    count=100
  fi

  for i in $(seq  1 $count); do
    tr -dc 'A-Za-z0-9_+\055!@#$%^&*()|:<>,.?=' < /dev/urandom | fold -w ${length} | grep -i '[A-Z]' | grep -i '[a-z]' | grep -i '[0-9]' | grep -i '[_+\055!@#$%^&*()|:<>,.?=]' | head -n 1
  done
}

# full directory name of the script no matter where it is being called from
get_setup_root() {
  if [[ -z "${SETUP_ROOT}" ]]; then
    # for non-symlink location
    #SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    # for any location
    source_path="${BASH_SOURCE[0]}"
    while [ -L "${source_path}" ]; do
      physical_directory="$(cd -P "$(dirname "${source_path}")" >/dev/null 2>&1 && pwd)"
      source_path="$(readlink "${source_path}")"
      [[ ${source_path} != /* ]] && source_path="${physical_directory}/${source_path}"
    done
    SETUP_ROOT="$(cd -P "$(dirname "${source_path}")" >/dev/null 2>&1 && pwd)"
  fi
  echo "${SETUP_ROOT}"
}
SETUP_ROOT="$(get_setup_root)"

# checking interactive shell
is_invoked() {
  if [ "$0" = "${BASH_SOURCE[0]}" ]; then
    true
  else
    false
  fi
}

# arguments parsing
for i in "$@" ; do
  case $i in
      -i=*|--include=*)
      INCLUDE_CSV="${i#*=}"
      shift # past argument=value
      ;;
      -v*)
      VERBOSITY=$i
      shift
      ;;
      -r)
      RETRY=true
      shift
      ;;
      *)
        # unknown option
      ;;
  esac
done
function split_csv {
  local IFS=','; # shellcheck disable=SC2206
  local v=( $1 );
  echo "${v[@]}";
}
declare -A STEP_NAME2INT
for i in ${!STEP_NAMES[*]} ; do
  STEP_NAME2INT["${STEP_NAMES[${i}]}"]=$i
done
declare -A included
for key in ${!STEP_NAMES[*]} ; do
  included[$key]=0
done
for key in $(split_csv "${INCLUDE_CSV}") ; do
  if [[ ${STEP_NAME2INT[$key]} ]] ; then
    included[${STEP_NAME2INT[$key]}]=1
  elif [[ -n "${included[$key]}" ]] ; then
    included[$key]=1
  fi
done
if [ "${RETRY,,}" = false ] ; then
  for i in "${SETUP_ROOT}"/playbooks/*.retry ; do
    if [ -e "$i" ] ; then
      /bin/rm "$i"
    fi
  done
fi



__main() {
  START_TIME=$SECONDS

  # hardening
  if is_invoked; then
    set -o pipefail
    set -o errtrace
    set -o nounset
    set -o errexit
  fi


  # start message
  echo -e '\n\n\n'
  echo "We are running on ${SETUP_ROOT}"
  echo

  # check ansible
  echo '# Checking ansible and packages ...'
  if ! ansible --version > /dev/null; then
    echo ' - Installing ansible ...'
    if ! sudo yum list installed epel-release > /dev/null; then
      sudo yum install -y epel-release
    fi
    sudo yum install -y --enablerepo=epel ansible
    echo ' - ... Installed ansible'
  fi
  packages=( "libselinux-python" "bind-utils" "jq" )
  for package in "${packages[@]}"; do
    if ! rpm -q "${package}" > /dev/null; then
      echo " - Installing ${package} ..."
      sudo yum install -y --enablerepo=epel "${package}"
      echo " - ... Installed ${package}"
    fi
  done
  echo '... Checked ansible and packages'
  echo -e '\n\n\n'

  # setup vault
  echo '# Setting up vaults ...'
  # set vault password
  VAULT_PASSWORD_FILE="${SETUP_ROOT}/tmp/.vault"
  VAULT_BASE="${SETUP_ROOT}/tmp/vaults"
  if [ ! -e "${VAULT_PASSWORD_FILE}" ]; then
    echo ' - Setting up vault password ...'
    touch "${VAULT_PASSWORD_FILE}"
    chmod 600 "${VAULT_PASSWORD_FILE}"
    password=''
    while [ -z "${password}" ]
    do
      read -r -s -p "   Vault password: " password1
      echo
      read -r -s -p "   Re-enter password to verify: " password2
      echo
      if [ "${password1}" = "${password2}" ]; then
        password="${password1}"
        echo "${password}" > "${VAULT_PASSWORD_FILE}"
        echo
        echo
      else
        echo
        echo "   Passwords do not match"
        echo
        echo
      fi
    done
    password=''
    password1=''
    password2=''
    mkdir -p "${VAULT_BASE}"
    echo ' - ... Set up vault password'
  fi
  # set secrets
  VAULT_FILE="vault.yml"
  if [ ! -e "${VAULT_BASE}/${VAULT_FILE}" ]; then
    echo ' - Setting up secrets ...'
    touch "${VAULT_BASE}/${VAULT_FILE}"
    chmod 600 "${VAULT_BASE}/${VAULT_FILE}"
    echo -e "---\n" >> "${VAULT_BASE}/${VAULT_FILE}"
    userlist=( "admin" "manager" )
    for user in "${userlist[@]}" ; do
    password=''
    while [ -z "${password}" ]
    do
      read -r -p "   ${user} id: " userid
      echo
      read -r -s -p "   ${user} password: " password1
      echo
      read -r -s -p "   Re-enter password to verify: " password2
      echo
      if [ "${password1}" = "${password2}" ]; then
        password="${password1}"
        echo -e "vault_${user}:\n"\
                "  id: ${userid}\n"\
                "  password: ${password}\n" >> "${VAULT_BASE}/${VAULT_FILE}"
        echo
        echo
      else
        echo
        echo "   Password dose not match"
        echo
        echo
      fi
    done
    password=''
    password1=''
    password2=''
    done
    ansible-vault encrypt --vault-id="setup@${VAULT_PASSWORD_FILE}" "${VAULT_BASE}/${VAULT_FILE}"
    echo ' - ... Set up secrets'
  fi
  # generate random password
  VAULT_RANDOM_PASSWORDS_FILE="vault_random_password.yml"
  if [ ! -e "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}" ]; then
    echo ' - Generate random password ...'
    touch "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}"
    chmod 600 "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}"
    echo -e "---\n" >> "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}"
    echo -e "vault_random_passwords:" >> "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}"
    for password in $(gen_password 30 100) ; do
      echo -e "- '${password}'" >> "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}"
    done
    echo >> "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}"
    password=''
    ansible-vault encrypt --vault-id="setup@${VAULT_PASSWORD_FILE}" "${VAULT_BASE}/${VAULT_RANDOM_PASSWORDS_FILE}"
    echo ' - ... Generated random password'
  fi
  VAULT_FILES=( "${VAULT_FILE}" "${VAULT_RANDOM_PASSWORDS_FILE}" )
  echo '... Set up vaults'
  echo -e '\n\n\n'

  # bootstrap ansible
  if [[ ${included["0"]} -eq 1 ]] ; then
    echo '# Bootstrapping ansible ...'
    extra_vars=$(echo "{ \"setup_root\": \"${SETUP_ROOT}\", \"vault_base\": \"${VAULT_BASE}\", \"vault_files\": $(printf '%s\n' "${VAULT_FILES[@]}" | jq -R . | jq -cs . ) }" | jq -c .)
    # shellcheck disable=SC2086
    ansible-playbook ${VERBOSITY} -f 1 -i localhost, -c local -e "${extra_vars}" "${SETUP_ROOT}/bootstrap-playbooks/site.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}"
    if [ -e "${SETUP_ROOT}/bootstrap-playbooks/site.retry" ]; then /bin/rm "${SETUP_ROOT}/bootstrap-playbooks/site.retry"; fi
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  # set ansible.cfg
  export ANSIBLE_CONFIG=${SETUP_ROOT}/tmp/ansible.cfg

  # scan SSH public key
  if [[ ${included["1"]} -eq 1 ]] ; then
    echo '# Scanning SSH public key ...'
    bash -c "ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i '${SETUP_ROOT}/inventory/hosts' -e 'setup_root=${SETUP_ROOT}' '${SETUP_ROOT}/playbooks/ssh-key-scan.yml' --vault-id='setup@${VAULT_PASSWORD_FILE}'"
    # shellcheck disable=SC2086
    if ! ansible all ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -m ping ; then
      echo
      echo " - Try copy ssh public key"
      # shellcheck disable=SC2086
      ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -k -e "setup_root=${SETUP_ROOT}" "${SETUP_ROOT}/playbooks/ssh-copy-id.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}"
    fi
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  # check requirements
  if [[ ${included["2"]} -eq 1 ]] ; then
    echo '# Checking requirements ...'
    # shellcheck disable=SC2086
    ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -e "setup_root=${SETUP_ROOT}" "${SETUP_ROOT}/playbooks/requirements-check.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}"
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  # upgrade packages
  if [[ ${included["3"]} -eq 1 ]] ; then
    echo '# Upgrading packages ...'
    running_holder="${SETUP_ROOT}/tmp/UPGRADED"
    if [ ! -e "${running_holder}" ]; then
      # shellcheck disable=SC2086
      ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -e "setup_root=${SETUP_ROOT}" "${SETUP_ROOT}/playbooks/paralleling-upgrade.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}"
      touch "${running_holder}"
    else
      echo ''
      echo '  skipped'
      echo ''
    fi
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  # run base
  if [[ ${included["4"]} -eq 1 ]] ; then
    echo '# Running base ...'
    limit=(  )
    if [ -e "${SETUP_ROOT}/playbooks/site.retry" ]; then
      limit=( --limit "@${SETUP_ROOT}/playbooks/site.retry" )
    fi
    # shellcheck disable=SC2086
    ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -e "setup_root=${SETUP_ROOT}" "${SETUP_ROOT}/playbooks/site.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}" --tags=base ${limit[@]+"limit[@]"}
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  # run prepare
  if [[ ${included["5"]} -eq 1 ]] ; then
    echo '# Running prepare ...'
    limit=(  )
    if [ -e "${SETUP_ROOT}/playbooks/site.retry" ]; then
      limit=( --limit "@${SETUP_ROOT}/playbooks/site.retry" )
    fi
    # shellcheck disable=SC2086
    ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -e "setup_root=${SETUP_ROOT}" "${SETUP_ROOT}/playbooks/site.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}" --tags=prepare ${limit[@]+"limit[@]"}
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  # run install
  if [[ ${included["6"]} -eq 1 ]] ; then
    echo '# Running install ...'
    limit=(  )
    if [ -e "${SETUP_ROOT}/playbooks/site.retry" ]; then
      limit=( --limit "@${SETUP_ROOT}/playbooks/site.retry" )
    fi
    # shellcheck disable=SC2086
    ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -e "setup_root=${SETUP_ROOT}" "${SETUP_ROOT}/playbooks/site.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}" --tags=install ${limit[@]+"limit[@]"}
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  # run post
  if [[ ${included["7"]} -eq 1 ]] ; then
    echo '# Running post ...'
    limit=(  )
    if [ -e "${SETUP_ROOT}/playbooks/site.retry" ]; then
      limit=( --limit "@${SETUP_ROOT}/playbooks/site.retry" )
    fi
    # shellcheck disable=SC2086
    ansible-playbook ${VERBOSITY} -f ${ANSIBLE_FORKS} -i "${SETUP_ROOT}/inventory/hosts" -e "setup_root=${SETUP_ROOT}" "${SETUP_ROOT}/playbooks/site.yml" --vault-id="setup@${VAULT_PASSWORD_FILE}" --tags=post ${limit[@]+"limit[@]"}
    echo '* ... done'
    echo -e '\n\n\n'
  fi

  END_TIME=$SECONDS
  duration=$((END_TIME - START_TIME))
  echo "$(date -u -d @"$duration" +'%-Hh %-Mm %-Ss') elapsed."
}


LOG="${SETUP_ROOT}/tmp/setup-$(date +%Y-%m-%d-%H-%M-%S)"

clear
__main 1> >(tee -a "${LOG}.stdout.log" | tee -a "${LOG}.combnd.log" >&1) 2> >(tee -a "${LOG}.stderr.log" | tee -a  "${LOG}.combnd.log" >&2)

less -R "${LOG}.combnd.log"
