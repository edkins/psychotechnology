import boto3
import json
import os
import random
import re
import string
import time

re_room = re.compile(r'^room/([a-zA-Z0-9]+)$')
ddb = boto3.client('dynamodb')
table = os.environ['table']

def random_id():
    chars = string.ascii_letters + string.digits
    size = 20
    return ''.join(random.SystemRandom().choice(chars) for _ in range(size))

def create_room(room_id):
    expiration = int(time.time()) + 4 * 3600
    ddb.put_item(
        TableName = table,
        Item = {
            'id': {'S':f'room/{room_id}'},
            'expiration': {'N':str(expiration)}
        }
    )

def get_room(room_id):
    response = ddb.get_item(
        TableName = table,
        Key = {
            'id': {'S':f'room/{room_id}'}
        },
        ProjectionExpression = 'id'
    )
    if 'Item' in response:
        return {
            'cookies': [],
            'isBase64Encoded': False,
            'statusCode': 200,
            'headers': {},
            'body': '{}'
        }
    else:
        return {
            'cookies': [],
            'isBase64Encoded': False,
            'statusCode': 404,
            'headers': {},
            'body': '{"message":"Not Found"}'
        }

def handler(event, context):
    method = event['requestContext']['http']['method']
    path = event['pathParameters']['path']
    if method == 'POST' and path == 'room':
        room_id = random_id()
        create_room(room_id)
        return {
            'cookies': [],
            'isBase64Encoded': False,
            'statusCode': 303,
            'headers': {
                'Location': f'/room/{room_id}'
            },
            'body': ''
        }
    elif method == 'GET':
        m = re_room.match(path)
        if m != None:
            return get_room(m.group(1))
    return {
        'cookies': [],
        'isBase64Encoded': False,
        'statusCode': 404,
        'headers': {},
        'body': '{"message":"Not Found"}'
    }

