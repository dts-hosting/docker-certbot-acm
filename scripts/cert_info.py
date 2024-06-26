#!/usr/bin/python3
#
# Requirements:
# - boto3
# - click
#
# Either export AWS_PROFILE=... or run the command with an AWS_PROFILE specified.
#
# -----
#
# Installation:
#
#  python3 -m pip install boto3
#  python3 -m pip install click
#
# -----
#
# Usage: cert_info.py [OPTIONS] COMMAND [ARGS]...
#
# Options:
#  --help  Show this message and exit.
#
# Commands:
#  check
#  clean
#
# -----
#
# Usage: cert_info.py check [OPTIONS]
#
# Options:
#  -d, --dest TEXT    AWS destination region. (default: us-east-1)
#  -s, --source TEXT  AWS source region. (default: us-west-2)
#
# -----
#
# Usage: cert_info.py clean [OPTIONS]
#
# Options:
#  -a, --arns         Show ARNs in addition to domain names. (default: False)
#  -d, --delete       Delete certificates in ACM that are not used by load
#                     balancers. (default: False)
#  -r, --region TEXT  The AWS region to work in. (default: us-west-2)
#
# -----
#
# Usage: cert_info.py duplicates [OPTIONS]
#
# Options:
#  -d, --delete        Delete duplicate certificates. (default: False)
#  -r, --region TEXT   The AWS region to work in. (default: us-west-2)
#  -w, --wait INTEGER  Time in seconds to wait between dissociation and
#                      deletion of certificates. (default: 20)
#
import time

import boto3
import click


KEY_TYPES = ['RSA_1024', 'RSA_2048', 'RSA_3072', 'RSA_4096', 'EC_prime256v1', 'EC_secp384r1', 'EC_secp521r1']
LIST_CERTIFICATE_INCLUDES = {"Includes": {'keyTypes': KEY_TYPES}}


@click.group()
def cli():
  pass


def get_all_certs_in_region(aws_region):
  acm = boto3.client('acm', region_name=aws_region)

  response = acm.list_certificates(**LIST_CERTIFICATE_INCLUDES)
  certs = response['CertificateSummaryList']

  while 'NextToken' in response:
    response = acm.list_certificates(**LIST_CERTIFICATE_INCLUDES, NextToken=response['NextToken'])
    certs += response['CertificateSummaryList']

  return certs


# Method for just finding certs in use by load balancers, not *everything*.
def get_lb_cert_arns_by_region(aws_region):
  elb = boto3.client('elbv2', region_name=aws_region)
  response = elb.describe_load_balancers()
  certs = []
  for lb in response['LoadBalancers']:
    listeners = elb.describe_listeners(LoadBalancerArn=lb['LoadBalancerArn'])
    for listener in listeners['Listeners']:
      listener_certs = elb.describe_listener_certificates(ListenerArn=listener['ListenerArn'])
      if 'Certificates' in listener_certs:
        for cert in listener_certs['Certificates']:
          if 'CertificateArn' in cert:
            certs.append(cert['CertificateArn'])
  return certs


def get_lb_and_listener_by_cert_arn(aws_region):
  elb = boto3.client('elbv2', region_name=aws_region)
  response = elb.describe_load_balancers()
  certs = {}
  for lb in response['LoadBalancers']:
    listeners = elb.describe_listeners(LoadBalancerArn=lb['LoadBalancerArn'])
    for listener in listeners['Listeners']:
      listener_certs = elb.describe_listener_certificates(ListenerArn=listener['ListenerArn'])
      if 'Certificates' in listener_certs:
        for cert in listener_certs['Certificates']:
          if 'CertificateArn' in cert:
            certs[cert['CertificateArn']] = {"lb_arn": lb['LoadBalancerArn'], "listener_arn": listener['ListenerArn']}
  return certs


def get_unused_elb_certs(acm_certs, elb_cert_arns):
  unused_certs = []
  for cert in acm_certs:
    if cert['CertificateArn'] not in elb_cert_arns:
      unused_certs.append(cert)
  return unused_certs


def get_unused_certs_in_region(aws_region):
  certs = get_all_certs_in_region(aws_region)
  certs = [cert for cert in certs if cert['InUse'] == False]
  return certs
  

@cli.command(name='clean')
@click.option('--arns', '-a', 'show_arns', is_flag=True, default=False, help='Show ARNs in addition to domain names. (default: False)')
@click.option('--delete', '-d', 'delete_unused', is_flag=True, default=False, help='Delete certificates in ACM that are not used by load balancers. (default: False)')
@click.option('--region', '-r', 'aws_region', default='us-west-2', help='The AWS region to work in. (default: us-west-2)')
def find_unused_certs(show_arns, delete_unused, aws_region):
  unused_certs = get_unused_certs_in_region(aws_region)
  print(f"[*] Unused certificates in {aws_region}: {len(unused_certs)}")
  if show_arns:
    for cert in unused_certs:
      print(f"{cert['CertificateArn']} {cert['DomainName']}")
  else:
    for cert in unused_certs:
      print(cert['DomainName'])

  if delete_unused:
    acm = boto3.client('acm', region_name=aws_region)
    for cert in unused_certs:
      print(f"[-] Deleting {cert['DomainName']} with ARN {cert['CertificateArn']}")
      acm.delete_certificate(CertificateArn=cert['CertificateArn'])
      


@cli.command(name='check')
@click.option('--dest', '-d', 'dest_region', default='us-east-1', help='AWS destination region. (default: us-east-1)')
@click.option('--source', '-s', 'src_region', default='us-west-2', help='AWS source region. (default: us-west-2)')
def check_certs(src_region, dest_region):
  source_certs = get_all_certs_in_region(src_region)
  dest_certs = get_all_certs_in_region(dest_region)

  certs_already_copied = []
  different_cert_in_use = {}
  missing_from_dest = []
  for s_cert in source_certs:
    # Only consider certs imported from LetsEncrypt, not anything generated by ACM.
    if s_cert['Type'] != 'IMPORTED':
      continue

    for d_cert in dest_certs:
      if s_cert['DomainName'] == d_cert['DomainName'] and s_cert['CreatedAt'] == d_cert['CreatedAt']:
        certs_already_copied.append(s_cert)
      if s_cert['DomainName'] == d_cert['DomainName'] and d_cert['InUse'] == True and s_cert['InUse'] == True:
        different_cert_in_use[d_cert['CertificateArn']] = s_cert
    if s_cert['InUse'] == True and s_cert not in different_cert_in_use.values():
      missing_from_dest.append(s_cert)

  print(f"[*] Certificates that exist in {src_region} and {dest_region}: {len(certs_already_copied)}")
  for cert in certs_already_copied:
    print(f"{cert['CertificateArn']} {cert['DomainName']}")

  print(f"[*] Certificates in {src_region} with different certs in use in {dest_region}: {len(different_cert_in_use)}")
  for arn, cert in different_cert_in_use:
    print(f"{arn} {cert['DomainName']}")

  print(f"[*] Certificates in {src_region} missing from {dest_region}: {len(missing_from_dest)}")
  for cert in missing_from_dest:
    print(f"{cert['CertificateArn']} {cert['DomainName']}")

@cli.command(name="duplicates")
@click.option('--delete', '-d', 'delete_duplicates', is_flag=True, default=False, help='Delete duplicate certificates. (default: False)')
@click.option('--region', '-r', 'aws_region', default='us-west-2', help='The AWS region to work in. (default: us-west-2)')
@click.option('--wait', '-w', 'wait_time', default=20, help='Time in seconds to wait between dissociation and deletion of certificates. (default: 20)')
def find_duplicate_certs(delete_duplicates, aws_region, wait_time):
  elb = boto3.client('elbv2', region_name=aws_region)
  acm = boto3.client('acm', region_name=aws_region)
  certs = get_all_certs_in_region(aws_region)
  certs_by_lb = get_lb_and_listener_by_cert_arn(aws_region)
  cert_map = {}
  cert_arn_map = {}
  for cert in certs:
    if cert['DomainName'] in cert_map:
      cert_map[cert['DomainName']].append(cert)
    else:
      cert_map[cert['DomainName']] = [cert]
    if cert['CertificateArn'] in cert_arn_map:
      cert_arn_map[cert['CertificateArn']].append(cert)
    else:
      cert_arn_map[cert['CertificateArn']] = [cert]

  for domain, certs in cert_map.items():
    if len(certs) > 1:
      print(f"[*] {domain} has {len(certs)} certificates:")
      for index, cert in enumerate(certs):
        in_use = "✔️" if cert['InUse'] else "❌"
        if cert['CertificateArn'] in certs_by_lb:
          print(f"  - {in_use} [{certs_by_lb[cert['CertificateArn']]['lb_arn']}] {cert['CertificateArn']} {cert['DomainName']}")
          if index > 0 and delete_duplicates:
            elb.remove_listener_certificates(ListenerArn=certs_by_lb[cert['CertificateArn']]['listener_arn'], Certificates=[{'CertificateArn': cert['CertificateArn']}])
            time.sleep(wait_time)
            acm.delete_certificate(CertificateArn=cert['CertificateArn'])


if __name__ == '__main__':
  cli()

