import boto3
import json
import os
import time

ddb = boto3.client('dynamodb')
table = os.environ['table']

def join(connection_id, room_id, name):
    print(f'Joining connection_id {connection_id}, room_id {room_id}, name {name}')
    expiration = int(time.time()) + 4 * 3600
    ddb.put_item(
        TableName = table,
        Item = {
            'id': {'S':f'connection/{connection_id}'},
            'expiration': {'N':str(expiration)},
            'room': {'S':room_id}
        }
    )
    ddb.update_item(
        TableName = table,
        Key = {
            'id': {'S':f'room/{room_id}'}
        },
        UpdateExpression = 'SET connections.#conid = :me',
        ExpressionAttributeNames = {
            '#conid': connection_id
        },
        ExpressionAttributeValues = {
            ':me': {
                'M': {
                    'name': {'S':name}
                }
            }
        }
    )

def disconnect(connection_id):
    response = ddb.get_item(
        TableName = table,
        Key = {
            'id': {'S':f'connection/{connection_id}'}
        },
        ProjectionExpression = 'room'
    )
    if 'Item' in response:
        print(response['Item'])
        room_id = response['Item']['room']['S']
        print(f'Disconnecting: connection_id {connection_id}, room_id {room_id}')
        ddb.update_item(
            TableName = table,
            Key = {
                'id': {'S':f'room/{room_id}'}
            },
            UpdateExpression = 'REMOVE connections.#conid',
            ExpressionAttributeNames = {
                '#conid': connection_id
            }
        )
        ddb.delete_item(
            TableName = table,
            Key = {
                'id': {'S':f'connection/{connection_id}'}
            }
        )
    else:
        print(f'Disconnecting: connection_id {connection_id}, no room_id')

def handler(event, context):
    print(event)
    route_key = event['requestContext']['routeKey'] 
    connection_id = event['requestContext']['connectionId'] 
    if route_key == '$connect':
        print('Connecting connection_id {connection_id}')
        return {
            'statusCode': 200,
            'body': '{}'
        }
    elif route_key == '$disconnect':
        disconnect(connection_id)
        return {}
    elif route_key == '$default':
        body = json.loads(event['body'])
        action = body['action']
        room_id = body['room_id']
        if action == 'join':
            join(connection_id, room_id, body['name'])
        else:
            raise Exception(f'Unrecognized action: {action}')
        return {}
    else:
        raise Exception(f'Unrecognized route key: {route_key}')

