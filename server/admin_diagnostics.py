"""Explicit projections for the private admin console. Never serialize DB rows wholesale."""
import json


def overview(store, settings):
    with store.tx() as db:
        jobs = []
        for row in db.execute('SELECT id,owner,request_id,state,result,expires FROM jobs ORDER BY rowid DESC LIMIT 50'):
            entry = {k: row[k] for k in ('id', 'owner', 'request_id', 'state', 'expires')}
            entry['items'] = []
            try:
                result = json.loads(row['result'] or 'null')
            except (ValueError, TypeError):
                result = None
            claims = {r['item']: r['state'] for r in db.execute('SELECT item,state FROM claims WHERE job=?', (row['id'],))}
            if isinstance(result, list):
                from app import quality_fields
                for item in result[:20]:
                    if not isinstance(item, dict):
                        continue
                    try:
                        quality = quality_fields(item)
                    except ValueError:
                        quality = quality_fields({})
                    entry['items'].append({'id': str(item.get('id', ''))[:128],
                        'category': str(item.get('category', ''))[:100],
                        'enhancement_state': claims.get(item.get('id'), 'not_requested'), **quality})
            jobs.append(entry)
        operations = [dict(r) for r in db.execute('SELECT id,owner,amount,state FROM operations ORDER BY rowid DESC LIMIT 100')]
        operations += [dict(r) for r in db.execute('SELECT id,owner,amount,state FROM period_operations ORDER BY rowid DESC LIMIT 100')]
        return {'jobs': jobs, 'operations': operations,
            'errors': [dict(r) for r in db.execute('SELECT job,item,stage,outcome,code,created FROM inference_audit WHERE outcome=\'failed\' ORDER BY rowid DESC LIMIT 50')],
            'enhancement_audit': [dict(r) for r in db.execute('SELECT job,item,stage,outcome,code,category,source_hash,reference_hash,created FROM inference_audit ORDER BY rowid DESC LIMIT 100')],
            'token_balances': [dict(r) for r in db.execute('SELECT owner,balance FROM style_tokens ORDER BY owner LIMIT 100')],
            'token_load_history': [dict(r) for r in db.execute('SELECT id,owner,amount,created,state FROM token_load_requests ORDER BY created DESC LIMIT 100')],
            'settings': {'inference_enabled': settings.enabled, 'enhancement_tokens_per_item': 2,
                'max_image_bytes': settings.max_image_bytes, 'session_ttl_seconds': settings.session_ttl_seconds,
                'max_storage_bytes': settings.max_storage_bytes,
                'github_login_configured': bool(settings.github_client_id and settings.github_client_secret),
                'provider_calls_on_refresh': False},
            'limits': {'jobs': 50, 'operations_per_ledger': 100, 'history': 100},
            'notice': 'Bounded diagnostics; category and mask completeness are not semantically verified.'}
