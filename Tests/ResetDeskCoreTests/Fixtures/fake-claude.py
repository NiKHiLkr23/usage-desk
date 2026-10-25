import json
import os
import sys
import time

mode = sys.argv[1] if len(sys.argv) > 1 else 'success'
if mode == '-p':
    args = sys.argv[1:]
    assert args[args.index('--tools') + 1] == ''
    assert args[args.index('--setting-sources') + 1] == ''
    assert '--no-session-persistence' in args
    assert '--strict-mcp-config' in args
    assert json.loads(args[args.index('--mcp-config') + 1]) == {'mcpServers': {}}
    assert json.loads(args[args.index('--settings') + 1])['disableAllHooks'] is True
    assert os.path.basename(os.getcwd()).startswith('usage-desk-claude-')
    assert os.environ.get('USER'), 'Claude needs the macOS user context for Keychain sign-in'
    assert 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC' not in os.environ, 'The umbrella flag suppresses quota reads'
    for key in ['DISABLE_TELEMETRY', 'DISABLE_ERROR_REPORTING', 'DISABLE_AUTOUPDATER', 'DISABLE_FEEDBACK_COMMAND']:
        assert os.environ.get(key) == '1', 'Keep optional reporting and updates disabled'
    for key in ['ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX']:
        assert key not in os.environ
    mode = 'success'
for line in sys.stdin:
    msg = json.loads(line)
    assert msg['type'] == 'control_request', 'Never send a model prompt'
    request = msg['request']
    kind = request['subtype']
    assert kind in ['initialize', 'get_usage'], 'Only read controls are allowed'
    if mode == 'hang':
        time.sleep(10)
        continue
    if mode == 'exit':
        sys.exit(0)
    if mode == 'error':
        print(json.dumps({'type':'control_response','response':{'subtype':'error','request_id':msg['request_id'],'error':'private-token raw error'}}), flush=True)
        continue
    if kind == 'initialize':
        value = {'account': {'email': 'fixture@example.test', 'subscriptionType': 'pro'}}
    else:
        assert request.get('skip_behaviors') is True, 'Do not scan transcripts'
        value = {'subscription_type':'pro','rate_limits_available':True,'rate_limits':{
            'five_hour':{'utilization':25,'resets_at':'2099-01-01T12:00:00Z'},
            'seven_day':{'utilization':70,'resets_at':'2099-01-05T12:00:00.000Z'}}}
        if mode == 'null':
            value['rate_limits'] = None
        if mode == 'unsupported':
            value['rate_limits_available'] = False
            value['rate_limits'] = None
        if mode == 'malformed':
            value = {'unexpected':True}
    print(json.dumps({'type':'control_response','response':{'subtype':'success','request_id':msg['request_id'],'response':value}}), flush=True)
