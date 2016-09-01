import json
import os


from keystoneclient import session as ksc_session
from keystoneclient.auth.identity import v3
from keystoneclient.v3 import client as keystone_v3


class K2KClient(object):
    def __init__(self):
        # os sp id need set manually
        #self.sp_id = os.environ.get('OS_SP_ID')
        self.sp_id = 'keystone-sp'
        self.token_id = os.environ.get('OS_TOKEN')
        self.auth_url = os.environ.get('OS_AUTH_URL')
        self.project_id = os.environ.get('OS_PROJECT_ID')
        self.username = os.environ.get('OS_USERNAME')
        self.password = os.environ.get('OS_PASSWORD')
        #self.domain_id = os.environ.get('OS_DOMAIN_ID')
        self.domain = os.environ.get('OS_DOMAIN')


    def v3_authenticate(self):
        auth = v3.Password(auth_url=self.auth_url,
                           username=self.username,
                           password=self.password,
                           user_domain_id='default',
                           project_id=self.project_id)
        self.session = ksc_session.Session(auth=auth, verify=False)
        self.session.auth.get_auth_ref(self.session)
        self.token = self.session.auth.get_token(self.session)


    def _generate_token_json(self):
        return {
            "auth": {
                "identity": {
                    "methods": [
                        "token"
                    ],
                    "token": {
                        "id": self.token
                        #"id": "23fd45092e434d529bc7bb5fa9bdb711"
                    }
                },
                "scope": {
                    "service_provider": {
                        "id": self.sp_id
                    }
                }
            }
        }


    def _check_response(self, response):
        if not response.ok:
            raise Exception("Something went wrong, %s" % response.__dict__)


    def get_saml2_ecp_assertion(self):
        """ Exchange a scoped token for an ECP assertion. """
        token = json.dumps(self._generate_token_json())
        url = self.auth_url + '/auth/OS-FEDERATION/saml2/ecp'
        r = self.session.post(url=url, data=token, verify=False)
        self._check_response(r)
        self.assertion = str(r.text)


    def _get_sp(self):
        url = self.auth_url + '/OS-FEDERATION/service_providers/' + self.sp_id
        r = self.session.get(url=url, verify=False)
        self._check_response(r)
        sp = json.loads(r.text)[u'service_provider']
        return sp


    def _handle_http_302_ecp_redirect(self, session, response, location, method, **kwargs):
        #return session.get(location, authenticated=False, data=self.assertion, **kwargs)
        return session.get(location, authenticated=False, **kwargs)
        #return session.request(location, method, authenticated=False,
        #                       **kwargs)


    def exchange_assertion(self):
        """Send assertion to a Keystone SP and get token."""
        sp = self._get_sp()

        response = self.session.post(
            sp[u'sp_url'],
            headers={'Content-Type': 'application/vnd.paos+xml'},
            data=self.assertion,
            authenticated=False,
            redirect=False)
        self._check_response(response)

        #r = self._handle_http_302_ecp_redirect(r, sp[u'auth_url'],
        #                                       headers={'Content-Type':
        #                                       'application/vnd.paos+xml'})
        r = self._handle_http_302_ecp_redirect(self.session, response, sp[u'auth_url'],
                                               method='GET',
                                               headers={'Content-Type':
                                               'application/vnd.paos+xml'})
        self.fed_token_id = r.headers['X-Subject-Token']
        self.fed_token = r.text




def main():
    client = K2KClient()
    client.v3_authenticate()
    client.get_saml2_ecp_assertion()
    print('ECP wrapped SAML assertion: %s' % client.assertion)
    client.exchange_assertion()
    print('Unscoped token id: %s' % client.fed_token_id)


if __name__ == "__main__":
    main()
