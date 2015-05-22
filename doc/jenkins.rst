Creating a Jenkins server with Khaleesi jobs
============================================

Getting a Jenkins
-----------------

Deploying the jobs require a properly configured Jenkins server. We have a
couple of them already, but if you want to experiment without any fear of
messing with other jobs, the best is to get yourself a server. It's recommended
to use the Long Term Support (LTS) version.

You can create a VM on any of our OpenStack instances (don't forget to use your
public key for it), attach a floating IP and then `install Jenkins`_. This
should work both on Fedora and RHEL::

    sudo wget -O /etc/yum.repos.d/jenkins.repo \
    http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo
    sudo rpm --import \
    http://pkg.jenkins-ci.org/redhat-stable/jenkins-ci.org.key
    yum install jenkins
    service jenkins start
    chkconfig jenkins on

.. _install Jenkins: http://pkg.jenkins-ci.org/redhat-stable/

Installing plugins
------------------

Our jobs require quite a few plugins. So when your Jenkins is up and running,
navigate to ``http://$JENKINS_IP:8080/cli`` and download jenkins-cli.jar.

Afterwards. just execute these commands::

    java -jar jenkins-cli.jar -s http://$JENKINS_IP:8080/ install-plugin git \
    xunit ansicolor multiple-scms rebuild ws-cleanup gerrit-trigger \
    parameterized-trigger envinject email-ext sonar copyartifact timestamper \
    build-timeout jobConfigHistory test-stability jenkins-multijob-plugin \
    dynamicparameter swarm shiningpanda scm-api ownership mask-passwords \
    jobConfigHistory buildresult-trigger test-stability dynamicparameter \
    scm-api token-macro swarm scripttrigger groovy-postbuild shiningpanda \
    jenkins-multijob-plugin ownership


Deploying the jobs
------------------

You can do this from any machine. Install JJB::

    pip install jenkins-job-builder

Create a config file for it::

    cat > my_jenkins << EOF
    [jenkins]
    user=my_username
    password=my_password
    url=http://$JENKINS_IP:8080/
    EOF

Optional: I recommend turning off the timed runs (deleting - timed lines from
the job template), otherwise they would run periodically on your test server::

    sed '/- timed:/d' khaleesi-settings/jobs/main.yaml

Then just run the job creation (the last argument is the job directory of the
khaleesi-settings repo, which I assume you cloned previously)::

    jenkins-jobs --conf my_jenkins update khaleesi-settings/jobs/

Bonus: Test your job changes
----------------------------

If you want to experiment with your own job changes:

* open ``khaleesi-settings/jobs/defaults.yaml``
* change the khaleesi and/or khalessi-settings repo URL to your own
  (probably on http://REPLACE_ME) and your own branch
* execute the job building step above

Now your test server will use your own version of the repos.

.. Tip:: you can ``git stash save testing`` these changes, and later recall
   them with ``git stash pop`` to make this testing step easy along the code
   review submission.

.. _jenkins-slave:

Creating a Jenkins slave
------------------------

Now you need to either set up the machine itself as a slave, or attach/create a
slave to run the jobs. The slave needs to have the 'khaleesi' label on it to
run the JJB jobs.

You can set up a slave with the help of the khaleesi-slave repo. ::

    git clone git://REPLACE_ME/users/REPLACE_ME/khaleesi-slave/.git
    cd khaleesi-slave/
    cat << EOF > hosts
    $SLAVE_IP

    [slave]
    $SLAVE_IP
    EOF

Check the settings in ansible.cfg. If you run into weird ansible errors about
modules you probably don't have them set up correctly. This should be enough::

    [defaults]
    host_key_checking = False
    roles_path = ./roles

Execute the playbook, assuming that your instance uses the "fedora" user and
you can access it by the "rhos-jenkins.pem" private key file. If you used a
proper cloud image, it will fail. ::

    ansible-playbook -i hosts -u fedora playbooks/basic_internal_slave.yml --private-key=rhos-jenkins.pem -v

Login to the machine, become root and delete the characters from
/root/.ssh/authorized_keys before the "ssh-rsa" word. Log out and rerun the
ansible command. It should now finish successfully.

Add the slave to Jenkins. If you used the same machine, specify ``localhost``
and add the relevant public key for the rhos-ci user. use the
``/home/rhos-ci/jenkins`` directory, add the ``khaleesi`` label, only run tied
jobs. You're done.

