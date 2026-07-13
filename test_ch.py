import clickhouse_connect, getpass
pw = getpass.getpass('Password: ')
c = clickhouse_connect.get_client(
    host='tplb1fkekn.eu-west-2.aws.clickhouse.cloud',
    port=8443, username='jh_dna_dev', password=pw,
    secure=True, verify=False)
print(c.query('SELECT 1').result_rows)
