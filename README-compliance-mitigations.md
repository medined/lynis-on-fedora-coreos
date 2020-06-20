# Compliance Mitigations

The ocp4-playbook-coreos-ncp.yml Ansible playbook checks 266 controls for
compliance. Of those, 207 pass on the Fedora CoreOS server.

## Links

* https://github.com/vmware-tanzu/tgik/blob/master/episodes/086/README.md
* https://github.com/vmware-tanzu/tgik/blob/master/episodes/101/README.md

* https://www.stigviewer.com/stig/red_hat_enterprise_linux_7/
* Ansible Hardening
  * https://galaxy.ansible.com/fedoraredteam/compliant
  * https://galaxy.ansible.com/konstruktoid/hardening
  * https://galaxy.ansible.com/dockpack/hardened7
  * https://galaxy.ansible.com/aishee/ansible_redhat_centos_7
  * https://galaxy.ansible.com/dockpack/secure_ssh
  * https://galaxy.ansible.com/erpadmin/rhel7-cis
  * https://galaxy.ansible.com/civicactions/simple-harden
  *
* http://atopathways.redhatgov.io/ - The Red Hat ATO Pathways microsite provides resources to accelerate your ATO process.
  * http://atopathways.redhatgov.io/cac/ansible/ocp4-playbook-coreos-ncp.yml
* https://www.openrmf.io/ - OpenRMF is an open source tool for managing, viewing, and reporting of your DoD STIG checklists.
  * https://github.com/Cingulara/openrmf-docs/blob/master/step-by-step.md
* https://github.com/ComplianceAsCode/

## Changes To Playbook

* Add `become: yes` to `Disable SSH Support for .rhosts Files / Deduplicate values from /etc/ssh/sshd_config'
* Add `become: yes` to `Disable SSH Support for .rhosts Files / Insert correct line to /etc/ssh/sshd_config'

## Changes To Fedora Baseline

* Deduplicate values from /etc/ssh/sshd_config

/etc/ssh/sshd_config, remove line with "IgnoreRhosts".

## Mitigation

### "Changed" OK

* require single user mode password - Production servers require PKI credentials in order to connect to them via
SSH. Proof:

/etc/ssh/sshd_config, "ChallengeResponseAuthentication no"
/etc/ssh/sshd_config, "PasswordAuthentication no"

# WARNING: 'UsePAM no' is not supported in Fedora and may cause several
# problems.
