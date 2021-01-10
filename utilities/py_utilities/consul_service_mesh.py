import os
from pprint import pprint
import sys

import requests


CONSUL_HTTP_TOKEN = os.environ.get('CONSUL_HTTP_TOKEN')
assert CONSUL_HTTP_TOKEN


HEALTH_URL = 'http://127.0.0.1:8500/v1/health/connect/%(service_name)s?connect=true&token=%(token)s'

ALLOCATIONS_URL = 'http://127.0.0.1:8500/v1/job/%(job_id)s/allocations?token=%(token)s'


def _print_health_resp(resp_data):
    for di in resp_data:
        result_di = {
            'Service.Proxy.LocalServiceAddress': di['Service']['Proxy']['LocalServiceAddress'],
            'Service.Proxy.LocalServicePort': di['Service']['Proxy']['LocalServicePort'],
            'Service.Proxy.Config.bind_address': di['Service']['Proxy']['Config']['bind_address'],
            'Service.Proxy.Config.bind_port': di['Service']['Proxy']['Config']['bind_port'],
            'Node.Address': di['Node']['Address'],
            'Node.TaggedAddresses': ','.join(set(di['Node']['TaggedAddresses'].values())),
            'Service.Address': di['Service']['Address'],
            'Service.Port': di['Service']['Port']
        }
        service_tagged_addrs = set()
        for key, addr_di in di['Service']['TaggedAddresses'].items():
            addr = f"{addr_di['Address']}:{addr_di['Port']}"
            service_tagged_addrs.add(addr)
        result_di['Service.TaggedAddresses'] = [s for s in service_tagged_addrs]
        pprint(result_di)

        print('--------------------------')
        listener_public_addr = f"{result_di['Service.Proxy.Config.bind_address']}:{result_di['Service.Proxy.Config.bind_port']}"
        print(f"public address of proxy mTLS listener: {listener_public_addr}")
        local_service_addr = f"{result_di['Service.Proxy.LocalServiceAddress']}:{result_di['Service.Proxy.LocalServicePort']}"
        print(f"local app address that proxy connects to: {local_service_addr}")


def get_service_nodes(service_name):
    health_url = HEALTH_URL % {
        'service_name': service_name, 'token': CONSUL_HTTP_TOKEN
    }
    resp = requests.get(health_url)
    if resp.status_code != 200:
        print(f"unexpected status_code from consul API: {resp.status_code}"); exit(1)
    node_names = [di['Node']['Node'] for di in resp.json()]
    return node_names


def get_job_allocations(job_id):
    health_url = HEALTH_URL % {'job_id': job_id, 'token': CONSUL_HTTP_TOKEN}
    resp = requests.get(health_url)
    if resp.status_code != 200:
        print(f"unexpected status_code from consul API: {resp.status_code}"); exit(1)
    return [di['ID'] for di in resp.json()]


def get_alloc_addresses(alloc_id):
    pass
    # run: nomad alloc status -json <alloc_id>
    # and parse json as:
    '''
    di['AllocatedResources']['Shared']['Ports']
[{'HostIP': '172.20.20.14', 'Label': 'http', 'To': 0, 'Value': 80}, {'HostIP': '172.20.20.14', 'Label': 'ui', 'To': 0, 'Value': 8080}, {'HostIP': '172.20.20.14', 'Label': 'api', 'To': 0, 'Value': 8081}]
    '''


def get_envoy_listener_info(service_name):
    pass
    # run: sudo docker ps  (or python docker client)
    # get id of container with prefix f"connect-proxy-{service_name}"
    # run: docker logs <id> and search for string 'public_listener'


def main(info_type, service_name):
    if info_type == 'health-info':
        return print_health(service_name)
    if info_type == 'nodes':
        node_names = get_service_nodes(service_name)
        print(' '.join(node_names))


def print_health(service_name):
    health_url = HEALTH_URL % {
        'service_name': service_name, 'token': CONSUL_HTTP_TOKEN
    }
    resp = requests.get(health_url)
    if resp.status_code != 200:
        print(f"unexpected status_code from consul API: {resp.status_code}")
        exit(1)
    _print_health_resp(resp.json())


if __name__ == '__main__':
    args = sys.argv[1:]
    if len(args) != 2:
        exit('expected two arguments "info_type" "service_name"')

    info_slug = args[0].strip().lower()
    service = args[1].strip().lower()
    main(info_slug, service)
