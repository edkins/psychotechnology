import boto3
import json
import os

endpoint_url = os.environ['endpoint_url']
apigm = boto3.client('apigatewaymanagementapi', endpoint_url=endpoint_url)

def handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])
        op = body['op']
        print(f'Body = {body}')
        if op == 'post':
            cid = body['cid']
            data = json.dumps(body['msg']).encode('utf-8')
            print(f'Posting to connection {cid}')
            apigm.post_to_connection(Data=data, ConnectionId=cid)
        elif op == 'disconnect':
            cid = body['cid']
            apigm.delete_connection(ConnectionId=cid)
        else:
            raise Exception(f'Unrecognized operation {op}')
