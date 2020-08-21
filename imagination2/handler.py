import boto3
import random
import re
import string

re_room = re.compile(r'^room/([a-zA-Z0-9]+)$')

def random_id():
    chars = string.ascii_letters + string.digits
    size = 20
    return ''.join(random.SystemRandom().choice(chars) for _ in range(size))

def handler(event, context):
    method = event['requestContext']['http']['method']
    path = event['pathParameters']['path']
    if method == 'POST' and path == 'room':
        room_id = random_id()
        return {
            'cookies': [],
            'isBase64Encoded': False,
            'statusCode': 200,
            'headers': {},
            'body': f'Your randomly generated id is {room_id}'
        }
    elif method == 'GET':
        m = re_room.match(path)
        if m != None:
            return {
                'cookies': [],
                'isBase64Encoded': False,
                'statusCode': 200,
                'headers': {},
                'body': f'Hello from Lambda! {m.group(1)}'
            }
    return {
        'cookies': [],
        'isBase64Encoded': False,
        'statusCode': 404,
        'headers': {},
        'body': '{"message":"Not Found"}'
    }

