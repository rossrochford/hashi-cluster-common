import json
import os
import sys

import jinja2

from py_utilities.consul_kv import ConsulCli
from py_utilities.consul_kv__traefik import get_traefik_sidecar_upstreams
from py_utilities.util import sys_call


HOSTING_ENV = os.environ['HOSTING_ENV']
NODE_TYPE = os.environ['NODE_TYPE']


CONSUL_FILES_BASE = [
    ('/scripts/services/consul/conf/agent/base.hcl.tmpl', '/etc/consul.d/base.hcl'),
    '/scripts/services/consul/acl/policies/consul_agent_policy.hcl',
    '/scripts/services/consul/acl/policies/shell_policies/hashi_server_1_shell_policy.hcl',
    '/scripts/services/consul/acl/policies/shell_policies/read_only_policy.hcl',
    '/scripts/services/consul/acl/policies/shell_policies/traefik_shell_policy.hcl'
]
CONSUL_SERVER_FILES = CONSUL_FILES_BASE + [
    ('/scripts/services/consul/conf/agent/server.hcl.tmpl', '/etc/consul.d/server.hcl'),
]
CONSUL_CLIENT_FILES = CONSUL_FILES_BASE + [
    ('/scripts/services/consul/conf/agent/client.hcl.tmpl', '/etc/consul.d/client.hcl'),
]


FILES = {
    'ansible': {
        'gcp': [
            ('/scripts/build/ansible/auth.gcp.yml.tmpl', '/scripts/build/ansible/auth.gcp.yml'),
        ],
        'vagrant': [
            ('/scripts/build_vagrant/ansible/ansible_hosts.tmpl', '/etc/ansible/hosts')
        ]
    },
    'consul': {
        'hashi_server': CONSUL_SERVER_FILES,
        'hashi_client': CONSUL_CLIENT_FILES,
        'vault': CONSUL_CLIENT_FILES,
        'traefik': CONSUL_CLIENT_FILES
    },

    'traefik': [
        ('/scripts/services/traefik/conf/traefik-consul-service.json.tmpl', '/etc/traefik/traefik-consul-service.json'),

        # we'll maintain a json file with the latest routes, this is used by operations/traefik/fetch-service-routes.sh
        # ('/scripts/services/traefik/conf/traefik-service-routes.json.tmpl', '/etc/traefik/traefik-service-routes.json')
    ]
}


def do_template_render(template_fp, json_data):
    base_path, filename = template_fp.rsplit('/', 1)
    template_loader = jinja2.FileSystemLoader(searchpath=base_path)
    template_env = jinja2.Environment(loader=template_loader, lstrip_blocks=True)
    template = template_env.get_template(filename)

    return template.render(**json_data)


def render_templates(service, extra_args):

    if service == 'ansible':
        files = FILES['ansible'][HOSTING_ENV]
    elif service == 'consul':
        files = FILES['consul'][NODE_TYPE]
    else:
        files = FILES[service]

    if service == 'traefik':
        consul_cli = ConsulCli()
        data = {
            'sidecar_upstreams': get_traefik_sidecar_upstreams(consul_cli)[0]
        }
    else:
        with open('/etc/node-metadata.json') as f:
            data = json.loads(f.read())

    if service == 'ansible':
        # comma-separated list of instance names
        data['new_hashi_clients'] = extra_args[0].split(',') if extra_args else []

    if service == 'consul':
        stdout, _ = sys_call('go_discover consul-server', shell=True)
        data['consul_server_ips'] = stdout.split(' ')

    for filepath in files:
        target_path = filepath
        if type(filepath) is tuple:
            filepath, target_path = filepath

        rendered_tmpl = do_template_render(filepath, data)

        with open(target_path, 'w') as file:
            file.write(rendered_tmpl)


if __name__ == '__main__':
    service_slug = sys.argv[1]
    extra_args = sys.argv[2:]

    if service_slug not in ('ansible', 'consul'):
        if service_slug not in FILES:
            exit('unexpected service name: "%s"' % service_slug)

    render_templates(service_slug, extra_args)
