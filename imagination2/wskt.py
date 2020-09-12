import boto3
import json
import os

ddb = boto3.client('dynamodb')
table = os.environ['table']

def join(connection_id, room_id, name):
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

def handler(event, context):
    print(event)
    route_key = event['requestContext']['routeKey'] 
    connection_id = event['requestContext']['connectionId'] 
    if route_key == '$connect':
        return {
            'statusCode': 200,
            'body': '{}'
        }
    elif route_key == '$disconnect':
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

