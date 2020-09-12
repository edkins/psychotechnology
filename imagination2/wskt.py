def handler(event, context):
    print(event)
    if event['requestContext']['routeKey'] == '$connect':
        return {
            'statusCode': 200,
            'body': '{}'
        }
    else:
        return {}
