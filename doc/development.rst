Contributing to Khaleesi development
====================================

Adding workarounds
------------------

Let's walk through the process using an example. Let's assume that the
``openstack-nova-objectstore`` package is not installed on the controller
during the packstack installation. We want to install this package and start
the service before running Tempest.

Creating the role
^^^^^^^^^^^^^^^^^

Create a role in the ``khaleesi/roles/workarounds`` directory that will execute
the necessary steps.

In our case, we install the package and start the service in this role by
adding the ``nova-objectstore-install/tasks/main.yml`` file with the following
content::

    ---
    - name: workaround install openstack-nova-objectstore bz1138740
    yum: name=openstack-nova-objectstore state=present
    sudo: yes

    - name: start and enable openstack-nova-objectstore
    service: name=openstack-nova-objectstore state=restarted enabled=yes
    sudo: yes

Enabling the workaround
^^^^^^^^^^^^^^^^^^^^^^^

Decide on which system you want to enable it. This is done in the
``khaleesi-settings`` repository. If you only want to apply it on Fedora 20
systems, go to
``settings/product/rdo/version/icehouse/workaround/fedora-20.yml`` and enable
the specific workaround for that system::

    workaround:
        nova_objectstore_install: true

.. Warning:: Don't use hypens/dashes ("-") in the variable name, it won't work.

You can place this workaround specification to any relevant ksgen settings file
(different levels for products, installers, etc.).

By default Khaleesi runs with workarounds enabled, but you candisable all of
them by running ksgen with the ``--workarounds=disabled``option.

Specifying where to run
^^^^^^^^^^^^^^^^^^^^^^^

Now we have to decide when and on which machine we want to apply the
workaround. Look in the ``khaleesi/workarounds`` folder for different playbooks
that get executed with different installers and at different points of the run.

In this case, we're using the ``workarounds-post-run-packstack.yml`` file, and
add a role for the Controller specific workarounds part. ::

    - name: Workarounds | specific to Controllers (roles)
    hosts: controller
    roles:
        - { role: workarounds/nova-objectstore-install,
              when: workarounds.enabled and workaround.nova_objectstore_install | default(false) }

