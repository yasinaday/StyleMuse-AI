"""Official fal queue contract, network-free transport fixture."""
import pytest
from virtual_tryon import VirtualTryOn, TryOnError

def test_poll_uses_parent_endpoint_and_no_post(monkeypatch):
    p = VirtualTryOn('fixture-not-a-key')
    calls = []
    def request(method, url, **kw):
        calls.append((method, url))
        return {'status':'COMPLETED'} if url.endswith('/status') else {'images':[{'url':'https://fal.media/result.png'}]}
    monkeypatch.setattr(p, '_request', request)
    assert p.poll('rid') == 'https://fal.media/result.png'
    assert calls == [('GET','https://queue.fal.run/fal-ai/image-apps-v2/requests/rid/status'),
                     ('GET','https://queue.fal.run/fal-ai/image-apps-v2/requests/rid')]

@pytest.mark.parametrize('url', ['http://fal.media/x', 'https://localhost/x','https://fal.media.evil.test/x','https://user:pass@fal.media/x','https://fal.media:444/x'])
def test_untrusted_result_is_rejected(monkeypatch, url):
    p = VirtualTryOn('fixture')
    monkeypatch.setattr(p, '_request', lambda method, u: {'status':'COMPLETED'} if u.endswith('/status') else {'images':[{'url':url}]})
    with pytest.raises(TryOnError): p.poll('rid')

def test_real_provider_fal_balance_routes_tryon_to_same_read_only_gate(monkeypatch):
    from providers import RealProviders
    p = RealProviders('fixture','fixture')
    calls=[]
    def request(*args, **kw):
        calls.append(args)
        return {'credits':{'current_balance':1,'currency':'USD'}}
    monkeypatch.setattr(p, '_json', request)
    assert p.credit_available_usd('tryon') == 1
    assert calls[0][0] == 'GET'
