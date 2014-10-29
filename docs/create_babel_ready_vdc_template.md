#Creating "babel-ready" VDC Templates

**babel-ready** templates are created from an instance booted using a bare-OS template to which has been added the minimum amount of software needed to allow the instance to boot, classify itself based on launch time parameters in userdata and invoke Puppet successfully once.

#Prerequisites

* A checkout of [net-cloudstack-simple](https://github.com/photobox/net-cloudstack-simple).
* Perl and the necessary modules locally installed by following the [net-cloudstack-simple README](https://github.com/photobox/net-cloudstack-simple/blob/master/README.md).
* The address of a NAT instance, referred to as NAT_INSTANCE_ADDRESS in this document, that will provide internet access during the bootstrap software installation.
* The ID of the bare OS template upon which the babel-ready template will be based.

#Steps

##Boot bare instance

```
./vdc_launch_instance -t TEMPLATE_ID --role basetemplate -z 'Paris (ESX)' -s 1024-2 --networkid c6f16a47-28dc-47a7-a037-c84f89d3f492 --debug --userdata '{"facts":{"nat_device":"NAT_INSTANCE_ADDRESS"}}'
```

##Set up temporary networking

Connect to the instance with SSH and the username & password that have been circulated. Instances created from the bare template don't know how to route to the internet by design but preinstallation requires it; this is how to set it up:

```
sudo ip route add 10.0.00/8 via $(ip route show to 0.0.0.0/0|awk '{print $3}')
sudo ip route del to 0.0.0.0/0
sudo ip route add default via NAT_INSTANCE_ADDRESS
```

##Run pre-boostrapper

Now run the pre-bootstrap script to install Git & Puppet (which will finish the bootstrap installation).

```
wget -q -O- --no-check-certificate https://raw.githubusercontent.com/photobox/basic-bootstraps/master/bin/vdc_template_prep.sh|sudo bash
```

Next, follow the instructions printed by the previous step to complete the preinstallation. Don't forget to shut the instance down before the next step.

##Snapshot & Template Instance

Make sure the instance about to be snapshotted is in state **Stopped**.

```
vdc> list virtualmachines id=VM_ID
```

The command `vdc_list_instances` command provided by [net-cloudstack-simple](https://github.com/photobox/net-cloudstack-simple) may also be used.

If necessary stop the VM:

```
vdc> stop virtualmachine id=VM_ID
```

Note that sometimes a VM will take a few minutes to show correct status after a `poweroff` from the shell or an API `stopVirtualMachine`.

Now snapshot the VM's root volume:

```
vdc> list volumes virtualmachineid=YOUR_VM_ID
vdc> create snapshot volumeid=VOLUME_ID_FROM_PREVIOUS_STEP
```

The snapshotting process typically takes 10 minutes. When it has completed, create a template from the snapshot:

```
vdc> create template snapshotid=SNAPSHOT_ID_FROM_LAST_STEP ostypeid=d0f2984c-8510-11e3-8895-005056ac0d46 name=SOME_NAME displaytext="My Awesome Template"
```

Template creation should only take a few seconds. Note that the command above assumes the OS is **Ubuntu 10.04**, otherwise a different *ostype* is required. Ostype IDs can be discovered by:

```
vdc> list ostypes
```

A keyword may be provided to narrow the search, eg:

```
vdc> list ostypes keyword=12.04
```
