if [ -d "khaleesi" ]; then
  echo "" > khaleesi/ssh.config.ansible
else
  echo "" > ssh.config.ansible
fi
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_ROLES_PATH=$WORKSPACE/khaleesi/roles
export ANSIBLE_LIBRARY=$WORKSPACE/khaleesi/library:$VIRTUAL_ENV/share/ansible
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=False
export ANSIBLE_FORCE_COLOR=yes
export ANSIBLE_CALLBACK_PLUGINS=$WORKSPACE/khaleesi/plugins/callbacks/
export ANSIBLE_FILTER_PLUGINS=$WORKSPACE/khaleesi/plugins/filters/
export ANSIBLE_SSH_ARGS=' -F ssh.config.ansible'
export ANSIBLE_TIMEOUT=60
