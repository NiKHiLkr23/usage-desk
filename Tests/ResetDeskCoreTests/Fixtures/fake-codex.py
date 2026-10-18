import json
import sys

def send(message):
    print(json.dumps(message), flush=True)

print('ignored diagnostic line', flush=True)
for line in sys.stdin:
    request = json.loads(line)
    method = request['method']
    if 'id' not in request:
        continue
    if method == 'account/read' and not isinstance(request.get('params'), dict):
        send({'id': request['id'], 'error': {'code': -32602, 'message': 'missing field params'}})
        continue
    params = request.get('params') or {}
    if params.get('mode') == 'hang':
        continue
    if params.get('mode') == 'error':
        send({'id': request['id'], 'error': {'code': -32000, 'message': '401 unauthorized private-token-should-never-surface'}})
        continue
    if params.get('mode') == 'exit':
        sys.exit(0)
    if method == 'initialize':
        result = {'userAgent': 'test'}
    elif method == 'account/read':
        result = {'account': {'type': 'chatgpt', 'email': 'fixture@example.test', 'planType': 'plus'}}
    elif method == 'account/rateLimits/read':
        result = {'rateLimits': {'limitId': 'codex', 'primary': {'usedPercent': 38, 'windowDurationMins': 300, 'resetsAt': 1900000000}}, 'rateLimitResetCredits': {'availableCount': 2, 'credits': None}}
    elif method == 'account/login/start':
        result = {'loginId': 'fake-login', 'authUrl': 'https://auth.openai.com/authorize?state=synthetic'}
    else:
        result = {}
    send({'id': request['id'], 'result': result})
    if method == 'account/login/start':
        send({'method': 'account/login/completed', 'params': {'loginId': 'fake-login', 'success': True}})
