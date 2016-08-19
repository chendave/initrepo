'''
Created on 2016 y 8 m 14 d

@author: wchen106
'''
import uuid
import json
import urllib2
from oauthlib import oauth1
from six.moves import urllib
from keystone.oauth1.backends.sql import Consumer


def _urllib_parse_qs_text_keys(content):
    results = urllib.parse.parse_qs(content)
    return {key.decode('utf-8'): value for key, value in results.items()}

class Token(object):
    def __init__(self, key, secret):
        self.key = key
        self.secret = secret
        self.verifier = None

    def set_verifier(self, verifier):
        self.verifier = verifier

class OAuth(object):

    def __init__(self):
        pass

    def _create_consumer(self):
        #endpoint = 'http://10.239.159.68/identity_v2_admin/v3/OS-OAUTH1/consumers'
        endpoint = 'http://10.239.48.152:35357/v3/OS-OAUTH1/consumers'
        body = {'consumer':{'description': uuid.uuid4().hex}}
        data = json.dumps(body)
        request = urllib2.Request(endpoint, data)
        request.add_header('X-Auth-Token', 'db310df0df564a6cba21d865d4f3f7b8')
        request.add_header('Content-Type', 'application/json')
        response = urllib2.urlopen(request)
        return json.load(response)['consumer']

    # reference: http://blog.chinaunix.net/uid-26000296-id-4394470.html
    # try this one: http://www.cnblogs.com/qq78292959/archive/2013/04/01/2993127.html
    def _create_request_token(self, consumer):
        # NOTE(davechen): Not sure why endpoint 'identity_v2_admin' cannot get get the request
        # projet id from the header, this is very tricky and maybe related with apache2.
        # endpoint with http port should be pass and I just tested it with uwsgi model on the
        # machine in the lab.
        #endpoint = 'http://10.239.159.68/identity_v2_admin/v3/OS-OAUTH1/request_token'
        endpoint = 'http://10.239.48.152:35357/v3/OS-OAUTH1/request_token'
        project_id = 'e54f0e44a9a04f408a72b7b06639a57b'
        client = oauth1.Client(consumer['key'],
                               client_secret=consumer['secret'],
                               signature_method=oauth1.SIGNATURE_HMAC,
                               callback_uri="oob")
        headers = {'requested_project_id': project_id}
        url, headers, body = client.sign(endpoint,
                                         http_method='POST',
                                         headers=headers)
        # headers is now looks like the below:
        #{u'Authorization': u'OAuth oauth_nonce="38702257708668034711471170765", 
        # oauth_timestamp="1471170765", oauth_version="1.0", oauth_signature_method="HMAC-SHA1", 
        # oauth_consumer_key="dd20510f276740cd94232caa4cdfbdb4", oauth_callback="oob",
        # oauth_signature="ji7t%2BeN0G0A73iX7b4FgCWX5DGQ%3D"', u'requested_project_id': u'caaa06cf868e44c2882623afd34eea60'}
        request = urllib2.Request(endpoint)
        # HTTP header required it to be 'str' on both PY2 and PY3.
        headers = {str(k): str(v) for k, v in headers.items()}
        request.headers = headers
        request.add_header('response_content_type', 'application/x-www-form-urlencoded')
        request.get_method = lambda:'POST'
        # FXIME(davechen): cannot the get the request project id.
        # 'HTTP_REQUESTED_PROJECT_ID': '0feada3b57f145ad951b19af390dca09'
        # The above issue can be fixed by using the endpoint with http port and under uwsgi model.
        response = urllib2.urlopen(request)
        # (Pdb) p response.read()
        # 'oauth_token=757bcba900ec42e788b3023adf6b6ec8&oauth_token_secret=1d6ba3b092f8496ca87e1b84746261e0
        # &oauth_expires_at=2016-08-18T15:57:15.172100Z'
        return response.read()

    def _authorize_request_token(self, request_id):
        endpoint = 'http://10.239.48.152:35357/v3/OS-OAUTH1/authorize/%s' % (request_id)
        # admin role id
        role_id = '86fe49c8b5c041b891c18fbb27e240c8'
        body = {'roles': [{'id': role_id}]}
        data = json.dumps(body)
        request = urllib2.Request(endpoint, data)
        request.add_header('X-Auth-Token', 'db310df0df564a6cba21d865d4f3f7b8')
        request.add_header('Content-Type', 'application/json')
        request.get_method = lambda:'PUT'
        resp = urllib2.urlopen(request)
        verifier = json.load(resp)['token']['oauth_verifier']
        # The length should be 8.
        # '{"token": {"oauth_verifier": "4uVtQvFr"}}'
        print (len(verifier))
        return verifier

    def _create_access_token(self, consumer, token):
        endpoint = 'http://10.239.48.152:35357/v3/OS-OAUTH1/access_token'
        client = oauth1.Client(consumer['key'],
                               client_secret=consumer['secret'],
                               resource_owner_key=token.key,
                               resource_owner_secret=token.secret,
                               signature_method=oauth1.SIGNATURE_HMAC,
                               verifier=token.verifier)
        # TODO(davechen): Since there is no headers to be signed, check this with the standard;
        # check the headers that is returned.
        url, headers, body = client.sign(endpoint,
                                         http_method='POST')
        headers.update({'Content-Type': 'application/json'})

        request = urllib2.Request(endpoint)
        request.headers = headers
        request.add_header('response_content_type', 'application/x-www-form-urlencoded')
        request.get_method = lambda:'POST'
        response = urllib2.urlopen(request)
        return response.read()

    def _get_oauth_token(self, consumer, token):
        client = oauth1.Client(consumer['key'],
                               client_secret=consumer['secret'],
                               resource_owner_key=token.key,
                               resource_owner_secret=token.secret,
                               signature_method=oauth1.SIGNATURE_HMAC)
        endpoint = 'http://10.239.48.152:35357/v3/auth/tokens'
        url, headers, body = client.sign(endpoint,
                                         http_method='POST')
        # This will cause the headers for 't' is upper case, which will not pass
        # (Pdb) p request.headers
        #headers.update({'Content-Type': 'application/json'})

        ref = {'auth': {'identity': {'oauth1': {}, 'methods': ['oauth1']}}}
        data = json.dumps(ref)
        request = urllib2.Request(endpoint, data)
        request.headers = headers
        # This will cause the headers for 't' is lower case
        # (Pdb) p request.headers
        # {'Content-type': 'application/json'...
        request.add_header('Content-Type', 'application/json')
        request.get_method = lambda:'POST'
        response = urllib2.urlopen(request)
        return response

    def _test_generic_token(self):
        endpoint = 'http://10.239.48.152:35357/v3/auth/tokens'
        ref = {'auth': {'identity': {'password': {'user': {'name': 'admin', 'domain': {'id': 'default'}, 'password': "zaq12wsx"}}, 'methods': ['password']}}}
        data = json.dumps(ref)
        request = urllib2.Request(endpoint, data)
        request.add_header('Content-Type', 'application/json')
        request.get_method = lambda:'POST'
        response = urllib2.urlopen(request)
        print response.read()

    def verify_oauth(self):
        # create consumer
        consumer = self._create_consumer()
        consumer_id = consumer['id']
        consumer_secret = consumer['secret']
        self.consumer = {'key': consumer_id, 'secret': consumer_secret}

        # create request token
        # AttributeError: 'OAuth' object has no attribute 'base_url'
        request_token_raw = self._create_request_token(self.consumer)
        credentials = _urllib_parse_qs_text_keys(request_token_raw)
        request_key = credentials['oauth_token'][0]
        request_secret = credentials['oauth_token_secret'][0]

        self.request_token = Token(request_key, request_secret)
    
        # authorize the request token.
        verifier = self._authorize_request_token(request_key)
        self.request_token.set_verifier(verifier)
        
        # create access token
        access_token_raw = self._create_access_token(self.consumer,
                                                     self.request_token)
        credentials = _urllib_parse_qs_text_keys(access_token_raw)
        access_key = credentials['oauth_token'][0]
        access_secret = credentials['oauth_token_secret'][0]
        self.access_token = Token(access_key, access_secret)

        # generate the oauth1 token
        token_raw = self._get_oauth_token(self.consumer,
                                         self.access_token)
        self.keystone_token_id = token_raw.headers.get('X-Subject-Token')
        # NOTE(davechen): The token generated can be used normally as other tokens.
        print self.keystone_token_id
        self.keystone_token = json.load(token_raw)['token']

if __name__ == '__main__':
    inst = OAuth()
    inst.verify_oauth()