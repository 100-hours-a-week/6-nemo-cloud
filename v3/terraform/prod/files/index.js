const AWS = require('aws-sdk');
const ec2 = new AWS.EC2();

exports.handler = async function (event) {
  const action = process.env.ACTION || 'stop';
  const instanceIds = (process.env.INSTANCE_IDS || '').split(',');

  if (!instanceIds.length || !instanceIds[0]) {
    return { status: 'No instance IDs provided' };
  }

  try {
    if (action === 'start') {
      await ec2.startInstances({ InstanceIds: instanceIds }).promise();
      return { status: 'Started', instanceIds };
    } else if (action === 'stop') {
      await ec2.stopInstances({ InstanceIds: instanceIds }).promise();
      return { status: 'Stopped', instanceIds };
    } else {
      return { status: 'Invalid action', action };
    }
  } catch (err) {
    console.error(err);
    return { status: 'Error', error: err.message };
  }
};