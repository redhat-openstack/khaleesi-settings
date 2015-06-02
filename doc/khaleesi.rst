Using Khaleesi
==============

.. _prereqs:

Prerequisites
-------------

RHEL7 or Fedora20 with Python 2.7 (2.6 is not supported). For running jobs,
khaleesi requires a dedicated RHEL7 or F20 Jenkins slave. We do have an ansible
playbook that sets up a slave, see :ref:`jenkins-slave`.

.. WARNING:: Do not use the root user, as these instructions assumes that you
   are a normal user and uses venv. Being root may shadow some of the errors
   you may make like forgetting to source venv and pip install ansible.

In case of RHEL7, first add the RDO and EPEL repos::

    sudo yum install https://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-4.noarch.rpm
    sudo yum install http://mirror.compevo.com/epel/beta/7/x86_64/epel-release-7-0.2.noarch.rpm

Install the required packages::

    sudo yum install python-pip python-virtualenv gcc git
    sudo yum install python-keystoneclient python-novaclient python-glanceclient python-neutronclient python-keystoneclient

.. _installation:

Installation
------------

Create or enter a folder where you want to check out the repos. We assume that
both repo and your virtual environment is in the same directory. Clone the
repos::

    git clone https://github.com/redhat-openstack/khaleesi.git
    git clone https://REPLACE_ME/gerrit/p/khaleesi-settings.git

read-only mirror::

    git clone http://REPLACE_ME/git/khaleesi-settings.git

Gerrit::

    https://review.gerrithub.io/#/q/project:redhat-openstack/khaleesi
    https://REPLACE_ME/gerrit/gitweb?p=khaleesi-settings.git;a=summary

Create the virtual envionment, install ansible and ksgen in it::

    virtualenv venv
    source venv/bin/activate
    pip install ansible
    cd khaleesi
    cd tools/ksgen
    python setup.py develop
    cd ../..

Create the appropriate ansible.cfg for khaleesi::

    cat > ansible.cfg << EOF
    [defaults]
    host_key_checking = False
    roles_path = ./roles
    library = ./library:$VIRTUAL_ENV/share/ansible/
    lookup_plugins = ./plugins/lookups
    EOF

Copy your private key file that you will use to access instances to
``khaleesi/``. We're going to use the common ``rhos-jenkins.pem`` key.::

    cp ../khaleesi-settings/settings/provisioner/openstack/site/qeos/tenant/keys/rhos-jenkins.pem  <dir>/khaleesi/
    chmod 600 rhos-jenkins.pem

Usage
-----

After you have everything set up, let's see how you can create machines using
packstack or foreman installer. The most simple case is using automatically
acquired hosts, so we discuss that first. In both cases we're going to use
ksgen_ (Khaleesi Settings Generator) for supplying Khaleesi's ansible
playbooks_ with a correct configuration.

.. _ksgen: https://github.com/redhat-openstack/khaleesi/tree/master/tools/ksgen
.. _playbooks: http://docs.ansible.com/playbooks_intro.html

Let's have a simple case: We will deploy an all-in-one RHEL OSP 5.0 with
packstack.

First we create the appropriate configuration file with ksgen. Make sure that
you are in your virtual envirnment that you previously created. ::

    source venv/bin/activate

Generate the configuration with the following command::

    ksgen --config-dir=../khaleesi-settings/settings generate \
        --rules-file=../khaleesi-settings/rules/packstack-rhos-aio.yml \
        --provisioner=openstack \
        --provisioner-site=qeos \
        --provisioner-site-user=rhos-jenkins \
        --extra-vars provisioner.key_file=$PRIVATE_KEY \
        --provisioner-options=execute_provision \
        --product-version=5.0 \
        --product-version-repo=puddle \
        --product-version-build=latest \
        --product-version-workaround=rhel-6.5 \
        --workarounds=enabled \
        --distro=rhel-6.5 \
        --installer-network-variant=ml2-vxlan \
        --installer-messaging=rabbitmq \
        --tester=tempest \
        --tester-setup=rpm \
        --tester-tests=minimal \
        ksgen_settings.yml

.. Note:: These run settings can get outdated. If you want to replicate a
   Jenkins job, the best solution is to check its configuration and use the
   commands found inside the "Build" section. For example, this command was
   copied from here_.

.. _here: http://REPLACE_ME/view/khaleesi/view/rhos-puddle/job/khaleesi-rhos-5.0-puddle-rhel-6.5-aio-packstack-neutron-gre-rabbitmq-tempest-rpm-minimal/configure

The result is a YAML file collated from all the small YAML snippets from
``khaleesi-settings/settings``. All the options are quite self-explanatory and
changing them is simple as well. The rule file is currently only used for
deciding the installer+product+topology configuration. Check out ksgen_ for
detailed documentation.

.. Note:: We're using the ``rhos-dev`` user on the QEOS OpenStack instance for
   our example. The username cannot be arbitrary, it must be a file in
   ``khaleesi-settings/settings/provisioner/openstack/site/qeos/user``.

This next step is going to do all the work. If you're just building a testing
machine for yourself, consider adding the ``--no-logs`` switch. Otherwise all
the logs will be copied from the testing machines to the ``collect_logs``
directory after the run. If you're debugging, add ``--verbose``. ::

    ./run.sh --use ksgen_settings.yml playbooks/packstack.yml

.. Note:: If you get various ansible related errors while running this command
   (for example ``ERROR: group_by is not a legal parameter in an Ansible task
   or handler``) then first check if you installed ansible in the virtual env,
   that you enabled the virtual env. If you have a system wide ansible
   installation, please also try removing it and try again.

If any part fails, you can ask for help on the internal #rdo-ci channel. Don't
forget to save the relevant error lines on something like pastebin_.

.. _pastebin: http://REPLACE_ME

Using your new nodes
--------------------

When your run is complete (or even while it's running), you can log in to your
nodes. Finding out your node names is simple with the novaclient installed.
You'll see something like this when ansible is working::

    TASK: common | Ensure common dependencies

    ok: [rhos-pksk-XXXXXXXXXX-controller] => (item=libselinux-python)
    ok: [rhos-pksk-XXXXXXXXXX-tempest] => (item=libselinux-python)

The important part is the random string before -controller or -tempest. You can
also find this in the first few lines of ``ksgen_settings.yml`` under
``node.prefix``.

If you don't have an OpenStack RC file for QEOS, `download it`_, save it to
your khaleesi folder, then source it in your current shell::

    source rhos-dev-openrc.sh

.. _`download it`: http://REPLACE_ME/dashboard/project/access_and_security/api_access/openrc/

Now you can list your instances::

    nova list| grep XXXXXXXXXX
    | f69cc0d9-a62b-4144-b07d-ccec13e759a9 | rhos-pksk-vbkvjjjmtn-controller        | ACTIVE | -          | Running     | rhos-dev-2=172.16.41.6; rhos-dev=172.16.40.12, 10.8.48.89 |
    | 5433c40e-69d1-46f0-9dcb-e130ac692064 | rhos-pksk-vbkvjjjmtn-tempest           | ACTIVE | -          | Running     | rhos-dev-2=172.16.41.7; rhos-dev=172.16.40.14, 10.8.48.124 |

The 10.x.x.x IP is the floating IP of the nodes. If you don't want to run Tempest, you can ignore the second machine. Log in to your node::

    ssh -i rhos-jenkins.pem cloud-user@10.8.48.89

.. Note:: If you're using Fedora, replace ``cloud-user`` with ``fedora``.

Cleanup
-------
After you finished your work, you can simply remove the created instances by::

    ./cleanup.sh ksgen_settings.yml

.. Note:: The instances are cleaned up by a janitor script after they are more
   than 1 day old, so don't use these nodes as a long term solution.

Deploying Foreman
-----------------

Not much needs to be changed for deploying a Foreman instance. We only need to
replace the rules file with the appropriate foreman one. Currently we only have
the "default" multinode configuration, which will expand later. This will
result in 1 controller and 1 compute node. This time let's deploy on RHEL7. ::

    ksgen --config-dir=$CONFIG_BASE/settings generate \
      --rules-file=$CONFIG_BASE/rules/foreman-rhos-default.yml \
      --provisioner=openstack \
      --provisioner-site=qeos \
      --provisioner-site-user=rhos-jenkins \
      --extra-vars provisioner.key_file=$PRIVATE_KEY \
      --provisioner-options=execute_provision \
      --product-version=5.0 \
      --product-version-repo=poodle \
      --product-version-build=latest \
      --product-version-workaround=rhel-6.6 \
      --workarounds=enabled \
      --distro=rhel-6.6 \
      --installer-network=neutron \
      --installer-network-variant=gre \
      --installer-messaging=rabbitmq \
      --tester=tempest \
      --tester-setup=rpm \
      --tester-tests=all \
      ksgen_settings.yml
    ./run.sh --use ksgen_settings.yml playbooks/foreman.yml

Accessing your nodes are done by the same was as in the previous step.

Using existing hosts
--------------------

There's an extra step involved, creating the proper inventory_ file for
ansible.

.. _inventory: http://docs.ansible.com/intro_inventory.html

As usual, create a ksgen settings file that matches your hosts. (Of course
adjust the product-version and others to match your preference.) Note the
``--provisioner-options=skip_provision \`` setting. ::

    ksgen --config-dir=$CONFIG_BASE/settings generate \
      --rules-file=$CONFIG_BASE/rules/packstack-rdo-aio.yml \
      --provisioner=openstack \
      --provisioner-site=qeos \
      --provisioner-site-user=rhos-jenkins \
      --provisioner-options=skip_provision \
      --extra-vars provisioner.key_file=$PRIVATE_KEY \
      --product-version=icehouse \
      --product-version-repo=stage \
      --product-version-workaround=fedora-20 \
      --workarounds=enabled \
      --distro=fedora-20 \
      --installer-network=nova \
      --installer-network-variant=flatdhcp \
      --installer-messaging=rabbitmq \
      --tester=tempest \
      --tester-setup=rpm \
      --tester-tests=minimal \
      ksgen_settings.yml

Create a new hosts file::

    cat > my_hosts << EOF
    controller ansible_ssh_host=<ipv4-address> ansible_ssh_user=<username> ansible_sudo_pass=<passwd> private_ip=<internal-ip> fqdn=controller.packstack.example.com
    tempest    ansible_ssh_host=<ipv4-address> ansible_ssh_user=<username> ansible_sudo_pass=<passwd>

    [manually-provisioned]
    controller
    tempest

    [manually-provisioned:vars]
    ansible_ssh_private_key_file=rhos-jenkins.pem

    [local]
    localhost ansible_connection=local

    # all the VMs
    [openstack_nodes]
    controller
    tempest

    [packstack]
    controller

    [rdo]
    controller

    [neutron]
    controller

    [compute]
    controller
    EOF

Replace all the <> values with your own settings. You can leave out the
ansible_sudo_pass variable if your image doesn't require sudo password.

Afterwards, execute ``run.sh`` using the custom inventory file::

    ./run.sh --use ksgen_settings.yml --inventory my_hosts playbooks/packstack.yml

The system should be set up after the command finishes.
