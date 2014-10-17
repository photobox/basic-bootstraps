#Creating "Babel-Ready" VDC Templates

"Babel-Ready" templates are created from an instance booted using a bare-OS template to which has been added the minimum amount of software needed to allow the instance to boot, classify itself based on launch time parameters in userdata and invoke Puppet successfully once.

##Steps

Before beginning you need to know the address of a NAT instance that will provide internet access during the bootstrap software installation.

##Set up temporary networking

Connect to the instance with SSH. Instances created from the bare template don't know how to route to the internet by design but preinstallation requires it; this is how to set it up:

```
ip route add 10.0.00/8 via EXISTING_DEFAULT_GW_ADDRESS
ip route del default
ip route add default via NAT_INSTANCE_ADDRESS
```

##Run pre-boostrapper

Now run the pre-bootstrap script to install Git & Puppet (which will finish the bootstrap installation).

```
wget -q -O- --no-check-certificate https://raw.githubusercontent.com/photobox/basic-bootstraps/master/bin/vdc_template_prep.sh|sudo bash
```

Next, follow the instructions printed by the previous step to complete the preinstallation. Don't forget to shut the instance down before the next step.

##Snapshot & Template Instance

Snapshot the instance by first discovering the volume id of the source instance.

```
$ cloudmonkey
vdc> list volumes virtualmachineid=YOUR_VM_ID
vdc> create template volumeid=VOLUME_ID_FROM_LAST_STEP ostypeid=d0f2984c-8510-11e3-8895-005056ac0d46 name=SOME_NAME displaytext="My Awesome Template"
```
