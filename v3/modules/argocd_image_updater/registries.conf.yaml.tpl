registries:
  - name: aws
    prefix: ${aws_account_id}.dkr.ecr.${region}.amazonaws.com
    api_url: https://${aws_account_id}.dkr.ecr.${region}.amazonaws.com
    ping: true
    credentials:
      use_aws_sdk: true