import boto3
from log import log
from time import sleep

ec2 = boto3.resource('ec2')
ec2client = boto3.client('ec2')


# start an instance and return IP
def create_ebs(conf, dryRun=true):

    if ( !(conf['id'] is None) && !(volume = ec2.Volume(conf['id']) is None) )
        return volume

    log("Creating EBS volume, size: %s" % conf['size'])
    response = ec2client.create_volume(
        DryRun=dryRun,
        Size=conf['size'],
#        SnapshotId= undef,
        AvailabilityZone=conf['availability-zone'],
        VolumeType=conf['type'], #'standard'|'io1'|'gp2',
#        Iops=123,
        Encrypted=conf['encrypted'],
#        KmsKeyId='string'
    )

    volume = ec2.Volume(response.VolumeId)

    log("Waiting for volume '%s' to be available" % volume.id)

    waiter = ec2client.get_waiter('volume_available')
    waiter.wait(VolumeIds=[volume.id])

    log("Volume '%s' is available" % volume.id)

    volume.load()

    return volume



# start an instance and return IP
def start_instance(user_data_str, conf, dryRun=true):

    log("Requesting instance, %d bytes userdata" % (len(user_data_str)))
    instances = ec2.create_instances(
        DryRun=dryRun,
        ImageId=conf['machine-image'],
        # KeyName=conf['keypair'],
        MinCount=1,
        MaxCount=1,
        NetworkInterfaces=[{
            'DeviceIndex': 0,
            'SubnetId': conf['subnet'],
            'Groups': [conf['security-group']],  # make it a singleton list
            'PrivateIpAddress': conf['ip-address'],
            'AssociatePublicIpAddress': True
        }],
        # BlockDeviceMappings=[{
        #     'VirtualName': 'api-upload',
        #     'DeviceName': '/dev/sdh',
        #     'Ebs': {
        #         'VolumeSize': 32,
        #         'DeleteOnTermination': False,
        #         'VolumeType': 'standard',
        #         'Encrypted': False
        #     }
        # }],
        InstanceType=conf['instance-type'],
        UserData=user_data_str
    )

    inst = instances[0]
    log("Waiting for instance '%s' to start" % inst.id)

    waiter = ec2client.get_waiter('instance_running')
    waiter.wait(InstanceIds=[inst.id])

    log("Instance '%s' running" % inst.id)

    inst.load()
    log("Address '%s' (%s)" % (inst.public_dns_name, inst.public_ip_address))

    return inst


def tag_instance(inst, project, name):
    t1 = {'Key': 'Name', 'Value': name}
    t2 = {'Key': 'Project', 'Value': project}
    response = ec2client.create_tags(Resources=[inst.id], Tags=[t1, t2])
    return response


def wait_for_console_output(inst):
    log("Waiting for console output")
    while(True):
        try:
            return inst.console_output()['Output']
        except:
            sleep(3)
            log('.')

def delete_instances(names):
    #get a list of all instances with 'staging' as part of the name
    instances = ec2.instances.filter(Filters=[{'Name': 'tag:Name', 'Values': names}])
    ids = []
    for instance in instances:
	       ids.append(instance.id)

    print("terminating instances: %s", ids)
    ec2.instances.filter(InstanceIds=ids).terminate()
