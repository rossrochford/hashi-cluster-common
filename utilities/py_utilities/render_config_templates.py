import json
import os
import sys

import jinja2

from py_utilities.consul_kv import ConsulCli
from py_utilities.consul_kv__traefik import get_traefik_sidecar_upstreams
from py_utilities.util import sys_call


HOSTING_ENV = os.environ['HOSTING_ENV']
NODE_TYPE = os.environ['NODE_TYPE']


CONSUL_POLICY_FILES = [
    ('/scripts/services/consul/acl/policies/consul_agent_policy.hcl.tmpl', '/scripts/services/consul/acl/policies/consul_agent_policy.hcl'),
    ('/scripts/services/consul/acl/policies/shell_policies/hashi_server_1_shell_policy.hcl.tmpl', '/scripts/services/consul/acl/policies/shell_policies/hashi_server_1_shell_policy.hcl'),
    ('/scripts/services/consul/acl/policies/shell_policies/read_only_policy.hcl.tmpl', '/scripts/services/consul/acl/policies/shell_policies/read_only_policy.hcl'),
    ('/scripts/services/consul/acl/policies/shell_policies/traefik_shell_policy.hcl.tmpl', '/scripts/services/consul/acl/policies/shell_policies/traefik_shell_policy.hcl'),
]

FILES = {
    'ansible': {
        'gcp': [
            ('/scripts/build/ansible/auth.gcp.yml.tmpl', '/scripts/build/ansible/auth.gcp.yml'),
        ],
        'vagrant': [
            ('/scripts/build_vagrant/ansible/ansible_hosts.tmpl', '/etc/ansible/hosts')
        ],
        'lxd': [
            # ('/scripts/build_lxd/ansible/ansible_hosts.tmpl', '/etc/ansible/hosts')
        ]
    },
    'consul': CONSUL_POLICY_FILES,
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

    if service == 'env-vars-json':
        create_environment_variable_json_file()
        return

    if service == 'ansible':
        files = FILES['ansible'][HOSTING_ENV]
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

    if service == 'ansible' and extra_args:  # todo: revisit this
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


def create_environment_variable_json_file():
    if os.path.exists('/tmp/ansible-data/environment.json'):
        # to force regeneration, delete this file beforehand
        return
    if not os.path.exists('/etc/environment'):
        return
    with open('/etc/environment') as file:
        lines = [s.strip() for s in file.readlines()]
        env_variables = dict([tuple(s.split('=')) for s in lines])
        env_variables = {k: v.strip().strip('"') for (k, v) in env_variables.items()}

    with open('/tmp/ansible-data/environment.json', 'w') as file:
        file.write(
            json.dumps(env_variables)
        )


if __name__ == '__main__':
    service_slug = sys.argv[1]
    extra_args = sys.argv[2:]

    render_templates(service_slug, extra_args)
