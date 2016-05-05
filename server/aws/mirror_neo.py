import sys
import os
import yaml

import boto3
import time

ec2 = boto3.resource('ec2')
client = boto3.client('ec2')

config_filename = sys.argv[1]

# check if config file exists
if not os.path.exists(config_filename):
    print("no such file '%s'" % config_filename)
    sys.exit(1)

# load configuration
with open(config_filename, "r") as f:
    conf = yaml.load(f)

response = client.create_image(
		DryRun=False,
		InstanceId=conf['neo4j']['instanceId'],
		Name='neo4j_mirror',
		Description='histograph neo4j mirror',
		NoReboot=True,
		BlockDeviceMappings=[
			{
				'DeviceName': '/dev/sdh',
				'Ebs': {
					'VolumeSize': 100,
					'DeleteOnTermination': False,
					'VolumeType': 'gp2',
					}
				}
			]
		)

image_id = response['ImageId']

if(image_id):
	print("Waiting for image to become available: " + image_id)
	waiter = client.get_waiter('image_available')
	waiter.wait(ImageIds=[image_id])

	#create new instance based on image_id
	instances = ec2.create_instances(
			DryRun=False,
			ImageId=image_id,
			MinCount=1,
			MaxCount=1,
			InstanceType="r3.large",
			NetworkInterfaces=[{
				'DeviceIndex': 0,
				'SubnetId': "subnet-71b36f0a", # production subnet
				'Groups': ["sg-baac24d3"],  # make it a singleton list
				'PrivateIpAddress': conf['neo4j']['ip-address'],
				'AssociatePublicIpAddress': True
			}]
	)

	inst = instances[0]
	print("Waiting for instance '%s' to start" % inst.id)

	waiter = client.get_waiter('instance_running')
	waiter.wait(InstanceIds=[inst.id])
	inst.create_tags(Tags=[{
		"Key" : "Name",
		"Value" : "neo4j_mirror"
	}])

	print("Instance '%s' running" % inst.id)
	print("Waiting for status ok")
	waiter = client.get_waiter('instance_status_ok')
	waiter.wait(InstanceIds=[inst.id])

	#TODO: clean up:
	# delete instance tagged 'neo4j_staging'
	# deregister image id
	# delete snapshots by image id
