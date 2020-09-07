import base64
import boto3
import os
import re

re_room = re.compile(r'^/room/([a-zA-Z0-9]+)$')

def get_binary(name, content_type):
    s3 = boto3.client('s3')
    bucket = os.environ['bucket']
    body = s3.get_object(Bucket=bucket, Key=name)['Body'].read()
    return {
        'cookies': [],
        'isBase64Encoded': True,
        'statusCode': 200,
        'headers': {
            'Content-Type': content_type
        },
        'body': base64.encodebytes(body).decode('utf-8')
    }

def get_text(name, content_type):
    s3 = boto3.client('s3')
    bucket = os.environ['bucket']
    body = s3.get_object(Bucket=bucket, Key=name)['Body'].read().decode('utf-8')
    return {
        'cookies': [],
        'isBase64Encoded': False,
        'statusCode': 200,
        'headers': {
            'Content-Type': content_type
        },
        'body': body
    }

def handler(event, context):
    path = event['requestContext']['http']['path']
    method = event['requestContext']['http']['method']
    if method == 'GET':
        if re_room.match(path) or path == '/':
            return get_text('index.html', 'text/html')
        elif path == '/favicon.ico':
            return get_binary('favicon.ico', 'image/png')
    return {
        'cookies': [],
        'isBase64Encoded': False,
        'statusCode': 404,
        'headers': {},
        'body': '{"message":"Not Found"}'
    }

