import re

re_room = re.compile(r'room/([a-zA-Z0-9]+)')

def handler(event, context):
    path = event['pathParameters']['path']
    m = re_room.match(path)
    if m != None:
        return {
            'cookies': [],
            'isBase64Encoded': False,
            'statusCode': 200,
            'headers': {},
            'body': f'Hello from Lambda! {m.group(1)}'
        }
    else:
        return {
            'cookies': [],
            'isBase64Encoded': False,
            'statusCode': 404,
            'headers': {},
            'body': '{"message":"Not Found"}'
        }

